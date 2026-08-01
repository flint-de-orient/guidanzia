import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import { Sparkles, TrendingUp, ArrowRight, RefreshCw, Target, BookOpen, Zap } from 'lucide-react';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';
import { useAuth } from '../contexts/AuthContext';

const DOMAIN_ICONS = ['💼', '🎯', '🌐'];
const JOB_ICONS = ['📊', '🔬', '⚙️', '🤖', '📈', '💡', '🏆', '🚀'];

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

export function RecommendationsDashboard() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [careers, setCareers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingPct, setLoadingPct] = useState(0);

  useEffect(() => {
    const fetchTopCareers = async () => {
      try {
        const username = sessionStorage.getItem('username') || user?.email;
        if (!username) {
          navigate('/signup');
          return;
        }

        // Check sessionStorage cache first
        const cached = sessionStorage.getItem('careerRecommendations');
        if (cached) {
          const parsed = JSON.parse(cached);
          if (parsed?.careers?.length > 0) {
            setCareers(parsed.careers);
            setLoadingPct(100);
            setLoading(false);
            return;
          }
        }

        // Simulate progress while waiting for API
        setLoadingPct(10);
        const ticker = setInterval(() => {
          setLoadingPct(prev => prev < 85 ? prev + 5 : prev);
        }, 600);

        const response = await fetch('http://localhost:8080/api/get-top-3-careers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username })
        });

        clearInterval(ticker);
        setLoadingPct(95);

        const result = await response.json();
        if (result.success && result.careers) {
          // Save to sessionStorage for future loads
          sessionStorage.setItem('careerRecommendations', JSON.stringify({ careers: result.careers }));
          setCareers(result.careers);
          setLoadingPct(100);
        }
      } catch (error) {
        console.error('Failed to fetch career recommendations:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchTopCareers();
  }, [navigate, user]);

  return (
    <div className="min-h-screen abstract-bg">
      <Navbar />

      {/* Main Content */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-indigo-100 to-purple-100 text-indigo-700 rounded-full text-sm font-semibold mb-4">
            <Sparkles className="w-4 h-4" />
            <TranslatedText>Your Top Career Matches</TranslatedText>
          </div>
          <h1 className="text-4xl sm:text-5xl font-bold text-gray-900 mb-4">
            <TranslatedText>Your Top 3 Career Recommendations</TranslatedText>
          </h1>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            <TranslatedText>Based on your profile, interests, and assessment results</TranslatedText>
          </p>
        </div>

        {/* Loading State */}
        {loading && (
          <div className="flex flex-col justify-center items-center py-20 gap-4">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
            <div className="w-64">
              <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden mb-2">
                <div
                  className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-500"
                  style={{ width: `${loadingPct}%` }}
                />
              </div>
              <p className="text-sm font-semibold text-indigo-600 text-center">{loadingPct}% — Fetching your career matches...</p>
            </div>
          </div>
        )}

        {/* Career Cards */}
        {!loading && careers.length > 0 && (
          <div className="grid md:grid-cols-3 gap-6 mb-12">
            {careers.map((career, index) => (
              <div
                key={index}
                className="bg-white border-2 border-gray-200 rounded-2xl p-6 hover:border-indigo-300 transition-all hover:shadow-lg"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className={`text-3xl w-14 h-14 flex items-center justify-center rounded-xl ${
                    index === 0 ? 'bg-indigo-100' : index === 1 ? 'bg-purple-100' : 'bg-emerald-100'
                  }`}>
                    {index === 0 ? '🎯' : index === 1 ? '💼' : '🚀'}
                  </div>
                  <div className="text-right">
                    <div className="text-2xl font-bold text-indigo-600">{career.matchScore}%</div>
                    <div className="text-xs text-gray-500"><TranslatedText>Match</TranslatedText></div>
                  </div>
                </div>

                <h3 className="text-xl font-bold text-gray-900 mb-3">
                  <TranslatedText>{career.title}</TranslatedText>
                </h3>

                <p className="text-gray-600 text-sm mb-6">
                  <TranslatedText>{career.description}</TranslatedText>
                </p>

                <Button
                  // onClick={() => navigate(`/role/job-${index}`)}
                  onClick={() => navigate(`/payment?job=${index}`)}
                  className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                >
                  <TranslatedText>Know More</TranslatedText>
                  <ArrowRight className="w-4 h-4 ml-1" />
                </Button>
              </div>
            ))}
          </div>
        )}

        {/* Retake Assessment */}
        <div className="mt-12 bg-white border-2 border-gray-200 rounded-2xl p-8 text-center">
          <h3 className="text-2xl font-bold text-gray-900 mb-2"><TranslatedText>Not satisfied with results?</TranslatedText></h3>
          <p className="text-gray-600 mb-6">
            <TranslatedText>Retake the assessment with updated information to get better recommendations</TranslatedText>
          </p>
          <Link to="/onboarding-new" onClick={clearSession}>
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