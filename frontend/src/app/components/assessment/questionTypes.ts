/**
 * Declarative definition of the assessment. The current onboarding hardcodes
 * all 20 questions as bespoke JSX with a flat `if (currentQuestion === N)`
 * validation chain. Encoding them as data makes the count dynamic, makes
 * reordering safe, and lets the ProgressRail derive its total from the flow.
 *
 * CRITICAL: every `value` here MUST match the exact enum string the backend
 * and the mindset report expect (see career-report.tsx label maps and
 * onboarding-new.tsx saveAssessmentData). A wrong value fails silently —
 * blank dashes in the report, degraded AI output, no error.
 */

export type QuestionType = 'single' | 'multi' | 'ranking' | 'text' | 'marks';

export interface QuestionOption {
  /** Backend enum value — do not change without checking the report/prompts. */
  value: string;
  label: string;
  description?: string;
}

export interface QuestionDef {
  /** Backend field key, e.g. 'whyHere', 'careerValues'. */
  id: string;
  module: number;
  type: QuestionType;
  prompt: string;
  optional?: boolean;
  helper?: string;
  options?: QuestionOption[];
  /** multi/ranking cap. */
  maxSelect?: number;
  /** multi/ranking floor for validity. */
  minSelect?: number;
}

/** Answer value shapes by question type. */
export type SingleAnswer = string;
export type MultiAnswer = string[];
export type RankingAnswer = string[]; // ordered
export type TextAnswer = string;
export type MarksAnswer = Record<string, string>; // subject -> band
export type AnswerValue =
  | SingleAnswer
  | MultiAnswer
  | RankingAnswer
  | TextAnswer
  | MarksAnswer;
