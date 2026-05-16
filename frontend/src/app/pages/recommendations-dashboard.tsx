import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import {
  Accordion, AccordionContent, AccordionItem, AccordionTrigger,
} from '../components/ui/accordion';
import { Sparkles, TrendingUp, ArrowRight, RefreshCw, Target, BookOpen, Zap } from 'lucide-react';
import { CareerDomain, JobRole } from '../../types/career';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';

// Session management function
const clearSession = () => {
  const keysToRemove = [];
  for (let i = 0; i < sessionStorage.length; i++) {
    const key = sessionStorage.key(i);
    if (key && (key === 'careerRecommendations' || key === 'userProfile' || key.startsWith('jobDetail_'))) {
      keysToRemove.push(key);
    }
  }
  keysToRemove.forEach((k) => sessionStorage.removeItem(k));
};

const DOMAIN_ICONS = ['💼', '🎯', '🌐'];
const JOB_ICONS = ['📊', '🔬', '⚙️', '🤖', '📈', '💡', '🏆', '🚀'];

// Map backend careers[] → CareerDomain[] shape used by existing JSX
function mapBackendCareers(careers: any[]): CareerDomain[] {
  return careers.map((domain, domainIndex) => ({
    id: `domain-${domainIndex}`,
    title: domain.title,
    summary: domain.summary,
    icon: DOMAIN_ICONS[domainIndex] ?? '💼',
    match: domain.match ?? 0,
    salary: domain.salary ?? 'Not specified',
    growth: domain.growth ?? 'Not specified',
    jobs: (domain.jobs ?? []).map((job: any, jobIndex: number) => ({
      id: `domain-${domainIndex}-job-${jobIndex}`,
      title: job.title,
      domainId: `domain-${domainIndex}`,
      icon: JOB_ICONS[jobIndex % JOB_ICONS.length],
      matchPercentage: domain.match ?? 0,
      salaryRange: job.salary,
      growthRate: job.growth,
      description: job.description,
    } as JobRole)),
  }));
}

