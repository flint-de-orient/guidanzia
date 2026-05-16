import { createBrowserRouter } from 'react-router';
import { Landing } from './pages/landing';
import { Login } from './pages/login';
import { Signup } from './pages/signup';
import { Onboarding } from './pages/onboarding';
import { RecommendationsDashboard } from './pages/recommendations-dashboard';
import { JobRoleDetail } from './pages/job-role-detail-new';
import { CareerReport } from './pages/career-report';
import { Profile } from './pages/profile';
import { Settings } from './pages/settings';
import { NotFound } from './pages/not-found';
import { PageTransition } from './components/page-transition';
import { ScrollRestoration } from './components/scroll-restoration';

export const router = createBrowserRouter(
  [
    {
      path: '/',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Landing />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/login',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Login />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/signup',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Signup />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/onboarding',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Onboarding />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/recommendations',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <RecommendationsDashboard />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/role/:roleId',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <JobRoleDetail />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/career-report/:roleId',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <CareerReport />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/profile',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Profile />
          </PageTransition>
        </>
      ),
    },
    {
      path: '/settings',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <Settings />
          </PageTransition>
        </>
      ),
    },
    {
      path: '*',
      element: (
        <>
          <ScrollRestoration />
          <PageTransition>
            <NotFound />
          </PageTransition>
        </>
      ),
    },
  ],
  {
    future: {
      v7_startTransition: true,
      v7_relativeSplatPath: true,
    },
  }
);