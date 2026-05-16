import { Link } from 'react-router';
import { Button } from '../components/ui/button';
import { Brain, Home, ArrowLeft, Search } from 'lucide-react';
import { TranslatedText } from '../components/TranslatedText';

export function NotFound() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-indigo-50/30 to-purple-50/30 flex items-center justify-center px-4">
      <div className="max-w-2xl w-full text-center">
        {/* Logo */}
        <Link to="/" className="inline-flex items-center gap-2 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
            <Brain className="w-7 h-7 text-white" />
          </div>
          <span className="text-2xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
            EduBot
          </span>
        </Link>

        {/* 404 Illustration */}
        <div className="mb-8">
          <div className="relative inline-block">
            <div className="text-9xl font-bold text-gray-200">404</div>
            <div className="absolute inset-0 flex items-center justify-center">
              <Search className="w-16 h-16 text-indigo-400" />
            </div>
          </div>
        </div>

        {/* Error Message */}
        <h1 className="text-3xl font-bold text-gray-900 mb-4"><TranslatedText>Page Not Found</TranslatedText></h1>
        <p className="text-lg text-gray-600 mb-8">
          <TranslatedText>Sorry, we couldn't find the page you're looking for. The URL might be incorrect or the page may have been moved.</TranslatedText>
        </p>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <Link to="/">
            <Button
              size="lg"
              className="bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
            >
              <Home className="w-5 h-5 mr-2" />
              <TranslatedText>Go to Home</TranslatedText>
            </Button>
          </Link>
          <Button
            size="lg"
            variant="outline"
            onClick={() => window.history.back()}
          >
            <ArrowLeft className="w-5 h-5 mr-2" />
            <TranslatedText>Go Back</TranslatedText>
          </Button>
        </div>

        {/* Helpful Links */}
        <div className="mt-12 pt-8 border-t border-gray-200">
          <p className="text-sm text-gray-600 mb-4"><TranslatedText>Looking for something specific?</TranslatedText></p>
          <div className="flex flex-wrap gap-3 justify-center">
            <Link to="/onboarding">
              <Button variant="ghost" size="sm" className="text-indigo-600 hover:text-indigo-700">
                <TranslatedText>Take Assessment</TranslatedText>
              </Button>
            </Link>
            <Link to="/recommendations">
              <Button variant="ghost" size="sm" className="text-indigo-600 hover:text-indigo-700">
                <TranslatedText>View Recommendations</TranslatedText>
              </Button>
            </Link>
            <Link to="/login">
              <Button variant="ghost" size="sm" className="text-indigo-600 hover:text-indigo-700">
                <TranslatedText>Login</TranslatedText>
              </Button>
            </Link>
            <Link to="/signup">
              <Button variant="ghost" size="sm" className="text-indigo-600 hover:text-indigo-700">
                <TranslatedText>Sign Up</TranslatedText>
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
