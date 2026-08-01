import sqlite3
import json
import google.generativeai as genai
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import time
import logging
import random
import threading
import requests
from urllib.parse import quote_plus
from datetime import datetime
from translation import translate_text, translate_batch
from playwright.sync_api import sync_playwright
import tempfile

import os
from dotenv import load_dotenv

# Typed upstream errors (429 / 400 / 5xx). Optional import so the app still
# starts if google-api-core is not present; we fall back to string matching.
try:
    from google.api_core import exceptions as gapi_exceptions
except ImportError:  # pragma: no cover
    gapi_exceptions = None

# Load environment variables from project root .env file
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))


# ---------------------------------------------------------------------------
# AI error taxonomy
#
# The whole point: a *bad prompt* and a *dead API key* are different failures
# and must be handled differently. Previously every exception was blamed on the
# key, which benched healthy keys and burned the retry budget on prompts that
# could never succeed.
# ---------------------------------------------------------------------------
class AIError(Exception):
    """Base class for AI-layer failures."""


class AIPromptError(AIError):
    """The request itself is the problem (400 / safety-blocked / empty
    candidate). Switching keys or retrying cannot help — fail fast."""


class AIQuotaExhausted(AIError):
    """Every key is rate-limited or out of quota. The caller should retry
    later (HTTP 429)."""


class AIUnavailable(AIError):
    """Upstream is transiently unavailable (5xx / timeout) after retries
    (HTTP 503)."""


class AIConfigError(AIError):
    """No usable API keys are configured."""


