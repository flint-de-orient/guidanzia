import React, { createContext, useContext } from 'react';
import { useSession } from '../../hooks/useSession';

interface AuthContextType {
  user: any;
  isAuthenticated: boolean;
  loading: boolean;
  error: string | null;
  login: (user: any) => void;
  loginUser: (credentials: { username: string; password: string }) => Promise<{ success: boolean; message?: string }>;
  logout: () => void;
  clearError: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const session = useSession();

  return (
    <AuthContext.Provider value={session}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

// Higher-order component for protected routes
export function withAuth(Component: React.ComponentType<any>) {
  return function AuthenticatedComponent(props: any) {
    const { isAuthenticated, loading } = useAuth();

    if (loading) {
      return (
        <div className="min-h-screen flex items-center justify-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-indigo-600"></div>
        </div>
      );
    }

    if (!isAuthenticated) {
      // Redirect to login or show login form
      window.location.href = '/login';
      return null;
    }

    return <Component {...props} />;
  };
}