import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Brain } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { TranslatedText } from '../components/TranslatedText';

export function Signup() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/signup`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: email, password }),
        }
      );
      const data = await res.json();
      if (data.success) {
        login({ email, name: name || email.split('@')[0] });
        navigate('/onboarding-new');
      } else {
        setError(data.message || 'Signup failed');
      }
    } catch {
      setError('Unable to reach server. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen abstract-bg flex">
      {/* Left Panel - Illustration */}
      <div className="hidden lg:flex lg:w-1/2 gradient-primary p-12 items-center justify-center relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-20 left-20 w-64 h-64 bg-white rounded-full blur-3xl"></div>
          <div className="absolute bottom-20 right-20 w-96 h-96 bg-white rounded-full blur-3xl"></div>
        </div>
        <div className="relative z-10 text-white max-w-md">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-12 h-12 bg-white/20 backdrop-blur-sm rounded-xl flex items-center justify-center">
              <Brain className="w-7 h-7 text-white" />
            </div>
            <span className="text-3xl font-bold">EduBot</span>
          </div>
          <h2 className="text-4xl font-bold mb-4"><TranslatedText>Start Your Journey</TranslatedText></h2>
          <p className="text-xl text-purple-100 mb-8">
            <TranslatedText>Join thousands of students discovering their perfect career path with AI-powered guidance.</TranslatedText>
          </p>
          <div className="space-y-4">
            <div className="flex items-start gap-3">
              <div className="w-6 h-6 bg-white/20 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-sm">✓</span>
              </div>
              <p className="text-purple-100"><TranslatedText>Free AI-powered career assessment</TranslatedText></p>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-6 h-6 bg-white/20 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-sm">✓</span>
              </div>
              <p className="text-purple-100"><TranslatedText>Personalized learning roadmaps</TranslatedText></p>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-6 h-6 bg-white/20 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-sm">✓</span>
              </div>
              <p className="text-purple-100"><TranslatedText>Access to career resources and insights</TranslatedText></p>
            </div>
          </div>
        </div>
      </div>

      {/* Right Panel - Signup Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8">
        <div className="w-full max-w-md">
          <div className="lg:hidden mb-8">
            <Link to="/" className="flex items-center gap-2 justify-center">
              <div className="w-10 h-10 gradient-primary rounded-xl flex items-center justify-center">
                <Brain className="w-6 h-6 text-white" />
              </div>
              <span className="text-2xl font-bold bg-gradient-to-r from-indigo-600 via-purple-600 to-teal-500 bg-clip-text text-transparent">
                EduBot
              </span>
            </Link>
          </div>

          <div className="bg-white rounded-2xl border border-gray-200 shadow-xl p-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-2"><TranslatedText>Create Account</TranslatedText></h1>
            <p className="text-gray-600 mb-8"><TranslatedText>Start your career discovery journey</TranslatedText></p>

            <form onSubmit={handleSignup} className="space-y-6">
              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm">
                  {error}
                </div>
              )}
              <div className="space-y-2">
                <Label htmlFor="name"><TranslatedText>Full Name</TranslatedText></Label>
                <Input
                  id="name"
                  type="text"
                  placeholder="John Doe"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  className="h-12"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="email"><TranslatedText>Email Address</TranslatedText></Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="h-12"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password"><TranslatedText>Password</TranslatedText></Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="h-12"
                />
                <p className="text-xs text-gray-500">
                  <TranslatedText>Must be at least 8 characters with numbers and letters</TranslatedText>
                </p>
              </div>

              <Button
                type="submit"
                disabled={loading}
                className="w-full h-12 gradient-primary hover:opacity-90 transition-opacity text-base disabled:opacity-60"
              >
                <TranslatedText>{loading ? 'Creating Account...' : 'Create Account'}</TranslatedText>
              </Button>

              <div className="relative">
                <div className="absolute inset-0 flex items-center">
                  <span className="w-full border-t border-gray-300" />
                </div>
                <div className="relative flex justify-center text-sm">
                  <span className="px-2 bg-white text-gray-500"><TranslatedText>Or continue with</TranslatedText></span>
                </div>
              </div>

              <Button
                type="button"
                variant="outline"
                className="w-full h-12"
                onClick={() => navigate('/onboarding-new')}
              >
                <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24">
                  <path
                    fill="currentColor"
                    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                  />
                  <path
                    fill="currentColor"
                    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  />
                  <path
                    fill="currentColor"
                    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  />
                  <path
                    fill="currentColor"
                    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  />
                </svg>
                Google
              </Button>
            </form>

            <p className="mt-8 text-center text-gray-600">
              <TranslatedText>Already have an account?</TranslatedText>{' '}
              <Link to="/login" className="text-purple-600 hover:text-purple-700 font-semibold">
                <TranslatedText>Sign In</TranslatedText>
              </Link>
            </p>
            
            <p className="mt-4 text-center text-xs text-gray-500">
              <TranslatedText>By signing up, you agree to our</TranslatedText>{' '}
              <a href="#" className="text-purple-600 hover:text-purple-700">
                <TranslatedText>Terms of Service</TranslatedText>
              </a>{' '}
              <TranslatedText>and</TranslatedText>{' '}
              <a href="#" className="text-purple-600 hover:text-purple-700">
                <TranslatedText>Privacy Policy</TranslatedText>
              </a>
            </p>
          </div>

          <p className="mt-6 text-center text-sm text-gray-500">
            <Link to="/" className="hover:text-gray-700">
              <TranslatedText>← Back to Home</TranslatedText>
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}