class EducationBot:
    def __init__(self):
        # Logging first: setup_ai now logs (and can raise a clear config error).
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        self.setup_ai()
        self.init_database()

    def get_db_path(self):
        """Get the absolute path to the database file in the backend directory"""
        return os.path.join(os.path.dirname(__file__), 'users.db')

    def setup_ai(self):
        # ---- keys -----------------------------------------------------------
        self.api_keys = [os.getenv(f'GEMINI_API_KEY_{i}') for i in range(1, 5)]
        self.api_keys = [key for key in self.api_keys if key]
        if not self.api_keys:
            # Previously this produced a ZeroDivisionError deep inside the retry
            # loop (modulo by an empty key list). Fail loudly and legibly.
            raise AIConfigError(
                'No GEMINI_API_KEY_* found in the environment. Set at least one '
                'in the project .env before starting the server.'
            )

        self.current_api_index = 0
        self.model = None
        self.current_model_name = None
        # api_key -> (cooldown_until_ts, consecutive_failures)
        self.api_failures = {}

        # ---- model pinning ---------------------------------------------------
        # Resolved ONCE and cached. We no longer probe list_models() and burn a
        # throwaway generate_content("Test") on every rebind — that cost a billed
        # call per candidate and made the served model non-deterministic.
        # NOTE: list_models() cannot be trusted for validity — it still advertises
        # models/gemini-2.0-flash, which now 404s on generateContent ("no longer
        # available"). So we pin a known-current model and treat a 404 as a
        # signal to re-resolve, rather than trusting the advertised catalogue.
        env_model = os.getenv('GEMINI_MODEL')
        self.preferred_models = ([env_model] if env_model else []) + [
            'models/gemini-2.5-flash',       # current, fast, good JSON adherence
            'models/gemini-flash-latest',    # always-current alias
            'models/gemini-2.5-flash-lite',  # cheapest / highest free-tier quota
            'models/gemini-3.5-flash',
            'models/gemini-2.5-pro',
        ]

        # ---- concurrency -----------------------------------------------------
        # All shared-state mutation goes through this lock. The web report page
        # fires 11 sections in parallel against this single instance, so the old
        # lock-free mutation of self.model / self.current_api_index was a real race.
        self._lock = threading.RLock()
        # Cap in-flight Gemini calls so our own fan-out stops manufacturing the
        # 429s that the rotation logic then has to defend against.
        limit = max(1, int(os.getenv('GEMINI_MAX_CONCURRENCY', '4')))
        self._slots = threading.BoundedSemaphore(limit)
        self._max_transient_retries = 3

        self.logger.info(
            f'AI ready — {len(self.api_keys)} API key(s), max concurrency {limit}'
        )

    # -- error classification -------------------------------------------------

    def _classify(self, exc):
        """Categorise an upstream failure.

        Returns one of: 'quota' | 'transient' | 'prompt' | 'auth' | 'model'.
        This is the crux: a bad prompt must NOT be blamed on the API key.
        """
        if isinstance(exc, AIPromptError):
            return 'prompt'

        if gapi_exceptions is not None:
            if isinstance(exc, gapi_exceptions.ResourceExhausted):
                return 'quota'
            if isinstance(exc, (gapi_exceptions.ServiceUnavailable,
                                gapi_exceptions.InternalServerError,
                                gapi_exceptions.DeadlineExceeded,
                                gapi_exceptions.Aborted)):
                return 'transient'
            if isinstance(exc, gapi_exceptions.InvalidArgument):
                return 'prompt'
            if isinstance(exc, (gapi_exceptions.PermissionDenied,
                                gapi_exceptions.Unauthenticated)):
                return 'auth'
            if isinstance(exc, gapi_exceptions.NotFound):
                return 'model'

        msg = str(exc).lower()
        if any(s in msg for s in ('429', 'quota', 'rate limit', 'resource_exhausted')):
            return 'quota'
        if any(s in msg for s in ('safety', 'blocked', 'finish_reason', 'candidate')):
            return 'prompt'
        if any(s in msg for s in ('403', 'permission', 'unauthenticated', 'api key not valid')):
            return 'auth'
        if any(s in msg for s in ('404', 'not found')):
            return 'model'
        if any(s in msg for s in ('500', '503', 'unavailable', 'timeout', 'deadline')):
            return 'transient'
        if any(s in msg for s in ('400', 'invalid')):
            return 'prompt'
        return 'transient'

    def _extract_text(self, response):
        """Pull text out of a response, turning safety-blocks / empty candidates
        into AIPromptError — a *prompt* problem, not an API-key problem.

        (`response.text` raises when the candidate was blocked; the old code
        swallowed that and rotated keys, benching perfectly healthy ones.)
        """
        feedback = getattr(response, 'prompt_feedback', None)
        block_reason = getattr(feedback, 'block_reason', None) if feedback else None
        if block_reason:
            raise AIPromptError(f'Prompt blocked by a safety filter ({block_reason}).')
        try:
            text = response.text
        except Exception as e:
            raise AIPromptError(f'Model returned no usable candidate ({e}).')
        if not text or not text.strip():
            raise AIPromptError('Model returned an empty response.')
        return text

    # -- key / model binding (all callers must hold self._lock) ----------------

    def _key_available_locked(self, idx):
        key = self.api_keys[idx]
        entry = self.api_failures.get(key)
        if not entry:
            return True
        until, _ = entry
        if time.time() >= until:
            del self.api_failures[key]
            return True
        return False

    def _pick_key_locked(self):
        n = len(self.api_keys)
        for offset in range(n):
            idx = (self.current_api_index + offset) % n
            if self._key_available_locked(idx):
                self.current_api_index = idx
                return self.api_keys[idx]
        raise AIQuotaExhausted(
            'All Gemini API keys are rate-limited or exhausted. Try again shortly.'
        )

    def _resolve_model_name_locked(self):
        """Resolve the model id once, preferring the pinned list. list_models()
        is consulted at most once per process — never a test generation."""
        if self.current_model_name:
            return self.current_model_name

        available = set()
        try:
            available = {
                m.name for m in genai.list_models()
                if 'generateContent' in getattr(m, 'supported_generation_methods', [])
            }
        except Exception as e:
            self.logger.warning(f'Could not list models ({e}); trusting the pinned model.')

        for candidate in self.preferred_models:
            if not candidate:
                continue
            name = candidate if candidate.startswith('models/') else f'models/{candidate}'
            if not available or name in available:
                self.current_model_name = name
                self.logger.info(f'Using Gemini model: {name}')
                return name

        if available:
            name = sorted(available)[0]
            self.logger.warning(f'No preferred model available; falling back to {name}')
            self.current_model_name = name
            return name

        raise AIUnavailable('No Gemini model supporting generateContent is available.')

    def _bind_locked(self):
        key = self._pick_key_locked()
        genai.configure(api_key=key)
        name = self._resolve_model_name_locked()
        self.model = genai.GenerativeModel(name)
        self.logger.info(
            f'Bound model {name} to API key #{self.current_api_index + 1}'
        )
        return self.model

    def _penalise_key_locked(self, idx, base_seconds):
        """Bench a key with an exponential, capped cooldown (was a flat 5 min,
        which is both too long for a blip and too short for a daily quota)."""
        key = self.api_keys[idx]
        _, fails = self.api_failures.get(key, (0, 0))
        fails += 1
        cooldown = min(base_seconds * (2 ** (fails - 1)), 900)  # cap 15 min
        self.api_failures[key] = (time.time() + cooldown, fails)
        self.logger.warning(
            f'API key #{idx + 1} benched for {int(cooldown)}s (failure #{fails})'
        )
        if self.current_api_index == idx:
            self.model = None  # force a rebind onto a healthy key

    def _log_usage(self, response, idx, model_name):
        # Never log key material (the old code printed the first 8 chars of the
        # live API key on every single call).
        usage = getattr(response, 'usage_metadata', None)
        if usage:
            self.logger.info(
                f'[EduBot] key #{idx + 1} | model {model_name} | tokens '
                f'prompt={getattr(usage, "prompt_token_count", "?")} '
                f'output={getattr(usage, "candidates_token_count", "?")} '
                f'total={getattr(usage, "total_token_count", "?")}'
            )
        else:
            self.logger.info(f'[EduBot] key #{idx + 1} | model {model_name}')

    # -- the public entry point ------------------------------------------------

    def generate_with_fallback(self, prompt, max_retries=None):
        """Generate content, rotating keys ONLY for key-level failures.

          quota (429)         -> bench this key, rotate to the next healthy key
          transient (5xx)     -> retry the SAME key with exponential backoff+jitter
          prompt (400/safety) -> fail fast; another key cannot fix a bad prompt
          auth (401/403)      -> bench the key hard, rotate
          model (404)         -> re-resolve the model id, rebind

        Every key gets a turn (the old code hard-coded 3 retries against a pool
        that has since grown to 4 keys, so key #4 was never reachable).
        """
        last_exc = None

        with self._slots:  # throttle our own fan-out
            for _ in range(len(self.api_keys)):
                with self._lock:
                    model = self.model or self._bind_locked()
                    idx = self.current_api_index
                    model_name = self.current_model_name

                for attempt in range(self._max_transient_retries):
                    try:
                        response = model.generate_content(prompt)
                        self._extract_text(response)  # raises AIPromptError on block/empty
                        self._log_usage(response, idx, model_name)
                        with self._lock:
                            self.api_failures.pop(self.api_keys[idx], None)
                        return response

                    except AIPromptError:
                        raise  # not the key's fault — do not rotate, do not retry

                    except Exception as e:
                        last_exc = e
                        kind = self._classify(e)
                        self.logger.warning(
                            f'Gemini error on key #{idx + 1} [{kind}]: {e}'
                        )

                        if kind == 'transient' and attempt < self._max_transient_retries - 1:
                            delay = (2 ** attempt) + random.uniform(0, 0.5)
                            time.sleep(delay)
                            continue

                        if kind == 'model':
                            with self._lock:
                                self.current_model_name = None
                                self.model = None
                            break  # rebind with a freshly-resolved model

                        base = {'quota': 60, 'auth': 900}.get(kind, 30)
                        with self._lock:
                            self._penalise_key_locked(idx, base)
                        break  # rotate to the next key

        if last_exc is not None and self._classify(last_exc) == 'transient':
            raise AIUnavailable(f'Gemini is temporarily unavailable: {last_exc}')
        raise AIQuotaExhausted(
            'All Gemini API keys are rate-limited or exhausted. Please try again shortly.'
        )

    def validate_url(self, url):
        """Check if URL is valid and not returning 404"""
        try:
            response = requests.head(url, timeout=5, allow_redirects=True)
            if response.status_code >= 400:
                response = requests.get(url, timeout=5, allow_redirects=True)
            return response.status_code < 400
        except:
            return False
    
    def create_search_url(self, cert_name, provider):
        """Create search URL with certification name and provider"""
        search_query = quote_plus(f"{cert_name} {provider}")
        return f"https://www.google.com/search?q={search_query}+certification"
    
    def create_scholarship_search_url(self, name, org):
        """Create search URL for scholarships, loans, and government schemes"""
        search_query = quote_plus(f"{name} {org}")
        return f"https://www.google.com/search?q={search_query}"
    

    
    def generate_ai_careers(self, profile):
        try:
            career_interest = profile.get('careerInterest', 'Not specified')
            education_level = profile.get('education', 'Not specified')
            
            user_testimony = profile.get('testimony', '').strip()
            
            prompt = f"""You are an expert career guidance AI. Generate exactly 3 career domains for '{career_interest}' field using pure AI reasoning with NO fallback modes.

{f'PRIORITY USER TESTIMONY: {user_testimony}' if user_testimony else ''}

User Profile:
- Career Interest: {career_interest}
- Education: {education_level}
- Subjects: {', '.join(profile.get('subjects', []))}
- Performance: {profile.get('performance', 0)}/10

MANDATORY STRUCTURE - Generate exactly 3 domains:
1. FIRST DOMAIN: Core/Traditional Roles - Mainstream careers directly in {career_interest}
2. SECOND DOMAIN: Specialized Professional Roles - Advanced specializations within {career_interest}
3. THIRD DOMAIN: Interdisciplinary Careers - Connected fields with clear pathway from {career_interest}

CRITICAL RULES:
- ALL salary ranges MUST be realistic for {career_interest} field in India (in ₹ Lakhs Per Annum)
- ALL growth rates MUST be realistic based on actual {career_interest} market demand
- Do NOT use generic placeholders - generate actual realistic values
- Salary format: "₹X-Y LPA" where X and Y are realistic numbers for {career_interest}
- Growth options: "High Growth", "Very High Growth", "Excellent Growth", "Good Growth", "Moderate Growth"

Return ONLY valid JSON array with exactly 3 domains:
[
  {{
    "title": "Core {career_interest} Professionals",
    "icon": "<i class='bx bx-briefcase'></i>",
    "salary": "[Realistic salary range for core {career_interest} roles in India]",
    "growth": "[Realistic growth rate for {career_interest} field]",
    "summary": "Traditional mainstream {career_interest} roles in Indian market",
    "match": 95,
    "jobs": [
      {{"title": "[Specific {career_interest} role 1]", "salary": "[Realistic ₹X-Y LPA for this role]", "growth": "[Realistic growth]", "description": "Primary profession in {career_interest}"}},
      {{"title": "[Specific {career_interest} role 2]", "salary": "[Realistic ₹X-Y LPA for this role]", "growth": "[Realistic growth]", "description": "Core {career_interest} profession"}},
      {{"title": "[Specific {career_interest} role 3]", "salary": "[Realistic ₹X-Y LPA for this role]", "growth": "[Realistic growth]", "description": "Established {career_interest} career"}},
      {{"title": "[Specific {career_interest} role 4]", "salary": "[Realistic ₹X-Y LPA for this role]", "growth": "[Realistic growth]", "description": "Senior {career_interest} position"}}
    ]
  }},
  {{
    "title": "Specialized {career_interest} Experts",
    "icon": "<i class='bx bx-cog'></i>",
    "salary": "[Realistic salary range for specialized {career_interest} roles]",
    "growth": "[Realistic growth rate for specialized roles]",
    "summary": "Advanced specializations within {career_interest} field",
    "match": 90,
    "jobs": [
      {{"title": "[Specific specialization 1]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Specialized {career_interest} expertise"}},
      {{"title": "[Specific specialization 2]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Advanced {career_interest} role"}},
      {{"title": "[Specific specialization 3]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Expert level {career_interest}"}},
      {{"title": "[Specific specialization 4]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Senior specialist role"}}
    ]
  }},
  {{
    "title": "Interdisciplinary {career_interest} Careers",
    "icon": "<i class='bx bx-network-chart'></i>",
    "salary": "[Realistic salary range for interdisciplinary roles]",
    "growth": "[Realistic growth rate for interdisciplinary field]",
    "summary": "Adjacent careers with clear pathway from {career_interest}",
    "match": 85,
    "jobs": [
      {{"title": "[Connected role 1]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Adjacent career to {career_interest}"}},
      {{"title": "[Connected role 2]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Interdisciplinary {career_interest} role"}},
      {{"title": "[Connected role 3]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Cross-functional career"}},
      {{"title": "[Connected role 4]", "salary": "[Realistic ₹X-Y LPA]", "growth": "[Realistic growth]", "description": "Advanced interdisciplinary role"}}
    ]
  }}
]

CRITICAL: Replace ALL bracketed placeholders with actual job titles and REALISTIC salary/growth data for {career_interest} in India. System is fully AI-driven - no fallback modes allowed."""
            
            response = self.generate_with_fallback(prompt)
            
            if not response or not response.text:
                raise Exception("AI service completely unavailable - system is fully AI-driven")
            
            response_text = response.text.strip()
            
            # Enhanced JSON cleaning
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            # Remove any text before first [ or {
            start_idx = min([i for i in [response_text.find('['), response_text.find('{')] if i != -1] or [0])
            if start_idx > 0:
                response_text = response_text[start_idx:]
            
            # Remove any text after last ] or }
            end_idx = max(response_text.rfind(']'), response_text.rfind('}'))
            if end_idx != -1:
                response_text = response_text[:end_idx + 1]
            
            # Clean problematic characters
            import re
            response_text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', response_text)
            response_text = response_text.replace('&quot;', '"').replace('&#39;', "'")
            response_text = re.sub(r'\s+', ' ', response_text).strip()
            
            # Fix JSON formatting
            response_text = re.sub(r',\s*([}\]])', r'\1', response_text)
            response_text = re.sub(r',\s*,', ',', response_text)
            
            if not response_text or response_text in ['{}', '[]', 'null']:
                raise Exception("AI generated empty response - system is fully AI-driven")
            
            try:
                careers = json.loads(response_text)
            except json.JSONDecodeError as e:
                self.logger.error(f"JSON decode error: {str(e)}")
                self.logger.error(f"Raw response: {response_text[:500]}...")
                raise Exception("AI JSON parsing failed - system is fully AI-driven")
            
            if not isinstance(careers, list):
                raise Exception("AI must return JSON array - system is fully AI-driven")
            
            if len(careers) != 3:
                raise Exception(f"AI must return exactly 3 career domains, got {len(careers)} - system is fully AI-driven")
            
            # Validate all required fields - no fallback defaults
            for i, career in enumerate(careers):
                required_fields = ['title', 'summary', 'icon', 'salary', 'growth', 'match', 'jobs']
                for field in required_fields:
                    if not career.get(field):
                        raise Exception(f"AI must generate complete career data including {field} - system is fully AI-driven")
                
                if not isinstance(career.get('jobs'), list) or len(career.get('jobs')) == 0:
                    raise Exception("AI must generate complete job arrays - system is fully AI-driven")
                
                # Validate job structure
                for job in career['jobs']:
                    job_fields = ['title', 'salary', 'growth', 'description']
                    for field in job_fields:
                        if not job.get(field):
                            raise Exception(f"AI must generate complete job data including {field} - system is fully AI-driven")
            
            self.logger.info(f"Successfully generated 3 career domains using pure AI - system is fully AI-driven")
            return careers

        except AIError:
            # Preserve the typed AI failure (quota / prompt / unavailable) so the
            # route can map it to a real HTTP status instead of a generic 200.
            raise
        except Exception as e:
            self.logger.error(f"AI career generation failed: {str(e)}")
            raise Exception(f"Fully AI-driven career generation failed: {str(e)}")
    
    def generate_detailed_content(self, career_title, section_type, user_profile):
        """Generate AI-driven content for specific career detail sections"""
        try:
            user_testimony = user_profile.get('testimony', '').strip()
            testimony_context = f"\nPRIORITY USER TESTIMONY: {user_testimony}\n" if user_testimony else ""
            
            prompts = {
                'overview': f"""{testimony_context}Generate comprehensive overview for {career_title} based on user profile.
User Profile: {user_profile}

Provide detailed JSON with complete job role information:
{{"overview": {{"role_description": "2-3 line concise description of what this professional does daily and their work environment", "key_responsibilities": ["Responsibility 1", "Responsibility 2", "Responsibility 3", "Responsibility 4"], "why_suitable": "2-3 line concise explanation of why this career matches user's profile and interests"}}}}

Make descriptions concise and personalized.""",
                'pathway': f"""Generate the academic pathway for {career_title} starting STRICTLY from the user's current education level.
User Profile: {user_profile}
Current Education Level: {user_profile.get('education', 'undergraduate')}

CRITICAL RULES:
- Education code mapping: 'class-10'=Class 10th, 'class-11'=Class 11th, 'class-12'=Class 12th, 'graduation'=Pursuing Graduation, 'graduated'=Graduated, 'postgrad'=Post Graduation
- The FIRST step must be the IMMEDIATE NEXT academic step after the user's current level
- Do NOT include or repeat any steps the user has already completed
- Every step must be a real academic qualification DIRECTLY required to become a {career_title}
- Use EXACTLY the key name "phase" for the step name, "duration" for time, "description" for details
- Generate ONLY the academic steps needed from current level to become a {career_title}
- Each description must include: key subjects, entrance exams (if any), and specific career preparation

STEP-BY-STEP EXAMPLES:
- If user is 'class-10' wanting Software Engineer: 
  Step 1 = "Class 11-12 (Science with Maths)" (2 years)
  Step 2 = "B.Tech/B.E. in Computer Science" (4 years) 
  Step 3 = "Optional: M.Tech in Computer Science" (2 years)

- If user is 'class-12' wanting Software Engineer:
  Step 1 = "B.Tech/B.E. in Computer Science" (4 years)
  Step 2 = "Optional: M.Tech in Computer Science" (2 years)

- If user is 'graduated' wanting Doctor:
  Step 1 = "MBBS (Bachelor of Medicine)" (5.5 years)
  Step 2 = "MD/MS Specialization" (3 years)

- If user is 'class-10' wanting CA:
  Step 1 = "Class 11-12 (Commerce)" (2 years)
  Step 2 = "B.Com/BBA" (3 years)
  Step 3 = "CA Foundation + Intermediate + Final" (3-4 years)

Return ONLY this exact JSON structure:
{{"careerPathway": {{
  "pathway": [
    {{"phase": "[Immediate next degree/course for {career_title}]", "duration": "[X years]", "description": "[Key subjects to study, entrance exams like JEE/NEET/CAT, eligibility criteria, and how this prepares for {career_title}]"}},
    {{"phase": "[Next qualification for {career_title}]", "duration": "[X years]", "description": "[Advanced study requirements, specialization options, and career advancement for {career_title}]"}}
  ]
}}}}

CRITICAL: Generate 2-4 academic steps starting EXACTLY from the user's current level. Each step must be a real degree/course/certification required for {career_title}. Include entrance exams, key subjects, and career preparation details. MUST use key name "phase" and "careerPathway" as the root object.""",
                
                'skills': f"""Generate classified skills for {career_title} with DIRECT COURSE LINKS and YOUTUBE VIDEO LINKS.
User Profile: {user_profile}

CRITICAL REQUIREMENTS:
1. Each skill MUST include direct course link AND YouTube search link
2. Course URL format: https://www.coursera.org/learn/COURSE-SLUG
3. YouTube search URL format: https://www.youtube.com/results?search_query=SKILL_NAME+tutorial
4. Replace spaces with + in YouTube URLs
5. ALL SKILLS MUST BE DISTINCT - NO DUPLICATE SKILL NAMES across all priority levels (high, medium, low)
6. Each skill name must be unique and different from all other skills

Provide JSON with skills classified by priority with DIRECT COURSE LINKS and YOUTUBE LINKS:
{{"skills": {{"high": [{{"name": "Python Programming", "description": "Why this skill is essential for career success", "course_url": "https://www.coursera.org/learn/python", "video_url": "https://www.youtube.com/results?search_query=Python+Programming+tutorial"}}], "medium": [{{"name": "Data Analysis", "description": "Supporting skill description", "course_url": "https://www.coursera.org/learn/data-analysis", "video_url": "https://www.youtube.com/results?search_query=Data+Analysis+tutorial"}}], "low": [{{"name": "Git Version Control", "description": "Additional skill benefits", "course_url": "https://www.coursera.org/learn/version-control", "video_url": "https://www.youtube.com/results?search_query=Git+Version+Control+tutorial"}}]}}}}

CRITICAL: Generate direct course URLs and YouTube search URLs for each skill. ALL SKILLS MUST BE DISTINCT AND UNIQUE - no duplicates allowed. System is fully AI-driven - no fallback modes. Focus on 3-4 skills per priority level.""",
                
                'roadmap': f"""Create professional 90-day learning roadmap for {career_title} with clear phases and progress tracking.
User Profile: {user_profile}

Provide JSON with structured learning plan:
{{"roadmap": {{"total_duration": "90 days", "overview": "AI-curated step-by-step career development plan", "phase1": {{"title": "Foundation Phase (Days 1-30)", "goals": ["Master fundamental concepts", "Build core knowledge base"], "tasks": ["Complete basic courses", "Practice daily exercises"], "progress_indicators": ["Complete 5 modules", "Pass assessment test"]}}, "phase2": {{"title": "Building Phase (Days 31-60)", "goals": ["Apply knowledge practically", "Develop intermediate skills"], "tasks": ["Work on real projects", "Join study groups"], "progress_indicators": ["Complete 3 projects", "Achieve 80% score"]}}, "phase3": {{"title": "Mastery Phase (Days 61-90)", "goals": ["Achieve professional competency", "Prepare for career transition"], "tasks": ["Build portfolio", "Network with professionals"], "progress_indicators": ["Complete capstone project", "Get industry certification"]}}}}}}

Ensure each phase has clear goals, tasks, and measurable progress indicators.""",
                
                'institute': f"""Generate Indian educational institutes STRICTLY for {career_title} profession with WORKING WEBSITE LINKS.
User Profile: {user_profile}

CRITICAL REQUIREMENT: Every institute MUST include an 'eligibility' field with specific admission criteria. This is MANDATORY and NON-NEGOTIABLE.

CRITICAL REQUIREMENTS:
1. Generate ONLY real, well-known Indian institutes that offer courses for {career_title}
2. Each institute MUST have programs/departments directly related to {career_title}
3. Use REAL institute names and their official websites
4. For government institutes: Use .ac.in, .edu.in, or .gov.in domains
5. For private institutes: Use their verified official domains
6. Each institute must show the specific department/course relevant to {career_title}
7. Provide realistic ratings between 3.8 to 4.8
8. Include major cities across India for better geographic coverage

FIELD REQUIREMENTS (in order of importance):
1. eligibility (MANDATORY): Specific admission eligibility criteria. This field is CRITICAL and must be populated for every institute.
   - Government institutes: "JEE Main Rank < 10000", "90%+ in Class 12", "NEET Score 600+", "GATE Score 650+"
   - Private institutes: "85%+ in Class 12", "Entrance exam score 70%+", "75%+ in qualifying exam"
   - Distance Learning: "60%+ in qualifying exam", "Open for graduates", "50%+ in Class 12"
   - Online platforms: "Basic eligibility - Class 12 pass", "No entrance exam", "Open enrollment"
2. name: Real institute name
3. location: City, State
4. department: Specific department/course for {career_title}
5. rating: Between 3.8 to 4.8
6. website: Official website URL

EXAMPLE FORMAT (showing eligibility field FIRST):
{{
  "name": "Indian Institute of Technology Delhi",
  "location": "New Delhi",
  "department": "Computer Science Engineering",
  "rating": 4.7,
  "website": "https://www.iitd.ac.in/",
  "eligibility": "JEE Advanced Rank < 500"
}}

Generate ONLY valid JSON with this exact structure:
{{
  "institutes": {{
    "government": [
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.5, "website": "[Real .ac.in/.edu.in URL]", "eligibility": "[Realistic eligibility like '90%+ in Class 12' or 'JEE Rank < 5000']"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.3, "website": "[Real .ac.in/.edu.in URL]", "eligibility": "[Realistic eligibility like 'NEET Score 600+' or '85%+ in Class 12']"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.6, "website": "[Real .ac.in/.edu.in URL]", "eligibility": "[Realistic eligibility like 'GATE Score 650+' or 'CAT Score 90%ile']"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.4, "website": "[Real .ac.in/.edu.in URL]", "eligibility": "[Realistic eligibility like '92%+ in Class 12' or 'JEE Main Rank < 15000']"}}
    ],
    "private": [
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.2, "website": "[Real official website]", "eligibility": "[Realistic eligibility like '75%+ in Class 12' or 'Entrance exam score 60%+']"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.4, "website": "[Real official website]", "eligibility": "[Realistic eligibility like '80%+ in Class 12' or 'Institute entrance test 70%+']"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.1, "website": "[Real official website]", "eligibility": "[Realistic eligibility like '70%+ in qualifying exam' or 'Entrance score 65%+']"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.3, "website": "[Real official website]", "eligibility": "[Realistic eligibility like '85%+ in Class 12' or 'Merit-based admission 75%+']"}}      
    ],
    "distance": [
      {{"name": "Indira Gandhi National Open University (IGNOU)", "location": "New Delhi", "department": "[Relevant IGNOU school/program for {career_title}]", "rating": 4.0, "website": "https://www.ignou.ac.in/", "eligibility": "[Realistic eligibility like 'Open admission' or '50%+ in qualifying exam']"}},
      {{"name": "[Real Distance Learning Institute]", "location": "[City, State]", "department": "[Distance program for {career_title}]", "rating": 3.9, "website": "[Real website]", "eligibility": "[Realistic eligibility like '60%+ in qualifying exam' or 'Open for graduates']"}},
      {{"name": "[Real Distance Learning Institute]", "location": "[City, State]", "department": "[Distance program for {career_title}]", "rating": 4.1, "website": "[Real website]", "eligibility": "[Realistic eligibility like '55%+ in Class 12' or 'Open admission for working professionals']"}}      
    ],
    "online": [
      {{"name": "NPTEL (National Programme on Technology Enhanced Learning)", "location": "Online", "department": "[Relevant NPTEL courses for {career_title}]", "rating": 4.5, "website": "https://nptel.ac.in/", "eligibility": "Open enrollment"}},
      {{"name": "Coursera", "location": "Online", "department": "[Relevant specializations for {career_title}]", "rating": 4.6, "website": "https://www.coursera.org/", "eligibility": "Open enrollment"}},
      {{"name": "edX", "location": "Online", "department": "[Relevant programs for {career_title}]", "rating": 4.6, "website": "https://www.edx.org/", "eligibility": "Open enrollment"}},
      {{"name": "Udemy", "location": "Online", "department": "[Relevant courses for {career_title}]", "rating": 4.4, "website": "https://www.udemy.com/", "eligibility": "Open enrollment"}}      
    ]
  }}
}}

CRITICAL: Replace ALL bracketed placeholders with REAL institute names that offer programs for {career_title}. Use ACTUAL official websites. Each department must be specifically relevant to {career_title} profession. Generate institutes from different states for geographic diversity. 

IMPORTANT: Verify all institutes have the eligibility field populated with realistic admission criteria. Government institutes typically have higher eligibility requirements (85-95%+, competitive entrance exams) than private institutes (70-85%+, institute-level tests). Distance learning has moderate requirements (50-70%+). Online platforms usually have open enrollment.
""",
                
                'fees': f"""Generate realistic fee structure for {career_title} career starting STRICTLY from user's CURRENT education level. 
User Profile: {user_profile}
Current Education Level: {user_profile.get('education', 'undergraduate')}

CRITICAL RULES:
- Map education codes: 'class-10' = Class 10th, 'class-11' = Class 11th, 'class-12' = Class 12th, 'graduation' = Pursuing Graduation, 'graduated' = Graduated, 'postgrad' = Post Graduation
- Include ONLY the fee categories for steps the user still needs to complete from their current level.
- If 'class-10': include Class 11-12 fees + Bachelor's fees + any professional course fees for {career_title}
- If 'class-11' or 'class-12': include Bachelor's fees + Master's/specialization fees for {career_title}
- If 'graduation' or 'graduated': include Master's/specialization fees + certification fees for {career_title}
- If 'postgrad': include only certification/exam fees relevant to {career_title}
- All fees must be realistic for {career_title} profession in India (e.g., MBBS fees differ from B.Tech fees)
- total_investment MUST be ONLY the numeric range in INR, e.g. "Rs 5-15 Lakhs" — NO extra description, NO parentheses, NO explanatory text

Provide JSON:
{{"fees": {{"total_investment": "Rs X-Y Lakhs", "breakdown": [{{"category": "Specific degree/course name", "range": "Rs X-Y Lakhs", "duration": "X years"}}], "note": "Realistic cost estimate for {career_title} in India from current education level"}}}}

Generate 2-4 fee categories relevant to {career_title} from the user's current level only.""",
                
                'scholarships': f"""Generate financial support options for {career_title} education in India.
User Profile: {user_profile}

CRITICAL REQUIREMENTS:
1. Generate REAL scholarships, loans, and schemes that exist in India
2. Use ACTUAL government and private scholarship names
3. Provide REALISTIC amounts in Indian Rupees
4. Include WORKING website links (use https://scholarships.gov.in/ for government schemes)
5. Focus on scholarships relevant to {career_title} field education

Generate ONLY valid JSON with this exact structure:
{{
  "financial_support": {{
    "scholarships": [
      {{"name": "National Merit Scholarship", "amount": "Rs 12,000 per year", "eligibility": "Top 1% in Class 12", "link": "https://scholarships.gov.in/"}},
      {{"name": "Merit-cum-Means Scholarship", "amount": "Rs 20,000 per year", "eligibility": "Family income below Rs 6 lakhs + 80% marks", "link": "https://scholarships.gov.in/"}},
      {{"name": "State Merit Scholarship", "amount": "Rs 15,000 per year", "eligibility": "State board toppers", "link": "https://scholarships.gov.in/"}},
      {{"name": "Inspire Scholarship (for Science)", "amount": "Rs 80,000 per year", "eligibility": "Top 1% in Science subjects", "link": "https://scholarships.gov.in/"}},
      {{"name": "Kishore Vaigyanik Protsahan Yojana", "amount": "Rs 7,000 per month", "eligibility": "KVPY qualified students", "link": "https://scholarships.gov.in/"}}
    ],
    "loans": [
      {{"provider": "State Bank of India Education Loan", "max_amount": "Rs 30 Lakhs", "interest_rate": "8.5-9.5% per annum", "link": "https://sbi.co.in/web/personal-banking/loans/education-loans"}},
      {{"provider": "HDFC Credila Education Loan", "max_amount": "Rs 25 Lakhs", "interest_rate": "9.0-10.5% per annum", "link": "https://www.hdfcbank.com/personal/borrow/popular-loans/educational-loan"}},
      {{"provider": "Axis Bank Education Loan", "max_amount": "Rs 20 Lakhs", "interest_rate": "8.8-9.8% per annum", "link": "https://www.axisbank.com/retail/loans/education-loan"}},
      {{"provider": "ICICI Bank Education Loan", "max_amount": "Rs 50 Lakhs", "interest_rate": "9.5-11.5% per annum", "link": "https://www.icicibank.com/personal-banking/loans/education-loan"}}
    ],
    "government_schemes": [
      {{"name": "National Scholarship Portal (NSP)", "benefit": "Rs 10,000-50,000 per year", "eligibility": "Various categories (SC/ST/OBC/Minority)", "link": "https://scholarships.gov.in/"}},
      {{"name": "Post Matric Scholarship for SC Students", "benefit": "Full tuition + Rs 380-1200 per month", "eligibility": "SC category students", "link": "https://scholarships.gov.in/"}},
      {{"name": "Central Sector Scheme of Scholarship", "benefit": "Rs 20,000 per year", "eligibility": "Top 20% students in Class 12", "link": "https://scholarships.gov.in/"}},
      {{"name": "Prime Minister's Scholarship Scheme", "benefit": "Rs 25,000 per year (Boys), Rs 30,000 (Girls)", "eligibility": "Children of Armed Forces personnel", "link": "https://ksb.gov.in/"}},
      {{"name": "Pre-Matric Scholarship for Minorities", "benefit": "Rs 1,000-5,700 per year", "eligibility": "Minority community students", "link": "https://scholarships.gov.in/"}},
      {{"name": "Begum Hazrat Mahal National Scholarship", "benefit": "Rs 5,000-12,000 per year", "eligibility": "Minority girl students", "link": "https://scholarships.gov.in/"}}
    ]
  }}
}}

CRITICAL: Replace ALL placeholder values with REAL scholarship names, ACTUAL amounts, and REALISTIC eligibility criteria relevant to {career_title} education in India. Use government portal links for authenticity.""",                 
                'jobmarket': f"""Generate realistic Indian job market analysis for {career_title}.
User Profile: {user_profile}
Current Year: {datetime.now().year}

Generate ONLY valid JSON with this EXACT structure (no extra fields, no arrays where numbers expected):
{{
  "jobmarket": {{
    "demand": "High demand in Indian market for {career_title} professionals",
    "demand_percentage": 85,
    "growth_rate": "12% annual growth",
    "success_rate": "78% placement rate",
    "hiring_trends": [
      {{"month": "Jan {datetime.now().year}", "openings": 1200}},
      {{"month": "Feb {datetime.now().year}", "openings": 1300}},
      {{"month": "Mar {datetime.now().year}", "openings": 1450}},
      {{"month": "Apr {datetime.now().year}", "openings": 1600}},
      {{"month": "May {datetime.now().year}", "openings": 1750}},
      {{"month": "Jun {datetime.now().year}", "openings": 1900}},
      {{"month": "Jul {datetime.now().year}", "openings": 2100}},
      {{"month": "Aug {datetime.now().year}", "openings": 2250}},
      {{"month": "Sep {datetime.now().year}", "openings": 2400}},
      {{"month": "Oct {datetime.now().year}", "openings": 2600}},
      {{"month": "Nov {datetime.now().year}", "openings": 2800}},
      {{"month": "Dec {datetime.now().year}", "openings": 3000}}
    ],
    "top_companies": [
      {{"name": "TCS", "type": "IT Services", "hiring_frequency": "Monthly", "package_range": "Rs 8-15 LPA"}},
      {{"name": "Infosys", "type": "IT Services", "hiring_frequency": "Quarterly", "package_range": "Rs 10-18 LPA"}},
      {{"name": "Google India", "type": "Technology", "hiring_frequency": "Monthly", "package_range": "Rs 25-50 LPA"}},
      {{"name": "Microsoft India", "type": "Technology", "hiring_frequency": "Bi-annual", "package_range": "Rs 30-60 LPA"}},
      {{"name": "Amazon India", "type": "E-commerce/Tech", "hiring_frequency": "Monthly", "package_range": "Rs 20-45 LPA"}},
      {{"name": "Wipro", "type": "IT Services", "hiring_frequency": "Quarterly", "package_range": "Rs 8-16 LPA"}}
    ],
    "key_insights": [
      "Market demand for {career_title} professionals increased by 25% from {datetime.now().year - 5} to {datetime.now().year - 1}",
      "Average salary for {career_title} roles grew by 40% over the past 5 years ({datetime.now().year - 5}-{datetime.now().year - 1})",
      "Remote work opportunities in {career_title} expanded significantly during {datetime.now().year - 3} to {datetime.now().year - 1}",
      "Skills-based hiring for {career_title} positions became the primary recruitment trend from {datetime.now().year - 4} onwards",
      "Indian startups are increasingly hiring {career_title} professionals with competitive packages"
    ]
  }}
}}

CRITICAL RULES:
1. demand_percentage MUST be a single integer (60-95), NOT an array
2. key_insights MUST be exactly 5 strings in an array, each referencing market trends for {career_title}
3. hiring_trends MUST have exactly 12 entries showing monthly data for {datetime.now().year}
4. Use REAL company names that hire {career_title} professionals in India
5. Replace ALL placeholder text with realistic data for {career_title}
6. All insights must reference market evolution and be specific to {career_title}
7. Hiring trends should show progressive growth pattern throughout the year
8. Company package ranges must be realistic for {career_title} in India

Return ONLY the JSON, no extra text.""",
                
                'salary': f"""Generate Indian salary progression for {career_title}.
User Profile: {user_profile}

Generate ONLY valid JSON with this EXACT structure:
{{
  "salary": {{
    "fresher_level": {{
      "experience": "0-1 years",
      "range": "Rs 4-8 LPA",
      "cities": {{
        "Mumbai": "Rs 5-9 LPA",
        "Delhi": "Rs 4-8 LPA",
        "Bangalore": "Rs 6-10 LPA",
        "Pune": "Rs 4-7 LPA",
        "Chennai": "Rs 4-7 LPA",
        "Hyderabad": "Rs 5-8 LPA"
      }}
    }},
    "5years_level": {{
      "experience": "5 years",
      "range": "Rs 12-20 LPA",
      "cities": {{
        "Mumbai": "Rs 15-25 LPA",
        "Delhi": "Rs 12-20 LPA",
        "Bangalore": "Rs 18-28 LPA",
        "Pune": "Rs 12-18 LPA",
        "Chennai": "Rs 12-18 LPA",
        "Hyderabad": "Rs 14-22 LPA"
      }}
    }},
    "10years_level": {{
      "experience": "10 years",
      "range": "Rs 25-40 LPA",
      "cities": {{
        "Mumbai": "Rs 30-50 LPA",
        "Delhi": "Rs 25-40 LPA",
        "Bangalore": "Rs 35-55 LPA",
        "Pune": "Rs 25-40 LPA"
      }}
    }},
    "15years_level": {{
      "experience": "15+ years",
      "range": "Rs 40-70 LPA",
      "cities": {{
        "Mumbai": "Rs 50-80 LPA",
        "Delhi": "Rs 40-70 LPA",
        "Bangalore": "Rs 60-90 LPA",
        "Pune": "Rs 40-65 LPA"
      }}
    }},
    "growth_tips": [
      "Focus on learning new technologies and frameworks relevant to {career_title}",
      "Build a strong portfolio with real projects in {career_title}",
      "Contribute to open source projects and build professional network",
      "Obtain industry certifications specific to {career_title}",
      "Develop leadership and communication skills for career advancement"
    ]
  }}
}}

CRITICAL: Replace salary ranges with realistic values for {career_title} profession in India. Use appropriate cities where {career_title} professionals typically work. All salary ranges must be realistic and progressive.""",
                
                'experts': f"""Generate 3 industry expert profiles for {career_title} in India.
User Profile: {user_profile}

Generate ONLY valid JSON with this exact structure:
{{
  "experts": [
    {{
      "name": "Expert Name 1",
      "designation": "Senior Position",
      "company": "Company Name",
      "experience": "15+ years",
      "achievements": "Key achievements in {career_title} field",
      "key_advice": "Practical advice for {career_title} newcomers"
    }},
    {{
      "name": "Expert Name 2",
      "designation": "Leadership Position",
      "company": "Organization Name",
      "experience": "12+ years",
      "achievements": "Notable accomplishments in {career_title}",
      "key_advice": "Career guidance for aspiring {career_title} professionals"
    }},
    {{
      "name": "Expert Name 3",
      "designation": "Expert Position",
      "company": "Institution Name",
      "experience": "10+ years",
      "achievements": "Significant contributions to {career_title} field",
      "key_advice": "Success tips for {career_title} career growth"
    }}
  ]
}}

Replace placeholder values with realistic Indian names, companies, and advice relevant to {career_title} profession.""",
                
                "certifications": f"""Generate certifications STRICTLY for {career_title} profession.

CRITICAL REQUIREMENTS:
1. Certifications MUST be DIRECTLY relevant to {career_title} profession ONLY
2. DO NOT suggest certifications from unrelated fields - Examples:
   - Dermatologist: ONLY dermatology/medical certifications, NOT Python/AWS/data analytics
   - Software Engineer: ONLY programming/tech certifications, NOT medical/healthcare
   - Accountant: ONLY finance/accounting certifications, NOT engineering/medical
3. Focus ONLY on certifications that professionals in {career_title} actually need and pursue
4. Platforms: Coursera, Udemy, edX, Udacity, NPTEL, AWS, Google, Microsoft, or industry-specific certification bodies
5. Provide REAL, VALID direct course page URLs (not search URLs)
6. Use actual course slugs and paths that exist on these platforms
7. Generate ONLY well-known, popular certifications with verified URLs
8. DO NOT make up or guess URLs - use only real, existing course links

Provide JSON with certification details STRICTLY RELEVANT to {career_title}:
{{"certifications": [
    {{"name": "[Certification directly used by {career_title} professionals]", "provider": "[Relevant certification body]", "duration": "[Duration]", "cost": "[Cost in Rs]", "difficulty": "Beginner/Intermediate/Advanced", "career_impact": "High/Very High", "link": "[Direct course page URL]"}},
    {{"name": "[Another {career_title}-specific certification]", "provider": "[Relevant provider]", "duration": "[Duration]", "cost": "[Cost in Rs]", "difficulty": "Beginner/Intermediate/Advanced", "career_impact": "High/Very High", "link": "[Direct course page URL]"}},
    {{"name": "[Third {career_title}-relevant certification]", "provider": "[Relevant provider]", "duration": "[Duration]", "cost": "[Cost in Rs]", "difficulty": "Intermediate/Advanced", "career_impact": "Very High", "link": "[Direct course page URL]"}}
]}}

CRITICAL: Generate 3-5 REAL certifications with VALID direct course page URLs that are STRICTLY RELEVANT to {career_title} profession. System is fully AI-driven. NO unrelated certifications allowed.""",
                
                'marketoverview': f"""Generate market overview for {career_title} in India.
User Profile: {user_profile}

Provide JSON with market analysis:
{{"market_overview": {{"job_demand": "High demand", "growth_rate": "15 percent annual growth", "average_salary": "Rs 8-15 LPA", "key_insights": ["High demand in tech sector", "Remote work increasing", "Skills-based hiring"], "employment_outlook": "Positive growth expected", "geographic_hotspots": ["Bangalore", "Mumbai", "Delhi NCR", "Pune"]}}}}

Focus on realistic Indian market data for {career_title}."""
            }
            
            if section_type not in prompts:
                return None
                
            response = self.generate_with_fallback(prompts[section_type])
            
            if not response or not response.text:
                return None
                
            response_text = response.text.strip()
            
            # Clean response text more thoroughly
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            # Remove any text before first { or [
            start_idx = min([i for i in [response_text.find('{'), response_text.find('[')] if i != -1] or [0])
            if start_idx > 0:
                response_text = response_text[start_idx:]
            
            # Remove any text after last } or ]
            end_idx = max(response_text.rfind('}'), response_text.rfind(']'))
            if end_idx != -1:
                response_text = response_text[:end_idx + 1]
            
            # Enhanced sanitization for job market content
            import re
            # Remove all control characters and problematic characters
            response_text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', response_text)
            # Remove HTML entities and problematic quotes
            response_text = response_text.replace('&quot;', '"').replace('&#39;', "'")
            response_text = response_text.replace("'", "'")
            response_text = response_text.replace('"', '"')
            response_text = response_text.replace('\\n', ' ').replace('\\r', ' ').replace('\\t', ' ')
            # Remove extra whitespace and normalize
            response_text = re.sub(r'\s+', ' ', response_text).strip()
            
            # Fix trailing commas and malformed JSON
            response_text = re.sub(r',\s*([}\]])', r'\1', response_text)
            response_text = re.sub(r',\s*,', ',', response_text)
            
            # Log cleaned response for debugging problematic sections
            if section_type in ['jobmarket', 'scholarships', 'experts']:
                self.logger.info(f"Cleaned {section_type} response: {response_text[:1000]}...")
            # Additional validation for empty response
            if not response_text.strip() or response_text.strip() in ['{}', '[]', 'null', 'undefined']:
                raise Exception(f"AI failed to generate content for {section_type} - system is fully AI-driven")
                
            try:
                parsed_content = json.loads(response_text)
                if not parsed_content:
                    raise Exception(f"AI content generation failed for {section_type} - system is fully AI-driven")
                
                # Enhanced logging for debugging specific sections
                if section_type in ['jobmarket', 'scholarships', 'experts', 'institute', 'pathway']:
                    self.logger.info(f"Successfully parsed {section_type} content with keys: {list(parsed_content.keys())}")
                
                # Validate and fix certification links if section is certifications
                if section_type == 'certifications' and 'certifications' in parsed_content:
                    for cert in parsed_content['certifications']:
                        if 'link' in cert and 'name' in cert and 'provider' in cert:
                            self.logger.info(f"Validating certification link: {cert['link']}")
                            # Validate the direct link
                            if not self.validate_url(cert['link']):
                                # If direct link fails, create search URL with provider name
                                self.logger.warning(f"Direct link failed for {cert['name']}, using search URL")
                                cert['link'] = self.create_search_url(cert['name'], cert['provider'])
                            else:
                                self.logger.info(f"Direct link validated successfully for {cert['name']}")
                
                # Validate and fix institute links if section is institute
                if section_type == 'institute' and 'institutes' in parsed_content:
                    for category in ['government', 'private', 'distance', 'online']:
                        if category in parsed_content['institutes']:
                            for institute in parsed_content['institutes'][category]:
                                if 'website' in institute and 'name' in institute:
                                    self.logger.info(f"Validating institute link: {institute['website']}")
                                    # Validate the direct link
                                    if not self.validate_url(institute['website']):
                                        # Only if direct link fails, use search URL
                                        self.logger.warning(f"Direct link failed for {institute['name']}, using search URL")
                                        search_query = quote_plus(f"{institute['name']} official website")
                                        institute['website'] = f"https://www.google.com/search?q={search_query}"
                                    else:
                                        self.logger.info(f"Institute link validated successfully for {institute['name']}")
                
                # Validate and fix scholarship/loan/scheme links
                if section_type == 'scholarships' and 'financial_support' in parsed_content:
                    fs = parsed_content['financial_support']
                    
                    # Validate scholarships
                    if 'scholarships' in fs:
                        for item in fs['scholarships']:
                            if 'link' in item and 'name' in item:
                                self.logger.info(f"Validating scholarship link: {item['link']}")
                                if not self.validate_url(item['link']):
                                    org = item['name'].split()[0]  # Extract organization name
                                    self.logger.warning(f"Scholarship link failed for {item['name']}, using search URL")
                                    item['link'] = self.create_scholarship_search_url(item['name'], org)
                                else:
                                    self.logger.info(f"Scholarship link validated successfully for {item['name']}")
                    
                    # Validate loans
                    if 'loans' in fs:
                        for item in fs['loans']:
                            if 'link' in item and 'provider' in item:
                                self.logger.info(f"Validating loan link: {item['link']}")
                                if not self.validate_url(item['link']):
                                    self.logger.warning(f"Loan link failed for {item['provider']}, using search URL")
                                    item['link'] = self.create_scholarship_search_url(item['provider'], 'education loan')
                                else:
                                    self.logger.info(f"Loan link validated successfully for {item['provider']}")
                    
                    # Validate government schemes
                    if 'government_schemes' in fs:
                        for item in fs['government_schemes']:
                            if 'link' in item and 'name' in item:
                                self.logger.info(f"Validating scheme link: {item['link']}")
                                if not self.validate_url(item['link']):
                                    self.logger.warning(f"Scheme link failed for {item['name']}, using search URL")
                                    item['link'] = self.create_scholarship_search_url(item['name'], 'government scheme')
                                else:
                                    self.logger.info(f"Scheme link validated successfully for {item['name']}")

                # Validate specific section structures
                if section_type == 'jobmarket':
                    if 'jobmarket' not in parsed_content:
                        raise Exception("AI must generate jobmarket object")
                    jm = parsed_content['jobmarket']
                    required_fields = ['demand', 'demand_percentage', 'growth_rate', 'success_rate', 'hiring_trends', 'top_companies', 'key_insights']
                    for field in required_fields:
                        if field not in jm:
                            raise Exception(f"AI must generate {field} in jobmarket section")
                    if not isinstance(jm.get('hiring_trends'), list) or len(jm['hiring_trends']) < 10:
                        raise Exception("AI must generate at least 10 months of hiring_trends data")
                    if not isinstance(jm.get('key_insights'), list) or len(jm['key_insights']) < 4:
                        raise Exception("AI must generate at least 4 key_insights")
                
                if section_type == 'experts':
                    if 'experts' not in parsed_content:
                        raise Exception("AI must generate experts array")
                    experts = parsed_content['experts']
                    if not isinstance(experts, list) or len(experts) < 2:
                        raise Exception("AI must generate at least 2 expert profiles")
                    for expert in experts:
                        required_fields = ['name', 'designation', 'company', 'experience', 'achievements', 'key_advice']
                        for field in required_fields:
                            if not expert.get(field):
                                raise Exception(f"AI must generate {field} for each expert")

                if section_type == 'scholarships':
                    if 'financial_support' not in parsed_content:
                        raise Exception("AI must generate financial_support object")
                    fs = parsed_content['financial_support']
                    required_categories = ['scholarships', 'loans', 'government_schemes']
                    for category in required_categories:
                        if category not in fs or not isinstance(fs[category], list) or len(fs[category]) < 2:
                            raise Exception(f"AI must generate at least 2 items in {category}")
                
                if section_type == 'institute':
                    if 'institutes' not in parsed_content:
                        raise Exception("AI must generate institutes object")
                    inst = parsed_content['institutes']
                    required_categories = ['government', 'private', 'distance', 'online']
                    for category in required_categories:
                        if category not in inst or not isinstance(inst[category], list) or len(inst[category]) < 2:
                            raise Exception(f"AI must generate at least 2 institutes in {category}")
                        for institute in inst[category]:
                            required_fields = ['name', 'location', 'department', 'rating', 'website', 'eligibility']
                            for field in required_fields:
                                if not institute.get(field):
                                    raise Exception(f"AI must generate {field} for each institute")
                
                if section_type == 'pathway':
                    if 'careerPathway' not in parsed_content:
                        raise Exception("AI must generate careerPathway object")
                    cp = parsed_content['careerPathway']
                    if 'pathway' not in cp or not isinstance(cp['pathway'], list) or len(cp['pathway']) < 2:
                        raise Exception("AI must generate at least 2 pathway steps")
                    for step in cp['pathway']:
                        required_fields = ['phase', 'duration', 'description']
                        for field in required_fields:
                            if not step.get(field):
                                raise Exception(f"AI must generate {field} for each pathway step")

                return parsed_content
            except json.JSONDecodeError as json_error:
                self.logger.error(f"JSON decode error for {section_type}: {str(json_error)}")
                self.logger.error(f"Raw response for {section_type}: {response_text[:1000]}...")
                raise Exception(f"AI JSON generation failed for {section_type} - system is fully AI-driven: {str(json_error)}")
            
        except AIError:
            raise  # keep the typed failure for the route's status mapping
        except Exception as e:
            self.logger.error(f"AI content generation failed for {section_type}: {str(e)}")
            raise Exception(f"Fully AI-driven system failed for {section_type}: {str(e)}")

    def init_database(self):
        db_path = self.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT, username VARCHAR(50) UNIQUE NOT NULL, password VARCHAR(255) NOT NULL, name VARCHAR(100), profile_image TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_session (
                id INTEGER PRIMARY KEY AUTOINCREMENT, username VARCHAR(50) NOT NULL UNIQUE, user_profile TEXT, why_here VARCHAR(255), five_year_vision VARCHAR(255), career_thinking TEXT, career_ruled_out TEXT, module1_insight TEXT, free_sunday VARCHAR(255), group_role VARCHAR(255), job_bothers VARCHAR(255), module2_insight TEXT, favorite_subjects TEXT, difficult_subject VARCHAR(100), subject_marks TEXT, study_experience VARCHAR(255), module3_insight TEXT, outside_activities TEXT, external_validation VARCHAR(255), self_initiated TEXT, module4_insight TEXT, study_location TEXT, family_budget VARCHAR(255),
                career_values TEXT,
                module5_insight TEXT,
                planning_style VARCHAR(255),
                stress_response VARCHAR(255),
                surprise_reaction VARCHAR(255),
                module6_insight TEXT,
                number_sense_score INTEGER,
                word_sense_score INTEGER,
                shape_sense_score INTEGER,
                logic_sense_score INTEGER,
                persistence_effort_rating TEXT,
                persistence_approach_style TEXT,
                persistence_counselor_flags TEXT,
                persistence_highest_tier INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (username) REFERENCES users(username)
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS job_role_details (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(50) NOT NULL UNIQUE,
                role_id VARCHAR(100),
                role_title VARCHAR(200),
                sec_overview TEXT,
                sec_career_pathway TEXT,
                sec_skills_learning TEXT,
                sec_roadmap_90days TEXT,
                sec_top_institutes TEXT,
                sec_fees_investment TEXT,
                sec_scholarships TEXT,
                sec_job_market TEXT,
                sec_certifications TEXT,
                sec_salary_growth TEXT,
                sec_industry_experts TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS onboarding_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(50) NOT NULL UNIQUE,
                name VARCHAR(100),
                class_level VARCHAR(20),
                board VARCHAR(50),
                district VARCHAR(100),
                parent_mobile VARCHAR(15),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (username) REFERENCES users(username)
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS career_recommendations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(50) NOT NULL UNIQUE,
                recommendations_json TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (username) REFERENCES users(username)
            )
        ''')
        
        # Migrate: add created_at column
        existing_detail_cols = [row[1] for row in cursor.execute('PRAGMA table_info(job_role_details)').fetchall()]
        if 'created_at' not in existing_detail_cols:
            cursor.execute('ALTER TABLE job_role_details ADD COLUMN created_at TIMESTAMP')
        
        # Migrate: add section columns
        new_cols = [
            'sec_overview', 'sec_career_pathway', 'sec_skills_learning',
            'sec_roadmap_90days', 'sec_top_institutes', 'sec_fees_investment',
            'sec_scholarships', 'sec_job_market', 'sec_certifications',
            'sec_salary_growth', 'sec_industry_experts',
        ]
        for col in new_cols:
            if col not in existing_detail_cols:
                cursor.execute(f'ALTER TABLE job_role_details ADD COLUMN {col} TEXT')

        # Migrate: add persistence columns to user_session
        existing_session_cols = [row[1] for row in cursor.execute('PRAGMA table_info(user_session)').fetchall()]
        persistence_cols = [
            ('persistence_effort_rating', 'TEXT'),
            ('persistence_approach_style', 'TEXT'),
            ('persistence_counselor_flags', 'TEXT'),
            ('persistence_highest_tier', 'INTEGER'),
            ('constraint_grid_approach', 'TEXT'),
            ('constraint_grid_solved', 'INTEGER'),
            ('constraint_grid_counselor_flag', 'TEXT'),
            ('blackbox_approach', 'TEXT'),
            ('blackbox_solved', 'INTEGER'),
            ('blackbox_abandoned_last_guess', 'INTEGER'),
            ('blackbox_counselor_flag', 'TEXT'),
            ('cipher_information_gathering', 'TEXT'),
            ('cipher_persistence', 'TEXT'),
            ('cipher_rule_adaptability', 'TEXT'),
            ('cipher_solved', 'INTEGER'),
            ('cipher_counselor_flags', 'TEXT'),
            ('game5_task1_insight', 'TEXT'),
            ('game5_task2_insight', 'TEXT'),
            ('game5_task3_insight', 'TEXT'),
            # Per-module AI feedback ("here's what we noticed") shown after each
            # module during the assessment, now persisted for the Career Report.
            # (On an existing DB these append at the end; fresh installs get them
            # interleaved after each module's columns in the CREATE TABLE above.)
            ('module1_insight', 'TEXT'),
            ('module2_insight', 'TEXT'),
            ('module3_insight', 'TEXT'),
            ('module4_insight', 'TEXT'),
            ('module5_insight', 'TEXT'),
            ('module6_insight', 'TEXT'),
        ]
        for col, col_type in persistence_cols:
            if col not in existing_session_cols:
                cursor.execute(f'ALTER TABLE user_session ADD COLUMN {col} {col_type}')
        conn.commit()
        conn.close()

    def signup_user(self, username, password, name=None):
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute('INSERT INTO users (username, password, name) VALUES (?, ?, ?)', (username, password, name or username))
            conn.commit()
            conn.close()
            return {'success': True, 'message': 'Account created successfully'}
        except sqlite3.IntegrityError:
            return {'success': False, 'message': 'Username already exists'}
        except:
            return {'success': False, 'message': 'Signup failed'}

    def login_user(self, username, password):
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute('SELECT password, name, profile_image FROM users WHERE username = ?', (username,))
            result = cursor.fetchone()
            conn.close()
            
            if not result:
                return {'success': False, 'message': 'Username not found'}
            if result[0] != password:
                return {'success': False, 'message': 'Invalid password'}
            
            return {'success': True, 'message': 'Login successful', 'name': result[1] or username, 'profileImage': result[2]}
        except Exception as e:
            return {'success': False, 'message': 'Login failed'}


    def update_user_profile(self, username, name=None, new_password=None, current_password=None, profile_image=None):
        """Update user profile information"""
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            # Verify current password if changing password
            if new_password:
                if not current_password:
                    conn.close()
                    return {'success': False, 'message': 'Current password required to change password'}
                
                cursor.execute('SELECT password FROM users WHERE username = ?', (username,))
                result = cursor.fetchone()
                if not result or result[0] != current_password:
                    conn.close()
                    return {'success': False, 'message': 'Current password is incorrect'}
            
            # Build update query dynamically
            updates = []
            params = []
            
            if name is not None:
                updates.append('name = ?')
                params.append(name)
            
            if new_password is not None:
                updates.append('password = ?')
                params.append(new_password)
            
            if profile_image is not None:
                updates.append('profile_image = ?')
                params.append(profile_image)
            
            if not updates:
                conn.close()
                return {'success': False, 'message': 'No updates provided'}
            
            params.append(username)
            query = f"UPDATE users SET {', '.join(updates)} WHERE username = ?"
            
            cursor.execute(query, params)
            conn.commit()
            conn.close()
            
            return {'success': True, 'message': 'Profile updated successfully'}
        except Exception as e:
            self.logger.error(f"Update profile failed: {str(e)}")
            return {'success': False, 'message': 'Failed to update profile'}
    

    def save_questionnaire_data(self, username, questionnaire_data):
        """Save Module 1-6 questionnaire answers and aptitude scores with UPSERT.

        The INSERT is built from a SINGLE ordered {column: value} mapping so the
        column list, the ? placeholders, the value tuple and the ON CONFLICT
        UPDATE clause are always generated in lockstep. Adding a new field is a
        one-line change here and can never drift out of sync (which previously
        caused the "N values for M columns" save failure).
        """
        qd = questionnaire_data

        def as_bool_int(key):
            return 1 if qd.get(key) else 0

        # Single source of truth — column name -> value (order preserved).
        fields = {
            'username': username,
            'user_profile': json.dumps(qd.get('userProfile', {})),
            'why_here': qd.get('whyHere'),
            'five_year_vision': qd.get('fiveYearVision'),
            'career_thinking': qd.get('careerThinking'),
            'career_ruled_out': qd.get('careerRuledOut'),
            'module1_insight': qd.get('module1Insight'),
            'free_sunday': qd.get('freeSunday'),
            'group_role': qd.get('groupRole'),
            'job_bothers': qd.get('jobBothers'),
            'module2_insight': qd.get('module2Insight'),
            'favorite_subjects': json.dumps(qd.get('favoriteSubjects', [])),
            'difficult_subject': qd.get('difficultSubject'),
            'subject_marks': json.dumps(qd.get('subjectMarks', {})),
            'study_experience': qd.get('studyExperience'),
            'module3_insight': qd.get('module3Insight'),
            'outside_activities': json.dumps(qd.get('outsideActivities', [])),
            'external_validation': qd.get('externalValidation'),
            'self_initiated': qd.get('selfInitiated'),
            'module4_insight': qd.get('module4Insight'),
            'study_location': json.dumps(qd.get('studyLocation', [])),
            'family_budget': qd.get('familyBudget'),
            'career_values': json.dumps(qd.get('careerValues', [])),
            'module5_insight': qd.get('module5Insight'),
            'planning_style': qd.get('planningStyle'),
            'stress_response': qd.get('stressResponse'),
            'surprise_reaction': qd.get('surpriseReaction'),
            'module6_insight': qd.get('module6Insight'),
            'number_sense_score': qd.get('numberSenseScore'),
            'word_sense_score': qd.get('wordSenseScore'),
            'shape_sense_score': qd.get('shapeSenseScore'),
            'logic_sense_score': qd.get('logicSenseScore'),
            'persistence_effort_rating': qd.get('persistenceEffortRating'),
            'persistence_approach_style': qd.get('persistenceApproachStyle'),
            'persistence_counselor_flags': json.dumps(qd.get('persistenceCounselorFlags', [])),
            'persistence_highest_tier': qd.get('persistenceHighestTier'),
            'constraint_grid_approach': qd.get('constraintGridApproach'),
            'constraint_grid_solved': as_bool_int('constraintGridSolved'),
            'constraint_grid_counselor_flag': qd.get('constraintGridCounselorFlag'),
            'blackbox_approach': qd.get('blackBoxApproach'),
            'blackbox_solved': as_bool_int('blackBoxSolved'),
            'blackbox_abandoned_last_guess': as_bool_int('blackBoxAbandonedLastGuess'),
            'blackbox_counselor_flag': qd.get('blackBoxCounselorFlag'),
            'cipher_information_gathering': qd.get('cipherInformationGathering'),
            'cipher_persistence': qd.get('cipherPersistence'),
            'cipher_rule_adaptability': qd.get('cipherRuleAdaptability'),
            'cipher_solved': as_bool_int('cipherSolved'),
            'cipher_counselor_flags': json.dumps(qd.get('cipherCounselorFlags', [])),
            'game5_task1_insight': qd.get('game5Task1Insight'),
            'game5_task2_insight': qd.get('game5Task2Insight'),
            'game5_task3_insight': qd.get('game5Task3Insight'),
        }

        columns = list(fields.keys())
        values = list(fields.values())

        # updated_at is set via a CURRENT_TIMESTAMP literal, not a placeholder.
        col_sql = ', '.join(columns + ['updated_at'])
        placeholder_sql = ', '.join(['?'] * len(columns) + ['CURRENT_TIMESTAMP'])
        # UPSERT: refresh every column except the conflict key (username).
        update_sql = ', '.join(
            f'{c} = excluded.{c}' for c in columns if c != 'username'
        ) + ', updated_at = CURRENT_TIMESTAMP'

        sql = (
            f'INSERT INTO user_session ({col_sql}) '
            f'VALUES ({placeholder_sql}) '
            f'ON CONFLICT(username) DO UPDATE SET {update_sql}'
        )

        conn = None
        try:
            conn = sqlite3.connect(self.get_db_path())
            cursor = conn.cursor()
            cursor.execute(sql, values)
            # A new assessment invalidates prior AI output: clear this user's
            # cached recommendations and dossier sections so they regenerate from
            # the fresh insight. (On normal logins these are served from the DB.)
            for _tbl in ('career_recommendations', 'job_role_details'):
                try:
                    cursor.execute(f'DELETE FROM {_tbl} WHERE username = ?', (username,))
                except Exception as _ce:
                    self.logger.warning(f"Cache-clear skipped for {_tbl}: {_ce}")
            conn.commit()
            self.logger.info(f"Saved questionnaire data for user: {username}")
            return {'success': True, 'message': 'Questionnaire data saved successfully'}
        except Exception as e:
            # Log the full traceback so structural/SQL errors are caught here,
            # not masked and surfaced downstream as "no data found".
            self.logger.error(f"Save questionnaire data failed: {str(e)}", exc_info=True)
            return {'success': False, 'message': f'Failed to save questionnaire data: {str(e)}'}
        finally:
            if conn is not None:
                conn.close()
    

    def save_job_role_detail(self, username, role_id, role_title, detail_data):
        """Upsert a full JobDetail object, storing each section in its own column."""
        try:
            col_map = {
                'overview':        'sec_overview',
                'careerPathway':   'sec_career_pathway',
                'skillsLearning':  'sec_skills_learning',
                'roadmap90Days':   'sec_roadmap_90days',
                'topInstitutes':   'sec_top_institutes',
                'feesInvestment':  'sec_fees_investment',
                'scholarships':    'sec_scholarships',
                'jobMarket':       'sec_job_market',
                'certifications':  'sec_certifications',
                'salaryGrowth':    'sec_salary_growth',
                'industryExperts': 'sec_industry_experts',
            }
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            cursor.execute(
                'SELECT id FROM job_role_details WHERE username = ?',
                (username,)
            )
            existing = cursor.fetchone()
            
            cursor.execute('''
                INSERT INTO job_role_details (username, role_id, role_title, created_at, updated_at)
                VALUES (?, ?, ?, datetime('now'), datetime('now'))
                ON CONFLICT(username) DO UPDATE SET
                    role_id = excluded.role_id,
                    role_title = excluded.role_title,
                    updated_at = datetime('now')
            ''', (username, role_id, role_title))
            
            for key, col in col_map.items():
                if key in detail_data:
                    cursor.execute(
                        f'UPDATE job_role_details SET {col} = ?, updated_at = datetime(\'now\') WHERE username = ?',
                        (json.dumps(detail_data[key]), username)
                    )
            
            conn.commit()
            conn.close()
            
            return {'success': True, 'updated': bool(existing)}
        except Exception as e:
            self.logger.error(f"Save job role detail failed: {str(e)}")
            return {'success': False}

    def load_job_role_details(self, username):
        """Return saved job role detail for a user."""
        try:
            col_map = {
                'sec_overview':        'overview',
                'sec_career_pathway':  'careerPathway',
                'sec_skills_learning': 'skillsLearning',
                'sec_roadmap_90days':  'roadmap90Days',
                'sec_top_institutes':  'topInstitutes',
                'sec_fees_investment': 'feesInvestment',
                'sec_scholarships':    'scholarships',
                'sec_job_market':      'jobMarket',
                'sec_certifications':  'certifications',
                'sec_salary_growth':   'salaryGrowth',
                'sec_industry_experts':'industryExperts',
            }
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cols = ['role_id', 'role_title'] + list(col_map.keys())
            cursor.execute(
                f'SELECT {", ".join(cols)} FROM job_role_details WHERE username = ?',
                (username,)
            )
            row = cursor.fetchone()
            conn.close()
            
            if not row:
                return {}
            
            role_id = row[0]
            detail = {'roleId': role_id}
            sections_loaded = 0
            
            for i, sec_col in enumerate(col_map.keys()):
                raw = row[2 + i]
                if raw:
                    try:
                        detail[col_map[sec_col]] = json.loads(raw)
                        sections_loaded += 1
                    except Exception:
                        pass
            
            if sections_loaded >= 8:
                return {role_id: detail}
            else:
                return {}
                
        except Exception as e:
            self.logger.error(f"Load job role details failed: {str(e)}")
            return {}
    
    def cleanup_incomplete_job_roles(self, username, min_sections=8):
        """Delete incomplete job role record if it has fewer than min_sections populated."""
        try:
            col_map = [
                'sec_overview', 'sec_career_pathway', 'sec_skills_learning',
                'sec_roadmap_90days', 'sec_top_institutes', 'sec_fees_investment',
                'sec_scholarships', 'sec_job_market', 'sec_certifications',
                'sec_salary_growth', 'sec_industry_experts',
            ]
            conn = sqlite3.connect('users.db')
            cursor = conn.cursor()
            
            # Find the user's record
            cursor.execute(
                f'SELECT id, role_id, role_title, {", ".join(col_map)} FROM job_role_details WHERE username = ?',
                (username,)
            )
            row = cursor.fetchone()
            
            if not row:
                conn.close()
                return {'success': True, 'deleted': 0}
            
            record_id = row[0]
            role_id = row[1]
            role_title = row[2]
            sections_present = sum(1 for i in range(3, len(row)) if row[i] is not None and row[i].strip())
            
            if sections_present < min_sections:
                cursor.execute('DELETE FROM job_role_details WHERE id = ?', (record_id,))
                conn.commit()
                conn.close()
                self.logger.info(f"Deleted incomplete job role '{role_title}' ({role_id}) with only {sections_present}/11 sections for user '{username}'")
                return {'success': True, 'deleted': 1}
            
            conn.close()
            return {'success': True, 'deleted': 0}
            
        except Exception as e:
            self.logger.error(f"Cleanup failed: {str(e)}")
            return {'success': False, 'deleted': 0}

    def save_onboarding_data(self, username, name, class_level, board, district, parent_mobile):
        """Save or update Stage 0 onboarding data for a user"""
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO onboarding_data (username, name, class_level, board, district, parent_mobile, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(username) DO UPDATE SET
                    name = excluded.name,
                    class_level = excluded.class_level,
                    board = excluded.board,
                    district = excluded.district,
                    parent_mobile = excluded.parent_mobile,
                    updated_at = CURRENT_TIMESTAMP
            ''', (username, name, class_level, board, district, parent_mobile))
            
            conn.commit()
            conn.close()
            self.logger.info(f"Saved onboarding data for user: {username}")
            return {'success': True, 'message': 'Onboarding data saved successfully'}
            
        except Exception as e:
            self.logger.error(f"Save onboarding data failed: {str(e)}")
            return {'success': False, 'message': 'Failed to save onboarding data'}
    
    def get_onboarding_data(self, username):
        """Fetch Stage 0 onboarding data for a user"""
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT name, class_level, board, district, parent_mobile
                FROM onboarding_data
                WHERE username = ?
            ''', (username,))
            
            row = cursor.fetchone()
            conn.close()
            
            if row:
                return {
                    'success': True,
                    'data': {
                        'name': row[0],
                        'classLevel': row[1],
                        'board': row[2],
                        'district': row[3],
                        'parentMobile': row[4]
                    }
                }
            else:
                return {'success': False, 'data': None}
                
        except Exception as e:
            self.logger.error(f"Get onboarding data failed: {str(e)}")
            return {'success': False, 'data': None}

    def generate_module_feedback(self, module_number, answers_so_far):
        """Generate personalized AI feedback after each onboarding module"""
        try:
            module_labels = {
                1: "Opening Questions (motivation, career thinking, what they've ruled out)",
                2: "How Your Mind Works (free Sunday preference, group role, job deal-breaker)",
                3: "What You're Actually Good At (favourite subjects, marks, difficult subject, study experience)",
                4: "Life Outside Marks (outside activities, external validation, self-initiated projects)",
                5: "The Constraints (study location, family budget, career values)",
                6: "The Final Calibration (planning style, stress response, reaction to surprises)",
            }

            prompt = f"""You are an expert career counsellor giving real-time feedback to a student after they completed Module {module_number} of a career assessment.

Module {module_number} is about: {module_labels.get(module_number, 'Career Assessment')}

All answers the student has given so far (across all modules completed):
{answers_so_far}

Write a SHORT, SHARP, PERSONALISED feedback note (EXACTLY 2 sentences, 35 words MAXIMUM total) that:
1. Directly references the student's ACTUAL answers — use their specific words, subjects, activities, values
2. Names one pattern or insight that ONLY applies to this specific combination of answers
3. Ends with a brief forward-looking note about what it means for their career path

CRITICAL RULES:
- HARD LIMIT: 2 sentences and no more than 35 words in total. Being concise matters more than being complete.
- Do NOT use phrases like "Great job!", "Well done!", "Interesting!", "Based on your answers"
- Do NOT give generic career advice or motivational fluff
- Every sentence must be grounded in their specific answers
- Write in second person ("you", "your")
- Plain text only, no bullet points, no headers

Return ONLY the feedback note, nothing else."""

            response = self.generate_with_fallback(prompt)
            if not response or not response.text:
                raise Exception("Empty response")
            return response.text.strip()
        except AIError:
            raise  # keep the typed failure for the route's status mapping
        except Exception as e:
            self.logger.error(f"Module feedback generation failed: {str(e)}")
            raise Exception(f"Feedback generation failed: {str(e)}")

    def validate_puzzle(self, puzzle):
        """Validate Story Deduction puzzle logical soundness"""
        suspects = set(puzzle['suspects'])
        eliminated = set()
        distractor_idx = puzzle.get('distractor_index', -1)
        for clue_idx_str, eliminated_names in puzzle.get('elimination_map', {}).items():
            if int(clue_idx_str) != distractor_idx:
                eliminated.update(eliminated_names)
        remaining = suspects - eliminated
        if len(remaining) != 1:
            return False
        correct_name = puzzle['suspects'][puzzle['correct_index']]
        if correct_name not in remaining:
            return False
        distractor_key = str(distractor_idx)
        if distractor_key in puzzle.get('elimination_map', {}):
            if correct_name in puzzle['elimination_map'][distractor_key]:
                return False
        return True

    def generate_story_puzzle(self, tier):
        """Generate and validate one Story Deduction puzzle for a given tier (A/B/C)"""
        import re

        templates = {
            'A': {
                'suspects': 4, 'clues': 3, 'distractor': False,
                'clue_types': ['elimination_2', 'elimination_1', 'negative_1'],
                'correct_provable_from': [0, 1, 2],
                'difficulty': 'easy',
            },
            'B': {
                'suspects': 4, 'clues': 4, 'distractor': True,
                'clue_types': ['elimination_2', 'negative_1', 'conditional_1', 'distractor'],
                'correct_provable_from': [0, 1, 2],
                'difficulty': 'medium',
            },
            'C': {
                'suspects': 4, 'clues': 5, 'distractor': True,
                'clue_types': ['elimination_1', 'conditional_1', 'negative_1', 'conditional_2', 'distractor'],
                'correct_provable_from': [0, 1, 2, 3],
                'difficulty': 'hard',
            },
        }

        fallbacks = {
            'A': {
                'scenario': 'Someone ate the last piece of cake from the office fridge. Four colleagues are suspected.',
                'suspects': ['Ravi', 'Meena', 'Arjun', 'Sunita'],
                'clues': [
                    'Ravi and Arjun were both in a meeting from 2pm to 4pm when the cake went missing.',
                    'Sunita is lactose intolerant and never eats dairy-based sweets.',
                    'Meena was seen near the fridge at 3pm.',
                ],
                'correct_index': 1,
                'distractor_index': -1,
                'elimination_map': {'0': ['Ravi', 'Arjun'], '1': ['Sunita']},
            },
            'B': {
                'scenario': 'A student\'s notebook went missing from the classroom. Four classmates are under suspicion.',
                'suspects': ['Priya', 'Kabir', 'Disha', 'Tarun'],
                'clues': [
                    'Priya and Tarun left school before the last period when the notebook disappeared.',
                    'Kabir does not sit anywhere near the victim\'s bench.',
                    'If a student borrowed the notebook to copy homework, they would sit in the back row — Disha sits in the back row.',
                    'Disha recently got a new pencil case as a gift.',
                ],
                'correct_index': 2,
                'distractor_index': 3,
                'elimination_map': {'0': ['Priya', 'Tarun'], '1': ['Kabir'], '2': [], '3': []},
            },
            'C': {
                'scenario': 'Money went missing from the cash box at a small shop. Four people had access that morning.',
                'suspects': ['Deepak', 'Anita', 'Farhan', 'Rekha'],
                'clues': [
                    'Deepak was on delivery duty outside the shop all morning.',
                    'If someone needed cash urgently for a medical bill, they would have taken a small amount — exactly Rs 500 is missing.',
                    'Anita mentioned yesterday that she needed money for her mother\'s medicine.',
                    'If Anita took the money, Farhan who monitors the cash box would have noticed — Farhan was absent today.',
                    'Rekha has worked at the shop for 10 years without any complaint.',
                ],
                'correct_index': 1,
                'distractor_index': 4,
                'elimination_map': {'0': ['Deepak'], '1': [], '2': [], '3': ['Farhan'], '4': []},
            },
        }

        tmpl = templates[tier]
        distractor_note = ''
        if tmpl['distractor']:
            distractor_pos = len(tmpl['clue_types']) - 1
            distractor_note = f"""- Clue {distractor_pos} (index {distractor_pos}) MUST be the distractor: it sounds relevant but does NOT eliminate any suspect and does NOT affect the correct answer
- distractor_index MUST be {distractor_pos}"""
        else:
            distractor_note = '- No distractor clue. distractor_index must be -1'

        prompt = f"""Generate a Story Deduction puzzle with EXACTLY these properties:

STRUCTURE:
- Suspects: {tmpl['suspects']} (use Bengali or common Indian names)
- Clues: {tmpl['clues']}
- Clue types in order: {tmpl['clue_types']}
- Difficulty: {tmpl['difficulty']}
- Correct answer: the suspect at index {tmpl['suspects'] - 2} (second from last in list)
- The answer must be provable from clues at indices {tmpl['correct_provable_from']} only

CLUE TYPE DEFINITIONS:
- elimination_2: one clue that rules out exactly 2 suspects with a clear reason
- elimination_1: one clue that rules out exactly 1 suspect
- negative_1: confirms what the correct suspect is NOT (rules out 1 more)
- conditional_1 / conditional_2: "If X then Y" — the antecedent must be confirmable from earlier clues
- distractor: sounds like evidence but is logically irrelevant — does NOT eliminate anyone

REQUIREMENTS:
- Set scene in familiar Indian context (school, office, hostel, market, wedding, etc.)
- Each clue is one sentence, simple and clear
- Every non-distractor clue is load-bearing (removing it makes answer ambiguous)
- Wrong suspects must each be eliminatable by at least one non-distractor clue
{distractor_note}

OUTPUT (strict JSON only, no extra text):
{{"scenario": "...", "suspects": ["name1","name2","name3","name4"], "clues": ["clue1",...], "correct_index": {tmpl['suspects'] - 2}, "distractor_index": <int or -1>, "elimination_map": {{"0": ["names eliminated by clue 0"], "1": [...], ...}}}}"""

        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                resp = self.generate_with_fallback(prompt)
                if not resp or not resp.text:
                    continue
                raw = resp.text.strip()
                if '```json' in raw:
                    raw = raw.split('```json')[1].split('```')[0].strip()
                elif '```' in raw:
                    raw = raw.split('```')[1].split('```')[0].strip()
                raw = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', raw)
                raw = re.sub(r',\s*([}\]])', r'\1', raw).strip()
                puzzle = json.loads(raw)
                required = ['scenario', 'suspects', 'clues', 'correct_index', 'distractor_index', 'elimination_map']
                if not all(k in puzzle for k in required):
                    self.logger.warning(f"Story puzzle tier {tier} attempt {attempt+1}: missing fields")
                    continue
                if len(puzzle['suspects']) != tmpl['suspects']:
                    continue
                if len(puzzle['clues']) != tmpl['clues']:
                    continue
                if not (0 <= puzzle['correct_index'] < tmpl['suspects']):
                    continue
                if self.validate_puzzle(puzzle):
                    self.logger.info(f"Story puzzle tier {tier} generated and validated on attempt {attempt+1}")
                    return puzzle
                else:
                    self.logger.warning(f"Story puzzle tier {tier} attempt {attempt+1}: failed validate_puzzle")
                    continue
            except Exception as e:
                self.logger.error(f"Story puzzle tier {tier} attempt {attempt+1} error: {str(e)}")
                continue

        self.logger.warning(f"Story puzzle tier {tier}: all attempts failed, using fallback")
        return fallbacks[tier]

    def generate_word_item(self, item_type, difficulty, language):
        """Generate and validate a verbal reasoning item for Game 2 (Word Sense)"""
        import re
        difficulty_label = {1: 'easy', 2: 'easy-medium', 3: 'medium', 4: 'medium-hard', 5: 'hard'}.get(difficulty, 'medium')

        word_prompt = f"""Generate one verbal reasoning item of type: {item_type}
Difficulty: {difficulty_label}
Language: {language}
Context: Indian everyday settings, familiar vocabulary

Item types:
- odd_one_out: 4 words, exactly one does not belong to the same category as the others
- analogy: Word1 is to Word2 as Word3 is to ___
- meaning_in_context: a sentence using a word, 4 options for what the word means
- same_meaning: a sentence, 4 options, exactly one means the same thing

Rules:
- Exactly one unambiguous correct answer
- Wrong options must each fail for a specific reason
- No culturally obscure references
- Keep vocabulary appropriate for class 12 WB students

OUTPUT (strict JSON only, no extra text):
{{"question": "...", "options": ["a", "b", "c", "d"], "correct_index": 0, "explanation": "why each wrong option is wrong"}}"""

        validate_prompt_template = """This verbal reasoning item has been generated:
{item_json}

Check:
1. Is there exactly one correct answer?
2. Could any wrong option be argued as correct?
3. Is the language appropriate for a class 12 student?

Reply with JSON only: {{"valid": true, "issue": null}} or {{"valid": false, "issue": "describe problem"}}"""

        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                # Step 1: Generate
                gen_response = self.generate_with_fallback(word_prompt)
                if not gen_response or not gen_response.text:
                    continue

                raw = gen_response.text.strip()
                if '```json' in raw:
                    raw = raw.split('```json')[1].split('```')[0].strip()
                elif '```' in raw:
                    raw = raw.split('```')[1].split('```')[0].strip()
                raw = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', raw)
                raw = re.sub(r',\s*([}\]])', r'\1', raw).strip()

                item = json.loads(raw)
                required = ['question', 'options', 'correct_index', 'explanation']
                if not all(k in item for k in required):
                    continue
                if not isinstance(item['options'], list) or len(item['options']) != 4:
                    continue
                if not isinstance(item['correct_index'], int) or not (0 <= item['correct_index'] <= 3):
                    continue

                # Step 2: Validate
                val_response = self.generate_with_fallback(validate_prompt_template.format(item_json=json.dumps(item)))
                if not val_response or not val_response.text:
                    return item  # return unvalidated if validator fails

                val_raw = val_response.text.strip()
                if '```json' in val_raw:
                    val_raw = val_raw.split('```json')[1].split('```')[0].strip()
                elif '```' in val_raw:
                    val_raw = val_raw.split('```')[1].split('```')[0].strip()
                val_raw = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', val_raw).strip()

                validation = json.loads(val_raw)
                if validation.get('valid'):
                    return item
                else:
                    self.logger.warning(f"Word item invalid (attempt {attempt+1}): {validation.get('issue')}")
                    continue

            except Exception as e:
                self.logger.error(f"Word item generation attempt {attempt+1} failed: {str(e)}")
                continue

        raise Exception(f"Failed to generate valid word item after {max_attempts} attempts")

    def generate_skill_resources(self, skill_name, career_context=""):
        """AI-driven skill resource generation"""
        try:
            prompt = f"""Generate learning resources for '{skill_name}' in {career_context} context.

Return ONLY valid JSON:
{{
    "resources": {{
        "courses": [{{"title": "Course Name", "provider": "Platform", "duration": "Duration", "level": "Beginner/Intermediate/Advanced"}}],
        "videos": [{{"title": "Video Title", "url": "https://youtube.com/embed/VIDEO_ID", "duration": "Duration"}}],
        "documentation": [{{"title": "Doc Title", "description": "What you'll learn", "type": "Official/Tutorial/Guide"}}],
        "practice_paths": [{{"title": "Practice Path", "description": "Hands-on exercises", "difficulty": "Easy/Medium/Hard"}}]
    }}
}}"""
            
            response = self.generate_with_fallback(prompt)
            
            if not response or not response.text:
                raise Exception("AI resource generation failed")
            
            response_text = response.text.strip()
            
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            import re
            response_text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', response_text)
            response_text = response_text.replace('&quot;', '"').replace('&#39;', "'")
            response_text = re.sub(r'\s+', ' ', response_text).strip()
            
            try:
                resource_data = json.loads(response_text)
                if not resource_data.get('resources'):
                    raise Exception("AI failed to generate resources")
                return resource_data
            except json.JSONDecodeError:
                raise Exception("AI JSON generation failed")
            
        except Exception as e:
            self.logger.error(f"AI resource generation failed: {str(e)}")
            raise Exception(f"Resource generation failed: {str(e)}")
    
    def generate_game5_insights(self, effort_rating, approach_style, highest_tier, constraint_approach, constraint_solved, cipher_gathering, cipher_persistence, cipher_adaptability):
        """Generate behavioral insights for Game 5 tasks once and cache them"""
        try:
            prompt = f"""Generate behavioral insights for 3 Game 5 tasks based on student performance:

Task 1 - Sliding Tile (Persistence):
- Effort Rating: {effort_rating or 'Not completed'}
- Approach Style: {approach_style or 'Not completed'} 
- Highest Tier: {highest_tier or 'Not completed'}

Task 2 - Constraint Grid (Problem Entry):
- Approach: {constraint_approach or 'Not completed'}
- Solved: {'Yes' if constraint_solved else 'No' if constraint_solved is not None else 'Not completed'}

Task 3 - Secret Agent Cipher (Cognitive Flexibility):
- Information Gathering: {cipher_gathering or 'Not completed'}
- Persistence: {cipher_persistence or 'Not completed'}
- Rule Adaptability: {cipher_adaptability or 'Not completed'}

Generate exactly 3 concise insights (2-3 sentences each) that reveal behavioral patterns:

Return ONLY valid JSON:
{{
  "task1": "Behavioral insight about persistence and problem-solving approach based on sliding tile performance",
  "task2": "Insight about how they enter and structure complex problems based on constraint grid", 
  "task3": "Insight about cognitive flexibility and adaptation to changing rules based on cipher task"
}}

Make each insight:
- Specific to the actual performance data
- Focused on behavioral patterns, not just success/failure
- Actionable for career guidance
- 2-3 sentences maximum"""
            
            response = self.generate_with_fallback(prompt)
            
            if not response or not response.text:
                raise Exception("AI insight generation failed")
            
            response_text = response.text.strip()
            
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            import re
            response_text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', response_text)
            response_text = response_text.replace('&quot;', '"').replace('&#39;', "'")
            response_text = re.sub(r'\s+', ' ', response_text).strip()
            
            try:
                insights = json.loads(response_text)
                if not isinstance(insights, dict) or not all(k in insights for k in ['task1', 'task2', 'task3']):
                    raise Exception("AI must generate all 3 task insights")
                return insights
            except json.JSONDecodeError:
                raise Exception("AI JSON generation failed for insights")
            
        except Exception as e:
            self.logger.error(f"AI insight generation failed: {str(e)}")
            # Return fallback insights if AI fails
            return {
                'task1': 'Performance on persistence tasks indicates systematic problem-solving approach with measured effort allocation.',
                'task2': 'Constraint handling shows structured thinking with attention to problem boundaries and systematic exploration.',
                'task3': 'Cognitive flexibility demonstrates adaptive thinking with ability to adjust strategies based on new information.'
            }

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max request size
CORS(app)
bot = EducationBot()


def ai_error_response(e):
    """Map a typed AI failure to a REAL HTTP status.

    Previously every failure came back as HTTP 200 with {'success': False},
    so no client could tell "we're out of quota, retry shortly" apart from
    "your input was bad". Now:
        400 -> the prompt/input is the problem (retrying will not help)
        429 -> all keys rate-limited / out of quota (retry later)
        503 -> upstream transiently unavailable (retry shortly)
    """
    if isinstance(e, AIPromptError):
        payload, status = {
            'success': False,
            'code': 'bad_request',
            'message': str(e),
            'retryable': False,
        }, 400
    elif isinstance(e, AIQuotaExhausted):
        payload, status = {
            'success': False,
            'code': 'quota_exhausted',
            'message': 'Our AI service is busy right now. Please try again in a minute.',
            'retryable': True,
        }, 429
    elif isinstance(e, AIUnavailable):
        payload, status = {
            'success': False,
            'code': 'unavailable',
            'message': 'The AI service is temporarily unavailable. Please try again shortly.',
            'retryable': True,
        }, 503
    else:
        payload, status = {
            'success': False,
            'code': 'ai_error',
            'message': str(e),
            'retryable': False,
        }, 500

    bot.logger.warning(f'AI failure -> HTTP {status} ({payload["code"]}): {e}')
    return jsonify(payload), status


@app.errorhandler(AIError)
def _handle_ai_error(e):
    """Safety net for any AIError that escapes a route handler."""
    return ai_error_response(e)

@app.route('/api/career-details', methods=['POST'])
def get_career_details():
    try:
        data = request.json
        if not data or 'career_title' not in data or 'section_type' not in data:
            return jsonify({'success': False, 'error': 'Career title and section type required'})
        
        career_title = data['career_title']
        section_type = data['section_type']
        user_profile = data.get('profile', {})
        
        content = bot.generate_detailed_content(career_title, section_type, user_profile)
        
        if content:
            return jsonify({'success': True, 'content': content})
        else:
            return jsonify({'success': False, 'error': 'AI content generation failed - system is fully AI-driven'})
            
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/career-recommendations', methods=['POST'])
def get_career_recommendations():
    try:
        data = request.json
        if not data or 'profile' not in data:
            return jsonify({'success': False, 'error': 'Profile data required'})
        
        careers = bot.generate_ai_careers(data['profile'])
        return jsonify({'success': True, 'careers': careers})
        
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/signup', methods=['POST'])
def signup():
    data = request.json
    if not data.get('username') or not data.get('password'):
        return jsonify({'success': False, 'message': 'Username and password required'})
    
    return jsonify(bot.signup_user(data['username'], data['password']))

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    if not data.get('username') or not data.get('password'):
        return jsonify({'success': False, 'message': 'Username and password required'})
    
    return jsonify(bot.login_user(data['username'], data['password']))

@app.route('/api/generate-module-feedback', methods=['POST'])
def generate_module_feedback():
    try:
        data = request.json
        if not data or not data.get('module_number') or not data.get('answers_so_far'):
            return jsonify({'success': False, 'error': 'module_number and answers_so_far required'})
        feedback = bot.generate_module_feedback(
            module_number=data['module_number'],
            answers_so_far=data['answers_so_far']
        )
        return jsonify({'success': True, 'feedback': feedback})
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/generate-story-puzzles', methods=['POST'])
def generate_story_puzzles():
    """Pre-generate all 3 Story Deduction puzzles for a session"""
    try:
        puzzles = {
            'A': bot.generate_story_puzzle('A'),
            'B': bot.generate_story_puzzle('B'),
            'C': bot.generate_story_puzzle('C'),
        }
        return jsonify({'success': True, 'puzzles': puzzles})
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        bot.logger.error(f"Story puzzle generation failed: {str(e)}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/generate-word-item', methods=['POST'])
def generate_word_item():
    try:
        data = request.json
        if not data or 'item_type' not in data or 'difficulty' not in data:
            return jsonify({'success': False, 'error': 'item_type and difficulty required'})
        item_type = data['item_type']
        difficulty = int(data['difficulty'])
        language = data.get('language', 'English')
        valid_types = ['odd_one_out', 'analogy', 'meaning_in_context', 'same_meaning']
        if item_type not in valid_types:
            return jsonify({'success': False, 'error': f'item_type must be one of {valid_types}'})
        if not (1 <= difficulty <= 5):
            return jsonify({'success': False, 'error': 'difficulty must be 1-5'})
        item = bot.generate_word_item(item_type, difficulty, language)
        return jsonify({'success': True, 'item': item})
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/generate-skill-resources', methods=['POST'])
def generate_skill_resources():
    try:
        data = request.json
        if not data or 'skill_name' not in data:
            return jsonify({'success': False, 'error': 'Skill name required'})
        
        skill_name = data['skill_name']
        career_context = data.get('career_context', '')
        
        resource_data = bot.generate_skill_resources(skill_name, career_context)
        return jsonify({'success': True, 'resources': resource_data})
            
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': f'Resource generation failed: {str(e)}'})

@app.route('/api/save-questionnaire', methods=['POST'])
def save_questionnaire():
    """Save Module 1-6 questionnaire answers and aptitude scores"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        questionnaire_data = data.get('questionnaireData', {})
        if not questionnaire_data:
            return jsonify({'success': False, 'message': 'Questionnaire data required'})
        
        return jsonify(bot.save_questionnaire_data(data['username'], questionnaire_data))
    except Exception as e:
        bot.logger.error(f"Save questionnaire endpoint failed: {str(e)}")
        return jsonify({'success': False, 'message': f'Failed to save questionnaire data: {str(e)}'})

@app.route('/api/save-job-role', methods=['POST'])
def save_job_role():
    data = request.json
    if not data or not data.get('username') or not data.get('roleId'):
        return jsonify({'success': False, 'message': 'username and roleId required'})
    detail_data = data.get('detailData', {})
    if not detail_data:
        return jsonify({'success': False, 'message': 'detailData required'})
    return jsonify(bot.save_job_role_detail(
        username=data['username'],
        role_id=data['roleId'],
        role_title=data.get('roleTitle', ''),
        detail_data=detail_data,
    ))

@app.route('/api/load-job-role', methods=['POST'])
def load_job_role():
    data = request.json
    if not data or not data.get('username') or not data.get('roleId'):
        return jsonify({'success': False, 'message': 'username and roleId required'})
    all_details = bot.load_job_role_details(data['username'])
    detail = all_details.get(data['roleId'])
    if detail:
        return jsonify({'success': True, 'detail': detail})
    return jsonify({'success': False, 'detail': None})

@app.route('/api/cleanup-incomplete-roles', methods=['POST'])
def cleanup_incomplete_roles():
    """Manual endpoint to cleanup incomplete job role records"""
    data = request.json
    if not data or not data.get('username'):
        return jsonify({'success': False, 'message': 'username required'})
    return jsonify(bot.cleanup_incomplete_job_roles(data['username']))

@app.route('/api/update-profile', methods=['POST'])
def update_profile():
    """Update user profile information"""
    data = request.json
    if not data or not data.get('username'):
        return jsonify({'success': False, 'message': 'Username required'})
    
    return jsonify(bot.update_user_profile(
        username=data['username'],
        name=data.get('name'),
        new_password=data.get('newPassword'),
        current_password=data.get('currentPassword'),
        profile_image=data.get('profileImage')
    ))

@app.route('/api/translate', methods=['POST'])
def translate():
    try:
        data = request.json
        text = data.get('text', '')
        target_language = data.get('target_language', 'en')
        source_language = data.get('source_language', 'en')
        
        translated = translate_text(text, target_language, source_language)
        return jsonify({'success': True, 'translated_text': translated})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/translate-batch', methods=['POST'])
def translate_batch_endpoint():
    try:
        data = request.json
        texts = data.get('texts', [])
        target_language = data.get('target_language', 'en')
        source_language = data.get('source_language', 'en')
        
        translations = translate_batch(texts, target_language, source_language)
        return jsonify({'success': True, 'translations': translations})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/get-recent-job-role', methods=['POST'])
def get_recent_job_role():
    """Get the most recent job role details for a user"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        username = data['username']
        
        db_path = bot.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get the most recent job role with section count
        cursor.execute('''
            SELECT 
                role_id, 
                role_title, 
                created_at,
                (
                    CASE WHEN sec_overview IS NOT NULL AND sec_overview != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_career_pathway IS NOT NULL AND sec_career_pathway != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_skills_learning IS NOT NULL AND sec_skills_learning != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_roadmap_90days IS NOT NULL AND sec_roadmap_90days != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_top_institutes IS NOT NULL AND sec_top_institutes != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_fees_investment IS NOT NULL AND sec_fees_investment != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_scholarships IS NOT NULL AND sec_scholarships != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_job_market IS NOT NULL AND sec_job_market != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_certifications IS NOT NULL AND sec_certifications != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_salary_growth IS NOT NULL AND sec_salary_growth != '' THEN 1 ELSE 0 END +
                    CASE WHEN sec_industry_experts IS NOT NULL AND sec_industry_experts != '' THEN 1 ELSE 0 END
                ) as sections_count
            FROM job_role_details 
            WHERE username = ? 
            ORDER BY updated_at DESC 
            LIMIT 1
        ''', (username,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            job_role = {
                'roleId': result[0],
                'roleTitle': result[1],
                'createdAt': result[2],
                'sectionsCount': result[3]
            }
            return jsonify({'success': True, 'jobRole': job_role})
        else:
            return jsonify({'success': False, 'jobRole': None})
            
    except Exception as e:
        bot.logger.error(f"Get recent job role failed: {str(e)}")
        return jsonify({'success': False, 'message': 'Failed to fetch recent job role'})

# In-memory storage for translated PDF data (temporary)
pdf_data_store = {}

@app.route('/api/generate-pdf', methods=['POST', 'OPTIONS'])
def generate_pdf():
    if request.method == 'OPTIONS':
        from flask import Response as FlaskResponse
        resp = FlaskResponse(status=200)
        resp.headers['Access-Control-Allow-Origin'] = '*'
        resp.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        return resp
    """Generate PDF from career report using Playwright with server-side translated data"""
    temp_key = None
    pdf_path = None
    try:
        data = request.json
        bot.logger.info(f"PDF generation request received: {data.keys() if data else 'No data'}")
        
        if not data or not data.get('roleId'):
            bot.logger.error("Missing roleId in request")
            return jsonify({'success': False, 'error': 'roleId required'}), 400
        
        role_id = data['roleId']
        role_title = data.get('roleTitle', 'Career Report')
        target_language = data.get('targetLanguage', 'en')
        translated_data = data.get('translatedData')
        
        if not translated_data:
            bot.logger.error("Missing translatedData in request")
            return jsonify({'success': False, 'error': 'translatedData required'}), 400
        
        bot.logger.info(f"Generating PDF for role: {role_title} (ID: {role_id}) in language: {target_language}")
        bot.logger.info(f"Translated data keys: {translated_data.keys() if isinstance(translated_data, dict) else 'Not a dict'}")
        
        # Store translated data temporarily with unique key
        temp_key = f"{role_id}_{int(time.time() * 1000)}"
        pdf_data_store[temp_key] = {
            'data': translated_data,
            'language': target_language,
            'roleTitle': role_title,
            'timestamp': time.time()
        }
        
        bot.logger.info(f"Stored translated data with key: {temp_key}")
        
        # Create temporary file for PDF
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            pdf_path = tmp_file.name
        
        bot.logger.info(f"Created temp PDF file: {pdf_path}")
        
        # Launch Playwright and generate PDF
        bot.logger.info("Launching Playwright...")
        with sync_playwright() as p:
            bot.logger.info("Launching Chromium browser...")
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            
            # Navigate to backend report template with data key
            backend_url = f"http://localhost:8080/report-template?key={temp_key}"
            bot.logger.info(f"Loading report template: {backend_url}")
            
            page.goto(backend_url, wait_until='networkidle', timeout=60000)
            bot.logger.info("Page loaded, waiting for fonts...")
            
            # Wait for fonts to load
            try:
                page.wait_for_function("document.fonts.ready", timeout=30000)
                bot.logger.info("Fonts loaded successfully")
            except Exception as font_error:
                bot.logger.warning(f"Font loading timeout: {str(font_error)}")
            
            # Wait for content to be populated
            bot.logger.info("Waiting for content to be ready...")
            page.wait_for_selector('[data-translation-ready="true"]', timeout=30000)
            bot.logger.info("Content populated and ready")
            
            # Generate PDF with proper settings for multi-language support
            bot.logger.info("Generating PDF...")
                        
            page.pdf(
                path=pdf_path,
                format='A4',
                print_background=True,
                margin={
                    'top': '20px',
                    'right': '20px',
                    'bottom': '20px',
                    'left': '20px'
                },
                prefer_css_page_size=False
            )
            
            bot.logger.info("PDF generated, closing browser...")
            browser.close()
        
        # Clean up stored data
        if temp_key in pdf_data_store:
            del pdf_data_store[temp_key]
            bot.logger.info(f"Cleaned up temporary data for key: {temp_key}")
        
        bot.logger.info(f"PDF generated successfully at: {pdf_path}")
        
        # Send file and cleanup
        safe_title = role_title.replace(' ', '-').replace('/', '-')
        lang_suffix = f"-{target_language}" if target_language != 'en' else ""
        filename = f"EduBot-Career-Report-{safe_title}{lang_suffix}-{int(time.time())}.pdf"
        
        bot.logger.info(f"Sending PDF file: {filename}")
        from flask import make_response
        response = make_response(send_file(
            pdf_path,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=filename
        ))
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response
        
    except Exception as e:
        bot.logger.error(f"PDF generation failed with error: {str(e)}")
        bot.logger.error(f"Error type: {type(e).__name__}")
        import traceback
        bot.logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Clean up on error
        if temp_key and temp_key in pdf_data_store:
            del pdf_data_store[temp_key]
            bot.logger.info(f"Cleaned up temp data after error: {temp_key}")
        
        return jsonify({'success': False, 'error': f'PDF generation failed: {str(e)}'}), 500
    finally:
        # Cleanup temp file after sending
        try:
            if pdf_path and os.path.exists(pdf_path):
                os.unlink(pdf_path)
                bot.logger.info(f"Cleaned up temp PDF file: {pdf_path}")
        except Exception as cleanup_error:
            bot.logger.error(f"Failed to cleanup temp file: {str(cleanup_error)}")

@app.route('/report-template', methods=['GET'])
def serve_report_template():
    """Serve the HTML report template"""
    try:
        template_path = os.path.join(os.path.dirname(__file__), 'report-template-new.html')
        with open(template_path, 'r', encoding='utf-8') as f:
            template_content = f.read()
        
        # Get language from query params
        key = request.args.get('key', '')
        lang = 'en'
        
        if key and key in pdf_data_store:
            lang = pdf_data_store[key].get('language', 'en')
        
        # Replace language placeholder
        template_content = template_content.replace('{{lang}}', lang)
        
        from flask import Response
        return Response(template_content, mimetype='text/html')
    except Exception as e:
        bot.logger.error(f"Failed to serve report template: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/report-data', methods=['GET'])
def get_report_data():
    """Serve translated report data for PDF generation"""
    try:
        key = request.args.get('key', '')
        bot.logger.info(f"Report data requested with key: {key}")
        
        if not key or key not in pdf_data_store:
            bot.logger.error(f"Invalid or expired data key: {key}")
            bot.logger.info(f"Available keys: {list(pdf_data_store.keys())}")
            return jsonify({'error': 'Invalid or expired data key'}), 404
        
        stored_data = pdf_data_store[key]
        bot.logger.info(f"Found stored data for key: {key}")
        bot.logger.info(f"Data language: {stored_data['language']}, Title: {stored_data['roleTitle']}")
        
        # Return the translated data
        return jsonify({
            'success': True,
            'data': stored_data['data'],
            'language': stored_data['language'],
            'roleTitle': stored_data['roleTitle']
        })
    except Exception as e:
        bot.logger.error(f"Failed to get report data: {str(e)}")
        import traceback
        bot.logger.error(f"Traceback: {traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500

@app.route('/fonts/<filename>', methods=['GET'])
def serve_font(filename):
    """Serve font files for PDF generation"""
    try:
        font_path = os.path.join(os.path.dirname(__file__), filename)
        if os.path.exists(font_path):
            return send_file(font_path, mimetype='font/ttf')
        else:
            return jsonify({'error': 'Font not found'}), 404
    except Exception as e:
        bot.logger.error(f"Failed to serve font: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/save-onboarding', methods=['POST'])
def save_onboarding():
    """Save Stage 0 onboarding data"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        return jsonify(bot.save_onboarding_data(
            username=data['username'],
            name=data.get('name', ''),
            class_level=data.get('classLevel', ''),
            board=data.get('board', ''),
            district=data.get('district', ''),
            parent_mobile=data.get('parentMobile', '')
        ))
    except Exception as e:
        bot.logger.error(f"Save onboarding endpoint failed: {str(e)}")
        return jsonify({'success': False, 'message': 'Failed to save onboarding data'})

@app.route('/api/get-onboarding', methods=['POST'])
def get_onboarding():
    """Get Stage 0 onboarding data"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        return jsonify(bot.get_onboarding_data(data['username']))
    except Exception as e:
        bot.logger.error(f"Get onboarding endpoint failed: {str(e)}")
        return jsonify({'success': False, 'message': 'Failed to fetch onboarding data'})

@app.route('/api/get-top-3-careers', methods=['POST'])
def get_top_3_careers():
    """Analyze user data and return top 3 career recommendations"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        username = data['username']

        # Serve the saved recommendations from the DB when present — regenerate
        # only when there is no cached row. The cache is cleared on a new
        # assessment save, so a re-take produces fresh content while a normal
        # login just reads what's stored.
        try:
            _cconn = sqlite3.connect(bot.get_db_path())
            _ccur = _cconn.cursor()
            _ccur.execute(
                'SELECT recommendations_json FROM career_recommendations WHERE username = ?',
                (username,),
            )
            _crow = _ccur.fetchone()
            _cconn.close()
            if _crow and _crow[0]:
                return jsonify({'success': True, 'careers': json.loads(_crow[0])})
        except Exception as _ce:
            bot.logger.warning(f"Recommendation cache read failed, regenerating: {_ce}")

        # Fetch onboarding data
        onboarding_result = bot.get_onboarding_data(username)
        if not onboarding_result.get('success'):
            return jsonify({'success': False, 'message': 'No onboarding data found'})
        
        onboarding_data = onboarding_result['data']
        
        # Fetch assessment data from user_session
        db_path = bot.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT user_profile, why_here, five_year_vision, career_thinking, career_ruled_out,
                   free_sunday, group_role, job_bothers, favorite_subjects, difficult_subject,
                   subject_marks, study_experience, outside_activities, external_validation,
                   self_initiated, study_location, family_budget, career_values, planning_style,
                   stress_response, surprise_reaction, number_sense_score, word_sense_score,
                   shape_sense_score, logic_sense_score,
                   persistence_effort_rating, persistence_approach_style,
                   persistence_counselor_flags, persistence_highest_tier
            FROM user_session WHERE username = ?
        ''', (username,))
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return jsonify({'success': False, 'message': 'No assessment data found'})
        
        # Parse assessment data
        user_profile = json.loads(result[0]) if result[0] else {}
        assessment_data = {
            'whyHere': result[1],
            'fiveYearVision': result[2],
            'careerThinking': result[3],
            'careerRuledOut': result[4],
            'freeSunday': result[5],
            'groupRole': result[6],
            'jobBothers': result[7],
            'favoriteSubjects': json.loads(result[8]) if result[8] else [],
            'difficultSubject': result[9],
            'subjectMarks': json.loads(result[10]) if result[10] else {},
            'studyExperience': result[11],
            'outsideActivities': json.loads(result[12]) if result[12] else [],
            'externalValidation': result[13],
            'selfInitiated': result[14],
            'studyLocation': json.loads(result[15]) if result[15] else [],
            'familyBudget': result[16],
            'careerValues': json.loads(result[17]) if result[17] else [],
            'planningStyle': result[18],
            'stressResponse': result[19],
            'surpriseReaction': result[20],
            'aptitudeScores': {
                'numberSense': result[21],
                'wordSense': result[22],
                'shapeSense': result[23],
                'logicSense': result[24]
            },
            'persistenceEffortRating': result[25],
            'persistenceApproachStyle': result[26],
            'persistenceCounselorFlags': json.loads(result[27]) if result[27] else [],
            'persistenceHighestTier': result[28],
        }
        
        # Combine all data for AI analysis
        combined_data = {
            'name': onboarding_data.get('name', ''),
            'education': onboarding_data.get('classLevel', ''),
            'board': onboarding_data.get('board', ''),
            'district': onboarding_data.get('district', ''),
            'careerInterest': user_profile.get('careerInterest', ''),
            'subjects': user_profile.get('subjects', []),
            'strengths': user_profile.get('strengths', []),
            'interests': user_profile.get('interests', []),
            'assessment': assessment_data,
            'persistenceEffortRating': assessment_data.get('persistenceEffortRating'),
            'persistenceApproachStyle': assessment_data.get('persistenceApproachStyle'),
            'persistenceCounselorFlags': assessment_data.get('persistenceCounselorFlags', []),
            'persistenceHighestTier': assessment_data.get('persistenceHighestTier'),
        }

        # Generate AI-based top 3 career recommendations
        def interpret_aptitude(score):
            if score >= 7: return "Exceptional (fast and accurate — natural fluency)"
            if score >= 5: return "Strong (accurate, moderate pace)"
            if score >= 3: return "Moderate (developing, needs practice)"
            return "Low (not a natural strength)"

        aptitude = combined_data['assessment']['aptitudeScores']
        aptitude_summary = {
            'numberSense':  f"{aptitude.get('numberSense', 0)}/8 — {interpret_aptitude(aptitude.get('numberSense', 0))}",
            'wordSense':    f"{aptitude.get('wordSense', 0)}/8 — {interpret_aptitude(aptitude.get('wordSense', 0))}",
            'shapeSense':   f"{aptitude.get('shapeSense', 0)}/8 — {interpret_aptitude(aptitude.get('shapeSense', 0))}",
            'logicSense':   f"{aptitude.get('logicSense', 0)}/8 — {interpret_aptitude(aptitude.get('logicSense', 0))}",
        }

        prompt = f"""Analyze this student profile and recommend EXACTLY 3 career paths.

Student Profile:
- Name: {combined_data['name']}
- Education: {combined_data['education']}
- Board: {combined_data['board']}
- Location: {combined_data['district']}
- Career Interest: {combined_data['careerInterest']}
- Subjects: {', '.join(combined_data['subjects'])}
- Strengths: {', '.join(combined_data['strengths'])}
- Interests: {', '.join(combined_data['interests'])}
- Aptitude Scores (0-8, speed+accuracy weighted):
  * Quantitative Reasoning: {aptitude_summary['numberSense']}
  * Verbal Reasoning: {aptitude_summary['wordSense']}
  * Spatial Reasoning: {aptitude_summary['shapeSense']}
  * Abstract/Logic Reasoning: {aptitude_summary['logicSense']}
- Career Values: {combined_data['assessment']['careerValues']}
- Study Experience: {combined_data['assessment']['studyExperience']}
- Persistence Profile (synthesized across all behavioral tasks):
  * Effort Rating: {combined_data['persistenceEffortRating'] or 'Not completed'}
  * Approach Style: {combined_data['persistenceApproachStyle'] or 'Not completed'}
  * Highest Tier Reached: {combined_data['persistenceHighestTier'] or 'N/A'}
  * Counselor Flags: {', '.join(combined_data['persistenceCounselorFlags']) if combined_data['persistenceCounselorFlags'] else 'None'}

FILTERING RULES — apply these strictly before generating recommendations:
1. If Effort Rating contains "move on quickly" AND Approach Style contains "Intuitive": DO NOT recommend NEET, JEE, UPSC, CA, or any multi-year competitive exam path as a primary recommendation. These paths require sustained grind that this student's behavioral profile flags as high-risk.
2. If Effort Rating contains "move on quickly" OR Approach Style contains "Cautious": Prioritize careers with faster feedback loops — design, media, applied tech, vocational, or entrepreneurial paths.
3. If Effort Rating contains "stick with hard problems" AND Approach Style contains "Systematic": Green signal for medicine, research, engineering, CA, law. These paths suit this profile.
4. If Counselor Flags contain "fear of failure" or "complexity-shutdown": Flag at least one recommendation as needing counselor guidance before commitment.
5. If Effort Rating contains "high effort, poor strategy": Include at least one recommendation that explicitly benefits from structured mentorship or coaching.

Return ONLY valid JSON:
[
  {{
    "title": "Career Title",
    "description": "2-3 line description why this matches",
    "matchScore": 95
  }},
  {{
    "title": "Career Title 2",
    "description": "2-3 line description",
    "matchScore": 88
  }},
  {{
    "title": "Career Title 3",
    "description": "2-3 line description",
    "matchScore": 82
  }}
]

CRITICAL: Match scores must be realistic (70-98) and descending. Apply all filtering rules above before selecting careers."""
        
        response = bot.generate_with_fallback(prompt)
        
        if not response or not response.text:
            raise Exception("AI career recommendation failed")
        
        response_text = response.text.strip()
        
        if '```json' in response_text:
            response_text = response_text.split('```json')[1].split('```')[0].strip()
        elif '```' in response_text:
            response_text = response_text.split('```')[1].split('```')[0].strip()
        
        import re
        response_text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', response_text)
        response_text = response_text.replace('&quot;', '"').replace('&#39;', "'")
        response_text = re.sub(r'\s+', ' ', response_text).strip()
        
        careers = json.loads(response_text)
        
        if not isinstance(careers, list) or len(careers) != 3:
            raise Exception("AI must return exactly 3 career recommendations")
        
        # Save recommendations
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO career_recommendations (username, recommendations_json, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(username) DO UPDATE SET
                recommendations_json = excluded.recommendations_json,
                updated_at = CURRENT_TIMESTAMP
        ''', (username, json.dumps(careers)))
        conn.commit()
        conn.close()
        
        bot.logger.info(f"Saved top 3 career recommendations for user: {username}")
        
        return jsonify({'success': True, 'careers': careers})
        
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        bot.logger.error(f"Top 3 careers generation failed: {str(e)}")
        return jsonify({'success': False, 'message': f'Failed to generate recommendations: {str(e)}'})

@app.route('/api/get-mindset-report', methods=['POST', 'OPTIONS'])
def get_mindset_report():
    """Return full assessment data for the mindset analysis report"""
    if request.method == 'OPTIONS':
        from flask import Response as FlaskResponse
        resp = FlaskResponse(status=200)
        resp.headers['Access-Control-Allow-Origin'] = '*'
        resp.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        return resp
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})

        username = data['username']
        db_path = bot.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Fetch onboarding data
        cursor.execute(
            'SELECT name, class_level, board, district FROM onboarding_data WHERE username = ?',
            (username,)
        )
        ob = cursor.fetchone()

        # Fetch full assessment row
        cursor.execute('''
            SELECT why_here, five_year_vision, career_thinking, career_ruled_out,
                   free_sunday, group_role, job_bothers,
                   favorite_subjects, difficult_subject, subject_marks, study_experience,
                   outside_activities, external_validation, self_initiated,
                   study_location, family_budget, career_values,
                   planning_style, stress_response, surprise_reaction,
                   number_sense_score, word_sense_score, shape_sense_score, logic_sense_score,
                   persistence_effort_rating, persistence_approach_style,
                   persistence_counselor_flags, persistence_highest_tier,
                   constraint_grid_approach, constraint_grid_solved, constraint_grid_counselor_flag,
                   blackbox_approach, blackbox_solved, blackbox_abandoned_last_guess, blackbox_counselor_flag,
                   cipher_information_gathering, cipher_persistence, cipher_rule_adaptability,
                   cipher_solved, cipher_counselor_flags,
                   game5_task1_insight, game5_task2_insight, game5_task3_insight,
                   module1_insight, module2_insight, module3_insight,
                   module4_insight, module5_insight, module6_insight
            FROM user_session WHERE username = ?
        ''', (username,))
        row = cursor.fetchone()

        # Fetch top career recommendation
        cursor.execute(
            'SELECT recommendations_json FROM career_recommendations WHERE username = ?',
            (username,)
        )
        rec_row = cursor.fetchone()
        conn.close()

        if not row:
            return jsonify({'success': False, 'message': 'No assessment data found'})
        
        # Generate insights if not cached
        insights = {
            'task1': row[40] if len(row) > 40 and row[40] else None,
            'task2': row[41] if len(row) > 41 and row[41] else None, 
            'task3': row[42] if len(row) > 42 and row[42] else None
        }
        
        # Check if any insights are missing and generate them
        if not all(insights.values()):
            try:
                generated_insights = bot.generate_game5_insights(
                    effort_rating=row[24],
                    approach_style=row[25], 
                    highest_tier=row[27],
                    constraint_approach=row[28],
                    constraint_solved=bool(row[29]) if row[29] is not None else None,
                    cipher_gathering=row[35],
                    cipher_persistence=row[36],
                    cipher_adaptability=row[37]
                )
                
                # Update database with generated insights
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor() 
                cursor.execute('''
                    UPDATE user_session SET 
                        game5_task1_insight = COALESCE(game5_task1_insight, ?),
                        game5_task2_insight = COALESCE(game5_task2_insight, ?),
                        game5_task3_insight = COALESCE(game5_task3_insight, ?)
                    WHERE username = ?
                ''', (
                    generated_insights.get('task1') if not insights['task1'] else None,
                    generated_insights.get('task2') if not insights['task2'] else None, 
                    generated_insights.get('task3') if not insights['task3'] else None,
                    username
                ))
                conn.commit()
                conn.close()
                
                # Update insights with generated ones
                for key, value in generated_insights.items():
                    if not insights[key]:
                        insights[key] = value
                        
            except Exception as e:
                bot.logger.error(f"Failed to generate game5 insights: {str(e)}")
                # Continue with None values if generation fails

        top_career = None
        if rec_row:
            try:
                recs = json.loads(rec_row[0])
                top_career = recs[0] if recs else None
            except Exception:
                pass

        # Combine all counselor flags
        persistence_flags = json.loads(row[26]) if row[26] else []
        cg_flag = row[30]
        bb_flag = row[34]
        cipher_flags = json.loads(row[39]) if row[39] else []
        all_flags = persistence_flags + ([cg_flag] if cg_flag else []) + ([bb_flag] if bb_flag else []) + cipher_flags

        report = {
            'onboarding': {
                'name': ob[0] if ob else '',
                'classLevel': ob[1] if ob else '',
                'board': ob[2] if ob else '',
                'district': ob[3] if ob else '',
            },
            'motivation': {
                'whyHere': row[0],
                'fiveYearVision': row[1],
                'careerThinking': row[2],
                'careerRuledOut': row[3],
            },
            'cognitiveStyle': {
                'freeSunday': row[4],
                'groupRole': row[5],
                'jobBothers': row[6],
            },
            'academic': {
                'favoriteSubjects': json.loads(row[7]) if row[7] else [],
                'difficultSubject': row[8],
                'subjectMarks': json.loads(row[9]) if row[9] else {},
                'studyExperience': row[10],
            },
            'behavioral': {
                'outsideActivities': json.loads(row[11]) if row[11] else [],
                'externalValidation': row[12],
                'selfInitiated': row[13],
            },
            'constraints': {
                'studyLocation': json.loads(row[14]) if row[14] else [],
                'familyBudget': row[15],
                'careerValues': json.loads(row[16]) if row[16] else [],
            },
            'calibration': {
                'planningStyle': row[17],
                'stressResponse': row[18],
                'surpriseReaction': row[19],
            },
            'aptitude': {
                'numberSense': row[20],
                'wordSense': row[21],
                'shapeSense': row[22],
                'logicSense': row[23],
            },
            'persistence': {
                'effortRating': row[24],
                'approachStyle': row[25],
                'counselorFlags': all_flags,
                'highestTier': row[27],
                'constraintGridApproach': row[28],
                'constraintGridSolved': bool(row[29]),
                'blackBoxApproach': row[31],
                'blackBoxSolved': bool(row[32]),
                'blackBoxAbandonedLastGuess': bool(row[33]),
            },
            'cipher': {
                'informationGathering': row[35],
                'persistence': row[36],
                'ruleAdaptability': row[37],
                'solved': bool(row[38]) if row[38] is not None else None,
                'counselorFlags': json.loads(row[39]) if row[39] else [],
            },
            'game5Insights': {
                'task1': row[40] if len(row) > 40 and row[40] else None,
                'task2': row[41] if len(row) > 41 and row[41] else None,
                'task3': row[42] if len(row) > 42 and row[42] else None,
            },
            # Per-module AI insight ("here's what we noticed"), shown below the
            # raw answers in the corresponding Career Report section.
            'moduleInsights': {
                'module1': row[43] if len(row) > 43 else None,
                'module2': row[44] if len(row) > 44 else None,
                'module3': row[45] if len(row) > 45 else None,
                'module4': row[46] if len(row) > 46 else None,
                'module5': row[47] if len(row) > 47 else None,
                'module6': row[48] if len(row) > 48 else None,
            },
            'topCareer': top_career,
            'game5Insights': insights,
        }

        return jsonify({'success': True, 'report': report})

    except Exception as e:
        bot.logger.error(f"Get mindset report failed: {str(e)}")
        return jsonify({'success': False, 'message': f'Failed to fetch mindset report: {str(e)}'})


# ── Cipher helpers (mirror frontend logic — answer always derived, never stored) ──────────────

def cipher_letter_count(sentence):
    """Tier 1: count letters per word, join as string."""
    import re
    return ''.join(str(len(re.sub(r'[^a-zA-Z]', '', w))) for w in sentence.strip().split())

def cipher_first_letters(sentence):
    """Tier 2/3: first letter of each word, uppercase."""
    import re
    result = []
    for w in sentence.strip().split():
        letters = re.sub(r'[^a-zA-Z]', '', w)
        if letters:
            result.append(letters[0].upper())
    return ''.join(result)

def cipher_sorted(s):
    import re
    return ''.join(sorted(re.sub(r'[^A-Za-z]', '', s).upper()))

# ── Static pools ───────────────────────────────────────────────────────────────
# Tier 1: word lengths 2-8, 4-6 words. Answer always re-derived from sentence.
TIER1_POOL = [
    "Spy Networks Operate Worldwide Daily",
    "Agents Decode Hidden Enemy Files",
    "Border Guards Watch Coded Signals",
    "Night Patrols Scan Dark Rooftops",
    "Radar Systems Track Moving Targets",
    "Field Agents Report Back Safely",
    "Secure Lines Carry Vital Data",
    "Drones Survey Urban Target Zones",
    "Coded Maps Guide Ground Units",
    "Silent Hawks Watch Border Posts",
]

# Tier 2: (sentence, target_word) — sentence first-letters spell the word exactly.
# Validated at startup by cipher_first_letters().
TIER2_POOL_RAW = [
    ("British Rangers Advance Very Efficiently.", "BRAVE"),
    ("Careful Agents Recon Every Target.", "CARET"),
    ("Scouts Hunt Away Dark Enemies.", "SHADE"),
    ("Foxes Operate Rapidly Constantly Everywhere.", "FORCE"),
    ("Brave Operatives Launch Tactical Strategy.", "BOLTS"),
    ("Night Operatives Target Enemy.", "NOTE"),
    ("Delta Agents Rush Toward Shelter.", "DARTS"),
    ("Foxes Leave At Ground Speed.", "FLAGS"),
    ("Bold Agents Secure Every Road.", "BASER"),
    ("Ground Units Arrive Ready Daily.", "GUARD"),
    ("Silent Operatives Active Regularly.", "SOAR"),
    ("Covert Units Break Enemy Routes.", "CUBER"),
    ("Field Intelligence Reports Everywhere.", "FIRE"),
    ("Rapid Agents Infiltrate Defense.", "RAID"),
    ("Special Targets Operate Near Enemies.", "STONE"),
    ("Covert Activity Reads Enemy Signals.", "CARES"),
    ("Loyal Operatives Cover Known Sectors.", "LOCKS"),
    ("Night Agents Patrol Exhaustively.", "NAPE"),
    ("Black Operations Maintain Balance.", "BOMB"),
]

# Curated word set for anagram validation fallback
_WORD_SET = {
    "STONE","NOTES","TONES","ONSET","SNORE","CARES","RACES","ACRES","SCARE","BASER",
    "BEARS","SABER","SABRE","BARES","BRAVE","RAVEN","BRACE","CARVE","GRAVE","CRAVE",
    "FORCE","FIRES","FRIES","RAIDS","DARTS","YARDS","GUARD","SOAR","OARS","LOCKS",
    "BOLTS","BLOTS","FROST","FORTS","FORTE","FLAGS","CARE","DARE","FARE","HARE","PARE",
    "FIRE","RAID","NOTE","TONE","BOMB","NAPE","NEAP","PANE","BOLD","COLD","FOLD",
    "GOLD","HOLD","SOLD","TOLD","BOLT","BEST","REST","TEST","VEST","WEST","BELT",
    "FELT","MELT","BENT","DENT","RENT","SENT","TENT","VENT","WENT","BEAT","FEAT",
    "HEAT","MEAT","NEAT","SEAT","BEAR","DEAR","FEAR","GEAR","HEAR","NEAR","PEAR",
    "REAR","SEAR","TEAR","WEAR","YEAR","CARET","TRACE","CRATE","CARTE","REACT",
    "SHADE","ASHED","DEASH","HEADS","SNORE","SENOR","REINS","SIREN",
    "NOTE","ENOL","NOEL","LONE","LODE","DONE","BOON","BOMB","MOBS",
    "LOCK","CLOT","COLT","COLS","CUBER","REBUT","BRUTE","RUBES",
    "SOAR","ROAS",
}

def _is_valid_word(word):
    import re
    word = re.sub(r'[^a-z]', '', word.lower())
    if len(word) < 2:
        return False
    # Try nltk wordnet (fast, offline)
    try:
        from nltk.corpus import wordnet
        return bool(wordnet.synsets(word))
    except Exception:
        pass
    # Fallback: Free Dictionary API
    try:
        resp = requests.get(f"https://api.dictionaryapi.dev/api/v2/entries/en/{word}", timeout=3)
        if resp.status_code == 200:
            return True
    except Exception:
        pass
    # Final fallback: curated set
    return word.upper() in _WORD_SET

def _build_tier2_pool():
    valid = []
    for sentence, word in TIER2_POOL_RAW:
        if cipher_first_letters(sentence) == word.upper() and 3 <= len(word) <= 7:
            valid.append((sentence, word.upper()))
    return valid

def _build_tier3_pool(tier2_valid):
    """Reuse tier2 sentences — answer is any valid anagram of their first letters."""
    valid = []
    for sentence, word in tier2_valid:
        target_sorted = cipher_sorted(word)
        anagrams = sorted({w for w in _WORD_SET if cipher_sorted(w) == target_sorted and len(w) == len(word)})
        if anagrams:
            valid.append((sentence, word, anagrams))
    return valid

_TIER2_VALID = _build_tier2_pool()
_TIER3_VALID = _build_tier3_pool(_TIER2_VALID)


@app.route('/api/generate-cipher-questions', methods=['POST'])
def generate_cipher_questions():
    """
    Generate all 3 cipher tier questions.
    Answers are NEVER stored — always re-derived from the sentence at validation time.
    Tier 1: letter count per word joined (deterministic).
    Tier 2: first letter of each word forms the target word.
    Tier 3: first letters rearranged into any valid English word.
    """
    import random
    try:
        # Tier 1
        t1_pool = TIER1_POOL[:]
        random.shuffle(t1_pool)
        t1_sentence = t1_pool[0]
        t1_examples = [{"message": s, "decoded": cipher_letter_count(s)} for s in t1_pool[1:4]]
        tier1 = {
            "tier": 1,
            "id": f"t1-{abs(hash(t1_sentence)) % 10000}",
            "examples": t1_examples,
            "testMessage": t1_sentence,
            "validAnswers": [cipher_letter_count(t1_sentence)],
        }

        if len(_TIER2_VALID) < 4:
            raise Exception("Tier 2 pool too small")

        # Tier 2
        t2_pool = _TIER2_VALID[:]
        random.shuffle(t2_pool)
        t2_sentence, t2_word = t2_pool[0]
        t2_examples = [{"message": s, "decoded": w} for s, w in t2_pool[1:4]]
        tier2 = {
            "tier": 2,
            "id": f"t2-{abs(hash(t2_sentence)) % 10000}",
            "examples": t2_examples,
            "testMessage": t2_sentence,
            "validAnswers": [cipher_first_letters(t2_sentence)],
        }

        if not _TIER3_VALID:
            raise Exception("Tier 3 pool empty")

        # Tier 3
        t3_pool = _TIER3_VALID[:]
        random.shuffle(t3_pool)
        t3_sentence, t3_letters, t3_valid_words = t3_pool[0]
        # Examples show first-letter extraction (student sees the pattern, must also anagram)
        t3_examples = [{"message": s, "decoded": w} for s, w in t2_pool[1:4]]
        tier3 = {
            "tier": 3,
            "id": f"t3-{abs(hash(t3_sentence)) % 10000}",
            "examples": t3_examples,
            "testMessage": t3_sentence,
            "validAnswers": t3_valid_words,
        }

        return jsonify({'success': True, 'questions': {'tier1': tier1, 'tier2': tier2, 'tier3': tier3}})
    except Exception as e:
        bot.logger.error(f"Cipher question generation failed: {str(e)}")
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/generate-game5-insights', methods=['POST'])
def generate_game5_insights():
    """Generate and cache game 5 behavioral insights"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'error': 'Username required'})
        
        username = data['username']
        
        # Get current game 5 data
        db_path = bot.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT persistence_effort_rating, persistence_approach_style, persistence_highest_tier,
                   constraint_grid_approach, constraint_grid_solved,
                   cipher_information_gathering, cipher_persistence, cipher_rule_adaptability,
                   game5_task1_insight, game5_task2_insight, game5_task3_insight
            FROM user_session WHERE username = ?
        ''', (username,))
        row = cursor.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'success': False, 'error': 'No game 5 data found'})
        
        # Check if insights already exist
        if row[8] and row[9] and row[10]:
            conn.close()
            return jsonify({
                'success': True, 
                'insights': {
                    'task1': row[8],
                    'task2': row[9], 
                    'task3': row[10]
                },
                'cached': True
            })
        
        # Generate new insights
        insights = bot.generate_game5_insights(
            effort_rating=row[0],
            approach_style=row[1],
            highest_tier=row[2],
            constraint_approach=row[3],
            constraint_solved=bool(row[4]) if row[4] is not None else None,
            cipher_gathering=row[5],
            cipher_persistence=row[6],
            cipher_adaptability=row[7]
        )
        
        # Cache insights in database
        cursor.execute('''
            UPDATE user_session SET
                game5_task1_insight = ?,
                game5_task2_insight = ?,
                game5_task3_insight = ?
            WHERE username = ?
        ''', (insights['task1'], insights['task2'], insights['task3'], username))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'insights': insights, 'cached': False})
        
    except AIError as e:
        # Typed AI failure -> real HTTP status (429 / 503 / 400),
        # so the client can distinguish "retry later" from "bad input".
        return ai_error_response(e)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/validate-word', methods=['POST'])
def validate_word():
    """Tier 3 word check — is the student's anagram a real English word?"""
    try:
        data = request.json
        word = data.get('word', '').strip().lower()
        if not word:
            return jsonify({'valid': False})
        return jsonify({'valid': _is_valid_word(word)})
    except Exception as e:
        return jsonify({'valid': False, 'error': str(e)})


if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=8080)