import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router';
import {
  LogOut, Zap, Clock, ArrowRight,
  Mail, User, Star, CheckCircle2, Sparkles, BarChart3, Settings as SettingsIcon,
  Calendar, TrendingUp, Building,
} from 'lucide-react';
import { Button } from '../components/ui/button';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';
import { useAuth } from '../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

interface RecentJobRole {
  roleId: string;
  roleTitle: string;
  createdAt: string;
  sectionsCount: number;
}

// Session management functions
const getLastViewedRole = () => {
  try {
    const raw = localStorage.getItem('edubot_last_role');
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
};

// Fetch recent job role details from database
const fetchRecentJobRole = async (username: string): Promise<RecentJobRole | null> => {
  try {
    const response = await fetch(`${API_BASE}/api/get-recent-job-role`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username }),
    });
    
    const result = await response.json();
    if (result.success && result.jobRole) {
      return result.jobRole;
    }
    return null;
  } catch (error) {
    console.error('Error fetching recent job role:', error);
    return null;
  }
};

export function Profile() {
  const navigate = useNavigate();
  const { user, isAuthenticated, logout } = useAuth();
  const [lastRole, setLastRole] = useState<{ roleId: string; roleTitle: string } | null>(null);
  const [recentJobRole, setRecentJobRole] = useState<RecentJobRole | null>(null);
  const [loadingRecentRole, setLoadingRecentRole] = useState(true);
  const [hasRecommendations, setHasRecommendations] = useState(false);

  useEffect(() => {
    if (!isAuthenticated || !user) { 
      navigate('/login'); 
      return; 
    }
    
    setLastRole(getLastViewedRole());
    
    // Check for recommendations from multiple sources
    const checkRecommendations = () => {
      // Check sessionStorage first
      const sessionRecs = sessionStorage.getItem('careerRecommendations');
      if (sessionRecs) {
        setHasRecommendations(true);
        return;
      }
      
      // Check localStorage as fallback
      const localRecs = localStorage.getItem('careerRecommendations');
      if (localRecs) {
        setHasRecommendations(true);
        // Restore to sessionStorage for future use
        sessionStorage.setItem('careerRecommendations', localRecs);
        return;
      }
      
      // Check if user has saved recommendations in database
      fetchUserRecommendations(user.email);
    };
    
    // Fetch recent job role from database
    const loadRecentJobRole = async () => {
      setLoadingRecentRole(true);
      const recentRole = await fetchRecentJobRole(user.email);
      setRecentJobRole(recentRole);
      setLoadingRecentRole(false);
    };
    
    checkRecommendations();
    loadRecentJobRole();
  }, [navigate, isAuthenticated, user]);

  // Fetch user recommendations from database
  const fetchUserRecommendations = async (username: string) => {
    try {
      const response = await fetch(`${API_BASE}/api/get-user-session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      
      const result = await response.json();
      if (result.success && result.session?.recommendations) {
        setHasRecommendations(true);
        // Restore recommendations to sessionStorage
        sessionStorage.setItem('careerRecommendations', JSON.stringify(result.session.recommendations));
      } else {
        setHasRecommendations(false);
      }
    } catch (error) {
      console.error('Error fetching user recommendations:', error);
      setHasRecommendations(false);
    }
  };

  const handleLogout = () => {
    logout(); // This will now automatically refresh and redirect
  };

  if (!user) return null;

  const initials = user.name
    .split(' ')
    .map((w: string) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const proFeatures = [
    { icon: '📄', label: 'Unlimited PDF Reports' },
    { icon: '⚡', label: 'Priority AI Analysis' },
    { icon: '🗺️', label: 'Advanced Roadmaps' },
    { icon: '🎓', label: '1-on-1 Expert Sessions' },
    { icon: '📊', label: 'Salary Benchmarking' },
    { icon: '🔔', label: 'Job Alert Notifications' },
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar showHomeButton />

      {/* Hero Banner */}
      <div className="gradient-primary">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
          <div className="flex flex-col sm:flex-row items-center sm:items-end gap-6">
            {/* Avatar */}
            <div className="relative flex-shrink-0">
              <div className="w-24 h-24 bg-white/20 backdrop-blur-sm rounded-2xl flex items-center justify-center border-4 border-white/40 shadow-xl">
                <span className="text-4xl font-bold text-white">{initials}</span>
              </div>
              <div className="absolute -bottom-2 -right-2 w-7 h-7 bg-emerald-400 rounded-full border-2 border-white flex items-center justify-center">
                <CheckCircle2 className="w-4 h-4 text-white" />
              </div>
            </div>

            {/* Name + email */}
            <div className="text-center sm:text-left flex-1">
              <h1 className="text-3xl font-bold text-white mb-1">{user.name}</h1>
              <div className="flex items-center justify-center sm:justify-start gap-2 text-indigo-200 text-sm">
                <Mail className="w-4 h-4" />
                <span>{user.email}</span>
              </div>
            </div>

            {/* Plan badge + Settings + Logout */}
            <div className="flex flex-col items-center sm:items-end gap-3 flex-shrink-0">
              <span className="inline-flex items-center gap-1.5 px-4 py-2 bg-white/15 border border-white/30 rounded-full text-white text-sm font-semibold backdrop-blur-sm">
                <User className="w-4 h-4" />
                <TranslatedText>Free Plan</TranslatedText>
              </span>
              <div className="flex gap-2">
                <Link to="/settings">
                  <button className="inline-flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 border border-white/30 rounded-full text-white text-sm font-semibold backdrop-blur-sm transition-all">
                    <SettingsIcon className="w-4 h-4" />
                    <TranslatedText>Settings</TranslatedText>
                  </button>
                </Link>
                <button
                  onClick={handleLogout}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 border border-white/30 rounded-full text-white text-sm font-semibold backdrop-blur-sm transition-all"
                >
                  <LogOut className="w-4 h-4" />
                  <TranslatedText>Logout</TranslatedText>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main content */}
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Left column */}
          <div className="lg:col-span-2 space-y-6">

            {/* Recent Work */}
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
              <div className="flex items-center gap-3 px-6 py-4 border-b border-gray-100">
                <div className="w-9 h-9 bg-indigo-100 rounded-xl flex items-center justify-center">
                  <Clock className="w-5 h-5 text-indigo-600" />
                </div>
                <h2 className="text-base font-bold text-gray-900"><TranslatedText>Recent Work</TranslatedText></h2>
              </div>
              <div className="p-6">
                {loadingRecentRole ? (
                  <div className="flex items-center justify-center py-8">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
                  </div>
                ) : recentJobRole ? (
                  <Link to={`/role/${recentJobRole.roleId}`}>
                    <div className="flex items-center justify-between p-4 rounded-xl bg-gradient-to-r from-indigo-50 to-purple-50 border border-indigo-200 hover:border-indigo-400 hover:shadow-md transition-all group cursor-pointer">
                      <div className="flex items-center gap-4">
                        <div className="w-11 h-11 gradient-primary rounded-xl flex items-center justify-center flex-shrink-0">
                          <BarChart3 className="w-5 h-5 text-white" />
                        </div>
                        <div>
                          <p className="text-xs text-indigo-500 font-semibold uppercase tracking-wide mb-0.5"><TranslatedText>Generated Career Analysis</TranslatedText></p>
                          <p className="font-bold text-gray-900"><TranslatedText>{recentJobRole.roleTitle}</TranslatedText></p>
                          <div className="flex items-center gap-4 mt-1">
                            <div className="flex items-center gap-1 text-xs text-gray-500">
                              <Calendar className="w-3 h-3" />
                              <span>{new Date(recentJobRole.createdAt).toLocaleDateString()}</span>
                            </div>
                            <div className="flex items-center gap-1 text-xs text-emerald-600">
                              <TrendingUp className="w-3 h-3" />
                              <span>{recentJobRole.sectionsCount} sections completed</span>
                            </div>
                          </div>
                          <p className="text-xs text-gray-500 mt-1"><TranslatedText>Click to view complete career dashboard</TranslatedText> →</p>
                        </div>
                      </div>
                      <ArrowRight className="w-5 h-5 text-indigo-400 group-hover:translate-x-1 transition-transform flex-shrink-0" />
                    </div>
                  </Link>
                ) : lastRole ? (
                  <Link to={`/role/${lastRole.roleId}`}>
                    <div className="flex items-center justify-between p-4 rounded-xl bg-gradient-to-r from-gray-50 to-gray-100 border border-gray-200 hover:border-gray-300 hover:shadow-md transition-all group cursor-pointer">
                      <div className="flex items-center gap-4">
                        <div className="w-11 h-11 bg-gray-400 rounded-xl flex items-center justify-center flex-shrink-0">
                          <Building className="w-5 h-5 text-white" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500 font-semibold uppercase tracking-wide mb-0.5"><TranslatedText>Last Viewed Role</TranslatedText></p>
                          <p className="font-bold text-gray-900"><TranslatedText>{lastRole.roleTitle}</TranslatedText></p>
                          <p className="text-xs text-gray-500 mt-0.5"><TranslatedText>No saved analysis - click to generate</TranslatedText> →</p>
                        </div>
                      </div>
                      <ArrowRight className="w-5 h-5 text-gray-400 group-hover:translate-x-1 transition-transform flex-shrink-0" />
                    </div>
                  </Link>
                ) : (
                  <div className="text-center py-8">
                    <div className="w-14 h-14 bg-gray-100 rounded-2xl flex items-center justify-center mx-auto mb-3">
                      <Clock className="w-7 h-7 text-gray-400" />
                    </div>
                    <p className="text-gray-500 text-sm mb-4"><TranslatedText>No recent activity yet. Take the assessment to get started.</TranslatedText></p>
                    <Link to="/onboarding-new">
                      <Button size="sm" className="gradient-primary hover:opacity-90">
                        <TranslatedText>Start Assessment</TranslatedText>
                        <ArrowRight className="w-4 h-4 ml-2" />
                      </Button>
                    </Link>
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
              <div className="flex items-center gap-3 px-6 py-4 border-b border-gray-100">
                <div className="w-9 h-9 bg-purple-100 rounded-xl flex items-center justify-center">
                  <Sparkles className="w-5 h-5 text-purple-600" />
                </div>
                <h2 className="text-base font-bold text-gray-900"><TranslatedText>Quick Actions</TranslatedText></h2>
              </div>
              <div className="p-6 grid grid-cols-1 sm:grid-cols-2 gap-3">
                <Link to="/onboarding-new">
                  <div className="flex items-center gap-3 p-4 rounded-xl border-2 border-indigo-100 bg-indigo-50 hover:border-indigo-300 hover:shadow-sm transition-all group cursor-pointer">
                    <span className="text-2xl">🎯</span>
                    <div>
                      <p className="font-semibold text-gray-900 text-sm"><TranslatedText>New Assessment</TranslatedText></p>
                      <p className="text-xs text-gray-500"><TranslatedText>Retake to refresh results</TranslatedText></p>
                    </div>
                    <ArrowRight className="w-4 h-4 text-indigo-400 ml-auto group-hover:translate-x-0.5 transition-transform" />
                  </div>
                </Link>
                <Link to={hasRecommendations ? '/recommendations' : '/onboarding-new'}>
                  <div className="flex items-center gap-3 p-4 rounded-xl border-2 border-purple-100 bg-purple-50 hover:border-purple-300 hover:shadow-sm transition-all group cursor-pointer">
                    <span className="text-2xl">✨</span>
                    <div>
                      <p className="font-semibold text-gray-900 text-sm"><TranslatedText>My Recommendations</TranslatedText></p>
                      <p className="text-xs text-gray-500">
                        {hasRecommendations ? <TranslatedText>View your career matches</TranslatedText> : <TranslatedText>Complete assessment first</TranslatedText>}
                      </p>
                    </div>
                    <ArrowRight className="w-4 h-4 text-purple-400 ml-auto group-hover:translate-x-0.5 transition-transform" />
                  </div>
                </Link>
              </div>
            </div>

          </div>

          {/* Right column */}
          <div className="space-y-6">

            {/* Upgrade Card */}
            <div className="bg-gradient-to-br from-indigo-600 via-purple-600 to-purple-700 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
              <div className="absolute -top-6 -right-6 w-24 h-24 bg-white/10 rounded-full" />
              <div className="absolute -bottom-4 -left-4 w-16 h-16 bg-white/10 rounded-full" />
              <div className="relative">
                <div className="flex items-center gap-2 mb-1">
                  <Zap className="w-5 h-5 text-yellow-300" />
                  <span className="text-xs font-bold uppercase tracking-widest text-indigo-200"><TranslatedText>Pro Plan</TranslatedText></span>
                </div>
                <h2 className="text-xl font-bold mb-1"><TranslatedText>Upgrade to Pro</TranslatedText></h2>
                <p className="text-indigo-200 text-xs mb-4 leading-relaxed">
                  <TranslatedText>Unlock the full power of AI career guidance.</TranslatedText>
                </p>
                <div className="space-y-2 mb-5">
                  {proFeatures.map((f) => (
                    <div key={f.label} className="flex items-center gap-2 text-sm text-indigo-100">
                      <span className="text-base">{f.icon}</span>
                      <span><TranslatedText>{f.label}</TranslatedText></span>
                    </div>
                  ))}
                </div>
                <div className="flex items-baseline gap-1 mb-4">
                  <span className="text-4xl font-bold">₹499</span>
                  <span className="text-indigo-300 text-sm">/month</span>
                </div>
                <Button className="w-full bg-white text-indigo-700 hover:bg-indigo-50 font-bold shadow-md flex items-center justify-center gap-2">
                  <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                  <TranslatedText>Upgrade Now</TranslatedText>
                </Button>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}
