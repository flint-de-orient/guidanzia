import { motion } from 'motion/react';
import { ReactNode, useEffect } from 'react';
import { useLocation } from 'react-router';

interface PageTransitionProps {
  children: ReactNode;
}

export function PageTransition({ children }: PageTransitionProps) {
  const location = useLocation();

  useEffect(() => {
    // Force immediate scroll to top when route changes
    // Using both methods to ensure compatibility
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    document.documentElement.scrollTop = 0;
    document.body.scrollTop = 0;
  }, [location.pathname, location.search, location.hash]); // Re-run when any part of location changes

  return (
    <motion.div
      key={location.pathname} // Force remount on path change
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{
        duration: 0.4,
        ease: 'easeOut',
      }}
    >
      {children}
    </motion.div>
  );
}