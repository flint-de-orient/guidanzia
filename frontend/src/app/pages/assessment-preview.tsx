import { useMemo, useState } from 'react';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';
import {
  ProgressRail,
  BottomActionBar,
} from '../components/assessment';
import { QuestionRenderer, isAnswerValid } from '../components/assessment/QuestionRenderer';
import { QUESTIONS, QUESTION_TOTAL } from '../components/assessment/questions';
import type { AnswerValue } from '../components/assessment/questionTypes';

/**
 * Proving slice for the new token layer + primitives. Renders the real question
 * config through the primitives with a dynamic, data-driven count — verify both
 * themes (toggle in the navbar) and all four input types here before pouring the
 * full flow into onboarding-new.tsx.
 */
export function AssessmentPreview() {
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, AnswerValue>>({});
  const [showError, setShowError] = useState(false);

  const question = QUESTIONS[index];

  // Dynamic subjects for the marks question — from the favouriteSubjects answer.
  const subjects = useMemo(() => {
    const v = answers['favoriteSubjects'];
    return Array.isArray(v) ? (v as string[]) : [];
  }, [answers]);

  const valid = isAnswerValid(question, answers[question.id], subjects);

  const setValue = (v: AnswerValue) => {
    setShowError(false);
    setAnswers((prev) => ({ ...prev, [question.id]: v }));
  };

  const goNext = () => {
    if (!valid && !question.optional) {
      setShowError(true);
      return;
    }
    setShowError(false);
    setIndex((i) => Math.min(i + 1, QUESTIONS.length - 1));
  };

  const goBack = () => {
    setShowError(false);
    setIndex((i) => Math.max(i - 1, 0));
  };

  const errorMsg = showError && !valid ? errorFor(question.type) : null;

  return (
    <div className="min-h-screen bg-surface text-on-surface">
      <Navbar showHomeButton />

      <div className="max-w-3xl mx-auto px-5 pt-6 pb-40">
        <ProgressRail
          current={index + 1}
          total={QUESTION_TOTAL}
          moduleLabel={`Module ${question.module}`}
          counterLabel={`Question ${index + 1} of ${QUESTION_TOTAL}`}
        />

        <div className="mt-8 mb-8">
          <h1 className="font-display text-[34px] leading-tight font-extrabold text-on-surface">
            <TranslatedText>{question.prompt}</TranslatedText>
          </h1>
          {question.helper && (
            <p className="mt-2 text-on-surface-variant">
              <TranslatedText>{question.helper}</TranslatedText>
            </p>
          )}
        </div>

        <QuestionRenderer
          question={question}
          value={answers[question.id]}
          onChange={setValue}
          error={errorMsg}
          subjects={subjects}
          showUnanswered={showError}
        />
      </div>

      <BottomActionBar
        onBack={index > 0 ? goBack : undefined}
        onContinue={goNext}
        continueDisabled={!valid && !question.optional}
        continueLabel={index === QUESTIONS.length - 1 ? 'Finish' : 'Continue'}
        onSkip={question.optional ? goNext : undefined}
        skipLabel="Skip"
      />
    </div>
  );
}

function errorFor(type: string): string {
  switch (type) {
    case 'multi': return 'Please select at least one option';
    case 'ranking': return 'Please select your top 2';
    case 'marks': return 'Please pick a band for each subject';
    default: return 'Please select an option';
  }
}
