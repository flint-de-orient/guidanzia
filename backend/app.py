import sqlite3
import json
import google.generativeai as genai
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import time
import logging
import requests
from urllib.parse import quote_plus
from datetime import datetime
from translation import translate_text, translate_batch
from playwright.sync_api import sync_playwright
import tempfile

import os

class EducationBot:
    def __init__(self):
        self.setup_ai()
        self.init_database()
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)

    def get_db_path(self):
        """Get the absolute path to the database file in the backend directory"""
        return os.path.join(os.path.dirname(__file__), 'users.db')

    def setup_ai(self):
        self.api_keys = [
            'AIzaSyBvlWkVeMcPKaMql-yxrugmVAAXOYA7508',
            'AIzaSyDBhdFEk7S98E6923X26Pxrt3gvse9eKCI',
            'AIzaSyAlqCbP31OQqYxirnUflqQU6vJOoen7-68'
        ]
        self.current_api_index = 0
        self.model = None
        self.current_model_name = None
        self.api_failures = {}

    def get_working_model(self):
        """Dynamically find and return a working model from available APIs"""
        for attempt in range(len(self.api_keys)):
            api_key = self.api_keys[self.current_api_index]
            
            # Skip recently failed APIs for a cooldown period
            if api_key in self.api_failures:
                if time.time() - self.api_failures[api_key] < 300:  # 5 min cooldown
                    self.current_api_index = (self.current_api_index + 1) % len(self.api_keys)
                    continue
                else:
                    del self.api_failures[api_key]  # Remove expired failure
            
            try:
                genai.configure(api_key=api_key)
                self.logger.info(f"Testing API key {self.current_api_index + 1}")
                
                # Get available models dynamically
                available_models = list(genai.list_models())
                
                for model_info in available_models:
                    if hasattr(model_info, 'supported_generation_methods') and 'generateContent' in model_info.supported_generation_methods:
                        try:
                            model = genai.GenerativeModel(model_info.name)
                            # Test the model with a simple prompt
                            test_response = model.generate_content("Test")
                            
                            if test_response and test_response.text:
                                self.model = model
                                self.current_model_name = model_info.name
                                self.logger.info(f"Successfully connected to {model_info.name} with API key {self.current_api_index + 1}")
                                return self.model
                                
                        except Exception as model_error:
                            self.logger.warning(f"Model {model_info.name} failed: {str(model_error)}")
                            continue
                
                raise Exception(f"No working models found for API key {self.current_api_index + 1}")
                
            except Exception as api_error:
                self.logger.error(f"API key {self.current_api_index + 1} failed: {str(api_error)}")
                self.api_failures[api_key] = time.time()
                self.current_api_index = (self.current_api_index + 1) % len(self.api_keys)
                continue
        
        raise Exception("All API keys exhausted or failed")

    def generate_with_fallback(self, prompt, max_retries=3):
        """Generate content with automatic API switching on failure"""
        for retry in range(max_retries):
            try:
                if not self.model:
                    self.model = self.get_working_model()
                
                api_key_display = self.api_keys[self.current_api_index][:8] + '...'
                print(f"\n{'='*80}")
                print(f"[EduBot] Using API key #{self.current_api_index + 1} ({api_key_display})")
                print(f"[EduBot] Model: {self.current_model_name}")
                print(f"{'='*80}\n")
                self.logger.info(f"[EduBot] API key #{self.current_api_index + 1} ({api_key_display}) | Model: {self.current_model_name}")

                response = self.model.generate_content(prompt)
                
                if response and response.text:
                    # Log token usage
                    usage = getattr(response, 'usage_metadata', None)
                    if usage:
                        prompt_tokens = getattr(usage, 'prompt_token_count', 'N/A')
                        candidates_tokens = getattr(usage, 'candidates_token_count', 'N/A')
                        total_tokens = getattr(usage, 'total_token_count', 'N/A')
                        print(f"\n{'='*80}")
                        print(f"[TOKEN USAGE] Prompt: {prompt_tokens} | Output: {candidates_tokens} | Total: {total_tokens}")
                        print(f"{'='*80}\n")
                        self.logger.info(f"[EduBot] Tokens — prompt: {prompt_tokens} | output: {candidates_tokens} | total: {total_tokens}")
                    return response
                else:
                    raise Exception("Empty response received")
                    
            except Exception as e:
                self.logger.error(f"Generation failed (attempt {retry + 1}): {str(e)}")
                
                # Reset model and try next API
                self.model = None
                self.current_model_name = None
                
                if retry < max_retries - 1:
                    self.current_api_index = (self.current_api_index + 1) % len(self.api_keys)
                    time.sleep(1)  # Brief delay before retry
                    continue
                else:
                    raise Exception(f"All generation attempts failed: {str(e)}")
    
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

