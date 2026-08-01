import { useState, useEffect, useRef } from 'react';
import { useParams, Link } from 'react-router';
import { Button } from '../components/ui/button';
import { JobRole } from '../../types/career';
import { JobDetail } from '../../types/career';
import {
  LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import {
  Brain, Home, GraduationCap, Target, Calendar, Building2, IndianRupee, Award, BarChart3, FileText, TrendingUp,
  Users, FileDown, ArrowLeft, X, Menu, CheckCircle2, MapPin, Star, ExternalLink, Youtube, MessageSquare,
  Lightbulb, Download, Loader2,
} from 'lucide-react';

import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';
import { translationService } from '../../services/translationService';

// Session management functions
const saveLastViewedRole = (roleId: string, roleTitle: string) => {
  try {
    localStorage.setItem('edubot_last_role', JSON.stringify({ roleId, roleTitle }));
  } catch { /* ignore */ }
};

const saveJobRoleToServer = async (roleId: string, roleTitle: string, detailData: any) => {
  try {
    const user = (() => {
      try { return JSON.parse(localStorage.getItem('edubot_user') || 'null'); } catch { return null; }
    })();
    if (!user?.email) return;
    await fetch(`${API_BASE}/api/save-job-role`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: user.email, roleId, roleTitle, detailData }),
    });
  } catch { /* non-critical */ }
};

// All sections the backend can generate
const DETAIL_SECTIONS = [
  'overview', 'pathway', 'roadmap',
  'institute', 'fees', 'scholarships', 'jobmarket',
  'certifications', 'salary', 'experts',
  'skills'
];

// Derive the broad domain of a job title so the backend AI stays domain-specific.
// This string is appended to career_title which is substituted into EVERY backend prompt.
function domainQualify(title: string): string {
  const t = title.toLowerCase();

  // Medical / Healthcare
  if (/doctor|physician|surgeon|dentist|dermatolog|cardiolog|neurolog|oncolog|pediatric|psychiatr|radiolog|patholog|gynecolog|orthoped|ophthalmolog|urolog|nephrolog|gastroenterolog|endocrinolog|pulmonolog|anesthesiolog|nurse|pharmacist|physiotherap|occupational therap|speech therap|dietitian|nutritionist|paramedic|medical|clinical|healthcare|mbbs|bds|bpharm|nursing/.test(t)) {
    return `${title} (Medical/Healthcare domain — generate ONLY medical colleges, hospitals, pharma/healthcare companies, and medical professionals as experts)`;
  }

  // Engineering / Technology
  if (/software|engineer|developer|programmer|data scien|machine learning|artificial intelligence|devops|cloud|cybersecur|network|system|full.?stack|frontend|backend|mobile|android|ios|web dev|database|blockchain|embedded|hardware|vlsi|mechanical|civil|electrical|electronics|chemical engineer|aerospace|automobile|robotics|iot/.test(t)) {
    return `${title} (Engineering/Technology domain — generate ONLY engineering colleges, tech companies, and technology professionals as experts)`;
  }

  // Finance / Accounting / Business
  if (/accountant|chartered accountant|ca |cfa|finance|banker|investment|auditor|tax|actuar|economist|financial analyst|credit analyst|risk analyst|portfolio manager|wealth manager|insurance|mba finance|commerce/.test(t)) {
    return `${title} (Finance/Commerce domain — generate ONLY finance/commerce institutes, banks/financial firms, and finance professionals as experts)`;
  }

  // Law
  if (/lawyer|advocate|attorney|legal|solicitor|judge|law clerk|paralegal|corporate law|criminal law|llb|llm/.test(t)) {
    return `${title} (Legal domain — generate ONLY law schools, law firms/courts, and legal professionals as experts)`;
  }

  // Design / Arts / Media
  if (/designer|graphic|ui.?ux|product design|fashion|interior design|architect|animator|illustrator|photographer|filmmaker|journalist|content writer|copywriter|media|advertising|public relation|marketing/.test(t)) {
    return `${title} (Design/Creative/Media domain — generate ONLY design/arts/media institutes, creative agencies, and design professionals as experts)`;
  }

  // Education / Research
  if (/teacher|professor|lecturer|educator|researcher|scientist|academic|phd|research analyst/.test(t)) {
    return `${title} (Education/Research domain — generate ONLY universities/research institutes, academic institutions, and educators/researchers as experts)`;
  }

  // Default: pass title as-is with a generic domain hint
  return `${title} (generate ONLY institutes, companies, and experts that are directly relevant to ${title} profession)`;
}

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080';

// Fetch one section from POST /api/career-details
async function fetchSection(careerTitle: string, sectionType: string, profile: any) {
  const res = await fetch(`${API_BASE}/api/career-details`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ career_title: careerTitle, section_type: sectionType, profile }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  if (!data.success) throw new Error(data.error || `Failed to load ${sectionType}`);
  return data.content;
}

const CACHE_KEY = (roleId: string) => `jobDetail_${roleId}`;

// Persist fully-built details to sessionStorage
function saveDetailCache(roleId: string, detail: JobDetail) {
  try {
    sessionStorage.setItem(CACHE_KEY(roleId), JSON.stringify(detail));
  } catch { /* quota exceeded — ignore */ }
}

// Restore details from sessionStorage cache
function loadDetailCache(roleId: string): JobDetail | null {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY(roleId));
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
}

// Resolve a role from sessionStorage careerRecommendations using flat job-N index
// Falls back to localStorage last role on refresh
function resolveRole(roleId: string): JobRole | undefined {
  // roleId format: job-0, job-1, job-2
  const index = parseInt(roleId.replace('job-', ''), 10);
  if (!isNaN(index)) {
    const stored = sessionStorage.getItem('careerRecommendations');
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        const career = parsed?.careers?.[index];
        if (career) {
          return {
            id: roleId,
            title: career.title,
            domainId: '',
            icon: '🎯',
            matchPercentage: career.matchScore ?? 0,
            salaryRange: '',
            growthRate: '',
            description: career.description ?? '',
          };
        }
      } catch { /* ignore */ }
    }
  }

  // Fallback: localStorage last role (after page refresh)
  const lastRole = (() => {
    try {
      const raw = localStorage.getItem('edubot_last_role');
      return raw ? JSON.parse(raw) : null;
    } catch { return null; }
  })();
  if (lastRole?.roleId === roleId && lastRole?.roleTitle) {
    return {
      id: roleId,
      title: lastRole.roleTitle,
      domainId: '',
      icon: '🎯',
      matchPercentage: 0,
      salaryRange: '',
      growthRate: '',
      description: '',
    };
  }

  return undefined;
}

