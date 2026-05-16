import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Alert, AlertDescription } from '../components/ui/alert';
import { Brain, Eye, EyeOff, Loader2, CheckCircle2 } from 'lucide-react';
import { TranslatedText } from '../components/TranslatedText';

export function Signup() {
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    password: '',
    confirmPassword: '',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    // Validation
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match');
      setLoading(false);
      return;
    }

    if (formData.password.length < 6) {
      setError('Password must be at least 6 characters long');
      setLoading(false);
      return;
    }

    try {
      const res = await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/signup`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            username: formData.username,
            password: formData.password,
            name: formData.name,
          }),
        }
      );
      const response = await res.json();

      if (response.success) {
        setSuccess(true);
        setTimeout(() => {
          navigate('/login');
        }, 2000);
      } else {
        setError(response.message || 'Signup failed');
      }
    } catch (err) {
      setError('Unable to reach server. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    if (error) setError('');
  };

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-50 via-white to-teal-50 px-4">
        <Card className="w-full max-w-md border-0 shadow-xl">
          <CardContent className="pt-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-8 h-8 text-green-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                <TranslatedText>Account Created Successfully!</TranslatedText>
              </h2>
              <p className="text-gray-600 mb-4">
                <TranslatedText>Welcome to EduBot! You can now sign in to start your career journey.</TranslatedText>
              </p>
              <p className="text-sm text-gray-500">
                <TranslatedText>Redirecting to login page...</TranslatedText>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-50 via-white to-teal-50 px-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-2 mb-4">
            <div className="w-12 h-12 gradient-primary rounded-xl flex items-center justify-center">
              <Brain className="w-7 h-7 text-white" />
            </div>
            <span className="text-3xl font-bold text-gray-900">EduBot</span>
          </div>
          <p className="text-gray-600">
            <TranslatedText>Start your AI-powered career journey</TranslatedText>
          </p>
        </div>

        <Card className="border-0 shadow-xl">
          <CardHeader className="text-center pb-4">
            <CardTitle className="text-2xl font-bold text-gray-900">
              <TranslatedText>Create Account</TranslatedText>
            </CardTitle>
            <CardDescription>
              <TranslatedText>Join thousands of students discovering their perfect career path</TranslatedText>
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <Alert variant="destructive">
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}

              <div className="space-y-2">
                <Label htmlFor="name">
                  <TranslatedText>Full Name</TranslatedText>
                </Label>
                <Input
                  id="name"
                  name="name"
                  type="text"
                  value={formData.name}
                  onChange={handleChange}
                  placeholder="Enter your full name"
                  required
                  disabled={loading}
                  className="h-12"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="username">
                  <TranslatedText>Email Address</TranslatedText>
                </Label>
                <Input
                  id="username"
                  name="username"
                  type="email"
                  value={formData.username}
                  onChange={handleChange}
                  placeholder="Enter your email address"
                  required
                  disabled={loading}
                  className="h-12"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">
                  <TranslatedText>Password</TranslatedText>
                </Label>
                <div className="relative">
                  <Input
                    id="password"
                    name="password"
                    type={showPassword ? 'text' : 'password'}
                    value={formData.password}
                    onChange={handleChange}
                    placeholder="Create a strong password"
                    required
                    disabled={loading}
                    className="h-12 pr-12"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
                    disabled={loading}
                  >
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                <p className="text-xs text-gray-500">
                  <TranslatedText>Password must be at least 6 characters long</TranslatedText>
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="confirmPassword">
                  <TranslatedText>Confirm Password</TranslatedText>
                </Label>
                <div className="relative">
                  <Input
                    id="confirmPassword"
                    name="confirmPassword"
                    type={showConfirmPassword ? 'text' : 'password'}
                    value={formData.confirmPassword}
                    onChange={handleChange}
                    placeholder="Confirm your password"
                    required
                    disabled={loading}
                    className="h-12 pr-12"
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
                    disabled={loading}
                  >
                    {showConfirmPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
              </div>

              <Button
                type="submit"
                className="w-full h-12 gradient-primary hover:opacity-90 transition-opacity text-lg font-semibold"
                disabled={loading || !formData.name || !formData.username || !formData.password || !formData.confirmPassword}
              >
                {loading ? (
                  <>
                    <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                    <TranslatedText>Creating Account...</TranslatedText>
                  </>
                ) : (
                  <TranslatedText>Create Account</TranslatedText>
                )}
              </Button>
            </form>

            <div className="mt-6 text-center">
              <p className="text-gray-600">
                <TranslatedText>Already have an account?</TranslatedText>{' '}
                <Link
                  to="/login"
                  className="text-indigo-600 hover:text-indigo-700 font-semibold transition-colors"
                >
                  <TranslatedText>Sign in</TranslatedText>
                </Link>
              </p>
            </div>

            <div className="mt-4 text-center">
              <Link
                to="/"
                className="text-sm text-gray-500 hover:text-gray-700 transition-colors"
              >
                <TranslatedText>← Back to Home</TranslatedText>
              </Link>
            </div>
          </CardContent>
        </Card>

        {/* Terms */}
        <div className="mt-6 text-center">
          <p className="text-xs text-gray-500">
            <TranslatedText>By creating an account, you agree to our</TranslatedText>{' '}
            <a href="#" className="text-indigo-600 hover:text-indigo-700">
              <TranslatedText>Terms of Service</TranslatedText>
            </a>{' '}
            <TranslatedText>and</TranslatedText>{' '}
            <a href="#" className="text-indigo-600 hover:text-indigo-700">
              <TranslatedText>Privacy Policy</TranslatedText>
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}