CRITICAL REQUIREMENTS:
1. Generate ONLY real, well-known Indian institutes that offer courses for {career_title}
2. Each institute MUST have programs/departments directly related to {career_title}
3. Use REAL institute names and their official websites
4. For government institutes: Use .ac.in, .edu.in, or .gov.in domains
5. For private institutes: Use their verified official domains
6. Each institute must show the specific department/course relevant to {career_title}
7. Provide realistic ratings between 3.8 to 4.8
8. Include major cities across India for better geographic coverage

Generate ONLY valid JSON with this exact structure:
{{
  "institutes": {{
    "government": [
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.5, "website": "[Real .ac.in/.edu.in URL]"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.3, "website": "[Real .ac.in/.edu.in URL]"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.6, "website": "[Real .ac.in/.edu.in URL]"}},
      {{"name": "[Real Government Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.4, "website": "[Real .ac.in/.edu.in URL]"}}
    ],
    "private": [
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.2, "website": "[Real official website]"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.4, "website": "[Real official website]"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.1, "website": "[Real official website]"}},
      {{"name": "[Real Private Institute Name]", "location": "[City, State]", "department": "[Specific department for {career_title}]", "rating": 4.3, "website": "[Real official website]"}}      
    ],
    "distance": [
      {{"name": "Indira Gandhi National Open University (IGNOU)", "location": "New Delhi", "department": "[Relevant IGNOU school/program for {career_title}]", "rating": 4.0, "website": "https://www.ignou.ac.in/"}},
      {{"name": "[Real Distance Learning Institute]", "location": "[City, State]", "department": "[Distance program for {career_title}]", "rating": 3.9, "website": "[Real website]"}},
      {{"name": "[Real Distance Learning Institute]", "location": "[City, State]", "department": "[Distance program for {career_title}]", "rating": 4.1, "website": "[Real website]"}}      
    ],
    "online": [
      {{"name": "NPTEL (National Programme on Technology Enhanced Learning)", "location": "Online", "department": "[Relevant NPTEL courses for {career_title}]", "rating": 4.5, "website": "https://nptel.ac.in/"}},
      {{"name": "Coursera", "location": "Online", "department": "[Relevant specializations for {career_title}]", "rating": 4.6, "website": "https://www.coursera.org/"}},
      {{"name": "edX", "location": "Online", "department": "[Relevant programs for {career_title}]", "rating": 4.6, "website": "https://www.edx.org/"}},
      {{"name": "Udemy", "location": "Online", "department": "[Relevant courses for {career_title}]", "rating": 4.4, "website": "https://www.udemy.com/"}}      
    ]
  }}
}}

