import { RouterProvider } from 'react-router';
import { router } from './routes';
import { ScrollToTop } from './components/scroll-to-top';
import { AuthProvider } from './contexts/AuthContext';

export default function App() {
  return (
    <AuthProvider>
      <RouterProvider router={router} />
      <ScrollToTop />
    </AuthProvider>
  );
}