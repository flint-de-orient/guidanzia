import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import {
  Brain, ArrowLeft, Target, Lightbulb, BookOpen, Heart, Shield, Zap,
  BarChart3, AlertCircle, CheckCircle2, TrendingUp, Users, Gamepad2,
} from 'lucide-react';
import { TranslatedText } from '../components/TranslatedText';
import { useAuth } from '../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080';

// ── Label maps ────────────────────────────────────────────────────────────────
const WHY_HERE: Record<string, string> = {
  'no-idea': 'No idea what to do after Class 12',
  'validate': 'Has a plan and wants to validate it',
  'disagree': 'Family disagreement about career',
  'explore': 'Wants to explore options before deciding',
};
const VISION: Record<string, string> = {
  'conventional': 'Expert / specialist work (uniform or lab coat)',
  'enterprising': 'Leadership / decision-making',
  'artistic': 'Creating — design, writing, performance',
  'entrepreneurial': 'Running own venture',
};
const FREE_SUNDAY: Record<string, string> = {
  'puzzle': 'Solving puzzles / strategy games',
  'friends': 'Hanging out and meeting people',
  'create': 'Making things — art, music, writing',
  'build': 'Fixing or building with hands',
  'organize': 'Organizing notes, room, life',
  'read': 'Reading about how the world works',
};
const GROUP_ROLE: Record<string, string> = {
  'plan': 'Planner — divides work and leads strategy',
  'research': 'Researcher — digs into analysis',
  'present': 'Presenter — shapes the final output',
  'motivate': 'Motivator — keeps the team energized',
  'execute': 'Executor — builds and delivers',
};
const JOB_BOTHERS: Record<string, string> = {
  'repetitive': 'Repeating the same task every day',
  'decisions': 'High-stakes decisions and blame',
  'alone': 'Working alone without human contact',
  'no-result': 'Not seeing a clear result of work',
  'strict-rules': 'Strict rules and procedures',
};
const STUDY_EXP: Record<string, string> = {
  'flow': 'Loses track of time — deep flow state',
  'work': 'Does well but it still feels like work',
  'class-only': 'Enjoys class but struggles to study alone',
  'videos': 'Prefers videos and discussion over textbooks',
};
const EXT_VAL: Record<string, string> = {
  'agree': 'Yes, and agrees with it',
  'unsure': 'Yes, but unsure',
  'disagree': 'Yes, but does not want to do it',
  'no': 'No external validation received',
};
const BUDGET: Record<string, string> = {
  'clear-budget': 'Yes — clear budget discussed',
  'depends': 'Yes — depends on the course',
  'not-really': 'Not really discussed',
  'no-money-factor': 'Prefers not to factor money in',
};
const VALUES: Record<string, string> = {
  'earning': 'Earning well',
  'interest': 'Doing genuinely interesting work',
  'family-pride': 'Family pride',
  'stability': 'Stability and security',
  'impact': 'Making a real impact',
};
const PLANNING: Record<string, string> = {
  'clear-plan': 'Prefers a clear plan and follows it',
  'options': 'Prefers options and figures it out as they go',
  'others': 'Wants to know what worked for others',
  'try-things': 'Learns by trying things',
};
const STRESS: Record<string, string> = {
  'power-through': 'Powers through and finishes',
  'take-break': 'Takes a break and comes back',
  'talk': 'Talks to someone about it',
  'procrastinate': 'Gets overwhelmed and procrastinates',
};
const SURPRISE: Record<string, string> = {
  'excited': 'Excited to explore it',
  'skeptical': 'Skeptical but curious',
  'wrong': 'Feels the system got it wrong',
  'counselor': 'Wants to talk to a counselor',
};
const CONSTRAINT_APPROACH: Record<string, string> = {
  'systematic-analytical':   'Scanned carefully and found the most constrained cell first — systematic, analytical entry.',
  'cautious':                'Scanned carefully but did not find the easiest entry point — thorough but not yet pattern-trained.',
  'intuitive-adaptive':      'Jumped in, made some mistakes, but corrected them — intuitive with good self-correction.',
  'low-ambiguity-tolerance': 'Used the hint almost immediately — low tolerance for ambiguity; prefers clearly defined steps.',
  'complexity-shutdown':     'Did not attempt the grid after 30 seconds — froze at complexity; high-priority counselor flag.',
};

