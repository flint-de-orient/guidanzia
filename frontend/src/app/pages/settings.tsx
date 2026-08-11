import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { ArrowLeft, User, Lock, Image, Save, Loader2, CheckCircle2 } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

const getUserInfo = () => {
  try {
    const raw = localStorage.getItem('edubot_user');
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
};

export function Settings() {
  const navigate = useNavigate();
  const [user, setUser] = useState<{ name: string; email: string; profileImage?: string } | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
    profileImage: ''
  });
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    const info = getUserInfo();
    if (!info) { 
      navigate('/login'); 
      return; 
    }
    setUser(info);
    setFormData(prev => ({ ...prev, name: info.name, profileImage: info.profileImage || '' }));
  }, [navigate]);

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage(null);

    try {
      // Validate password change if attempted
      if (formData.newPassword) {
        if (formData.newPassword !== formData.confirmPassword) {
          setMessage({ type: 'error', text: 'New passwords do not match' });
          setLoading(false);
          return;
        }
        if (
          formData.newPassword.length < 8 ||
          !/[a-zA-Z]/.test(formData.newPassword) ||
          !/[0-9]/.test(formData.newPassword)
        ) {
          setMessage({
            type: 'error',
            text: 'Password must be at least 8 characters and include both letters and numbers.',
          });
          setLoading(false);
          return;
        }
      }

      const response = await fetch(`${API_BASE}/api/update-profile`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: user?.email,
          name: formData.name,
          currentPassword: formData.currentPassword || undefined,
          newPassword: formData.newPassword || undefined,
          profileImage: formData.profileImage || undefined
        })
      });

      const data = await response.json();

      if (data.success) {
        // Update local storage
        const updatedUser = {
          ...user!,
          name: formData.name,
          profileImage: formData.profileImage
        };
        localStorage.setItem('edubot_user', JSON.stringify(updatedUser));
        setUser(updatedUser);
        
        setMessage({ type: 'success', text: 'Profile updated successfully!' });
        
        // Clear password fields
        setFormData(prev => ({
          ...prev,
          currentPassword: '',
          newPassword: '',
          confirmPassword: ''
        }));
      } else {
        setMessage({ type: 'error', text: data.message || 'Failed to update profile' });
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error. Please try again.' });
    } finally {
      setLoading(false);
    }
  };

  if (!user) return null;

  const initials = user.name
    .split(' ')
    .map((w: string) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar showHomeButton />

      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-6">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => navigate('/profile')}
            className="mb-4"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            <TranslatedText>Back to Profile</TranslatedText>
          </Button>
          <h1 className="text-3xl font-bold text-gray-900">
            <TranslatedText>Account Settings</TranslatedText>
          </h1>
          <p className="text-gray-600 mt-2">
            <TranslatedText>Manage your account information and preferences</TranslatedText>
          </p>
        </div>

        {/* Settings Form */}
        <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <form onSubmit={handleUpdateProfile}>
            {/* Profile Image Section */}
            <div className="p-6 border-b border-gray-100">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-9 h-9 bg-indigo-100 rounded-xl flex items-center justify-center">
                  <Image className="w-5 h-5 text-indigo-600" />
                </div>
                <h2 className="text-lg font-bold text-gray-900">
                  <TranslatedText>Profile Picture</TranslatedText>
                </h2>
              </div>
              
              <div className="flex items-center gap-6">
                <div className="w-20 h-20 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-2xl flex items-center justify-center border-4 border-indigo-100">
                  {formData.profileImage ? (
                    <img 
                      src={formData.profileImage} 
                      alt="Profile" 
                      className="w-full h-full rounded-xl object-cover"
                    />
                  ) : (
                    <span className="text-2xl font-bold text-white">{initials}</span>
                  )}
                </div>
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <TranslatedText>Image URL</TranslatedText>
                  </label>
                  <input
                    type="url"
                    value={formData.profileImage}
                    onChange={(e) => setFormData({ ...formData, profileImage: e.target.value })}
                    placeholder="https://example.com/image.jpg"
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    <TranslatedText>Enter a URL to your profile image</TranslatedText>
                  </p>
                </div>
              </div>
            </div>

            {/* Name Section */}
            <div className="p-6 border-b border-gray-100">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-9 h-9 bg-purple-100 rounded-xl flex items-center justify-center">
                  <User className="w-5 h-5 text-purple-600" />
                </div>
                <h2 className="text-lg font-bold text-gray-900">
                  <TranslatedText>Display Name</TranslatedText>
                </h2>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <TranslatedText>Full Name</TranslatedText>
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  required
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                />
              </div>
            </div>

            {/* Password Section */}
            <div className="p-6 border-b border-gray-100">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-9 h-9 bg-emerald-100 rounded-xl flex items-center justify-center">
                  <Lock className="w-5 h-5 text-emerald-600" />
                </div>
                <h2 className="text-lg font-bold text-gray-900">
                  <TranslatedText>Change Password</TranslatedText>
                </h2>
              </div>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <TranslatedText>Current Password</TranslatedText>
                  </label>
                  <input
                    type="password"
                    value={formData.currentPassword}
                    onChange={(e) => setFormData({ ...formData, currentPassword: e.target.value })}
                    placeholder="Enter current password to change"
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <TranslatedText>New Password</TranslatedText>
                  </label>
                  <input
                    type="password"
                    value={formData.newPassword}
                    onChange={(e) => setFormData({ ...formData, newPassword: e.target.value })}
                    placeholder="Enter new password"
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <TranslatedText>Confirm New Password</TranslatedText>
                  </label>
                  <input
                    type="password"
                    value={formData.confirmPassword}
                    onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                    placeholder="Confirm new password"
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>
                
                <p className="text-xs text-gray-500">
                  <TranslatedText>Leave password fields empty if you don't want to change your password</TranslatedText>
                </p>
              </div>
            </div>

            {/* Message */}
            {message && (
              <div className={`mx-6 mt-6 p-4 rounded-lg ${
                message.type === 'success' 
                  ? 'bg-emerald-50 border border-emerald-200' 
                  : 'bg-red-50 border border-red-200'
              }`}>
                <div className="flex items-center gap-2">
                  {message.type === 'success' ? (
                    <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                  ) : (
                    <span className="text-red-600">⚠️</span>
                  )}
                  <p className={`text-sm font-medium ${
                    message.type === 'success' ? 'text-emerald-800' : 'text-red-800'
                  }`}>
                    <TranslatedText>{message.text}</TranslatedText>
                  </p>
                </div>
              </div>
            )}

            {/* Save Button */}
            <div className="p-6">
              <Button
                type="submit"
                disabled={loading}
                className="w-full gradient-primary hover:opacity-90 flex items-center justify-center gap-2"
              >
                {loading ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    <TranslatedText>Saving...</TranslatedText>
                  </>
                ) : (
                  <>
                    <Save className="w-5 h-5" />
                    <TranslatedText>Save Changes</TranslatedText>
                  </>
                )}
              </Button>
            </div>
          </form>
        </div>

        {/* Account Info */}
        <div className="mt-6 bg-gray-100 rounded-xl p-4">
          <p className="text-sm text-gray-600">
            <span className="font-semibold"><TranslatedText>Email:</TranslatedText></span> {user.email}
          </p>
          <p className="text-xs text-gray-500 mt-2">
            <TranslatedText>Email cannot be changed. Contact support if you need to update your email address.</TranslatedText>
          </p>
        </div>
      </div>
    </div>
  );
}
