// Type definitions for career-related data structures

export interface JobRole {
  id: string;
  title: string;
  domainId: string;
  icon: string;
  matchPercentage: number;
  salaryRange: string;
  growthRate: string;
  description: string;
}

export interface CareerDomain {
  id: string;
  title: string;
  icon: string;
  salary: string;
  growth: string;
  summary: string;
  match: number;
  jobs: JobRole[];
}

export interface JobDetail {
  roleId: string;
  overview: {
    description: string;
    keyResponsibilities: string[];
    whySuitable: string[];
  };
  careerPathway: {
    currentLevel: string;
    steps: Array<{
      phase: string;
      duration: string;
      description: string;
    }>;
  };
  skillsLearning: {
    mustHave: Array<{
      skill: string;
      description: string;
      courseUrl: string;
      youtubeLink: string;
    }>;
    core: Array<{
      skill: string;
      description: string;
      courseUrl: string;
      youtubeLink: string;
    }>;
    bonus: Array<{
      skill: string;
      description: string;
      courseUrl: string;
      youtubeLink: string;
    }>;
  };
  roadmap90Days: {
    phase1: {
      learningGoals: string[];
      actionTasks: string[];
      progressIndicators: string[];
    };
    phase2: {
      learningGoals: string[];
      actionTasks: string[];
      progressIndicators: string[];
    };
    phase3: {
      learningGoals: string[];
      actionTasks: string[];
      progressIndicators: string[];
    };
  };
  topInstitutes: {
    government: Array<{
      name: string;
      location: string;
      department: string;
      rating: number;
      website: string;
    }>;
    private: Array<{
      name: string;
      location: string;
      department: string;
      rating: number;
      website: string;
    }>;
    distanceLearning: Array<{
      name: string;
      location: string;
      department: string;
      rating: number;
      website: string;
    }>;
    online: Array<{
      name: string;
      location: string;
      department: string;
      rating: number;
      website: string;
    }>;
  };
  feesInvestment: {
    totalRange: string;
    description: string;
    breakdown: Array<{
      phase: string;
      cost: string;
      details: string;
    }>;
  };
  scholarships: {
    governmentPrivate: Array<{
      name: string;
      amount: string;
      eligibility: string;
      website: string;
    }>;
    bankLoans: Array<{
      name: string;
      amount: string;
      interestRate: string;
      website: string;
    }>;
    governmentSchemes: Array<{
      name: string;
      benefits: string;
      eligibility: string;
      website: string;
    }>;
  };
  jobMarket: {
    demandLevel: number;
    successRate: number;
    hiringTrends: Array<{
      month: string;
      openings: number;
    }>;
    topCompanies: Array<{
      name: string;
      packageRange: string;
      locations: string[];
    }>;
    keyInsights: string[];
  };
  certifications: Array<{
    name: string;
    platform: string;
    provider: string;
    duration: string;
    cost: string;
    impact: string;
    link: string;
  }>;
  salaryGrowth: {
    progression: Array<{
      experience: string;
      role: string;
      salary: string;
    }>;
    cityComparison: Array<{
      city: string;
      salary: string;
    }>;
    salaryTips: string[];
  };
  industryExperts: Array<{
    name: string;
    designation: string;
    company: string;
    experience: string;
    advice: string;
  }>;
}