const APTITUDE_LABEL = (score: number | null) => {
  if (score === null || score === undefined) return 'Not completed';
  if (score >= 7) return 'Exceptional';
  if (score >= 5) return 'Strong';
  if (score >= 3) return 'Moderate';
  return 'Developing';
};
const APTITUDE_COLOR = (score: number | null) => {
  if (score === null || score === undefined) return 'bg-gray-100 text-gray-500';
  if (score >= 7) return 'bg-emerald-100 text-emerald-700';
  if (score >= 5) return 'bg-indigo-100 text-indigo-700';
  if (score >= 3) return 'bg-amber-100 text-amber-700';
  return 'bg-red-100 text-red-700';
};

// ── Section card wrapper ──────────────────────────────────────────────────────
function Section({ icon, title, color, children }: {
  icon: React.ReactNode; title: string; color: string; children: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
      <h2 className={`text-xl font-bold text-gray-900 mb-6 flex items-center gap-3`}>
        <span className={`w-10 h-10 rounded-xl flex items-center justify-center ${color}`}>
          {icon}
        </span>
        <TranslatedText>{title}</TranslatedText>
      </h2>
      {children}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string | undefined | null }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 py-3 border-b border-gray-100 last:border-0">
      <span className="text-sm font-semibold text-gray-500 sm:w-48 flex-shrink-0">
        <TranslatedText>{label}</TranslatedText>
      </span>
      <span className="text-sm text-gray-800">
        <TranslatedText>{value || '—'}</TranslatedText>
      </span>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────
export function CareerReport() {
  const { user, loading: authLoading } = useAuth();
  const navigate = useNavigate();
  const [report, setReport] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Wait for auth to finish loading before attempting fetch
    if (authLoading) return;

    const fetchReport = async () => {
      // Try user from auth context first, then fall back to localStorage directly
      const storedUser = (() => {
        try { return JSON.parse(localStorage.getItem('edubot_user') || 'null'); } catch { return null; }
      })();
      const username = user?.email || storedUser?.email || sessionStorage.getItem('username');

      if (!username) {
        navigate('/login');
        return;
      }

      try {
        const res = await fetch(`${API_BASE}/api/get-mindset-report`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username }),
        });
        const data = await res.json();
        if (data.success) {
          setReport(data.report);
        } else {
          setError(data.message || 'No report found');
        }
      } catch (e) {
        console.error('Failed to fetch mindset report', e);
        setError('Failed to load report. Please try again.');
      } finally {
        setLoading(false);
      }
    };

    fetchReport();
  }, [user, authLoading, navigate]);

  if (authLoading || loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4" />
          <p className="text-gray-600">Loading your mindset report...</p>
        </div>
      </div>
    );
  }

  if (!report) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Report Not Available</h1>
          <p className="text-gray-600 mb-6">{error || 'Complete the assessment first to view your mindset report.'}</p>
          <Link to="/onboarding-new"><Button>Take Assessment</Button></Link>
        </div>
      </div>
    );
  }

  const { onboarding, motivation, cognitiveStyle, academic, behavioral, constraints, calibration, aptitude, persistence, cipher, topCareer } = report;

  const buildCipherInsight = () => {
    if (!cipher?.informationGathering) return null;
    const info: Record<string, string> = {
      patient:   'You studied multiple examples before attempting — you gather information before committing.',
      moderate:  'You balanced studying examples with attempting — a measured approach to new problems.',
      impulsive: 'You attempted before seeing most examples — you act on limited information and adjust from feedback.',
    };
    const pers: Record<string, string> = {
      high:   'You persisted through wrong answers without giving up — strong grit signal.',
      medium: 'You attempted most transmissions but stepped back from some — selective persistence.',
      low:    'You gave up on multiple transmissions — low frustration tolerance under ambiguity.',
    };
    const adapt: Record<string, string> = {
      fast:     'You adapted to a completely different rule type on the first attempt — strong cognitive flexibility.',
      moderate: 'You needed a couple of attempts to adjust when the rule changed — moderate adaptability.',
      slow:     'The rule change across transmissions cost you multiple attempts — you prefer consistent rule environments.',
    };
    return {
      infoGathering: info[cipher.informationGathering] ?? cipher.informationGathering,
      persistence:   pers[cipher.persistence]         ?? cipher.persistence,
      adaptability:  adapt[cipher.ruleAdaptability]   ?? cipher.ruleAdaptability,
      flags:         cipher.counselorFlags ?? [],
    };
  };
  const cipherInsight = buildCipherInsight();

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-indigo-50/30">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-50 shadow-sm">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link to="/recommendations">
              <Button variant="ghost" size="sm">
                <ArrowLeft className="w-4 h-4 mr-2" />
                <span className="hidden sm:inline"><TranslatedText>Back</TranslatedText></span>
              </Button>
            </Link>
            <div className="flex items-center gap-2">
              <div className="w-9 h-9 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
                <Brain className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-base sm:text-lg font-bold text-gray-900">
                  <TranslatedText>Mindset Analysis Report</TranslatedText>
                </h1>
                <p className="text-xs text-gray-500">{onboarding?.name || ''}</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">

        {/* Section 1 — Motivation Profile */}
        <Section icon={<Target className="w-5 h-5 text-indigo-600" />} title="1. Motivation Profile" color="bg-indigo-100">
          <Row label="Why here" value={WHY_HERE[motivation?.whyHere]} />
          <Row label="5-year vision" value={VISION[motivation?.fiveYearVision]} />
          <Row label="Career thinking about" value={motivation?.careerThinking || 'Not specified'} />
          <Row label="Career ruled out" value={motivation?.careerRuledOut || 'Not specified'} />
        </Section>

        {/* Section 2 — Cognitive & Work Style */}
        <Section icon={<Lightbulb className="w-5 h-5 text-amber-600" />} title="2. Cognitive & Work Style" color="bg-amber-100">
          <Row label="Free Sunday preference" value={FREE_SUNDAY[cognitiveStyle?.freeSunday]} />
          <Row label="Group project role" value={GROUP_ROLE[cognitiveStyle?.groupRole]} />
          <Row label="Job deal-breaker" value={JOB_BOTHERS[cognitiveStyle?.jobBothers]} />
        </Section>

        {/* Section 3 — Academic Strengths */}
        <Section icon={<BookOpen className="w-5 h-5 text-emerald-600" />} title="3. Academic Strengths vs Aspirations" color="bg-emerald-100">
          <Row label="Favourite subjects" value={(academic?.favoriteSubjects || []).join(', ') || '—'} />
          <Row label="Most difficult subject" value={academic?.difficultSubject || '—'} />
          <Row label="Study experience" value={STUDY_EXP[academic?.studyExperience]} />
          {academic?.favoriteSubjects?.length > 0 && (
            <div className="mt-4">
              <p className="text-sm font-semibold text-gray-500 mb-2"><TranslatedText>Marks in favourite subjects</TranslatedText></p>
              <div className="flex flex-wrap gap-2">
                {academic.favoriteSubjects.map((sub: string) => (
                  <span key={sub} className="px-3 py-1 bg-emerald-50 border border-emerald-200 rounded-lg text-xs font-medium text-emerald-800">
                    {sub}: {academic.subjectMarks?.[sub] || '—'}
                  </span>
                ))}
              </div>
            </div>
          )}
        </Section>

        {/* Section 4 — Behavioral Signals */}
        <Section icon={<Users className="w-5 h-5 text-purple-600" />} title="4. Behavioral Signals" color="bg-purple-100">
          <Row label="Outside activities" value={(behavioral?.outsideActivities || []).map((a: string) => a.replace('-', ' ')).join(', ') || '—'} />
          <Row label="External validation" value={EXT_VAL[behavioral?.externalValidation]} />
          <Row label="Self-initiated activity" value={behavioral?.selfInitiated || 'Not specified'} />
        </Section>

        {/* Section 5 — Constraints & Values */}
        <Section icon={<Heart className="w-5 h-5 text-rose-600" />} title="5. Constraints & Values" color="bg-rose-100">
          <Row label="Open to study in" value={(constraints?.studyLocation || []).join(', ') || '—'} />
          <Row label="Family budget discussion" value={BUDGET[constraints?.familyBudget]} />
          <Row label="Top career values" value={(constraints?.careerValues || []).map((v: string) => VALUES[v] || v).join(' → ') || '—'} />
        </Section>

        {/* Section 6 — Persistence Profile */}
        <Section icon={<Shield className="w-5 h-5 text-teal-600" />} title="6. Persistence Profile" color="bg-teal-100">
          <Row label="Effort rating" value={persistence?.effortRating || 'Not completed'} />
          <Row label="Approach style" value={persistence?.approachStyle || 'Not completed'} />
          {persistence?.counselorFlags?.length > 0 && (
            <div className="mt-4 space-y-2">
              <p className="text-sm font-semibold text-red-600 flex items-center gap-1">
                <AlertCircle className="w-4 h-4" />
                <TranslatedText>Counselor Flags</TranslatedText>
              </p>
              {persistence.counselorFlags.map((flag: string, i: number) => (
                <div key={i} className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-xl">
                  <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                  <p className="text-xs text-red-700">{flag}</p>
                </div>
              ))}
            </div>
          )}
        </Section>

        {/* Section 7 — Aptitude Pattern */}
        <Section icon={<BarChart3 className="w-5 h-5 text-indigo-600" />} title="7. Aptitude Pattern" color="bg-indigo-100">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[
              { label: 'Quantitative', score: aptitude?.numberSense },
              { label: 'Verbal', score: aptitude?.wordSense },
              { label: 'Spatial', score: aptitude?.shapeSense },
              { label: 'Abstract / Logic', score: aptitude?.logicSense },
            ].map(({ label, score }) => (
              <div key={label} className="text-center p-4 bg-gray-50 rounded-xl border border-gray-200">
                <p className="text-xs font-semibold text-gray-500 mb-2"><TranslatedText>{label}</TranslatedText></p>
                <p className="text-2xl font-bold text-gray-900 mb-1">{score ?? '—'}<span className="text-sm text-gray-400">/8</span></p>
                <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${APTITUDE_COLOR(score)}`}>
                  <TranslatedText>{APTITUDE_LABEL(score)}</TranslatedText>
                </span>
              </div>
            ))}
          </div>
        </Section>

        {/* Section 8 — Game 5 Behavioural Assessment */}
        <Section icon={<Gamepad2 className="w-5 h-5 text-teal-600" />} title="8. Game 5 — Behavioural Assessment" color="bg-teal-100">

          {/* Task 1 — Sliding Tile */}
          <div className="mb-6">
            <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-3">Task 1 — Sliding Tile (Persistence)</p>
            <Row label="Effort" value={persistence?.effortRating || 'Not completed'} />
            <Row label="Approach" value={persistence?.approachStyle || 'Not completed'} />
            <Row label="Highest tier reached" value={persistence?.highestTier ? `Tier ${persistence.highestTier}` : 'Not completed'} />
            {report?.game5Insights?.task1 && (
              <div className="mt-3 p-3 bg-blue-50 border border-blue-200 rounded-xl">
                <p className="text-xs font-semibold text-blue-700 mb-1">Behavioral Insight</p>
                <p className="text-xs text-blue-600">{report.game5Insights.task1}</p>
              </div>
            )}
          </div>

          {/* Task 2 — Constraint Grid */}
          <div className="pt-4 border-t border-gray-100 mb-6">
            <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-3">Task 2 — Constraint Grid (Problem Entry)</p>
            <Row label="Approach" value={persistence?.constraintGridApproach ? (CONSTRAINT_APPROACH[persistence.constraintGridApproach] ?? persistence.constraintGridApproach) : 'Not completed'} />
            <Row label="Solved" value={persistence?.constraintGridSolved !== undefined && persistence?.constraintGridSolved !== null ? (persistence.constraintGridSolved ? 'Yes' : 'No') : 'Not completed'} />
            {report?.game5Insights?.task2 && (
              <div className="mt-3 p-3 bg-green-50 border border-green-200 rounded-xl">
                <p className="text-xs font-semibold text-green-700 mb-1">Behavioral Insight</p>
                <p className="text-xs text-green-600">{report.game5Insights.task2}</p>
              </div>
            )}
          </div>

          {/* Task 3 — Secret Agent Cipher */}
          <div className="pt-4 border-t border-gray-100">
            <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-3">Task 3 — Secret Agent Cipher (Cognitive Flexibility)</p>
            {cipherInsight ? (
              <>
                <Row label="Information gathering" value={cipherInsight.infoGathering} />
                <Row label="Persistence under ambiguity" value={cipherInsight.persistence} />
                <Row label="Rule adaptability" value={cipherInsight.adaptability} />
                {report?.game5Insights?.task3 && (
                  <div className="mt-3 p-3 bg-purple-50 border border-purple-200 rounded-xl">
                    <p className="text-xs font-semibold text-purple-700 mb-1">Behavioral Insight</p>
                    <p className="text-xs text-purple-600">{report.game5Insights.task3}</p>
                  </div>
                )}
                {cipherInsight.flags.length > 0 && (
                  <div className="mt-3 space-y-2">
                    {cipherInsight.flags.map((flag: string, i: number) => (
                      <div key={i} className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-xl">
                        <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                        <p className="text-xs text-red-700">{flag}</p>
                      </div>
                    ))}
                  </div>
                )}
              </>
            ) : (
              <>
                <Row label="Status" value="Not completed" />
                {report?.game5Insights?.task3 && (
                  <div className="mt-3 p-3 bg-purple-50 border border-purple-200 rounded-xl">
                    <p className="text-xs font-semibold text-purple-700 mb-1">Behavioral Insight</p>
                    <p className="text-xs text-purple-600">{report.game5Insights.task3}</p>
                  </div>
                )}
              </>
            )}
          </div>

        </Section>

        {/* Section 9 — Final Calibration */}
        <Section icon={<Zap className="w-5 h-5 text-orange-600" />} title="9. Final Calibration" color="bg-orange-100">
          <Row label="Planning style" value={PLANNING[calibration?.planningStyle]} />
          <Row label="Stress response" value={STRESS[calibration?.stressResponse]} />
          <Row label="Reaction to surprises" value={SURPRISE[calibration?.surpriseReaction]} />
        </Section>

        {/* Section 10 — Top Career Match */}
        {topCareer && (
          <div className="bg-gradient-to-br from-indigo-600 to-purple-600 rounded-2xl p-6 sm:p-8 text-white">
            <div className="flex items-center gap-3 mb-4">
              <TrendingUp className="w-6 h-6" />
              <h2 className="text-xl font-bold"><TranslatedText>Top Career Match</TranslatedText></h2>
              <span className="ml-auto text-2xl font-bold">{topCareer.matchScore}%</span>
            </div>
            <h3 className="text-2xl font-bold mb-3">{topCareer.title}</h3>
            <p className="text-indigo-100 leading-relaxed">{topCareer.description}</p>
            <div className="mt-6">
              <Link to="/recommendations">
                <Button className="bg-white text-indigo-600 hover:bg-gray-100">
                  <CheckCircle2 className="w-4 h-4 mr-2" />
                  <TranslatedText>View All Recommendations</TranslatedText>
                </Button>
              </Link>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
