import { useEffect } from 'react';
import { useLocation } from 'react-router';

/**
 * ScrollRestoration component ensures the page scrolls to top on every route change.
 * This is a global component that should be rendered once in the app.
 */
export function ScrollRestoration() {
  const location = useLocation();

  useEffect(() => {
    // Execute scroll immediately and synchronously
    const scrollToTop = () => {
      // Try multiple methods to ensure scroll works across all browsers
      window.scrollTo(0, 0);
      window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
      document.documentElement.scrollTop = 0;
      document.body.scrollTop = 0;
    };

    // Execute immediately
    scrollToTop();

    // Also execute after a tiny delay to catch any delayed renders
    const timeoutId = setTimeout(scrollToTop, 0);

    return () => clearTimeout(timeoutId);
  }, [location.pathname, location.search, location.hash, location.key]);

  return null;
}
