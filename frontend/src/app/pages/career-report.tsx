import { useState, useMemo, useEffect } from 'react';
import { useParams, Link } from 'react-router';
import { Button } from '../components/ui/button';
import { JobRole } from '../../types/career';
import { JobDetail } from '../../types/career';
import {
  LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend, PieChart, Pie, Cell,
} from 'recharts';
import {
  ArrowLeft, Target, BookOpen, Calendar, Building2, IndianRupee, Briefcase, TrendingUp, BadgeCheck, MessageSquare, FileText, Download, Loader2, MapPin, Star, ExternalLink, Youtube, Lightbulb, CheckCircle2, Award, BarChart3, Users, Brain, GraduationCap, Zap, Shield,
} from 'lucide-react';
import { TranslatedText } from '../components/TranslatedText';
import { translationService } from '../../services/translationService';

// Resolve role from sessionStorage API careers only (fully AI-driven)
function resolveRole(roleId: string): JobRole | undefined {
  try {
    // Try sessionStorage first
    let stored = sessionStorage.getItem('careerRecommendations');
    
    // If not in sessionStorage, try localStorage
    if (!stored) {
      stored = localStorage.getItem('careerRecommendations');
      if (stored) {
        // Restore to sessionStorage for future use
        sessionStorage.setItem('careerRecommendations', stored);
      }
    }
    
    if (stored) {
      const parsed = JSON.parse(stored);
      if (parsed?.success && Array.isArray(parsed.careers)) {
        for (let di = 0; di < parsed.careers.length; di++) {
          const jobs = parsed.careers[di].jobs ?? [];
          for (let ji = 0; ji < jobs.length; ji++) {
            if (`domain-${di}-job-${ji}` === roleId) {
              return {
                id: roleId,
                title: jobs[ji].title,
                domainId: `domain-${di}`,
                icon: '🎯',
                matchPercentage: parsed.careers[di].match ?? 0,
                salaryRange: jobs[ji].salary,
                growthRate: jobs[ji].growth,
                description: jobs[ji].description,
              };
            }
          }
        }
      }
    }
  } catch { /* ignore */ }
  return undefined;
}

// Load role data from database when sessionStorage is empty
async function loadRoleFromDatabase(roleId: string): Promise<JobRole | undefined> {
  try {
    const user = JSON.parse(localStorage.getItem('edubot_user') || '{}');
    if (!user.email) return undefined;

    const response = await fetch('http://localhost:8080/api/load-job-role', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: user.email, roleId })
    });

    const result = await response.json();
    if (result.success && result.detail) {
      // Extract role info from saved detail data
      const detail = result.detail;
      return {
        id: roleId,
        title: detail.overview?.role_description?.split('.')[0] || 'Career Role',
        domainId: roleId.split('-job-')[0] || 'domain-0',
        icon: '🎯',
        matchPercentage: 85, // Default match percentage
        salaryRange: detail.salary?.fresher_level?.range || '₹4-8 LPA',
        growthRate: 'High Growth',
        description: detail.overview?.role_description || 'Professional career opportunity'
      };
    }
  } catch (error) {
    console.error('Failed to load role from database:', error);
  }
  return undefined;
}

// Load AI-generated details from session cache only (fully AI-driven)
function resolveDetails(roleId: string): JobDetail | null {
  try {
    // Check for translated version first
    const translatedRaw = sessionStorage.getItem(`jobDetail_${roleId}_translated`);
    if (translatedRaw) {
      const parsed = JSON.parse(translatedRaw) as JobDetail;
      if (parsed) return parsed;
    }
    
    // Fall back to original version
    const raw = sessionStorage.getItem(`jobDetail_${roleId}`);
    if (raw) {
      const parsed = JSON.parse(raw) as JobDetail;
      if (parsed) {
        if (Array.isArray(parsed.careerPathway?.steps)) {
          parsed.careerPathway.steps = parsed.careerPathway.steps.map((s: any) => ({
            phase: s.phase ?? s.level ?? '',
            duration: s.duration ?? '',
            description: s.description ?? '',
          }));
        }
        return parsed;
      }
    }
  } catch { /* ignore */ }
  return null;
}

