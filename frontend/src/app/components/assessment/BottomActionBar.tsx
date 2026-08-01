import { ChevronLeft } from 'lucide-react';
import { TranslatedText } from '../TranslatedText';

interface BottomActionBarProps {
  onBack?: () => void;
  onContinue: () => void;
  /** Continue is disabled until the question is answered. */
  continueDisabled?: boolean;
  continueLabel?: string;
  /** Optional low-emphasis skip action (used on optional questions). */
  onSkip?: () => void;
  skipLabel?: string;
}

/**
 * Thumb-zone action bar, fixed to the bottom with a blurred surface and
 * iOS safe-area padding. Back is a low-emphasis chevron; Continue is the
 * gold primary that only activates once an answer exists.
 */
export function BottomActionBar({
  onBack,
  onContinue,
  continueDisabled = false,
  continueLabel = 'Continue',
  onSkip,
  skipLabel = 'Skip',
}: BottomActionBarProps) {
  return (
    <nav
      className="fixed bottom-0 left-0 w-full z-50 backdrop-blur-xl bg-surface/90 border-t border-outline"
      style={{ paddingBottom: 'max(1rem, env(safe-area-inset-bottom))' }}
    >
      <div className="max-w-3xl mx-auto px-5 pt-4 flex items-center gap-3">
        {onBack && (
          <button
            onClick={onBack}
            aria-label="Go back"
            className="w-14 h-14 flex items-center justify-center rounded-full text-on-surface-variant hover:text-on-surface hover:bg-surface-container transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
          >
            <ChevronLeft className="w-7 h-7" />
          </button>
        )}

        {onSkip && (
          <button
            onClick={onSkip}
            className="h-14 px-4 rounded-pill font-semibold text-on-surface-variant hover:text-on-surface transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
          >
            <TranslatedText>{skipLabel}</TranslatedText>
          </button>
        )}

        <button
          onClick={onContinue}
          disabled={continueDisabled}
          className={
            'flex-1 h-14 rounded-pill font-bold text-lg transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-surface ' +
            (continueDisabled
              ? 'bg-surface-container text-on-surface-variant/50 cursor-not-allowed'
              : 'bg-gold text-gold-ink hover:brightness-95 active:scale-[0.99] shadow-lg')
          }
        >
          <TranslatedText>{continueLabel}</TranslatedText>
        </button>
      </div>
    </nav>
  );
}
