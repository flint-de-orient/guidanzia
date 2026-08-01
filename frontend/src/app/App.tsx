import { RouterProvider } from 'react-router';
import { router } from './routes';
import { ScrollToTop } from './components/scroll-to-top';
import { AuthProvider } from './contexts/AuthContext';
import { ThemeProvider } from './contexts/ThemeContext';

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <RouterProvider router={router} />
        <ScrollToTop />
      </AuthProvider>
    </ThemeProvider>
  );
}