// Load details from database when sessionStorage is empty
async function loadDetailsFromDatabase(roleId: string): Promise<JobDetail | null> {
  try {
    const user = JSON.parse(localStorage.getItem('edubot_user') || '{}');
    if (!user.email) return null;

    const response = await fetch('http://localhost:8080/api/load-job-role', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: user.email, roleId })
    });

    const result = await response.json();
    if (result.success && result.detail) {
      const detail = result.detail;
      
      // Transform database format to JobDetail format
      const jobDetail: JobDetail = {
        roleId: roleId,
        overview: {
          description: detail.overview?.role_description || '',
          keyResponsibilities: detail.overview?.key_responsibilities || [],
          whySuitable: Array.isArray(detail.overview?.why_suitable) 
            ? detail.overview.why_suitable 
            : [detail.overview?.why_suitable || '']
        },
        careerPathway: {
          currentLevel: 'Current Level',
          steps: (detail.careerPathway?.pathway || []).map((step: any) => ({
            phase: step.phase || '',
            duration: step.duration || '',
            description: step.description || ''
          }))
        },
        skillsLearning: {
          mustHave: (detail.skillsLearning?.skills?.high || []).map((skill: any) => ({
            skill: skill.name || skill.skill || skill,
            description: skill.description || '',
            courseUrl: skill.course_url || skill.courseUrl || '#',
            youtubeLink: skill.video_url || skill.youtubeLink || '#'
          })),
          core: (detail.skillsLearning?.skills?.medium || []).map((skill: any) => ({
            skill: skill.name || skill.skill || skill,
            description: skill.description || '',
            courseUrl: skill.course_url || skill.courseUrl || '#',
            youtubeLink: skill.video_url || skill.youtubeLink || '#'
          })),
          bonus: (detail.skillsLearning?.skills?.low || []).map((skill: any) => ({
            skill: skill.name || skill.skill || skill,
            description: skill.description || '',
            courseUrl: skill.course_url || skill.courseUrl || '#',
            youtubeLink: skill.video_url || skill.youtubeLink || '#'
          }))
        },
        roadmap90Days: {
          phase1: {
            learningGoals: detail.roadmap90Days?.roadmap?.phase1?.goals || [],
            actionTasks: detail.roadmap90Days?.roadmap?.phase1?.tasks || [],
            progressIndicators: detail.roadmap90Days?.roadmap?.phase1?.progress_indicators || []
          },
          phase2: {
            learningGoals: detail.roadmap90Days?.roadmap?.phase2?.goals || [],
            actionTasks: detail.roadmap90Days?.roadmap?.phase2?.tasks || [],
            progressIndicators: detail.roadmap90Days?.roadmap?.phase2?.progress_indicators || []
          },
          phase3: {
            learningGoals: detail.roadmap90Days?.roadmap?.phase3?.goals || [],
            actionTasks: detail.roadmap90Days?.roadmap?.phase3?.tasks || [],
            progressIndicators: detail.roadmap90Days?.roadmap?.phase3?.progress_indicators || []
          }
        },
        topInstitutes: {
          government: detail.topInstitutes?.institutes?.government || [],
          private: detail.topInstitutes?.institutes?.private || [],
          distanceLearning: detail.topInstitutes?.institutes?.distance || [],
          online: detail.topInstitutes?.institutes?.online || []
        },
        feesInvestment: {
          totalRange: detail.feesInvestment?.fees?.total_investment || '₹5-15 Lakhs',
          description: detail.feesInvestment?.fees?.note || '',
          breakdown: (detail.feesInvestment?.fees?.breakdown || []).map((item: any) => ({
            phase: item.category || item.phase || '',
            cost: item.range || item.cost || '',
            details: item.duration || item.details || ''
          }))
        },
        scholarships: {
          governmentPrivate: detail.scholarships?.financial_support?.scholarships || detail.scholarships?.scholarships || [
            {
              name: 'Merit-based Scholarship',
              amount: '₹50,000 - ₹2,00,000',
              eligibility: 'Academic excellence (85%+ marks)',
              website: '#'
            },
            {
              name: 'Need-based Financial Aid',
              amount: '₹25,000 - ₹1,50,000',
              eligibility: 'Family income below ₹5 LPA',
              website: '#'
            }
          ],
          bankLoans: detail.scholarships?.financial_support?.loans || detail.scholarships?.loans || [
            {
              name: 'SBI Education Loan',
              amount: 'Up to ₹30 Lakhs',
              interestRate: '8.5% - 10.5%',
              website: 'https://sbi.co.in'
            },
            {
              name: 'HDFC Credila',
              amount: 'Up to ₹40 Lakhs',
              interestRate: '9% - 11%',
              website: 'https://credila.com'
            }
          ],
          governmentSchemes: detail.scholarships?.financial_support?.government_schemes || detail.scholarships?.government_schemes || [
            {
              name: 'PM Scholarship Scheme',
              benefits: 'Monthly stipend + fee waiver',
              eligibility: 'Merit-based selection',
              website: 'https://scholarships.gov.in'
            },
            {
              name: 'State Government Scholarship',
              benefits: 'Partial fee reimbursement',
              eligibility: 'State domicile + income criteria',
              website: '#'
            }
          ]
        },
        jobMarket: {
          demandLevel: detail.jobMarket?.jobmarket?.demand_percentage || detail.jobMarket?.demand_percentage || 85,
          successRate: parseInt((detail.jobMarket?.jobmarket?.success_rate || detail.jobMarket?.success_rate || '75%').replace('%', '')),
          hiringTrends: detail.jobMarket?.jobmarket?.hiring_trends || detail.jobMarket?.hiring_trends || (() => {
            const currentYear = new Date().getFullYear();
            const trends = [];
            for (let i = 4; i >= 0; i--) {
              const year = currentYear - i;
              const baseOpenings = 1500 + Math.floor(Math.random() * 800);
              trends.push({
                month: `${year}`,
                openings: baseOpenings + (i * 150) // Show growth trend over years
              });
            }
            return trends;
          })(),
          topCompanies: (detail.jobMarket?.jobmarket?.top_companies || detail.jobMarket?.top_companies || [
            { name: 'TCS', package_range: '₹3.5-8 LPA', type: 'IT Services' },
            { name: 'Infosys', package_range: '₹4-9 LPA', type: 'IT Services' },
            { name: 'Wipro', package_range: '₹3.8-7.5 LPA', type: 'IT Services' },
            { name: 'Accenture', package_range: '₹4.5-10 LPA', type: 'Consulting' },
            { name: 'Cognizant', package_range: '₹4-8.5 LPA', type: 'IT Services' }
          ]).map((company: any) => ({
            name: company.name || '',
            packageRange: company.package_range || company.packageRange || '',
            locations: [company.type || company.hiring_frequency || company.locations?.[0] || 'Multiple Locations']
          })),
          keyInsights: detail.jobMarket?.jobmarket?.key_insights || detail.jobMarket?.key_insights || [
            'High demand for skilled professionals in this field',
            'Growing market with excellent career prospects',
            'Multiple career advancement opportunities available',
            'Strong industry growth expected in coming years'
          ]
        },
        certifications: (detail.certifications?.certifications || []).map((cert: any) => ({
          name: cert.name || '',
          provider: cert.provider || '',
          platform: cert.provider || '',
          duration: cert.duration || '',
          cost: cert.cost || '',
          impact: cert.career_impact || cert.impact || '',
          link: cert.link || '#'
        })),
        salaryGrowth: {
          progression: [
            {
              experience: detail.salaryGrowth?.salary?.fresher_level?.experience || detail.salary?.fresher_level?.experience || '0-1 years',
              role: 'Fresher',
              salary: detail.salaryGrowth?.salary?.fresher_level?.range || detail.salary?.fresher_level?.range || '₹4-8 LPA'
            },
            {
              experience: detail.salaryGrowth?.salary?.['5years_level']?.experience || detail.salary?.['5years_level']?.experience || '5 years',
              role: 'Experienced',
              salary: detail.salaryGrowth?.salary?.['5years_level']?.range || detail.salary?.['5years_level']?.range || '₹12-20 LPA'
            },
            {
              experience: detail.salaryGrowth?.salary?.['10years_level']?.experience || detail.salary?.['10years_level']?.experience || '10 years',
              role: 'Senior',
              salary: detail.salaryGrowth?.salary?.['10years_level']?.range || detail.salary?.['10years_level']?.range || '₹25-40 LPA'
            },
            {
              experience: detail.salaryGrowth?.salary?.['15years_level']?.experience || detail.salary?.['15years_level']?.experience || '15 years',
              role: 'Expert',
              salary: detail.salaryGrowth?.salary?.['15years_level']?.range || detail.salary?.['15years_level']?.range || '₹40-70 LPA'
            }
          ],
          cityComparison: Object.entries(detail.salaryGrowth?.salary?.fresher_level?.cities || detail.salary?.fresher_level?.cities || {
            'Mumbai': '₹6-12 LPA',
            'Bangalore': '₹5-10 LPA',
            'Delhi': '₹5-11 LPA',
            'Pune': '₹4-9 LPA',
            'Chennai': '₹4-8 LPA'
          }).map(([city, salary]) => ({
            city,
            salary: salary as string
          })),
          salaryTips: detail.salaryGrowth?.salary?.growth_tips || detail.salary?.growth_tips || [
            'Build strong technical skills and certifications',
            'Gain hands-on project experience',
            'Network with industry professionals',
            'Consider specialization in high-demand areas',
            'Negotiate based on market standards'
          ]
        },
        industryExperts: (detail.industryExperts?.experts || []).map((expert: any) => ({
          name: expert.name || '',
          designation: expert.designation || '',
          company: expert.company || '',
          advice: expert.key_advice || expert.advice || ''
        }))
      };
      
      return jobDetail;
    }
  } catch (error) {
    console.error('Failed to load details from database:', error);
  }
  return null;
}

