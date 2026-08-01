import type { QuestionDef } from './questionTypes';

/**
 * The real 20 questions, bound to backend field keys and exact enum values.
 * Values mirror the label maps in career-report.tsx and the payload built by
 * saveAssessmentData() in onboarding-new.tsx. `subjectMarks` (id: 'subjectMarks')
 * is dynamic — its subjects come from the favouriteSubjects answer, so it has no
 * static options here and is rendered from runtime state.
 */
export const QUESTIONS: QuestionDef[] = [
  // ── Module 1 — Motivation ────────────────────────────────────────────────
  {
    id: 'whyHere', module: 1, type: 'single',
    prompt: 'What brings you here?',
    options: [
      { value: 'no-idea', label: 'No idea what to do after Class 12' },
      { value: 'validate', label: 'I have a plan and want to validate it' },
      { value: 'disagree', label: 'Family disagreement about my career' },
      { value: 'explore', label: 'I want to explore options before deciding' },
    ],
  },
  {
    id: 'fiveYearVision', module: 1, type: 'single',
    prompt: 'Five years from now, what does a good day look like?',
    options: [
      { value: 'conventional', label: 'Expert / specialist work', description: 'Uniform or lab coat' },
      { value: 'enterprising', label: 'Leadership and decision-making' },
      { value: 'artistic', label: 'Creating — design, writing, performance' },
      { value: 'entrepreneurial', label: 'Running my own venture' },
    ],
  },
  {
    id: 'careerThinking', module: 1, type: 'text', optional: true,
    prompt: 'Is there a career you are already thinking about?',
    helper: 'Optional — skip if nothing comes to mind.',
  },
  {
    id: 'careerRuledOut', module: 1, type: 'text', optional: true,
    prompt: 'Any career you have definitely ruled out?',
    helper: 'Optional — skip if nothing comes to mind.',
  },

  // ── Module 2 — Cognitive & work style ────────────────────────────────────
  {
    id: 'freeSunday', module: 2, type: 'single',
    prompt: 'A free Sunday — what are you most likely doing?',
    options: [
      { value: 'puzzle', label: 'Solving puzzles / strategy games' },
      { value: 'friends', label: 'Hanging out and meeting people' },
      { value: 'create', label: 'Making things — art, music, writing' },
      { value: 'build', label: 'Fixing or building with my hands' },
      { value: 'organize', label: 'Organising notes, room, life' },
      { value: 'read', label: 'Reading about how the world works' },
    ],
  },
  {
    id: 'groupRole', module: 2, type: 'single',
    prompt: 'In a group project, which role do you naturally take?',
    options: [
      { value: 'plan', label: 'Planner', description: 'Divides work and leads strategy' },
      { value: 'research', label: 'Researcher', description: 'Digs into the analysis' },
      { value: 'present', label: 'Presenter', description: 'Shapes the final output' },
      { value: 'motivate', label: 'Motivator', description: 'Keeps the team energised' },
      { value: 'execute', label: 'Executor', description: 'Builds and delivers' },
    ],
  },
  {
    id: 'jobBothers', module: 2, type: 'single',
    prompt: 'What would bother you most in a job?',
    options: [
      { value: 'repetitive', label: 'Repeating the same task every day' },
      { value: 'decisions', label: 'High-stakes decisions and blame' },
      { value: 'alone', label: 'Working alone without human contact' },
      { value: 'no-result', label: 'Not seeing a clear result of my work' },
      { value: 'strict-rules', label: 'Strict rules and procedures' },
    ],
  },

  // ── Module 3 — Academics ─────────────────────────────────────────────────
  {
    id: 'favoriteSubjects', module: 3, type: 'multi', maxSelect: 3, minSelect: 1,
    prompt: 'Which subjects do you enjoy most?',
    helper: 'Select up to 3',
    options: [
      { value: 'Mathematics', label: 'Mathematics' },
      { value: 'Physics', label: 'Physics' },
      { value: 'Chemistry', label: 'Chemistry' },
      { value: 'Biology', label: 'Biology' },
      { value: 'Computer Science', label: 'Computer Science' },
      { value: 'Economics', label: 'Economics' },
      { value: 'Accountancy', label: 'Accountancy' },
      { value: 'History', label: 'History' },
      { value: 'Geography', label: 'Geography' },
      { value: 'English', label: 'English' },
      { value: 'Political Science', label: 'Political Science' },
      { value: 'Art', label: 'Art' },
    ],
  },
  {
    id: 'difficultSubject', module: 3, type: 'single',
    prompt: 'Which subject do you find most difficult?',
    options: [
      { value: 'Mathematics', label: 'Mathematics' },
      { value: 'Physics', label: 'Physics' },
      { value: 'Chemistry', label: 'Chemistry' },
      { value: 'Biology', label: 'Biology' },
      { value: 'Computer Science', label: 'Computer Science' },
      { value: 'Economics', label: 'Economics' },
      { value: 'Accountancy', label: 'Accountancy' },
      { value: 'History', label: 'History' },
      { value: 'Geography', label: 'Geography' },
      { value: 'English', label: 'English' },
    ],
  },
  {
    id: 'subjectMarks', module: 3, type: 'marks',
    prompt: 'What are your typical scores in these subjects?',
    helper: 'Pick the closest band for each.',
  },
  {
    id: 'studyExperience', module: 3, type: 'single',
    prompt: 'When you study something you like, what happens?',
    options: [
      { value: 'flow', label: 'I lose track of time', description: 'Deep flow state' },
      { value: 'work', label: 'I do well but it still feels like work' },
      { value: 'class-only', label: 'I enjoy class but struggle to study alone' },
      { value: 'videos', label: 'I prefer videos and discussion over textbooks' },
    ],
  },

  // ── Module 4 — Life outside marks ────────────────────────────────────────
  {
    id: 'outsideActivities', module: 4, type: 'multi', maxSelect: 3, minSelect: 1,
    prompt: 'Outside of studies, where do you spend your energy?',
    helper: 'Select up to 3',
    options: [
      { value: 'sports', label: 'Sports' },
      { value: 'music', label: 'Music' },
      { value: 'gaming', label: 'Gaming' },
      { value: 'coding', label: 'Coding / tech' },
      { value: 'art-craft', label: 'Art & craft' },
      { value: 'debate', label: 'Debate / public speaking' },
      { value: 'volunteering', label: 'Volunteering' },
      { value: 'reading', label: 'Reading' },
      { value: 'business', label: 'Small business / hustle' },
    ],
  },
  {
    id: 'externalValidation', module: 4, type: 'single',
    prompt: 'Has anyone told you what you would be good at?',
    options: [
      { value: 'agree', label: 'Yes, and I agree with it' },
      { value: 'unsure', label: 'Yes, but I am unsure' },
      { value: 'disagree', label: 'Yes, but I do not want to do it' },
      { value: 'no', label: 'No one has said anything' },
    ],
  },
  {
    id: 'selfInitiated', module: 4, type: 'text', optional: true,
    prompt: 'Anything you started entirely on your own?',
    helper: 'Optional — a project, club, channel, anything.',
  },

  // ── Module 5 — Constraints & values ──────────────────────────────────────
  {
    id: 'studyLocation', module: 5, type: 'multi', minSelect: 1,
    prompt: 'Where are you open to studying?',
    helper: 'Select all that apply',
    options: [
      { value: 'home-city', label: 'My home city' },
      { value: 'home-state', label: 'Anywhere in my state' },
      { value: 'anywhere-india', label: 'Anywhere in India' },
      { value: 'abroad', label: 'Abroad' },
    ],
  },
  {
    id: 'familyBudget', module: 5, type: 'single',
    prompt: 'Has your family discussed a budget for your education?',
    options: [
      { value: 'clear-budget', label: 'Yes — a clear budget' },
      { value: 'depends', label: 'Yes — depends on the course' },
      { value: 'not-really', label: 'Not really discussed' },
      { value: 'no-money-factor', label: 'I would rather not factor money in' },
    ],
  },
  {
    id: 'careerValues', module: 5, type: 'ranking', maxSelect: 2, minSelect: 2,
    prompt: 'What matters most in your career?',
    helper: 'Select your top 2, in order',
    options: [
      { value: 'earning', label: 'Earning well' },
      { value: 'interest', label: 'Doing genuinely interesting work' },
      { value: 'family-pride', label: 'Family pride' },
      { value: 'stability', label: 'Stability and security' },
      { value: 'impact', label: 'Making a real impact' },
    ],
  },

  // ── Module 6 — Final calibration ─────────────────────────────────────────
  {
    id: 'planningStyle', module: 6, type: 'single',
    prompt: 'How do you like to approach something new?',
    options: [
      { value: 'clear-plan', label: 'Give me a clear plan and I follow it' },
      { value: 'options', label: 'Give me options, I figure it out as I go' },
      { value: 'others', label: 'I want to know what worked for others' },
      { value: 'try-things', label: 'I learn by trying things' },
    ],
  },
  {
    id: 'stressResponse', module: 6, type: 'single',
    prompt: 'When something gets hard, what do you do?',
    options: [
      { value: 'power-through', label: 'Power through and finish' },
      { value: 'take-break', label: 'Take a break and come back' },
      { value: 'talk', label: 'Talk to someone about it' },
      { value: 'procrastinate', label: 'Get overwhelmed and put it off' },
    ],
  },
  {
    id: 'surpriseReaction', module: 6, type: 'single',
    prompt: 'If our result surprises you, how would you react?',
    options: [
      { value: 'excited', label: 'Excited to explore it' },
      { value: 'skeptical', label: 'Skeptical but curious' },
      { value: 'wrong', label: 'I would feel the system got it wrong' },
      { value: 'counselor', label: 'I would want to talk to a counsellor' },
    ],
  },
];

/** Total questionnaire steps (drives the ProgressRail; games are a separate phase). */
export const QUESTION_TOTAL = QUESTIONS.length;
