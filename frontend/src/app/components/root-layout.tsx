import { ReactNode } from 'react';
import { ScrollRestoration } from './scroll-restoration';
import { PageTransition } from './page-transition';

interface RootLayoutProps {
  children: ReactNode;
}

/**
 * Root layout component that wraps all routes and provides global functionality
 */
export function RootLayout({ children }: RootLayoutProps) {
  return (
    <>
      <ScrollRestoration />
      <PageTransition>
        {children}
      </PageTransition>
    </>
  );
}