export function CareerReport() {
  const { roleId } = useParams();
  const [isGenerating, setIsGenerating] = useState(false);
  const [pdfProgress, setPdfProgress] = useState(0);
  const [pdfStatus, setPdfStatus] = useState('');
  const [role, setRole] = useState<JobRole | undefined>(undefined);
  const [details, setDetails] = useState<JobDetail | null>(null);
  const [loading, setLoading] = useState(true);

  // Parse salary strings: handles "₹4-8 LPA", "Rs 2.5-5 LPA", "₹30-60+ LPA", "Rs 8-15 LPA"
  const parseSalaryToNumber = (salaryString: string): number => {
    // Strip currency symbols and normalize
    const cleaned = salaryString.replace(/[₹Rs\s]/g, '');
    // Match first number (possibly decimal) before a dash or LPA
    const match = cleaned.match(/(\d+\.?\d*)[-–]?(\d+\.?\d*)?/);
    if (match) {
      const min = parseFloat(match[1]) || 0;
      const max = parseFloat(match[2]) || min;
      return Math.round((min + max) / 2);
    }
    return 0;
  };

  // Resolve user's actual education level from session
  const currentLevel = useMemo(() => {
    const educationLabelMap: Record<string, string> = {
      'class-10': 'Class 10th', 'class-11': 'Class 11th', 'class-12': 'Class 12th',
      'graduation': 'Graduation (Pursuing)', 'graduated': 'Graduated', 'postgrad': 'Post Graduation',
    };
    try {
      // Try sessionStorage first, then localStorage
      let stored = sessionStorage.getItem('careerRecommendations');
      if (!stored) {
        stored = localStorage.getItem('careerRecommendations');
      }
      const edu = stored ? JSON.parse(stored)?.profile?.education || '' : '';
      return educationLabelMap[edu] ?? edu ?? details?.careerPathway?.currentLevel ?? '';
    } catch { return details?.careerPathway?.currentLevel ?? ''; }
  }, [details]);

  // Transform salary progression data for the chart - memoized with unique IDs
  const salaryProgressionDataWithIds = useMemo(() => {
    if (!details) return [];
    return details.salaryGrowth.progression.map((item, index) => ({
      id: `salary-prog-${index}-${item.experience.replace(/\s+/g, '-')}`,
      experience: item.experience,
      salary: parseSalaryToNumber(item.salary),
      salaryLabel: item.salary,
      role: item.role,
    }));
  }, [details]);

  // Skill distribution data for pie chart - memoized to prevent re-renders
  const skillDistribution = useMemo(() => {
    if (!details) return [];
    return [
      { id: 'must-have-skills', name: 'Must-Have', value: details.skillsLearning.mustHave.length, color: '#ef4444' },
      { id: 'core-skills', name: 'Core Skills', value: details.skillsLearning.core.length, color: '#6366f1' },
      { id: 'bonus-skills', name: 'Bonus Skills', value: details.skillsLearning.bonus.length, color: '#10b981' },
    ];
  }, [details]);

  // Add unique IDs to hiring trends data - memoized to prevent re-renders
  const hiringTrendsData = useMemo(() => {
    if (!details) return [];
    return details.jobMarket.hiringTrends.map((item, index) => ({
      id: `hiring-trend-${index}-${item.month}`,
      month: item.month,
      openings: item.openings,
    }));
  }, [details]);

  // Load role and details data on component mount
  useEffect(() => {
    async function loadData() {
      if (!roleId) {
        setLoading(false);
        return;
      }

      setLoading(true);
      
      // Try to resolve from sessionStorage first
      let roleData = resolveRole(roleId);
      let detailsData = resolveDetails(roleId);
      
      // If not found in sessionStorage, try database
      if (!roleData || !detailsData) {
        try {
          if (!roleData) {
            roleData = await loadRoleFromDatabase(roleId);
          }
          if (!detailsData) {
            detailsData = await loadDetailsFromDatabase(roleId);
          }
        } catch (error) {
          console.error('Failed to load data from database:', error);
        }
      }
      
      setRole(roleData);
      setDetails(detailsData);
      setLoading(false);
    }

    loadData();
  }, [roleId]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-indigo-600 mx-auto mb-4"></div>
          <h1 className="text-xl font-semibold text-gray-900 mb-2">Loading Career Report...</h1>
          <p className="text-gray-600">Please wait while we fetch your career data</p>
        </div>
      </div>
    );
  }

  if (!role || !details) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Career Report Not Available</h1>
          <p className="text-gray-600 mb-6">The career report data could not be found. Please generate a new career recommendation.</p>
          <Link to="/recommendations">
            <Button><TranslatedText>Back to Recommendations</TranslatedText></Button>
          </Link>
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
      
      // Translate data if not English
      let translatedDetails = details;
      setPdfProgress(20);
      setPdfStatus('Translating content...');
      if (targetLanguage !== 'en') {
        // Collect all text fields to translate
        const textsToTranslate: string[] = [
          details.overview.description,
          ...details.overview.keyResponsibilities,
          ...details.overview.whySuitable,
          ...details.careerPathway.steps.flatMap(s => [s.phase, s.description]),
          ...details.skillsLearning.mustHave.map(s => s.skill),
          ...details.skillsLearning.core.map(s => s.skill),
          ...details.skillsLearning.bonus.map(s => s.skill),
          ...details.roadmap90Days.phase1.learningGoals,
          ...details.roadmap90Days.phase1.actionTasks,
          ...details.roadmap90Days.phase1.progressIndicators,
          ...details.roadmap90Days.phase2.learningGoals,
          ...details.roadmap90Days.phase2.actionTasks,
          ...details.roadmap90Days.phase2.progressIndicators,
          ...details.roadmap90Days.phase3.learningGoals,
          ...details.roadmap90Days.phase3.actionTasks,
          ...details.roadmap90Days.phase3.progressIndicators,
          ...details.salaryGrowth.salaryTips,
          ...details.jobMarket.keyInsights,
          ...details.certifications.map(c => c.name),
          ...details.industryExperts.map(e => e.advice),
        ];

        // Translate all texts in batch
        setPdfProgress(40);
        setPdfStatus('Translating sections...');
        const translations = await translationService.translateBatch(textsToTranslate, targetLanguage);
        setPdfProgress(60);
        setPdfStatus('Building report...');
        
        // Reconstruct translated details
        let idx = 0;
        translatedDetails = {
          ...details,
          overview: {
            description: translations[idx++],
            keyResponsibilities: details.overview.keyResponsibilities.map(() => translations[idx++]),
            whySuitable: details.overview.whySuitable.map(() => translations[idx++]),
          },
          careerPathway: {
            ...details.careerPathway,
            steps: details.careerPathway.steps.map(s => ({
              ...s,
              phase: translations[idx++],
              description: translations[idx++],
            })),
          },
          skillsLearning: {
            mustHave: details.skillsLearning.mustHave.map(s => ({ ...s, skill: translations[idx++] })),
            core: details.skillsLearning.core.map(s => ({ ...s, skill: translations[idx++] })),
            bonus: details.skillsLearning.bonus.map(s => ({ ...s, skill: translations[idx++] })),
          },
          roadmap90Days: {
            phase1: {
              learningGoals: details.roadmap90Days.phase1.learningGoals.map(() => translations[idx++]),
              actionTasks: details.roadmap90Days.phase1.actionTasks.map(() => translations[idx++]),
              progressIndicators: details.roadmap90Days.phase1.progressIndicators.map(() => translations[idx++]),
            },
            phase2: {
              learningGoals: details.roadmap90Days.phase2.learningGoals.map(() => translations[idx++]),
              actionTasks: details.roadmap90Days.phase2.actionTasks.map(() => translations[idx++]),
              progressIndicators: details.roadmap90Days.phase2.progressIndicators.map(() => translations[idx++]),
            },
            phase3: {
              learningGoals: details.roadmap90Days.phase3.learningGoals.map(() => translations[idx++]),
              actionTasks: details.roadmap90Days.phase3.actionTasks.map(() => translations[idx++]),
              progressIndicators: details.roadmap90Days.phase3.progressIndicators.map(() => translations[idx++]),
            },
          },
          salaryGrowth: {
            ...details.salaryGrowth,
            salaryTips: details.salaryGrowth.salaryTips.map(() => translations[idx++]),
          },
          jobMarket: {
            ...details.jobMarket,
            keyInsights: details.jobMarket.keyInsights.map(() => translations[idx++]),
          },
          certifications: details.certifications.map(c => ({ ...c, name: translations[idx++] })),
          industryExperts: details.industryExperts.map(e => ({ ...e, advice: translations[idx++] })),
        };
      }
      
      // Send translated data to backend
      setPdfProgress(70);
      setPdfStatus('Generating PDF...');
      
      // Simulate progress during backend processing
      const progressInterval = setInterval(() => {
        setPdfProgress(prev => {
          if (prev < 85) return prev + 1;
          return prev;
        });
      }, 200);
      
      const response = await fetch('http://localhost:8080/api/generate-pdf', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          roleId,
          roleTitle: role.title,
          targetLanguage,
          translatedData: translatedDetails,
        })
      });

      clearInterval(progressInterval);

      if (!response.ok) {
        throw new Error('PDF generation failed');
      }

      setPdfProgress(90);
      setPdfStatus('Finalizing...');
      const blob = await response.blob();
      setPdfProgress(100);
      setPdfStatus('Complete!');
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `EduBot-Career-Report-${role.title.replace(/\s+/g, '-')}-${Date.now()}.pdf`;
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

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-indigo-50/30">
      {/* Fixed Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-50 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2 sm:gap-4 w-full sm:w-auto">
              <Link to={`/role/${roleId}`}>
                <Button variant="ghost" size="sm" className="h-8 px-2 sm:px-3">
                  <ArrowLeft className="w-4 h-4 sm:mr-2" />
                  <span className="hidden sm:inline"><TranslatedText>Back</TranslatedText></span>
                </Button>
              </Link>
              <div className="flex items-center gap-2 sm:gap-3">
                <div className="w-8 h-8 sm:w-10 sm:h-10 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
                  <Brain className="w-5 h-5 sm:w-6 sm:h-6 text-white" />
                </div>
                <div>
                  <h1 className="text-sm sm:text-xl font-bold text-gray-900"><TranslatedText>Complete Career Report</TranslatedText></h1>
                  <p className="text-xs sm:text-sm text-gray-600"><TranslatedText>{role.title}</TranslatedText></p>
                </div>
              </div>
            </div>
            <div className="flex flex-col gap-2 w-full sm:w-auto">
              <Button
                onClick={handleGenerateReport}
                disabled={isGenerating}
                size="sm"
                className="bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 w-full sm:w-auto"
              >
                {isGenerating ? (
                  <>
                    <Loader2 className="w-3 h-3 sm:w-4 sm:h-4 mr-2 animate-spin" />
                    <span><TranslatedText>Generating...</TranslatedText> {pdfProgress}%</span>
                  </>
                ) : (
                  <>
                    <Download className="w-3 h-3 sm:w-4 sm:h-4 mr-2" />
                    <TranslatedText>Download PDF</TranslatedText>
                  </>
                )}
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6 lg:py-8">
        {/* Executive Summary */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <div className="lg:col-span-2 bg-white rounded-xl sm:rounded-2xl border border-gray-200 p-4 sm:p-6 lg:p-8">
            <div className="flex flex-col sm:flex-row items-start gap-3 sm:gap-4 mb-4 sm:mb-6">
              <div className="w-12 h-12 sm:w-14 sm:h-14 lg:w-16 lg:h-16 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl sm:rounded-2xl flex items-center justify-center flex-shrink-0">
                <Target className="w-6 h-6 sm:w-7 sm:h-7 lg:w-8 lg:h-8 text-white" />
              </div>
              <div className="flex-1">
                <h2 className="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-1 sm:mb-2"><TranslatedText>Executive Summary</TranslatedText></h2>
                <p className="text-sm sm:text-base text-gray-600"><TranslatedText>{role.title}</TranslatedText></p>
              </div>
            </div>
            <p className="text-sm sm:text-base text-gray-700 leading-relaxed mb-4 sm:mb-6"><TranslatedText>{details.overview.description}</TranslatedText></p>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
              <div className="bg-indigo-50 rounded-lg sm:rounded-xl p-3 sm:p-4 text-center">
                <p className="text-2xl sm:text-3xl font-bold text-indigo-600 mb-1">{role.matchPercentage}%</p>
                <p className="text-xs sm:text-sm text-gray-600"><TranslatedText>Match Score</TranslatedText></p>
              </div>
              <div className="bg-emerald-50 rounded-lg sm:rounded-xl p-3 sm:p-4 text-center">
                <p className="text-2xl sm:text-3xl font-bold text-emerald-600 mb-1">{role.salaryRange}</p>
                <p className="text-xs sm:text-sm text-gray-600"><TranslatedText>Salary Range</TranslatedText></p>
              </div>
              <div className="bg-purple-50 rounded-lg sm:rounded-xl p-3 sm:p-4 text-center">
                <p className="text-2xl sm:text-3xl font-bold text-purple-600 mb-1">{role.growthRate}</p>
                <p className="text-xs sm:text-sm text-gray-600"><TranslatedText>Growth Rate</TranslatedText></p>
              </div>
            </div>
          </div>

          <div className="bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl sm:rounded-2xl border border-indigo-300 p-4 sm:p-6 lg:p-8 text-white">
            <h3 className="text-lg sm:text-xl font-bold mb-4 sm:mb-6"><TranslatedText>Quick Stats</TranslatedText></h3>
            <div className="space-y-3 sm:space-y-4">
              <div className="flex items-center justify-between pb-2 sm:pb-3 border-b border-white/20">
                <span className="text-sm sm:text-base text-indigo-100"><TranslatedText>Total Investment</TranslatedText></span>
                <span className="text-sm sm:text-base font-bold">{details.feesInvestment.totalRange}</span>
              </div>
              <div className="flex items-center justify-between pb-2 sm:pb-3 border-b border-white/20">
                <span className="text-sm sm:text-base text-indigo-100"><TranslatedText>Market Demand</TranslatedText></span>
                <span className="text-sm sm:text-base font-bold">{details.jobMarket.demandLevel}%</span>
              </div>
              <div className="flex items-center justify-between pb-2 sm:pb-3 border-b border-white/20">
                <span className="text-sm sm:text-base text-indigo-100"><TranslatedText>Success Rate</TranslatedText></span>
                <span className="text-sm sm:text-base font-bold">{details.jobMarket.successRate}%</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm sm:text-base text-indigo-100"><TranslatedText>Monthly Openings</TranslatedText></span>
                <span className="text-sm sm:text-base font-bold">3000+</span>
              </div>
            </div>
          </div>
        </div>

        {/* Key Responsibilities & Why Suitable */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <div className="bg-white rounded-xl sm:rounded-2xl border border-gray-200 p-4 sm:p-6 lg:p-8">
            <h2 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-4 sm:mb-6 flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5 sm:w-6 sm:h-6 text-indigo-600" />
              <TranslatedText>
                Key Responsibilities
              </TranslatedText>
            </h2>
            <ul className="space-y-2 sm:space-y-3">
              {details.overview.keyResponsibilities.map((item, index) => (
                <li key={index} className="flex items-start gap-2 sm:gap-3">
                  <CheckCircle2 className="w-4 h-4 sm:w-5 sm:h-5 text-indigo-600 flex-shrink-0 mt-0.5" />
                  <span className="text-gray-700 text-xs sm:text-sm"><TranslatedText>{item}</TranslatedText></span>
                </li>
              ))}
            </ul>
          </div>

          <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-xl sm:rounded-2xl border border-indigo-200 p-4 sm:p-6 lg:p-8">
            <h2 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-4 sm:mb-6 flex items-center gap-2">
              <Target className="w-5 h-5 sm:w-6 sm:h-6 text-indigo-600" />
              <TranslatedText>Why This Role Suits You</TranslatedText>
            </h2>
            <ul className="space-y-2 sm:space-y-3">
              {details.overview.whySuitable.map((item, index) => (
                <li key={index} className="flex items-start gap-2 sm:gap-3">
                  <CheckCircle2 className="w-4 h-4 sm:w-5 sm:h-5 text-indigo-600 flex-shrink-0 mt-0.5" />
                  <span className="text-gray-700 text-xs sm:text-sm"><TranslatedText>{item}</TranslatedText></span>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Career Pathway Timeline */}
        <div className="bg-white rounded-xl sm:rounded-2xl border border-gray-200 p-4 sm:p-6 lg:p-8 mb-6 sm:mb-8">
          <h2 className="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-2 flex items-center gap-2">
            <GraduationCap className="w-6 h-6 sm:w-7 sm:h-7 text-indigo-600" />
            <TranslatedText>Academic Career Pathway</TranslatedText>
          </h2>
          <p className="text-sm sm:text-base text-gray-600 mb-6 sm:mb-8">
            Starting from: <span className="font-semibold text-indigo-600"><TranslatedText>{currentLevel}</TranslatedText></span>
          </p>
          <div className="space-y-3 sm:space-y-4">
            {details.careerPathway.steps.map((step, index) => (
              <div key={index} className="relative pl-6 sm:pl-8 pb-4 sm:pb-6 border-l-2 border-indigo-200 last:border-transparent">
                <div className="absolute -left-2.5 sm:-left-3 top-0 w-5 h-5 sm:w-6 sm:h-6 bg-indigo-600 rounded-full flex items-center justify-center">
                  <span className="text-white text-[10px] sm:text-xs font-bold">{index + 1}</span>
                </div>
                <div className="bg-gray-50 rounded-lg sm:rounded-xl p-3 sm:p-4">
                  <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-2">
                    <h3 className="text-sm sm:text-base font-bold text-gray-900">{step.phase}</h3>
                    <span className="px-2 sm:px-3 py-1 bg-purple-100 text-purple-700 rounded-lg font-semibold text-[10px] sm:text-xs w-fit"><TranslatedText>{step.duration}</TranslatedText>
                    </span>
                  </div>
                  <p className="text-xs sm:text-sm text-gray-700"><TranslatedText>{step.description}</TranslatedText></p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Skills Analysis */}
        <div className="lg:col-span-2 space-y-4 sm:space-y-6 mb-8">
          {/* Must-Have Skills */}
          <div className="bg-white rounded-xl sm:rounded-2xl border-2 border-red-200 p-4 sm:p-6">
            <div className="flex items-center gap-2 sm:gap-3 mb-3 sm:mb-4">
              <div className="w-8 h-8 sm:w-10 sm:h-10 bg-red-100 rounded-lg sm:rounded-xl flex items-center justify-center flex-shrink-0">
                <Target className="w-5 h-5 sm:w-6 sm:h-6 text-red-600" />
              </div>
              <div>
                <h3 className="text-sm sm:text-base font-bold text-gray-900"><TranslatedText>Must-Have Skills</TranslatedText></h3>
                <p className="text-xs text-gray-600"><TranslatedText>Essential for this role</TranslatedText></p>
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {details.skillsLearning.mustHave.map((item, index) => (
                <a
                  key={index}
                  href={item.youtubeLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-2 sm:p-3 bg-red-50 rounded-lg border border-red-200 hover:bg-red-100 transition-colors cursor-pointer"
                >
                  <span className="font-medium text-gray-900 text-xs sm:text-sm"><TranslatedText>{item.skill}</TranslatedText></span>
                  <Youtube className="w-3 h-3 sm:w-4 sm:h-4 text-red-600 flex-shrink-0" />
                </a>
              ))}
            </div>
          </div>

          {/* Core Skills */}
          <div className="bg-white rounded-xl sm:rounded-2xl border-2 border-indigo-200 p-4 sm:p-6">
            <div className="flex items-center gap-2 sm:gap-3 mb-3 sm:mb-4">
              <div className="w-8 h-8 sm:w-10 sm:h-10 bg-indigo-100 rounded-lg sm:rounded-xl flex items-center justify-center flex-shrink-0">
                <Target className="w-5 h-5 sm:w-6 sm:h-6 text-indigo-600" />
              </div>
              <div>
                <h3 className="text-sm sm:text-base font-bold text-gray-900"><TranslatedText>Core Skills</TranslatedText></h3>
                <p className="text-xs text-gray-600"><TranslatedText>Important for growth</TranslatedText></p>
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {details.skillsLearning.core.map((item, index) => (
                <a
                  key={index}
                  href={item.youtubeLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-2 sm:p-3 bg-indigo-50 rounded-lg border border-indigo-200 hover:bg-indigo-100 transition-colors cursor-pointer"
                >
                  <span className="font-medium text-gray-900 text-xs sm:text-sm"><TranslatedText>{item.skill}</TranslatedText></span>
                  <Youtube className="w-3 h-3 sm:w-4 sm:h-4 text-indigo-600 flex-shrink-0" />
                </a>
              ))}
            </div>
          </div>

          {/* Bonus Skills */}
          <div className="bg-white rounded-xl sm:rounded-2xl border-2 border-emerald-200 p-4 sm:p-6">
            <div className="flex items-center gap-2 sm:gap-3 mb-3 sm:mb-4">
              <div className="w-8 h-8 sm:w-10 sm:h-10 bg-emerald-100 rounded-lg sm:rounded-xl flex items-center justify-center flex-shrink-0">
                <Zap className="w-5 h-5 sm:w-6 sm:h-6 text-emerald-600" />
              </div>
              <div>
                <h3 className="text-sm sm:text-base font-bold text-gray-900"><TranslatedText>Bonus Skills</TranslatedText></h3>
                <p className="text-xs text-gray-600"><TranslatedText>Stand out from others</TranslatedText></p>
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {details.skillsLearning.bonus.map((item, index) => (
                <a
                  key={index}
                  href={item.youtubeLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-2 sm:p-3 bg-emerald-50 rounded-lg border border-emerald-200 hover:bg-emerald-100 transition-colors cursor-pointer"
                >
                  <span className="font-medium text-gray-900 text-xs sm:text-sm"><TranslatedText>{item.skill}</TranslatedText></span>
                  <Youtube className="w-3 h-3 sm:w-4 sm:h-4 text-emerald-600 flex-shrink-0" />
                </a>
              ))}
            </div>
          </div>
        </div>

        {/* 90-Day Roadmap */}
        <div className="bg-white rounded-xl sm:rounded-2xl border border-gray-200 p-4 sm:p-6 lg:p-8 mb-6 sm:mb-8">
          <h2 className="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 mb-6 sm:mb-8 flex items-center gap-2">
            <Calendar className="w-5 h-5 sm:w-6 sm:h-6 lg:w-7 lg:h-7 text-indigo-600" />
            <TranslatedText>90-Day Success Roadmap</TranslatedText>
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
            {[
              { phase: details.roadmap90Days.phase1, title: 'Phase 1', subtitle: 'Days 1-30', color: 'indigo' },
              { phase: details.roadmap90Days.phase2, title: 'Phase 2', subtitle: 'Days 31-60', color: 'purple' },
              { phase: details.roadmap90Days.phase3, title: 'Phase 3', subtitle: 'Days 61-90', color: 'emerald' },
            ].map((item, idx) => (
              <div key={idx} className={`border-2 border-${item.color}-200 rounded-lg sm:rounded-xl p-4 sm:p-6 bg-${item.color}-50`}>
                <div className="text-center mb-3 sm:mb-4">
                  <h3 className="text-base sm:text-lg font-bold text-gray-900">{item.title}</h3>
                  <p className="text-xs sm:text-sm text-gray-600"><TranslatedText>{item.subtitle}</TranslatedText></p>
                </div>
                <div className="space-y-2 sm:space-y-3 text-xs">
                  <div>
                    <h4 className="font-semibold text-gray-900 mb-2"><TranslatedText>Learning Goals</TranslatedText></h4>
                    <ul className="space-y-1">
                      {item.phase.learningGoals.map((goal, index) => (
                        <li key={index} className="text-gray-700">• <TranslatedText>{goal}</TranslatedText></li>
                      ))}
                    </ul>
                  </div>
                  <div>
                    <h4 className="font-semibold text-gray-900 mb-2 mt-3"><TranslatedText>Action Tasks</TranslatedText></h4>
                    <ul className="space-y-1">
                      {item.phase.actionTasks.map((task, index) => (
                        <li key={index} className="text-gray-700">• <TranslatedText>{task}</TranslatedText></li>
                      ))}
                    </ul>
                  </div>
                  <div>
                    <h4 className="font-semibold text-gray-900 mb-2 mt-3"><TranslatedText>Progress Indicators</TranslatedText></h4>
                    <ul className="space-y-1">
                      {item.phase.progressIndicators.map((outcome, index) => (
                        <li key={index} className="text-gray-700">• <TranslatedText>{outcome}</TranslatedText></li>
                      ))}
                    </ul>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Salary Growth Analysis */}
        <div className="grid lg:grid-cols-2 gap-6 mb-8">
          <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
            <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
              <TrendingUp className="w-6 h-6 text-indigo-600" /><TranslatedText>Salary Progression Timeline</TranslatedText>
            </h2>
            <div className="h-48 sm:h-56 lg:h-64" style={{ minHeight: '192px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={salaryProgressionDataWithIds} key="salary-line-chart">
                  <CartesianGrid key="salary-grid" strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis 
                    key="salary-xaxis"
                    dataKey="experience" 
                    tick={{ fontSize: 10 }} 
                    stroke="#6b7280"
                  />
                  <YAxis 
                    key="salary-yaxis"
                    tick={{ fontSize: 10 }} 
                    stroke="#6b7280"
                  />
                  <Tooltip
                    key="salary-tooltip"
                    formatter={(value: number, name: string, props: any) => [
                      props?.payload?.salaryLabel ?? `${value} LPA`,
                      'Salary'
                    ]}
                  />
                  <Line 
                    key="salary-line"
                    type="monotone" 
                    dataKey="salary" 
                    stroke="#4f46e5" 
                    strokeWidth={2} 
                    dot={{ fill: '#4f46e5', r: 4 }}
                    isAnimationActive={false}
                    name="Salary (LPA)"
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8">
            <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
              <MapPin className="w-6 h-6 text-indigo-600" /><TranslatedText>City-wise Salary Comparison</TranslatedText>
            </h2>
            <div className="space-y-3">
              {details.salaryGrowth.cityComparison.map((city, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-xl">
                  <div className="flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-indigo-600" />
                    <span className="font-semibold text-gray-900"><TranslatedText>{city.city}</TranslatedText></span>
                  </div>
                  <span className="font-bold text-emerald-600"><TranslatedText>{city.salary}</TranslatedText></span>
                </div>
              ))}
            </div>
            <div className="mt-6 bg-gradient-to-br from-indigo-50 to-purple-50 rounded-xl p-4 border border-indigo-200">
              <h3 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
                <Lightbulb className="w-5 h-5 text-indigo-600" /><TranslatedText>Salary Tips</TranslatedText>
              </h3>
              <ul className="space-y-2 text-xs text-gray-700">
                {details.salaryGrowth.salaryTips.map((tip, index) => (
                  <li key={index} className="flex items-start gap-2">
                    <span className="text-indigo-600">•</span>
                    <span><TranslatedText>{tip}</TranslatedText></span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>

        {/* Job Market Insights */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <BarChart3 className="w-7 h-7 text-indigo-600" /><TranslatedText>Job Market Insights</TranslatedText>
          </h2>
          
          <div className="grid md:grid-cols-3 gap-4 mb-6">
            <div className="bg-gradient-to-br from-indigo-50 to-indigo-100 rounded-xl border border-indigo-200 p-4 text-center">
              <h3 className="text-sm font-semibold text-indigo-700 mb-1"><TranslatedText>Market Demand</TranslatedText></h3>
              <p className="text-3xl font-bold text-indigo-600">{details.jobMarket.demandLevel}%</p>
            </div>
            <div className="bg-gradient-to-br from-emerald-50 to-emerald-100 rounded-xl border border-emerald-200 p-4 text-center">
              <h3 className="text-sm font-semibold text-emerald-700 mb-1"><TranslatedText>Success Rate</TranslatedText></h3>
              <p className="text-3xl font-bold text-emerald-600">{details.jobMarket.successRate}%</p>
            </div>
            <div className="bg-gradient-to-br from-purple-50 to-purple-100 rounded-xl border border-purple-200 p-4 text-center">
              <h3 className="text-sm font-semibold text-purple-700 mb-1"><TranslatedText>Monthly Openings</TranslatedText></h3>
              <p className="text-3xl font-bold text-purple-600">3000+</p>
            </div>
          </div>

          <div className="mb-6">
            <h3 className="font-bold text-gray-900 mb-4">
              <TranslatedText>Hiring Trends</TranslatedText> (Previous 5 Years: {new Date().getFullYear() - 4} - {new Date().getFullYear()})
            </h3>
            <div className="h-48 sm:h-56 lg:h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={hiringTrendsData} key="hiring-trends-bar-chart">
                  <CartesianGrid key="hiring-grid" strokeDasharray="3 3" />
                  <XAxis key="hiring-xaxis" dataKey="month" tick={{ fontSize: 10 }} />
                  <YAxis key="hiring-yaxis" tick={{ fontSize: 10 }} />
                  <Tooltip key="hiring-tooltip" formatter={(value: number) => [`${value} openings`, 'Annual Job Openings']} />
                  <Bar key="hiring-bar" dataKey="openings" fill="#4f46e5" radius={[8, 8, 0, 0]} isAnimationActive={false}>
                    {hiringTrendsData.map((entry) => (
                      <Cell key={`bar-cell-${entry.id}`} fill="#4f46e5" />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div>
            <h3 className="font-bold text-gray-900 mb-4"><TranslatedText>Top Hiring Companies</TranslatedText></h3>
            <div className="grid md:grid-cols-2 gap-3">
              {details.jobMarket.topCompanies.map((company, index) => (
                <div key={index} className="p-4 bg-gray-50 rounded-xl border border-gray-200">
                  <h4 className="font-bold text-gray-900 mb-1"><TranslatedText>{company.name}</TranslatedText></h4>
                  <p className="text-emerald-600 font-semibold text-sm mb-2"><TranslatedText>{company.packageRange}</TranslatedText></p>
                  <div className="flex flex-wrap gap-1">
                    {company.locations.map((location, i) => (
                      <span key={i} className="px-2 py-1 bg-indigo-100 text-indigo-700 rounded text-xs">
                        {location}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Top Institutes */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <Building2 className="w-7 h-7 text-indigo-600" /><TranslatedText>Top Recommended Institutes</TranslatedText>
          </h2>
          <div className="space-y-6">
            <div>
              <h3 className="font-bold text-gray-900 mb-4 text-lg"><TranslatedText>Government Institutes</TranslatedText></h3>
              <div className="grid md:grid-cols-3 gap-3">
                {details.topInstitutes.government.map((inst, index) => (
                  <div key={index} className="border border-gray-200 hover:border-indigo-300 rounded-xl p-4 transition-all">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-bold text-gray-900 text-sm flex-1">{inst.name}</h4>
                      <div className="flex items-center gap-1">
                        <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                        <span className="font-bold text-xs text-gray-900">{inst.rating}</span>
                      </div>
                    </div>
                    <p className="text-xs text-gray-600 flex items-center gap-1 mb-1">
                      <MapPin className="w-3 h-3" /><TranslatedText>{inst.location}</TranslatedText>
                    </p>
                    <p className="text-xs text-indigo-600 font-medium mb-2">{inst.department}</p>
                    <a
                      href={inst.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-semibold"
                    >
                      <ExternalLink className="w-3 h-3" /><TranslatedText>Visit Website</TranslatedText>
                    </a>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 mb-4 text-lg"><TranslatedText>Private Institutes</TranslatedText></h3>
              <div className="grid md:grid-cols-3 gap-3">
                {details.topInstitutes.private.map((inst, index) => (
                  <div key={index} className="border border-gray-200 hover:border-indigo-300 rounded-xl p-4 transition-all">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-bold text-gray-900 text-sm flex-1">{inst.name}</h4>
                      <div className="flex items-center gap-1">
                        <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                        <span className="font-bold text-xs text-gray-900">{inst.rating}</span>
                      </div>
                    </div>
                    <p className="text-xs text-gray-600 flex items-center gap-1 mb-1">
                      <MapPin className="w-3 h-3" /><TranslatedText>{inst.location}</TranslatedText>
                    </p>
                    <p className="text-xs text-indigo-600 font-medium mb-2">{inst.department}</p>
                    <a
                      href={inst.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-semibold"
                    >
                      <ExternalLink className="w-3 h-3" /><TranslatedText>Visit Website</TranslatedText>
                    </a>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Certifications */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <BadgeCheck className="w-7 h-7 text-indigo-600" /><TranslatedText>Recommended Certifications</TranslatedText>
          </h2>
          <div className="space-y-4">
            {details.certifications.map((cert, index) => (
              <div key={index} className="p-5 bg-gradient-to-br from-gray-50 to-indigo-50/30 rounded-xl border border-gray-200">
                <div className="flex flex-wrap items-start justify-between gap-3 mb-3">
                  <div className="flex-1">
                    <h3 className="font-bold text-gray-900 mb-2"><TranslatedText>{cert.name}</TranslatedText></h3>
                    <div className="flex flex-wrap gap-2 text-xs">
                      <span className="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg font-semibold">
                        {cert.platform}
                      </span>
                      <span className="px-2 py-1 bg-purple-100 text-purple-700 rounded-lg">
                        {cert.provider}
                      </span>
                    </div>
                  </div>
                  <a
                    href={cert.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-semibold text-sm transition-colors"
                  >
                    <ExternalLink className="w-4 h-4" /><TranslatedText>View Course</TranslatedText>
                  </a>
                </div>
                <div className="grid grid-cols-3 gap-3 text-sm mb-3">
                  <div>
                    <p className="text-xs text-gray-600"><TranslatedText>Duration</TranslatedText>
                    </p>
                    <p className="font-semibold text-gray-900"><TranslatedText>{cert.duration}</TranslatedText></p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-600"><TranslatedText>Cost</TranslatedText></p>
                    <p className="font-semibold text-emerald-600">{cert.cost}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-600"><TranslatedText>Impact</TranslatedText></p>
                    <p className="font-semibold text-gray-900"><TranslatedText>{cert.impact}</TranslatedText></p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
        
        <div className="bg-gradient-to-br mb-8 from-indigo-50 to-purple-50 rounded-2xl border-2 border-indigo-200 p-6 sm:p-8">
          <h2 className="text-xl font-bold text-gray-900 mb-2 flex items-center gap-2">
            <IndianRupee className="w-6 h-6 text-indigo-600" /><TranslatedText>Total Investment</TranslatedText>
          </h2>
          <p className="text-4xl font-bold text-indigo-600 mb-4"><TranslatedText>{details.feesInvestment.totalRange}</TranslatedText></p>
          <p className="text-gray-700 text-sm mb-6"><TranslatedText>{details.feesInvestment.description}</TranslatedText></p>
          <div className="space-y-2">
            {details.feesInvestment.breakdown.map((item, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-white rounded-lg border border-indigo-200">
                <span className="text-sm font-medium text-gray-900"><TranslatedText>{item.phase}</TranslatedText></span>
                <span className="font-bold text-indigo-600 text-sm">{item.cost}</span>
              </div>
            ))}
          </div>
        </div>
        
        
        <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8 mb-8">
          <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <Award className="w-6 h-6 text-indigo-600" /><TranslatedText>Scholarships & Financial Aid</TranslatedText>
          </h2>
          <strong className="inline-block mb-2 mt-2"><TranslatedText>Scholarships</TranslatedText></strong>
          <div className="grid md:grid-cols-3 gap-6">
            {(details.scholarships?.governmentPrivate ?? []).map((scholarship, index) => (
              <div key={`scholarship-${index}`} className="p-4 bg-gray-50 rounded-xl border border-indigo-200">
                <h3 className="font-bold text-gray-900 mb-1 text-sm">{scholarship.name}</h3>
                <p className="text-emerald-600 font-semibold text-sm mb-2">{scholarship.amount}</p>
                <p className="text-xs text-gray-600"><TranslatedText>{scholarship.eligibility}</TranslatedText></p>
                {scholarship.website && scholarship.website !== '#' && (
                  <a
                    href={scholarship.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-2 inline-flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-semibold"
                  >
                    <span><TranslatedText>Visit Website</TranslatedText></span>
                  </a>
                )}
              </div>
            ))}
          </div>
          <strong className="inline-block mb-2 mt-2"><TranslatedText>Bank Loans</TranslatedText></strong>
          <div className="grid md:grid-cols-3 gap-6">
              {(details.scholarships?.bankLoans ?? []).map((loan, index) => (
                <div key={`loan-${index}`} className="p-4 bg-gray-50 rounded-xl border border-indigo-200">
                  <h3 className="font-bold text-gray-900 mb-1 text-sm">{loan.name}</h3>
                  <p className="text-emerald-600 font-semibold text-sm mb-2">{loan.amount}</p>
                  <p className="text-xs text-gray-600"><TranslatedText>{loan.interestRate}</TranslatedText></p>
                  {loan.website && loan.website !== '#' && (
                    <a
                      href={loan.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="mt-2 inline-flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-semibold"
                    >
                      <span><TranslatedText>Visit Website</TranslatedText></span>
                    </a>
                  )}
                </div>
              ))}
          </div>
          <strong className="inline-block mb-2 mt-2"><TranslatedText>Government Schemes</TranslatedText></strong>
          <div className="grid md:grid-cols-3 gap-6">
              {(details.scholarships?.governmentSchemes ?? []).map((scheme, index) => (
                <div key={`scheme-${index}`} className="p-4 bg-gray-50 rounded-xl border border-indigo-200">
                  <h3 className="font-bold text-gray-900 mb-1 text-sm">{scheme.name}</h3>
                  <p className="text-emerald-600 font-semibold text-sm mb-2"><TranslatedText>{scheme.benefits}</TranslatedText></p>
                  <p className="text-xs text-gray-600"><TranslatedText>{scheme.eligibility}</TranslatedText></p>
                  {scheme.website && scheme.website !== '#' && (
                    <a
                      href={scheme.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="mt-2 inline-flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-semibold"
                    >
                      <span><TranslatedText>Visit Website</TranslatedText></span>
                    </a>
                  )}
                </div>
              ))}
            {/* </div> */}
          </div>
          <div className="mt-4 p-4 bg-emerald-50 rounded-xl border border-emerald-200">
            <p className="text-sm text-gray-700 flex items-start gap-2">
              <Shield className="w-4 h-4 text-emerald-600 flex-shrink-0 mt-0.5" />
              <TranslatedText>Multiple scholarship options available to reduce your education investment significantly</TranslatedText>
            </p>
          </div>
        </div>
        

        {/* Industry Experts */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 sm:p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <Users className="w-7 h-7 text-indigo-600" /><TranslatedText>Industry Expert Advice</TranslatedText>
          </h2>
          <div className="grid md:grid-cols-2 gap-6">
            {details.industryExperts.map((expert, index) => (
              <div key={index} className="p-5 bg-gradient-to-br from-gray-50 to-indigo-50/30 rounded-xl border border-gray-200">
                <div className="flex items-start gap-3 mb-3">
                  <div className="w-12 h-12 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-full flex items-center justify-center text-xl text-white font-bold flex-shrink-0">
                    {expert.name.charAt(0)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="font-bold text-gray-900"><TranslatedText>{expert.name}</TranslatedText></h3>
                    <p className="text-indigo-600 font-semibold text-sm">{expert.designation}</p>
                    <p className="text-gray-600 text-xs">{expert.company}</p>
                  </div>
                </div>
                <div className="bg-white rounded-lg p-3 border border-indigo-200">
                  <p className="text-xs font-semibold text-indigo-700 mb-1 flex items-center gap-1">
                    <MessageSquare className="w-3 h-3" /><TranslatedText>Advice:</TranslatedText>
                  </p>
                  <p className="text-gray-700 italic text-sm">"<TranslatedText>{expert.advice}</TranslatedText>"</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Key Market Insights */}
        <div className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border border-indigo-200 p-6 sm:p-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <Lightbulb className="w-7 h-7 text-indigo-600" /><TranslatedText>Key Market Insights</TranslatedText>
          </h2>
          <div className="grid md:grid-cols-2 gap-4">
            {details.jobMarket.keyInsights.map((insight, index) => (
              <div key={index} className="flex items-start gap-3 p-4 bg-white rounded-xl border border-indigo-200">
                <CheckCircle2 className="w-5 h-5 text-indigo-600 flex-shrink-0 mt-0.5" />
                <span className="text-gray-700 text-sm"><TranslatedText>{insight}</TranslatedText></span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Footer CTA */}
      <div className="bg-gradient-to-r from-indigo-600 to-purple-600 py-6 sm:py-8 mt-8 sm:mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h3 className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-2 sm:mb-4"><TranslatedText>Ready to Download Your Complete Report?</TranslatedText></h3>
          <p className="text-sm sm:text-base text-indigo-100 mb-4 sm:mb-6"><TranslatedText>Get all this data in a professional PDF format</TranslatedText></p>
          <div className="flex flex-col items-center gap-3">
            <Button
              onClick={handleGenerateReport}
              disabled={isGenerating}
              size="lg"
              className="bg-white text-indigo-600 hover:bg-gray-100 w-full sm:w-auto"
            >
              {isGenerating ? (
                <>
                  <Loader2 className="w-4 h-4 sm:w-5 sm:h-5 mr-2 animate-spin" /><TranslatedText>Generating PDF...</TranslatedText>
                </>
              ) : (
                <>
                  <Download className="w-4 h-4 sm:w-5 sm:h-5 mr-2" /><TranslatedText>Download Complete Report</TranslatedText>
                </>
              )}
            </Button>
            {isGenerating && (
              <div className="flex flex-col gap-2 w-full max-w-md">
                <div className="flex items-center gap-3">
                  <div className="flex-1 bg-white/30 rounded-full h-3 overflow-hidden">
                    <div 
                      className="bg-white h-full transition-all duration-300"
                      style={{ width: `${pdfProgress}%` }}
                    />
                  </div>
                  <span className="text-lg font-bold text-white min-w-[3.5rem] text-right">{pdfProgress}%</span>
                </div>
                <span className="text-sm text-indigo-100 text-center">{pdfStatus}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
