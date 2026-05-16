import { Link } from 'react-router';
import { Button } from './ui/button';
import { Brain, Home } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { LanguageSwitcher } from './LanguageSwitcher';

interface NavbarProps {
  showHomeButton?: boolean;
}

export function Navbar({ showHomeButton = false }: NavbarProps) {
  const { user, isAuthenticated } = useAuth();

  return (
    <nav className="border-b border-gray-200 bg-white/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-10 h-10 gradient-primary rounded-xl flex items-center justify-center">
              <Brain className="w-6 h-6 text-white" />
            </div>
            <span className="text-2xl font-bold text-gradient-primary">EduBot</span>
          </Link>

          <div className="flex items-center gap-4">
            <LanguageSwitcher />
            {isAuthenticated && user ? (
              <>
                {showHomeButton && (
                  <Link to="/">
                    <Button variant="ghost" size="sm" className="flex items-center gap-2 text-gray-600">
                      <Home className="w-4 h-4" />
                      <span className="hidden sm:inline">Back to Home</span>
                    </Button>
                  </Link>
                )}
                <Link to="/profile">
                  <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-indigo-200 hover:border-indigo-400 bg-indigo-50 hover:bg-indigo-100 transition-all cursor-pointer">
                    <div className="w-7 h-7 gradient-primary rounded-full flex items-center justify-center">
                      <span className="text-xs font-bold text-white">
                        {(user.name || user.email).split(' ').map((w: string) => w[0]).join('').toUpperCase().slice(0, 2)}
                      </span>
                    </div>
                    <span className="text-sm font-semibold text-indigo-700 hidden sm:block">{user.name || user.email}</span>
                  </div>
                </Link>
              </>
            ) : (
              <>
                <Link to="/login">
                  <Button variant="ghost">Login</Button>
                </Link>
                <Link to="/signup">
                  <Button className="gradient-primary hover:opacity-90 transition-opacity">
                    Get Started
                  </Button>
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}