CRITICAL: Replace ALL bracketed placeholders with REAL institute names that offer programs for {career_title}. Use ACTUAL official websites. Each department must be specifically relevant to {career_title} profession. Generate institutes from different states for geographic diversity.""",
                
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
                            required_fields = ['name', 'location', 'department', 'rating', 'website']
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
            
        except Exception as e:
            self.logger.error(f"AI content generation failed for {section_type}: {str(e)}")
            raise Exception(f"Fully AI-driven system failed for {section_type}: {str(e)}")

    def init_database(self):
        db_path = self.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(50) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                name VARCHAR(100),
                profile_image TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(50) NOT NULL,
                recommendations TEXT,
                user_profile TEXT,
                last_role_id VARCHAR(100),
                last_role_title VARCHAR(200),
                session_token VARCHAR(255),
                expires_at TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(username)
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
        # Migrate: add new columns if upgrading
        new_session_cols = ['session_token', 'expires_at']
        existing_session_cols = [row[1] for row in cursor.execute('PRAGMA table_info(user_sessions)').fetchall()]
        for col in new_session_cols:
            if col not in existing_session_cols:
                col_type = 'VARCHAR(255)' if col == 'session_token' else 'TIMESTAMP'
                cursor.execute(f'ALTER TABLE user_sessions ADD COLUMN {col} {col_type}')
        
        # Migrate: add name and profile_image columns to users table
        existing_user_cols = [row[1] for row in cursor.execute('PRAGMA table_info(users)').fetchall()]
        if 'name' not in existing_user_cols:
            cursor.execute('ALTER TABLE users ADD COLUMN name VARCHAR(100)')
        if 'profile_image' not in existing_user_cols:
            cursor.execute('ALTER TABLE users ADD COLUMN profile_image TEXT')
        
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
            
            if not result:
                conn.close()
                return {'success': False, 'message': 'Username not found'}
            if result[0] != password:
                conn.close()
                return {'success': False, 'message': 'Invalid password'}
            
            user_name = result[1] or username
            profile_image = result[2]
            
            # Load saved session data
            cursor.execute(
                'SELECT recommendations, user_profile, last_role_id, last_role_title FROM user_sessions WHERE username = ?',
                (username,)
            )
            session_row = cursor.fetchone()
            conn.close()

            session_data = {
                'name': user_name,
                'profileImage': profile_image
            }
            if session_row:
                session_data.update({
                    'recommendations': json.loads(session_row[0]) if session_row[0] else None,
                    'userProfile': json.loads(session_row[1]) if session_row[1] else None,
                    'lastRole': {'roleId': session_row[2], 'roleTitle': session_row[3]} if session_row[2] else None,
                })

            # Load saved job role details
            job_role_details = self.load_job_role_details(username)
            session_data['jobRoleDetails'] = job_role_details

            return {'success': True, 'message': 'Login successful', 'session': session_data}
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
    
    def save_user_session(self, username, recommendations=None, user_profile=None, last_role_id=None, last_role_title=None):
        try:
            db_path = self.get_db_path()
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO user_sessions (username, recommendations, user_profile, last_role_id, last_role_title, updated_at)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(username) DO UPDATE SET
                    recommendations = COALESCE(excluded.recommendations, recommendations),
                    user_profile = COALESCE(excluded.user_profile, user_profile),
                    last_role_id = COALESCE(excluded.last_role_id, last_role_id),
                    last_role_title = COALESCE(excluded.last_role_title, last_role_title),
                    updated_at = CURRENT_TIMESTAMP
            ''', (
                username,
                json.dumps(recommendations) if recommendations else None,
                json.dumps(user_profile) if user_profile else None,
                last_role_id,
                last_role_title,
            ))
            conn.commit()
            conn.close()
            return {'success': True}
        except Exception as e:
            self.logger.error(f"Save session failed: {str(e)}")
            return {'success': False}
    

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

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max request size
CORS(app)
bot = EducationBot()

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
    
    result = bot.login_user(data['username'], data['password'])
    
    # Auto-cleanup incomplete job roles on successful login
    if result.get('success'):
        bot.cleanup_incomplete_job_roles(data['username'])
    
    return jsonify(result)

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
            
    except Exception as e:
        return jsonify({'success': False, 'error': f'Resource generation failed: {str(e)}'})

@app.route('/logout', methods=['POST'])
def logout():
    """Handle user logout - clear session token and expire session"""
    try:
        data = request.json
        username = data.get('username') if data else None
        
        if username:
            # Clear session token and set expiry
            conn = sqlite3.connect('users.db')
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE user_sessions 
                SET session_token = NULL, expires_at = CURRENT_TIMESTAMP 
                WHERE username = ?
            ''', (username,))
            conn.commit()
            conn.close()
            bot.logger.info(f"Session expired for user: {username}")
        
        return jsonify({'success': True, 'message': 'Logged out successfully'})
    except Exception as e:
        bot.logger.error(f"Logout failed: {str(e)}")
        return jsonify({'success': True, 'message': 'Logged out successfully'})  # Always succeed on client side

@app.route('/api/save-session', methods=['POST'])
def save_session():
    data = request.json
    if not data or not data.get('username'):
        return jsonify({'success': False, 'message': 'Username required'})
    return jsonify(bot.save_user_session(
        username=data['username'],
        recommendations=data.get('recommendations'),
        user_profile=data.get('userProfile'),
        last_role_id=data.get('lastRoleId'),
        last_role_title=data.get('lastRoleTitle'),
    ))

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

@app.route('/api/get-user-session', methods=['POST'])
def get_user_session():
    """Get user session data including recommendations"""
    try:
        data = request.json
        if not data or not data.get('username'):
            return jsonify({'success': False, 'message': 'Username required'})
        
        username = data['username']
        
        db_path = bot.get_db_path()
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get user session data
        cursor.execute(
            'SELECT recommendations, user_profile, last_role_id, last_role_title FROM user_sessions WHERE username = ?',
            (username,)
        )
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            session_data = {
                'recommendations': json.loads(result[0]) if result[0] else None,
                'userProfile': json.loads(result[1]) if result[1] else None,
                'lastRole': {'roleId': result[2], 'roleTitle': result[3]} if result[2] else None,
            }
            return jsonify({'success': True, 'session': session_data})
        else:
            return jsonify({'success': False, 'session': None})
            
    except Exception as e:
        bot.logger.error(f"Get user session failed: {str(e)}")
        return jsonify({'success': False, 'message': 'Failed to fetch user session'})

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

@app.route('/api/generate-pdf', methods=['POST'])
def generate_pdf():
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
            
            # Log token usage for PDF generation
            print(f"\n{'='*80}")
            print(f"[PDF GENERATION] Tokens used for this PDF generation")
            print(f"[PDF GENERATION] Role: {role_title}")
            print(f"[PDF GENERATION] Language: {target_language}")
            print(f"[PDF GENERATION] Check above logs for detailed token counts")
            print(f"{'='*80}\n")
            
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
        return send_file(
            pdf_path,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=filename
        )
        
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

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=8080)