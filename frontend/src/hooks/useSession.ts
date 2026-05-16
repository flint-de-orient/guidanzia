import { useState, useEffect } from 'react';

interface User {
  email: string;
  name?: string;
  profileImage?: string;
}

interface LoginCredentials {
  username: string;
  password: string;
}

interface SessionData {
  user: User | null;
  isAuthenticated: boolean;
  loading: boolean;
  error: string | null;
  login: (user: User) => void;
  loginUser: (credentials: LoginCredentials) => Promise<{ success: boolean; message?: string }>;
  logout: () => void;
  clearError: () => void;
}

export function useSession(): SessionData {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Check for stored user data on mount
    const initializeSession = async () => {
      try {
        const storedUser = localStorage.getItem('edubot_user');
        if (storedUser) {
          const userData = JSON.parse(storedUser);
          setUser(userData);
          
          // Restore career data from localStorage to sessionStorage if sessionStorage is empty
          if (!sessionStorage.getItem('careerRecommendations')) {
            const storedRecommendations = localStorage.getItem('careerRecommendations');
            if (storedRecommendations) {
              sessionStorage.setItem('careerRecommendations', storedRecommendations);
            } else {
              // If no local data, try to fetch from database
              await fetchUserSessionData(userData.email);
            }
          }
          
          if (!sessionStorage.getItem('userProfile')) {
            const storedProfile = localStorage.getItem('userProfile');
            if (storedProfile) {
              sessionStorage.setItem('userProfile', storedProfile);
            }
          }
        }
      } catch (error) {
        console.error('Error loading user session:', error);
      } finally {
        setLoading(false);
      }
    };
    
    initializeSession();
  }, []);

  // Fetch user session data from database
  const fetchUserSessionData = async (username: string) => {
    try {
      const response = await fetch('http://localhost:8080/api/get-user-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      
      const result = await response.json();
      if (result.success && result.session) {
        // Restore recommendations if available
        if (result.session.recommendations) {
          sessionStorage.setItem('careerRecommendations', JSON.stringify(result.session.recommendations));
          localStorage.setItem('careerRecommendations', JSON.stringify(result.session.recommendations));
        }
        
        // Restore user profile if available
        if (result.session.userProfile) {
          sessionStorage.setItem('userProfile', JSON.stringify(result.session.userProfile));
          localStorage.setItem('userProfile', JSON.stringify(result.session.userProfile));
        }
        
        // Restore last role if available
        if (result.session.lastRole) {
          localStorage.setItem('edubot_last_role', JSON.stringify(result.session.lastRole));
        }
      }
    } catch (error) {
      console.error('Error fetching user session data:', error);
    }
  };

  const login = (userData: User) => {
    setUser(userData);
    localStorage.setItem('edubot_user', JSON.stringify(userData));
  };

  const loginUser = async (credentials: LoginCredentials) => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch('http://localhost:8080/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(credentials),
      });
      
      const result = await response.json();
      
      if (result.success) {
        const userData = {
          email: credentials.username,
          name: result.session?.name || credentials.username,
          profileImage: result.session?.profileImage
        };
        
        login(userData);
        
        // Store session data if available
        if (result.session) {
          if (result.session.recommendations) {
            sessionStorage.setItem('careerRecommendations', JSON.stringify(result.session.recommendations));
            // Also store in localStorage for persistence across sessions
            localStorage.setItem('careerRecommendations', JSON.stringify(result.session.recommendations));
          }
          if (result.session.userProfile) {
            sessionStorage.setItem('userProfile', JSON.stringify(result.session.userProfile));
            localStorage.setItem('userProfile', JSON.stringify(result.session.userProfile));
          }
          if (result.session.lastRole) {
            localStorage.setItem('edubot_last_role', JSON.stringify(result.session.lastRole));
          }
          // Store job role details in sessionStorage for immediate access
          if (result.session.jobRoleDetails) {
            Object.entries(result.session.jobRoleDetails).forEach(([roleId, details]) => {
              sessionStorage.setItem(`jobDetail_${roleId}`, JSON.stringify(details));
            });
          }
        }
        
        return { success: true };
      } else {
        setError(result.message || 'Login failed');
        return { success: false, message: result.message };
      }
    } catch (error) {
      console.error('Login error:', error);
      setError('Network error. Please try again.');
      return { success: false, message: 'Network error. Please try again.' };
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    const currentUser = user;
    
    // Call backend logout API if user exists
    if (currentUser?.email) {
      try {
        await fetch('http://localhost:8080/logout', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ username: currentUser.email }),
        });
      } catch (error) {
        console.error('Logout API error:', error);
        // Continue with local logout even if API fails
      }
    }
    
    // Clear all local data
    setUser(null);
    localStorage.removeItem('edubot_user');
    localStorage.removeItem('edubot_last_role');
    localStorage.removeItem('lastRole');
    localStorage.removeItem('careerRecommendations');
    localStorage.removeItem('userProfile');
    sessionStorage.clear();
    
    // Force page refresh and redirect to home
    window.location.href = '/';
  };

  const clearError = () => {
    setError(null);
  };

  return {
    user,
    isAuthenticated: !!user,
    loading,
    error,
    login,
    loginUser,
    logout,
    clearError,
  };
}