export function JobRoleDetail() {
  const { roleId } = useParams();
  const [activeSection, setActiveSection] = useState('overview');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [pdfProgress, setPdfProgress] = useState(0);
  const [pdfStatus, setPdfStatus] = useState('');

  // Progress-aware loading state
  const [loadedCount, setLoadedCount] = useState(0);
  const [totalSections] = useState(DETAIL_SECTIONS.length);
  const [loadingDone, setLoadingDone] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loadingFromCache, setLoadingFromCache] = useState(false);

  // Merged details built section by section
  const [details, setDetails] = useState<JobDetail | null>(null);
  const completedRef = useRef(0);

  const role = resolveRole(roleId || '');

  // Track last viewed role for profile page
  useEffect(() => {
    if (role) saveLastViewedRole(role.id, role.title);
  }, [role?.id]);

  // Retrieve stored profile + education level for context
  const storedProfile = (() => {
    try {
      // Primary: dedicated userProfile key saved by onboarding
      const p = sessionStorage.getItem('userProfile');
      if (p) return JSON.parse(p);
      // Fallback: legacy location inside careerRecommendations
      const r = sessionStorage.getItem('careerRecommendations');
      return r ? (JSON.parse(r)?.profile ?? {}) : {};
    } catch { return {}; }
  })();

  const educationLabelMap: Record<string, string> = {
    'class-10': 'Class 10th',
    'class-11': 'Class 11th',
    'class-12': 'Class 12th',
    'graduation': 'Graduation (Pursuing)',
    'graduated': 'Graduated',
    'postgrad': 'Post Graduation',
  };
  const userEducationLevel = educationLabelMap[storedProfile.education] ?? storedProfile.education ?? 'Current Level';

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
  }, [activeSection]);

  // Load ALL sections — restore from cache/server if available, else generate via AI
  useEffect(() => {
    if (!role) return;

    // --- sessionStorage cache hit: restore instantly ---
    const cached = loadDetailCache(roleId || '');
    if (cached) {
      console.log(`[JobRoleDetail] Loaded from sessionStorage cache for ${roleId}`);
      setLoadingFromCache(true);
      setDetails(cached);
      setLoadedCount(DETAIL_SECTIONS.length);
      setLoadingDone(true);
      return;
    }

    // --- No sessionStorage cache: try server DB first ---
    const user = (() => {
      try { return JSON.parse(localStorage.getItem('edubot_user') || 'null'); } catch { return null; }
    })();

    if (user?.email) {
      setLoadingFromCache(true);
      fetch(`${API_BASE}/api/load-job-role`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: user.email, roleId: roleId || '' }),
      })
        .then(r => r.json())
        .then(data => {
          const SECTION_KEYS = ['overview','careerPathway',
            // 'skillsLearning','roadmap90Days',
            'topInstitutes','feesInvestment','scholarships','jobMarket','certifications','salaryGrowth','industryExperts'];
          // Check if at least 8 out of 11 sections exist (70%+ complete)
          const sectionsPresent = SECTION_KEYS.filter((k: string) => data.detail?.[k] !== undefined).length;
          const hasCompleteData = data.success && data.detail && sectionsPresent >= 8;
          
          if (hasCompleteData) {
            console.log(`[JobRoleDetail] Loaded from server: ${sectionsPresent}/11 sections for ${roleId}`);
            const detail = data.detail as JobDetail;
            saveDetailCache(roleId || '', detail);
            setDetails(detail);
            setLoadedCount(DETAIL_SECTIONS.length);
            setLoadingDone(true);
          } else {
            console.log(`[JobRoleDetail] Incomplete server data (${sectionsPresent}/11 sections), regenerating...`);
            runAIGeneration();
          }
        })
        .catch(() => { runAIGeneration(); });
      return;
    }

    runAIGeneration();

    function runAIGeneration() {
    setLoadingFromCache(false); // Reset to show "Generating" instead of "Connecting"
    if (!role) return; // Guard against undefined role
    // Use domain-qualified title as career_title so every backend prompt
    // substitution forces domain-correct institutes, companies, and experts.
    const qualifiedTitle = domainQualify(role.title);

    const enrichedProfile = {
      ...storedProfile,
      education: storedProfile.education ?? storedProfile.educationLevel ?? '',
      career_title: role.title,
      career_domain: role.title,
      strict_domain: true,
      instruction_institutes: `Generate ONLY institutes that offer courses/degrees directly relevant to ${role.title}. Do NOT include unrelated institutes. Each institute must show the specific department or branch related to ${role.title}.`,
      instruction_companies: `Generate ONLY companies that actively hire ${role.title} professionals. Do NOT include companies from unrelated industries. Each company must be a real employer of ${role.title} candidates.`,
      instruction_experts: `Generate ONLY real industry experts who are actual ${role.title} professionals with verified designations. Their advice must be specific to ${role.title} career path.`,
    };

    // Pure AI skeleton — no static data, all fields populated by AI sections
    const aiSkeleton: JobDetail = {
      roleId: roleId || '',
      overview: { description: '', keyResponsibilities: [], whySuitable: [] },
      careerPathway: { currentLevel: userEducationLevel, steps: [] },
      skillsLearning: { mustHave: [], core: [], bonus: [] },
      roadmap90Days: {
        phase1: { learningGoals: [], actionTasks: [], progressIndicators: [] },
        phase2: { learningGoals: [], actionTasks: [], progressIndicators: [] },
        phase3: { learningGoals: [], actionTasks: [], progressIndicators: [] },
      },
      topInstitutes: { government: [], private: [], distanceLearning: [], online: [] },
      feesInvestment: { totalRange: '', description: '', breakdown: [] },
      scholarships: { governmentPrivate: [], bankLoans: [], governmentSchemes: [] },
      jobMarket: { demandLevel: 0, successRate: 0, hiringTrends: [], topCompanies: [], keyInsights: [] },
      certifications: [],
      salaryGrowth: { progression: [], cityComparison: [], salaryTips: [] },
      industryExperts: [],
    };
    setDetails(aiSkeleton);
    completedRef.current = 0;

    // Map backend section keys → JobDetail fields
    const sectionMap: Record<string, (d: JobDetail, content: any) => JobDetail> = {
      overview: (d, c) => ({
        ...d,
        overview: {
          description: c.overview?.role_description ?? d.overview.description,
          keyResponsibilities: c.overview?.key_responsibilities ?? d.overview.keyResponsibilities,
          whySuitable: typeof c.overview?.why_suitable === 'string'
            ? [c.overview.why_suitable]
            : (c.overview?.why_suitable ?? d.overview.whySuitable),
        },
      }),
      pathway: (d, c) => {
        // Handle different possible data structures for pathway
        let pathwayData = [];
        
        if (c.careerPathway?.pathway) {
          pathwayData = c.careerPathway.pathway;
        } else if (c.pathway) {
          pathwayData = Array.isArray(c.pathway) ? c.pathway : [];
        } else if (c.steps) {
          pathwayData = Array.isArray(c.steps) ? c.steps : [];
        } else if (c.careerPathway) {
          pathwayData = Array.isArray(c.careerPathway) ? c.careerPathway : [];
        }
        
        return {
          ...d,
          careerPathway: {
            currentLevel: d.careerPathway.currentLevel,
            steps: pathwayData.map((s: any) => ({
              phase: s.phase ?? s.level ?? s.title ?? s.step ?? s.name ?? '',
              duration: s.duration ?? s.time ?? s.period ?? '',
              description: s.description ?? s.details ?? s.content ?? '',
            })).filter((s: any) => s.phase && s.phase.trim() !== ''),
          },
        };
      },
      //       skills: (d, c) => ({
      //   ...d,
      //   skillsLearning: {
      //     mustHave: (c.skills?.high ?? []).map((s: any) => ({
      //       skill: s.name,
      //       youtubeLink: s.video_url ?? `https://www.youtube.com/results?search_query=${encodeURIComponent(s.name)}+tutorial`,
      //     })),
      //     core: (c.skills?.medium ?? []).map((s: any) => ({
      //       skill: s.name,
      //       youtubeLink: s.video_url ?? `https://www.youtube.com/results?search_query=${encodeURIComponent(s.name)}+tutorial`,
      //     })),
      //     bonus: (c.skills?.low ?? []).map((s: any) => ({
      //       skill: s.name,
      //       youtubeLink: s.video_url ?? `https://www.youtube.com/results?search_query=${encodeURIComponent(s.name)}+tutorial`,
      //     })),
      //   },
      // }),
      // roadmap: (d, c) => ({
      //   ...d,
      //   roadmap90Days: {
      //     phase1: {
      //       learningGoals: c.roadmap?.phase1?.goals ?? d.roadmap90Days.phase1.learningGoals,
      //       actionTasks: c.roadmap?.phase1?.tasks ?? d.roadmap90Days.phase1.actionTasks,
      //       progressIndicators: c.roadmap?.phase1?.progress_indicators ?? d.roadmap90Days.phase1.progressIndicators,
      //     },
      //     phase2: {
      //       learningGoals: c.roadmap?.phase2?.goals ?? d.roadmap90Days.phase2.learningGoals,
      //       actionTasks: c.roadmap?.phase2?.tasks ?? d.roadmap90Days.phase2.actionTasks,
      //       progressIndicators: c.roadmap?.phase2?.progress_indicators ?? d.roadmap90Days.phase2.progressIndicators,
      //     },
      //     phase3: {
      //       learningGoals: c.roadmap?.phase3?.goals ?? d.roadmap90Days.phase3.learningGoals,
      //       actionTasks: c.roadmap?.phase3?.tasks ?? d.roadmap90Days.phase3.actionTasks,
      //       progressIndicators: c.roadmap?.phase3?.progress_indicators ?? d.roadmap90Days.phase3.progressIndicators,
      //     },
      //   },
      // }),
      institute: (d, c) => ({
        ...d,
        topInstitutes: {
          government: (c.institutes?.government ?? []).map((i: any) => ({
            name: i.name,
            location: i.location,
            department: i.department ?? i.specialization ?? '',
            rating: parseFloat(i.rating) || 4.0,
            website: i.website,
            eligibility: i.eligibility ?? 'Not specified',
          })),
          private: (c.institutes?.private ?? []).map((i: any) => ({
            name: i.name,
            location: i.location,
            department: i.department ?? i.specialization ?? '',
            rating: parseFloat(i.rating) || 4.0,
            website: i.website,
            eligibility: i.eligibility ?? 'Not specified',
          })),
          distanceLearning: (c.institutes?.distance ?? []).map((i: any) => ({
            name: i.name,
            location: i.location,
            department: i.department ?? i.specialization ?? '',
            rating: parseFloat(i.rating) || 4.0,
            website: i.website,
            eligibility: i.eligibility ?? 'Not specified',
          })),
          online: (c.institutes?.online ?? []).map((i: any) => ({
            name: i.name,
            location: i.location,
            department: i.department ?? i.specialization ?? '',
            rating: parseFloat(i.rating) || 4.0,
            website: i.website,
            eligibility: i.eligibility ?? 'Open enrollment',
          })),
        },
      }),
      fees: (d, c) => {
        const raw: string = c.fees?.total_investment ?? d.feesInvestment.totalRange;
        // Step 1: convert any USD amounts to INR
        const usdToInr = (s: string) => s
          .replace(/\$\s?([\d,]+(?:\.\d+)?)/g, (_: string, n: string) => `\u20b9${Math.round(parseFloat(n.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
          .replace(/([\d,]+(?:\.\d+)?)\s*USD/gi, (_: string, n: string) => `\u20b9${Math.round(parseFloat(n.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
          .replace(/USD\s*([\d,]+(?:\.\d+)?)/gi, (_: string, n: string) => `\u20b9${Math.round(parseFloat(n.replace(/,/g,''))*83).toLocaleString('en-IN')}`);
        const converted = usdToInr(raw);
        // Step 2: strip everything after '(' or after the unit word — keep only "Rs X-Y Lakhs" part
        // Matches: optional currency prefix + number(s) + optional range + optional unit
        const m = converted.match(
          /(?:Rs\.?\s*|\u20b9\s*)?[\d,]+(?:\.\d+)?(?:\s*[-\u2013]\s*(?:Rs\.?\s*|\u20b9\s*)?[\d,]+(?:\.\d+)?)?(?:\s*(?:Crores?|Lakhs?|LPA|Cr\.?|L|K))?/i
        );
        const totalRange = m ? m[0].trim() : converted.split('(')[0].trim();
        return {
          ...d,
          feesInvestment: {
            totalRange,
            description: c.fees?.note ?? d.feesInvestment.description,
            breakdown: (c.fees?.breakdown ?? []).map((b: any) => ({
              phase: b.category ?? b.phase ?? '',
              cost: b.range ?? b.cost ?? '',
              details: b.duration ?? b.details ?? '',
            })),
          },
        };
      },
      scholarships: (d, c) => {
        const fs = c.financial_support ?? {};
        return {
          ...d,
          scholarships: {
            governmentPrivate: (fs.scholarships ?? []).map((s: any) => ({
              name: s.name ?? 'Scholarship',
              amount: s.amount ?? 'Amount not specified',
              eligibility: s.eligibility ?? 'Eligibility criteria apply',
              website: s.link ?? '#',
            })),
            bankLoans: (fs.loans ?? []).map((l: any) => ({
              name: l.provider ?? 'Education Loan Provider',
              amount: l.max_amount ?? 'Amount varies',
              interestRate: l.interest_rate ?? 'Competitive rates',
              website: l.link ?? '#',
            })),
            governmentSchemes: (fs.government_schemes ?? []).map((g: any) => ({
              name: g.name ?? 'Government Scheme',
              benefits: g.benefit ?? 'Financial assistance',
              eligibility: g.eligibility ?? 'Eligibility criteria apply',
              website: g.link ?? '#',
            })),
          },
        };
      },
      jobmarket: (d, c) => {
        // Convert any USD value to INR in a string
        const toInr = (val: string) => val
          .replace(/\$\s?([\d,]+(?:\.\d+)?)/g, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
          .replace(/([\d,]+(?:\.\d+)?)\s*USD/gi, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
          .replace(/USD\s*([\d,]+(?:\.\d+)?)/gi, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`);
        // Collect key_insights from every possible key the AI might return
        const jm = c.jobmarket ?? c.job_market ?? c;
        const rawInsights =
          jm?.key_insights ??
          jm?.insights ??
          jm?.market_insights ??
          jm?.key_market_insights ??
          jm?.keyInsights ??
          [];
        const keyInsights: string[] = Array.isArray(rawInsights)
          ? rawInsights.map((x: any) => (typeof x === 'string' ? x : x?.insight ?? x?.text ?? x?.point ?? String(x))).filter(Boolean)
          : typeof rawInsights === 'string' ? [rawInsights] : [];
        return {
          ...d,
          jobMarket: {
            demandLevel: jm?.demand_percentage ?? jm?.demand_level ?? d.jobMarket.demandLevel,
            successRate: parseInt(jm?.success_rate) || d.jobMarket.successRate,
            hiringTrends: Array.isArray(jm?.hiring_trends) && jm.hiring_trends.length > 0
              ? jm.hiring_trends.map((t: any) => ({ month: t.month, openings: t.openings }))
              : d.jobMarket.hiringTrends,
            topCompanies: (jm?.top_companies ?? []).map((co: any) => ({
              name: co.name,
              packageRange: toInr(co.package_range ?? co.packageRange ?? ''),
              locations: [co.type ?? '', co.hiring_frequency ?? ''].filter(Boolean),
            })),
            keyInsights,
          },
        };
      },
      certifications: (d, c) => ({
        ...d,
        certifications: (c.certifications ?? []).map((cert: any) => {
          const rawCost: string = String(cert.cost ?? '');
          const toInr = (v: string) => v
            .replace(/\$\s?([\d,]+(?:\.\d+)?)/g, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
            .replace(/([\d,]+(?:\.\d+)?)\s*USD/gi, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`)
            .replace(/USD\s*([\d,]+(?:\.\d+)?)/gi, (_: string, a: string) => `\u20b9${Math.round(parseFloat(a.replace(/,/g,''))*83).toLocaleString('en-IN')}`);
          const finalCost = toInr(rawCost);
          return {
            name: cert.name,
            platform: cert.provider ?? '',
            provider: cert.provider ?? '',
            duration: cert.duration ?? '',
            cost: finalCost || rawCost,
            impact: cert.career_impact ?? 'High',
            link: cert.link ?? '#',
          };
        }),
      }),
      salary: (d, c) => {
        const allCities: Record<string, string> = {
          ...c.salary?.fresher_level?.cities,
          ...c.salary?.['5years_level']?.cities,
        };
        const cityComparison = Object.entries(allCities)
          .filter(([city]) => city && !city.startsWith('['))
          .map(([city, sal]) => ({
            city: city.charAt(0).toUpperCase() + city.slice(1),
            salary: sal as string,
          }));
        const progression = [
          c.salary?.fresher_level?.range && { experience: '0-1 years', salary: c.salary.fresher_level.range, role: 'Fresher' },
          c.salary?.['5years_level']?.range && { experience: '5 years', salary: c.salary['5years_level'].range, role: 'Mid-Level' },
          c.salary?.['10years_level']?.range && { experience: '10 years', salary: c.salary['10years_level'].range, role: 'Senior' },
          c.salary?.['15years_level']?.range && { experience: '15 years', salary: c.salary['15years_level'].range, role: 'Expert' },
        ].filter(Boolean) as { experience: string; salary: string; role: string }[];
        return {
          ...d,
          salaryGrowth: {
            progression: progression.length > 0 ? progression : d.salaryGrowth.progression,
            cityComparison: cityComparison.length > 0 ? cityComparison : d.salaryGrowth.cityComparison,
            salaryTips: c.salary?.growth_tips ?? d.salaryGrowth.salaryTips,
          },
        };
      },
      experts: (d, c) => {
        const expertList = c.experts ?? [];
        if (!Array.isArray(expertList) || expertList.length === 0) return d;
        return {
          ...d,
          industryExperts: expertList.map((e: any) => ({
            name: e.name ?? 'Industry Expert',
            designation: e.designation ?? '',
            company: e.company ?? '',
            experience: e.experience ?? '10+ years', // Add default experience
            advice: [
              e.key_advice,
              e.achievements ? `Achievements: ${e.achievements}` : null,
            ].filter(Boolean).join(' | '),
          })),
        };
      },
    };

    // Section key -> JobDetail field name mapping (matches backend col_map)
    const sectionToDetailKey: Record<string, string> = {
      overview: 'overview',
      pathway: 'careerPathway',
      // skills: 'skillsLearning',
      // roadmap: 'roadmap90Days',
      institute: 'topInstitutes',
      fees: 'feesInvestment',
      scholarships: 'scholarships',
      jobmarket: 'jobMarket',
      certifications: 'certifications',
      salary: 'salaryGrowth',
      experts: 'industryExperts',
    };

    const fetchWithRetry = async (section: string, retries = 3): Promise<void> => {
      for (let attempt = 1; attempt <= retries; attempt++) {
        try {
          const content = await fetchSection(qualifiedTitle, section, enrichedProfile);
          setDetails((prev) => {
            if (!prev) return prev;
            const mapper = sectionMap[section];
            const updated = mapper ? mapper(prev, content) : prev;
            // Save this section to server DB immediately after it's generated
            const detailKey = sectionToDetailKey[section];
            if (detailKey && (updated as any)[detailKey] !== undefined && role) {
              saveJobRoleToServer(roleId || '', role.title, { [detailKey]: (updated as any)[detailKey] });
            }
            return updated;
          });
          return;
        } catch {
          if (attempt === retries) { /* keep skeleton fallback */ }
          else await new Promise(r => setTimeout(r, 1000 * attempt));
        }
      }
    };

    DETAIL_SECTIONS.forEach((section) => {
      fetchWithRetry(section).finally(() => {
        completedRef.current += 1;
        setLoadedCount(completedRef.current);
        if (completedRef.current === DETAIL_SECTIONS.length) {
          setLoadingDone(true);
          setDetails((final) => {
            if (final && role) {
              saveDetailCache(roleId || '', final);
              saveJobRoleToServer(roleId || '', role.title, final);
            }
            return final;
          });
        }
      });
    });
    } // end runAIGeneration
  }, [roleId]); // eslint-disable-line react-hooks/exhaustive-deps

  const progressPct = Math.round((loadedCount / totalSections) * 100);

  if (!role) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4"><TranslatedText>Career not found</TranslatedText></h1>
          <Link to="/recommendations">
            <Button><TranslatedText>Back to Recommendations</TranslatedText></Button>
          </Link>
        </div>
      </div>
    );
  }

  // Block render until ALL sections are fully loaded from backend
  if (!loadingDone || !details) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="text-center max-w-sm w-full">
          <div className="w-20 h-20 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin mx-auto mb-6" />
          {loadingFromCache ? (
            <>
              <h2 className="text-xl font-bold text-gray-800 mb-1"><TranslatedText>Connecting to Previous Task</TranslatedText></h2>
              <p className="text-sm text-gray-500 mb-6">Loading your saved career details for <span className="font-semibold text-indigo-600">{role?.title}</span></p>
            </>
          ) : (
            <>
              <h2 className="text-xl font-bold text-gray-800 mb-1"><TranslatedText>Generating Career Details</TranslatedText></h2>
              <p className="text-sm text-gray-500 mb-6">AI is preparing your personalised report for <span className="font-semibold text-indigo-600">{role?.title}</span></p>
            </>
          )}
          <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden mb-2">
            <div
              className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-500"
              style={{ width: `${progressPct}%` }}
            />
          </div>
          <p className="text-sm font-semibold text-indigo-600">{progressPct}% complete — {loadedCount} of {totalSections} sections</p>
        </div>
      </div>
    );
  }

  const handleGenerateReport = async () => {
    setIsGenerating(true);
    setPdfProgress(0);
    setPdfStatus('Initializing...');
    try {
      const targetLanguage = (localStorage.getItem('edubot_language') || 'en') as 'en' | 'hi' | 'bn';
      setPdfProgress(10);
      setPdfStatus('Preparing data...');
      let translatedDetails = details!;
      setPdfProgress(20);
      setPdfStatus('Translating content...');
      if (targetLanguage !== 'en') {
        const textsToTranslate: string[] = [
          details!.overview.description,
          ...details!.overview.keyResponsibilities,
          ...details!.overview.whySuitable,
          ...details!.careerPathway.steps.flatMap(s => [s.phase, s.description]),
          // ...details!.skillsLearning.mustHave.map(s => s.skill),
          // ...details!.skillsLearning.core.map(s => s.skill),
          // ...details!.skillsLearning.bonus.map(s => s.skill),
          // ...details!.roadmap90Days.phase1.learningGoals,
          // ...details!.roadmap90Days.phase1.actionTasks,
          // ...details!.roadmap90Days.phase1.progressIndicators,
          // ...details!.roadmap90Days.phase2.learningGoals,
          // ...details!.roadmap90Days.phase2.actionTasks,
          // ...details!.roadmap90Days.phase2.progressIndicators,
          // ...details!.roadmap90Days.phase3.learningGoals,
          // ...details!.roadmap90Days.phase3.actionTasks,
          // ...details!.roadmap90Days.phase3.progressIndicators,
          // ...details!.salaryGrowth.salaryTips,
          ...details!.jobMarket.keyInsights,
          // ...details!.certifications.map(c => c.name),
          ...details!.industryExperts.map(e => e.advice),
          ...details!.topInstitutes.government.flatMap(i => [i.name, i.location, i.department, i.eligibility]),
          ...details!.topInstitutes.private.flatMap(i => [i.name, i.location, i.department, i.eligibility]),
          ...details!.topInstitutes.distanceLearning.flatMap(i => [i.name, i.location, i.department, i.eligibility]),
          ...details!.topInstitutes.online.flatMap(i => [i.name, i.location, i.department, i.eligibility]),
          ...(details!.scholarships?.governmentPrivate || []).flatMap(s => [s.name, s.eligibility]),
          ...(details!.scholarships?.bankLoans || []).flatMap(l => [l.name, l.interestRate]),
          ...(details!.scholarships?.governmentSchemes || []).flatMap(s => [s.name, s.benefits, s.eligibility]),
          details!.feesInvestment.description,
          ...details!.feesInvestment.breakdown.map(b => b.phase),
        ];
        setPdfProgress(40);
        setPdfStatus('Translating sections...');
        const translations = await translationService.translateBatch(textsToTranslate, targetLanguage);
        setPdfProgress(60);
        setPdfStatus('Building report...');
        let idx = 0;
        translatedDetails = {
          ...details!,
          overview: {
            description: translations[idx++],
            keyResponsibilities: details!.overview.keyResponsibilities.map(() => translations[idx++]),
            whySuitable: details!.overview.whySuitable.map(() => translations[idx++]),
          },
          careerPathway: {
            ...details!.careerPathway,
            steps: details!.careerPathway.steps.map(s => ({ ...s, phase: translations[idx++], description: translations[idx++] })),
          },
          // skillsLearning: {
          //   mustHave: details!.skillsLearning.mustHave.map(s => ({ ...s, skill: translations[idx++] })),
          //   core: details!.skillsLearning.core.map(s => ({ ...s, skill: translations[idx++] })),
          //   bonus: details!.skillsLearning.bonus.map(s => ({ ...s, skill: translations[idx++] })),
          // },
          // roadmap90Days: {
          //   phase1: {
          //     learningGoals: details!.roadmap90Days.phase1.learningGoals.map(() => translations[idx++]),
          //     actionTasks: details!.roadmap90Days.phase1.actionTasks.map(() => translations[idx++]),
          //     progressIndicators: details!.roadmap90Days.phase1.progressIndicators.map(() => translations[idx++]),
          //   },
          //   phase2: {
          //     learningGoals: details!.roadmap90Days.phase2.learningGoals.map(() => translations[idx++]),
          //     actionTasks: details!.roadmap90Days.phase2.actionTasks.map(() => translations[idx++]),
          //     progressIndicators: details!.roadmap90Days.phase2.progressIndicators.map(() => translations[idx++]),
          //   },
          //   phase3: {
          //     learningGoals: details!.roadmap90Days.phase3.learningGoals.map(() => translations[idx++]),
          //     actionTasks: details!.roadmap90Days.phase3.actionTasks.map(() => translations[idx++]),
          //     progressIndicators: details!.roadmap90Days.phase3.progressIndicators.map(() => translations[idx++]),
          //   },
          // },
          // salaryGrowth: { ...details!.salaryGrowth, salaryTips: details!.salaryGrowth.salaryTips.map(() => translations[idx++]) },
          jobMarket: { ...details!.jobMarket, keyInsights: details!.jobMarket.keyInsights.map(() => translations[idx++]) },
          // certifications: details!.certifications.map(c => ({ ...c, name: translations[idx++] })),
          industryExperts: details!.industryExperts.map(e => ({ ...e, advice: translations[idx++] })),
          topInstitutes: {
            government: details!.topInstitutes.government.map(i => ({ ...i, name: translations[idx++], location: translations[idx++], department: translations[idx++], eligibility: translations[idx++] })),
            private: details!.topInstitutes.private.map(i => ({ ...i, name: translations[idx++], location: translations[idx++], department: translations[idx++], eligibility: translations[idx++] })),
            distanceLearning: details!.topInstitutes.distanceLearning.map(i => ({ ...i, name: translations[idx++], location: translations[idx++], department: translations[idx++], eligibility: translations[idx++] })),
            online: details!.topInstitutes.online.map(i => ({ ...i, name: translations[idx++], location: translations[idx++], department: translations[idx++], eligibility: translations[idx++] })),
          },
          scholarships: {
            governmentPrivate: (details!.scholarships?.governmentPrivate || []).map(s => ({ ...s, name: translations[idx++], eligibility: translations[idx++] })),
            bankLoans: (details!.scholarships?.bankLoans || []).map(l => ({ ...l, name: translations[idx++], interestRate: translations[idx++] })),
            governmentSchemes: (details!.scholarships?.governmentSchemes || []).map(s => ({ ...s, name: translations[idx++], benefits: translations[idx++], eligibility: translations[idx++] })),
          },
          feesInvestment: {
            ...details!.feesInvestment,
            description: translations[idx++],
            breakdown: details!.feesInvestment.breakdown.map(b => ({ ...b, phase: translations[idx++] })),
          },
        };
      }
      setPdfProgress(70);
      setPdfStatus('Generating PDF...');
      const progressInterval = setInterval(() => {
        setPdfProgress(prev => prev < 85 ? prev + 1 : prev);
      }, 200);
      const response = await fetch(`${API_BASE}/api/generate-pdf`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ roleId, roleTitle: role!.title, targetLanguage, translatedData: translatedDetails }),
      });
      clearInterval(progressInterval);
      if (!response.ok) throw new Error('PDF generation failed');
      setPdfProgress(90);
      setPdfStatus('Finalizing...');
      const blob = await response.blob();
      setPdfProgress(100);
      setPdfStatus('Complete!');
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `EduBot-Career-Report-${role!.title.replace(/\s+/g, '-')}-${Date.now()}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
      setIsGenerating(false);
      setPdfProgress(0);
      setPdfStatus('');
    } catch (error) {
      setIsGenerating(false);
      setPdfProgress(0);
      setPdfStatus('');
      alert(`Failed to generate PDF: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  // Transform salary progression data for the chart
  const salaryProgressionData = details.salaryGrowth.progression.map(item => ({
    experience: item.experience,
    salary: (() => {
      const match = item.salary.match(/(\d+)/);
      return match ? parseInt(match[1]) : 0;
    })(),
    salaryLabel: item.salary,
    role: item.role,
  }));

  const menuItems = [
    { id: 'overview', label: 'Overview', icon: Home },
    { id: 'pathway', label: 'Career Pathway', icon: GraduationCap },
    // { id: 'skills', label: 'Skills & Learning', icon: Target },
    // { id: 'roadmap', label: '90-Day Roadmap', icon: Calendar },
    { id: 'institutes', label: 'Top Institutes', icon: Building2 },
    { id: 'fees', label: 'Fees & Investment', icon: IndianRupee },
    { id: 'scholarships', label: 'Scholarships', icon: Award },
    { id: 'market', label: 'Job Market', icon: BarChart3 },
    // { id: 'certifications', label: 'Certifications', icon: FileText },
    // { id: 'salary', label: 'Salary Growth', icon: TrendingUp },
    { id: 'experts', label: 'Industry Experts', icon: Users },
    { id: 'report', label: 'Career Report', icon: FileDown },
  ];

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <Navbar showHomeButton />
      <div className="flex flex-1 min-h-0">
      {/* Sidebar - Desktop */}
      <aside className="hidden lg:block w-64 bg-white border-r border-gray-200 h-screen sticky top-0 overflow-y-auto">
        <div className="p-6 border-b border-gray-200">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-10 h-10 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
              <Brain className="text-2xl text-white" />
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
              EduBot
            </span>
          </Link>
        </div>

        <nav className="p-4 space-y-1">
          {menuItems.map((item) => {
            if (item.id === 'report') {
              return (
                <Link key={item.id} to="/career-report">
                  <button className="w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all text-left text-gray-700 hover:bg-gray-50">
                    <item.icon className="text-xl" />
                    <span className="text-sm"><TranslatedText>{item.label}</TranslatedText></span>
                  </button>
                </Link>
              );
            }
            return (
              <button
                key={item.id}
                onClick={() => setActiveSection(item.id)}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all text-left ${
                  activeSection === item.id
                    ? 'bg-indigo-50 text-indigo-700 font-semibold'
                    : 'text-gray-700 hover:bg-gray-50'
                }`}
              >
                <item.icon className="text-xl" />
                <span className="text-sm"><TranslatedText>{item.label}</TranslatedText></span>
              </button>
            );
          })}
        </nav>

        <div className="p-4 border-t border-gray-200">
          <Link to="/recommendations">
            <Button variant="outline" className="w-full">
              <ArrowLeft className="text-lg mr-2" />
              <TranslatedText>Back to Results</TranslatedText>
            </Button>
          </Link>
        </div>
      </aside>

      {/* Mobile Sidebar */}
      {sidebarOpen && (
        <div className="lg:hidden fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/50" onClick={() => setSidebarOpen(false)} />
          <aside className="absolute left-0 top-0 bottom-0 w-64 bg-white overflow-y-auto">
            <div className="p-6 border-b border-gray-200 flex items-center justify-between">
              <Link to="/" className="flex items-center gap-2">
                <div className="w-10 h-10 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
                  <Brain className="text-2xl text-white" />
                </div>
                <span className="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                  EduBot
                </span>
              </Link>
              <button onClick={() => setSidebarOpen(false)}>
                <X className="text-3xl text-gray-600" />
              </button>
            </div>

            <nav className="p-4 space-y-1">
              {menuItems.map((item) => {
                if (item.id === 'report') {
                  return (
                    <Link key={item.id} to="/career-report">
                      <button className="w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all text-left text-gray-700 hover:bg-gray-50">
                        <item.icon className="text-xl" />
                        <span className="text-sm"><TranslatedText>{item.label}</TranslatedText></span>
                      </button>
                    </Link>
                  );
                }
                return (
                  <button
                    key={item.id}
                    onClick={() => {
                      setActiveSection(item.id);
                      setSidebarOpen(false);
                    }}
                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all text-left ${
                      activeSection === item.id
                        ? 'bg-indigo-50 text-indigo-700 font-semibold'
                        : 'text-gray-700 hover:bg-gray-50'
                    }`}
                  >
                    <item.icon className="text-xl" />
                    <span className="text-sm"><TranslatedText>{item.label}</TranslatedText></span>
                  </button>
                );
              })}
            </nav>

            <div className="p-4 border-t border-gray-200">
              <Link to="/recommendations">
                <Button variant="outline" className="w-full">
                  <ArrowLeft className="text-lg mr-2" />
                  <TranslatedText>Back to Results</TranslatedText>
                </Button>
              </Link>
            </div>
          </aside>
        </div>
      )}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Header */}
        <header className="bg-white border-b border-gray-200 sticky top-0 z-40">
          <div className="px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex items-center justify-between w-full">
              <button
                onClick={() => setSidebarOpen(true)}
                className="lg:hidden p-2 -ml-2 rounded-lg hover:bg-gray-100"
              >
                <Menu className="text-2xl text-gray-600" />
              </button>
              <div className="flex-1 min-w-0 lg:ml-0 ml-4">
                <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 truncate">
                  <TranslatedText>{role?.title}</TranslatedText>
                </h1>
                <div className="flex flex-wrap items-center gap-3 mt-2 text-sm text-gray-600">
                  {role?.matchPercentage ? (
                    <span className="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg font-semibold">
                      {role.matchPercentage}% <TranslatedText>Match</TranslatedText>
                    </span>
                  ) : null}
                  {role?.salaryRange && <span className="font-semibold text-emerald-600">{role.salaryRange}</span>}
                  {role?.growthRate && (
                    <span className="flex items-center gap-1">
                      <TrendingUp className="text-lg" />
                      <TranslatedText>{role.growthRate}</TranslatedText>
                    </span>
                  )}
                </div>
              </div>
              <Button
                onClick={handleGenerateReport}
                disabled={isGenerating || !details}
                size="sm"
                className="ml-4 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 flex-shrink-0"
              >
                {isGenerating ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    <span className="hidden sm:inline">{pdfProgress}%</span>
                  </>
                ) : (
                  <>
                    <Download className="w-4 h-4 sm:mr-2" />
                    <span className="hidden sm:inline"><TranslatedText>Download PDF</TranslatedText></span>
                  </>
                )}
              </Button>
            </div>
          </div>
        </header>

        {/* Content Area */}
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
          {/* Overview Section */}
          {activeSection === 'overview' && (
            <div className="max-w-5xl mx-auto space-y-6">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-4"><TranslatedText>Role Description</TranslatedText></h2>
                <p className="text-lg text-gray-700 leading-relaxed">
                  <TranslatedText>{details.overview.description}</TranslatedText>
                </p>
              </div>

              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Key Responsibilities</TranslatedText></h2>
                <ul className="space-y-4">
                  {details.overview.keyResponsibilities.map((item, index) => (
                    <li key={index} className="flex items-start gap-3">
                      <CheckCircle2 className="text-2xl text-indigo-600 flex-shrink-0" />
                      <span className="text-gray-700 flex-1"><TranslatedText>{item}</TranslatedText></span>
                    </li>
                  ))}
                </ul>
              </div>

              <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border border-indigo-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Why This Role Suits You</TranslatedText></h2>
                <ul className="space-y-4">
                  {details.overview.whySuitable.map((item, index) => (
                    <li key={index} className="flex items-start gap-3">
                      <CheckCircle2 className="text-2xl text-indigo-600 flex-shrink-0" />
                      <span className="text-gray-700 flex-1"><TranslatedText>{item}</TranslatedText></span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          )}

          {/* Career Pathway Section */}
          {activeSection === 'pathway' && (
            <div className="max-w-5xl mx-auto">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-2">
                  <TranslatedText>Academic Pathway to</TranslatedText> <TranslatedText>{role.title}</TranslatedText>
                </h2>
                <p className="text-gray-600 mb-8">
                  <TranslatedText>Starting from:</TranslatedText>{' '}
                    <span className="font-semibold text-indigo-600">
                      <TranslatedText>{userEducationLevel}</TranslatedText>
                    </span>
                </p>

                <div className="space-y-6">
                  {details.careerPathway.steps.map((step, index) => (
                    <div
                      key={index}
                      className="relative pl-8 pb-8 border-l-2 border-indigo-200 last:border-transparent"
                    >
                      <div className="absolute -left-3 top-0 w-6 h-6 bg-indigo-600 rounded-full flex items-center justify-center">
                        <span className="text-white text-xs font-bold">{index + 1}</span>
                      </div>
                      <div className="bg-gray-50 rounded-xl p-6">
                        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-3">
                          <h3 className="text-xl font-bold text-gray-900"><TranslatedText>{step.phase}</TranslatedText></h3>
                          <span className="px-3 py-1 bg-purple-100 text-purple-700 rounded-lg font-semibold text-sm w-fit">
                            <TranslatedText>{step.duration}</TranslatedText>
                          </span>
                        </div>
                        <p className="text-gray-700"><TranslatedText>{step.description}</TranslatedText></p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Skills & Learning Section */}
          {/* {activeSection === 'skills' && (
            <div className="max-w-5xl mx-auto space-y-6">
              <div className="bg-white rounded-2xl border-2 border-red-200 p-6 sm:p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                    <Target className="text-2xl text-red-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Must-Have Skills</TranslatedText></h2>
                    <p className="text-gray-600"><TranslatedText>Essential skills required for this role</TranslatedText></p>
                  </div>
                </div>
                <div className="grid gap-4">
                  {details.skillsLearning.mustHave.map((item, index) => (
                    <div
                      key={index}
                      className="flex items-center justify-between p-4 bg-red-50 rounded-xl border border-red-200"
                    >
                      <span className="font-semibold text-gray-900"><TranslatedText>{item.skill}</TranslatedText></span>
                      <a
                        href={item.youtubeLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-red-600 hover:text-red-700 font-medium"
                      >
                        <Youtube className="text-xl" />
                        <TranslatedText>Learn</TranslatedText>
                      </a>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-white rounded-2xl border-2 border-indigo-200 p-6 sm:p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                    <Target className="text-2xl text-indigo-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Core Skills</TranslatedText></h2>
                    <p className="text-gray-600"><TranslatedText>Important skills for career growth</TranslatedText></p>
                  </div>
                </div>
                <div className="grid gap-4">
                  {details.skillsLearning.core.map((item, index) => (
                    <div
                      key={index}
                      className="flex items-center justify-between p-4 bg-indigo-50 rounded-xl border border-indigo-200"
                    >
                      <span className="font-semibold text-gray-900"><TranslatedText>{item.skill}</TranslatedText></span>
                      <a
                        href={item.youtubeLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-indigo-600 hover:text-indigo-700 font-medium"
                      >
                        <Youtube className="text-xl" />
                        <TranslatedText>Learn</TranslatedText>
                      </a>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-white rounded-2xl border-2 border-emerald-200 p-6 sm:p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-emerald-100 rounded-xl flex items-center justify-center">
                    <Target className="text-2xl text-emerald-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Bonus Skills</TranslatedText></h2>
                    <p className="text-gray-600"><TranslatedText>Additional skills to stand out</TranslatedText></p>
                  </div>
                </div>
                <div className="grid gap-4">
                  {details.skillsLearning.bonus.map((item, index) => (
                    <div
                      key={index}
                      className="flex items-center justify-between p-4 bg-emerald-50 rounded-xl border border-emerald-200"
                    >
                      <span className="font-semibold text-gray-900"><TranslatedText>{item.skill}</TranslatedText></span>
                      <a
                        href={item.youtubeLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-emerald-600 hover:text-emerald-700 font-medium"
                      >
                        <Youtube className="text-xl" />
                        <TranslatedText>Learn</TranslatedText>
                      </a>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )} */}

          {/* 90-Day Roadmap Section */}
          {/* {activeSection === 'roadmap' && (
            <div className="max-w-5xl mx-auto">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-8">
                  <TranslatedText>90-Day Success Roadmap</TranslatedText>
                </h2>

                <div className="space-y-6">
                  {[
                    { phase: details.roadmap90Days.phase1, title: 'Phase 1: Days 1-30', color: 'indigo' },
                    { phase: details.roadmap90Days.phase2, title: 'Phase 2: Days 31-60', color: 'purple' },
                    { phase: details.roadmap90Days.phase3, title: 'Phase 3: Days 61-90', color: 'emerald' },
                  ].map((item, idx) => (
                    <div key={idx} className={`border-2 border-${item.color}-200 rounded-xl p-6 bg-${item.color}-50`}>
                      <h3 className="text-xl font-bold text-gray-900 mb-4"><TranslatedText>{item.title}</TranslatedText></h3>
                      <div className="space-y-4">
                        <div>
                          <h4 className="font-semibold text-gray-900 mb-2 flex items-center gap-2">
                            <Target className={`text-xl text-${item.color}-600`} />
                            <TranslatedText>Learning Goals</TranslatedText>
                          </h4>
                          <ul className="ml-7 space-y-1">
                            {item.phase.learningGoals.map((goal, index) => (
                              <li key={index} className="text-gray-700">• <TranslatedText>{goal}</TranslatedText></li>
                            ))}
                          </ul>
                        </div>

                        <div>
                          <h4 className="font-semibold text-gray-900 mb-2 flex items-center gap-2">
                            <CheckCircle2 className={`text-xl text-${item.color}-600`} />
                            <TranslatedText>Action Tasks</TranslatedText>
                          </h4>
                          <ul className="ml-7 space-y-1">
                            {item.phase.actionTasks.map((task, index) => (
                              <li key={index} className="text-gray-700">• <TranslatedText>{task}</TranslatedText></li>
                            ))}
                          </ul>
                        </div>

                        <div>
                          <h4 className="font-semibold text-gray-900 mb-2 flex items-center gap-2">
                            <TrendingUp className={`text-xl text-${item.color}-600`} />
                            <TranslatedText>Progress Indicators</TranslatedText>
                          </h4>
                          <ul className="ml-7 space-y-1">
                            {item.phase.progressIndicators.map((indicator, index) => (
                              <li key={index} className="text-gray-700">• <TranslatedText>{indicator}</TranslatedText></li>
                            ))}
                          </ul>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )} */}

          {/* Other sections remain but with boxicons */}
          {activeSection === 'institutes' && (
            <div className="max-w-6xl mx-auto space-y-6">
              {[
                { title: 'Government Institutes', data: details.topInstitutes.government },
                { title: 'Private Institutes', data: details.topInstitutes.private },
                { title: 'Distance Learning', data: details.topInstitutes.distanceLearning },
                { title: 'Online Platforms', data: details.topInstitutes.online },
              ].map((category, idx) => (
                <div key={idx} className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                  <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>{category.title}</TranslatedText></h2>
                  <div className="grid gap-4">
                    {category.data.map((inst, index) => (
                      <div key={index} className="border-2 border-gray-100 hover:border-indigo-300 rounded-xl p-5 transition-all">
                        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-3">
                          <div className="flex-1">
                            <h3 className="text-lg font-bold text-gray-900 mb-1">{inst.name}</h3>
                            <p className="text-gray-600 flex items-center gap-1 text-sm mb-1">
                              <MapPin className="text-lg" />
                              <TranslatedText>{inst.location}</TranslatedText>
                            </p>
                            <p className="font-medium text-sm text-indigo-600"><TranslatedText>{inst.department}</TranslatedText></p>
                            <div className="mt-2 px-3 py-1 bg-emerald-50 border border-emerald-200 rounded-lg inline-block">
                              <p className="text-xs text-emerald-700 font-semibold"><TranslatedText>Eligibility: </TranslatedText><span> {inst.eligibility}</span></p>
                            </div>
                          </div>
                          <div className="flex items-center gap-1">
                            <Star className="text-xl text-yellow-500" />
                            <span className="font-bold text-gray-900">{inst.rating}</span>
                          </div>
                        </div>
                        <a
                          href={inst.website}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-2 text-indigo-600 hover:opacity-80 font-medium text-sm"
                        >
                          <TranslatedText>Visit Website</TranslatedText>
                          <ExternalLink className="text-lg" />
                        </a>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeSection === 'fees' && (
            <div className="max-w-5xl mx-auto space-y-6">
              <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border-2 border-indigo-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-2"><TranslatedText>Total Investment Range</TranslatedText></h2>
                <p className="text-4xl font-bold text-indigo-600 mb-4">
                  {details.feesInvestment.totalRange}
                </p>
                <p className="text-gray-700"><TranslatedText>{details.feesInvestment.description}</TranslatedText></p>
              </div>

              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Essential Cost Breakdown</TranslatedText></h2>
                <div className="space-y-4">
                  {details.feesInvestment.breakdown.map((item, index) => (
                    <div key={index} className="flex items-start justify-between p-4 bg-gray-50 rounded-xl border border-gray-200">
                      <div className="flex-1">
                        <h3 className="font-bold text-gray-900 mb-1"><TranslatedText>{item.phase}</TranslatedText></h3>
                        <p className="text-sm text-gray-600"><TranslatedText>{item.details}</TranslatedText></p>
                      </div>
                      <div className="text-right ml-4">
                        <p className="font-bold text-indigo-600 text-lg">{item.cost}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {activeSection === 'scholarships' && (
            <div className="max-w-6xl mx-auto space-y-6">
              {[
                { title: 'Government & Private Scholarships', data: details.scholarships.governmentPrivate, type: 'scholarship' },
                { title: 'Available Bank Loans', data: details.scholarships.bankLoans, type: 'loan' },
                { title: 'Government Schemes', data: details.scholarships.governmentSchemes, type: 'scheme' },
              ].map((category, idx) => (
                <div key={idx} className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                  <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>{category.title}</TranslatedText></h2>
                  <div className="grid md:grid-cols-2 gap-4">
                    {category.data.map((item: any, index) => (
                      <div key={index} className="p-5 bg-gray-50 rounded-xl border-2 border-indigo-200">
                        <h3 className="font-bold text-gray-900 mb-2"><TranslatedText>{item.name}</TranslatedText></h3>
                        <div className="space-y-2 mb-3 text-sm text-gray-600">
                          {category.type === 'scholarship' && (
                            <>
                              <p><span className="font-semibold"><TranslatedText>Amount:</TranslatedText></span> <span className="text-emerald-600">{item.amount}</span></p>
                              <p><span className="font-semibold"><TranslatedText>Eligibility:</TranslatedText></span><TranslatedText>{item.eligibility}</TranslatedText></p>
                            </>
                          )}
                          {category.type === 'loan' && (
                            <>
                              <p><span className="font-semibold"><TranslatedText>Amount:</TranslatedText></span> <span className="text-emerald-600">{item.amount}</span></p>
                              <p><span className="font-semibold"><TranslatedText>Interest:</TranslatedText></span><TranslatedText>{item.interestRate}</TranslatedText></p>
                            </>
                          )}
                          {category.type === 'scheme' && (
                            <>
                              <p><span className="font-semibold"><TranslatedText>Benefits:</TranslatedText></span><TranslatedText>{item.benefits}</TranslatedText></p>
                              <p><span className="font-semibold"><TranslatedText>Eligibility:</TranslatedText></span><TranslatedText>{item.eligibility}</TranslatedText></p>
                            </>
                          )}
                        </div>
                        <a
                          href={item.website}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-2 text-indigo-600 hover:text-indigo-700 font-medium text-sm"
                        >
                          <TranslatedText>Visit Website</TranslatedText>
                          <ExternalLink className="text-lg" />
                        </a>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeSection === 'market' && (
            <div className="max-w-6xl mx-auto space-y-6">
              <div className="grid md:grid-cols-3 gap-6">
                <div className="bg-gradient-to-br from-indigo-50 to-indigo-100 rounded-2xl border border-indigo-200 p-6">
                  <h3 className="text-sm font-semibold text-indigo-700 mb-2"><TranslatedText>Market Demand</TranslatedText></h3>
                  <p className="text-4xl font-bold text-indigo-600 mb-1">{details.jobMarket.demandLevel}%</p>
                  <p className="text-sm text-gray-600"><TranslatedText>High demand in Indian market</TranslatedText></p>
                </div>
                <div className="bg-gradient-to-br from-emerald-50 to-emerald-100 rounded-2xl border border-emerald-200 p-6">
                  <h3 className="text-sm font-semibold text-emerald-700 mb-2"><TranslatedText>Success Rate</TranslatedText></h3>
                  <p className="text-4xl font-bold text-emerald-600 mb-1">{details.jobMarket.successRate}%</p>
                  <p className="text-sm text-gray-600"><TranslatedText>Students placed successfully</TranslatedText></p>
                </div>
                <div className="bg-gradient-to-br from-purple-50 to-purple-100 rounded-2xl border border-purple-200 p-6">
                  <h3 className="text-sm font-semibold text-purple-700 mb-2"><TranslatedText>Monthly Openings</TranslatedText></h3>
                  <p className="text-4xl font-bold text-purple-600 mb-1">3000+</p>
                  <p className="text-sm text-gray-600"><TranslatedText>Active job postings</TranslatedText></p>
                </div>
              </div>

              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Hiring Trends </TranslatedText>({new Date().getFullYear()})</h2>
                <div className="h-80" style={{ minHeight: '320px' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={details.jobMarket.hiringTrends}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="openings" fill="#4f46e5" radius={[8, 8, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Top Hiring Companies</TranslatedText></h2>
                <div className="grid md:grid-cols-2 gap-4">
                  {details.jobMarket.topCompanies.map((company, index) => (
                    <div key={index} className="p-4 bg-gray-50 rounded-xl border border-gray-200">
                      <h3 className="font-bold text-gray-900 mb-2"><TranslatedText>{company.name}</TranslatedText></h3>
                      <p className="text-emerald-600 font-semibold mb-2">{company.packageRange}</p>
                      <div className="flex flex-wrap gap-2">
                        {company.locations.map((location, i) => (
                          <span key={i} className="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs">
                            {location}
                          </span>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border border-indigo-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Key Market Insights</TranslatedText></h2>
                <ul className="space-y-3">
                  {details.jobMarket.keyInsights.map((insight, index) => (
                    <li key={index} className="flex items-start gap-3">
                      <CheckCircle2 className="text-2xl text-indigo-600" />
                      <span className="text-gray-700 flex-1"><TranslatedText>{insight}</TranslatedText></span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          )}

          {/* {activeSection === 'certifications' && (
            <div className="max-w-5xl mx-auto">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Industry-Recognized Certifications</TranslatedText></h2>
                <div className="space-y-4">
                  {details.certifications.map((cert, index) => (
                    <div key={index} className="p-6 bg-gradient-to-br from-gray-50 to-indigo-50/30 rounded-xl border border-gray-200 hover:border-indigo-300 transition-all">
                      <div className="flex items-start justify-between mb-4">
                        <div className="flex-1">
                          <h3 className="text-xl font-bold text-gray-900 mb-2"><TranslatedText>{cert.name}</TranslatedText></h3>
                          <div className="flex flex-wrap gap-2 text-sm">
                            <span className="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg font-semibold">
                              {cert.platform}
                            </span>
                            <span className="px-3 py-1 bg-purple-100 text-purple-700 rounded-lg">
                              {cert.provider}
                            </span>
                          </div>
                        </div>
                      </div>
                      <div className="grid md:grid-cols-3 gap-4 mb-3">
                        <div>
                          <p className="text-sm text-gray-600"><TranslatedText>Duration</TranslatedText></p>
                          <p className="font-semibold text-gray-900"><TranslatedText>{cert.duration}</TranslatedText></p>
                        </div>
                        <div>
                          <p className="text-sm text-gray-600"><TranslatedText>Cost</TranslatedText></p>
                          <p className="font-semibold text-emerald-600">{cert.cost}</p>
                        </div>
                        <div>
                          <p className="text-sm text-gray-600"><TranslatedText>Impact</TranslatedText></p>
                          <p className="font-semibold text-gray-900"><TranslatedText>{cert.impact}</TranslatedText></p>
                        </div>
                      </div>
                      <a
                        href={cert.link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium text-sm"
                      >
                        <TranslatedText>Get Certification</TranslatedText>
                        <ExternalLink className="text-lg" />
                      </a>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )} */}

          {/* {activeSection === 'salary' && (
            <div className="max-w-6xl mx-auto space-y-6">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Salary Progression Timeline</TranslatedText></h2>
                <div className="h-80" style={{ minHeight: '320px' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={salaryProgressionData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="experience" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Line type="monotone" dataKey="salary" stroke="#4f46e5" strokeWidth={3} dot={{ fill: '#4f46e5', r: 6 }} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="grid md:grid-cols-2 gap-6">
                <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                  <h2 className="text-xl font-bold text-gray-900 mb-6"><TranslatedText>City-wise Comparison</TranslatedText></h2>
                  <div className="space-y-3">
                    {details.salaryGrowth.cityComparison.map((city, index) => (
                      <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-xl">
                        <div className="flex items-center gap-2">
                          <MapPin className="text-lg text-indigo-600" />
                          <span className="font-semibold text-gray-900"><TranslatedText>{city.city}</TranslatedText></span>
                        </div>
                        <span className="font-bold text-emerald-600">{city.salary}</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border border-indigo-200 p-6 sm:p-8">
                  <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
                    <Lightbulb className="w-6 h-6 text-indigo-600" />
                    <TranslatedText>Salary Tips</TranslatedText>
                  </h2>
                  <ul className="space-y-3">
                    {details.salaryGrowth.salaryTips.map((tip, index) => (
                      <li key={index} className="flex items-start gap-2">
                        <span className="text-indigo-600 font-bold">•</span>
                        <span className="text-gray-700 text-sm flex-1"><TranslatedText>{tip}</TranslatedText></span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          )} */}

          {activeSection === 'experts' && (
            <div className="max-w-5xl mx-auto">
              <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
                <h2 className="text-2xl font-bold text-gray-900 mb-6"><TranslatedText>Industry Experts</TranslatedText></h2>
                <div className="grid gap-6">
                  {details.industryExperts.map((expert, index) => (
                    <div key={index} className="p-6 bg-gradient-to-br from-gray-50 to-indigo-50/30 rounded-xl border border-gray-200">
                      <div className="flex items-start gap-4 mb-4">
                        <div className="w-16 h-16 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-full flex items-center justify-center text-2xl text-white font-bold flex-shrink-0">
                          {expert.name.charAt(0)}
                        </div>
                        <div className="flex-1 min-w-0">
                          <h3 className="text-xl font-bold text-gray-900 mb-1"><TranslatedText>{expert.name}</TranslatedText></h3>
                          <p className="text-indigo-600 font-semibold mb-1"><TranslatedText>{expert.designation}</TranslatedText></p>
                          <div className="flex flex-wrap gap-2 text-sm text-gray-600">
                            <span className="flex items-center gap-1">
                              <Building2 className="w-4 h-4" />
                              {expert.company}
                            </span>
                            <span>•</span>
                            <span><TranslatedText>{expert.experience}</TranslatedText></span>
                          </div>
                        </div>
                      </div>
                      <div className="bg-white rounded-lg p-4 border border-indigo-200">
                        <p className="text-sm font-semibold text-indigo-700 mb-2 flex items-center gap-2">
                          <MessageSquare className="w-4 h-4" />
                          <TranslatedText>Advice for Newcomers:</TranslatedText>                          
                        </p>
                        <p className="text-gray-700 italic">"<TranslatedText>{expert.advice}</TranslatedText>"</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
      </div>
    </div>
  );
}