export function RecommendationsDashboard() {
  const navigate = useNavigate();
  const [domains, setDomains] = useState<CareerDomain[]>([]);
  const [displayProgress, setDisplayProgress] = useState(0);

  useEffect(() => {
    // Animate bar from 0 → 100 on mount to show generation is complete
    const t = setTimeout(() => setDisplayProgress(100), 100);
    return () => clearTimeout(t);
  }, []);

  useEffect(() => {
    // Try sessionStorage first, then localStorage as fallback
    let stored = sessionStorage.getItem('careerRecommendations');
    
    if (!stored) {
      stored = localStorage.getItem('careerRecommendations');
      if (stored) {
        // Restore to sessionStorage for future use
        sessionStorage.setItem('careerRecommendations', stored);
      }
    }
    
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (parsed?.success && Array.isArray(parsed.careers) && parsed.careers.length > 0) {
          setDomains(mapBackendCareers(parsed.careers));
        }
      } catch {
        // malformed storage — keep static fallback
      }
    }
  }, []);

  return (
    <div className="min-h-screen abstract-bg">
      <Navbar />

      {/* Main Content */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-indigo-100 to-purple-100 text-indigo-700 rounded-full text-sm font-semibold mb-4">
            <Sparkles className="w-4 h-4" />
            <TranslatedText>Your Personalized Career Matches</TranslatedText>
          </div>
          <h1 className="text-4xl sm:text-5xl font-bold text-gray-900 mb-4">
            <TranslatedText>Your Personalized Career Recommendations</TranslatedText>
          </h1>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            <TranslatedText>Based on your profile, interests, and assessment, here are the top career paths tailored for you</TranslatedText>
          </p>
          {/* Generation progress indicator */}
          <div className="mt-6 max-w-sm mx-auto">
            <div className="flex justify-between text-xs text-gray-500 mb-1">
              <span><TranslatedText>AI Analysis Complete</TranslatedText></span>
              <span>{displayProgress}%</span>
            </div>
            <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-700 ease-out"
                style={{ width: `${displayProgress}%` }}
              />
            </div>
          </div>
        </div>

        {/* Career Domains Accordion */}
        <div className="space-y-6">
          <Accordion type="single" collapsible className="space-y-4">
            {domains.map((domain, domainIndex) => (
              <AccordionItem
                key={domain.id}
                value={domain.id}
                className="bg-white border-2 border-gray-200 rounded-2xl overflow-hidden"
              >
                <AccordionTrigger className="px-6 py-6 hover:no-underline group">
                  <div className="flex items-center justify-between w-full pr-4">
                    <div className="flex items-center gap-4">
                      <div
                        className={`text-4xl w-16 h-16 flex items-center justify-center rounded-xl ${
                          domainIndex === 0
                            ? 'bg-indigo-100'
                            : domainIndex === 1
                            ? 'bg-purple-100'
                            : 'bg-emerald-100'
                        }`}
                      >
                        {domain.icon}
                      </div>
                      <div className="text-left">
                        <h3 className="text-xl font-bold text-gray-900 mb-1"><TranslatedText>{domain.title}</TranslatedText></h3>
                        <p className="text-gray-600 text-sm"><TranslatedText>{domain.summary}</TranslatedText></p>
                      </div>
                    </div>
                    <div className="flex items-center gap-6">
                      <div className="text-right">
                        <div className="text-2xl font-bold text-indigo-600">
                          {domain.match}%
                        </div>
                        <div className="text-xs text-gray-500"><TranslatedText>AI Match</TranslatedText></div>
                      </div>
                    </div>
                  </div>
                </AccordionTrigger>
                <AccordionContent className="px-6 pb-6">
                  <div className="grid md:grid-cols-2 gap-4 pt-4">
                    {domain.jobs.map((role: JobRole) => (
                      <div key={role.id} className="space-y-3">
                        <div className="border-2 rounded-xl p-5 transition-all border-gray-200 bg-white hover:border-indigo-200">
                          <div className="flex items-start gap-3 mb-3">
                            <div className="text-3xl flex-shrink-0">{role.icon}</div>
                            <div className="flex-1 min-w-0">
                              <h4 className="font-bold text-gray-900 mb-1"><TranslatedText>{role.title}</TranslatedText></h4>
                              <div className="flex flex-wrap items-center gap-2 text-sm mb-2">
                                <span className="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg font-semibold">
                                  {role.matchPercentage}% <TranslatedText>Match</TranslatedText>
                                </span>
                                <span className="text-emerald-600 font-semibold">
                                  {role.salaryRange}
                                </span>
                                <span className="text-gray-500 flex items-center gap-1">
                                  <TrendingUp className="w-3.5 h-3.5" />
                                  <TranslatedText>{role.growthRate}</TranslatedText>
                                </span>
                              </div>
                              <p className="text-gray-700 text-sm mb-3"><TranslatedText>{role.description}</TranslatedText></p>
                            </div>
                          </div>

                          <Button
                            size="sm"
                            onClick={() => navigate(`/role/${role.id}`)}
                            className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                          >
                            <TranslatedText>Career Details</TranslatedText>
                            <ArrowRight className="w-4 h-4 ml-1" />
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>

        {/* Retake Assessment */}
        <div className="mt-12 bg-white border-2 border-gray-200 rounded-2xl p-8 text-center">
          <h3 className="text-2xl font-bold text-gray-900 mb-2"><TranslatedText>Not satisfied with results?</TranslatedText></h3>
          <p className="text-gray-600 mb-6">
            <TranslatedText>Retake the assessment with updated information to get better recommendations</TranslatedText>
          </p>
          <Link to="/onboarding" onClick={clearSession}>
            <Button
              size="lg"
              variant="outline"
              className="border-indigo-600 text-indigo-600 hover:bg-indigo-50"
            >
              <RefreshCw className="w-5 h-5 mr-2" />
              <TranslatedText>Retake Assessment</TranslatedText>
            </Button>
          </Link>
        </div>

        {/* Info Cards */}
        <div className="grid md:grid-cols-3 gap-6 mt-12">
          <div className="bg-gradient-to-br from-indigo-50 to-purple-50 border border-indigo-200 rounded-2xl p-6">
            <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center mb-3">
              <Target className="w-6 h-6 text-indigo-600" />
            </div>
            <h4 className="font-bold text-gray-900 mb-2"><TranslatedText>Personalized for You</TranslatedText></h4>
            <p className="text-sm text-gray-600">
              <TranslatedText>Recommendations are tailored based on your unique profile and preferences</TranslatedText>
            </p>
          </div>
          <div className="bg-gradient-to-br from-purple-50 to-purple-100 border border-purple-200 rounded-2xl p-6">
            <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center mb-3">
              <BookOpen className="w-6 h-6 text-purple-600" />
            </div>
            <h4 className="font-bold text-gray-900 mb-2"><TranslatedText>Comprehensive Guidance</TranslatedText></h4>
            <p className="text-sm text-gray-600">
              <TranslatedText>Get detailed roadmaps, skills, institutes, and salary insights for each role</TranslatedText>
            </p>
          </div>
          <div className="bg-gradient-to-br from-emerald-50 to-teal-50 border border-emerald-200 rounded-2xl p-6">
            <div className="w-12 h-12 bg-emerald-100 rounded-xl flex items-center justify-center mb-3">
              <Zap className="w-6 h-6 text-emerald-600" />
            </div>
            <h4 className="font-bold text-gray-900 mb-2"><TranslatedText>Stay Updated</TranslatedText></h4>
            <p className="text-sm text-gray-600">
              <TranslatedText>Our AI continuously learns to provide the most relevant career recommendations</TranslatedText>
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}