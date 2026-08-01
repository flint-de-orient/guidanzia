import { TranslatedText } from '../TranslatedText';

interface ProgressRailProps {
  /** 1-based index of the current step. */
  current: number;
  /** Total number of steps in this phase — driven by the backend flow, not hardcoded. */
  total: number;
  /** Optional context line, e.g. "Module 2". */
  moduleLabel?: string;
  /** Optional right-aligned counter override; defaults to "Question {current} of {total}". */
  counterLabel?: string;
}

/**
 * Segmented progress rail. Completed ticks = gold, current = taller lime,
 * remaining = muted outline. Fully data-driven so it works for any question
 * count and adapts when optional questions are skipped.
 */
export function ProgressRail({ current, total, moduleLabel, counterLabel }: ProgressRailProps) {
  const safeTotal = Math.max(total, 1);
  const clamped = Math.min(Math.max(current, 1), safeTotal);
  const ticks = Array.from({ length: safeTotal }, (_, i) => i + 1);

  return (
    <div
      role="progressbar"
      aria-valuemin={1}
      aria-valuemax={safeTotal}
      aria-valuenow={clamped}
      aria-label={`Step ${clamped} of ${safeTotal}`}
      className="w-full"
    >
      <div className="flex items-end gap-[2px] h-3">
        {ticks.map((n) => {
          const state =
            n < clamped ? 'done' : n === clamped ? 'current' : 'todo';
          return (
            <div
              key={n}
              className={
                state === 'done'
                  ? 'flex-1 h-1 rounded-full bg-gold'
                  : state === 'current'
                  ? 'flex-1 h-2.5 rounded-full bg-lime shadow-[0_0_8px_var(--lime)]'
                  : 'flex-1 h-1 rounded-full bg-outline'
              }
            />
          );
        })}
      </div>
      {(moduleLabel || counterLabel !== undefined || safeTotal > 0) && (
        <div className="flex items-center justify-between mt-2">
          {moduleLabel ? (
            <span className="font-label text-xs font-bold uppercase tracking-wider text-on-surface-variant">
              <TranslatedText>{moduleLabel}</TranslatedText>
            </span>
          ) : (
            <span />
          )}
          <span className="font-label text-xs font-bold uppercase tracking-wider text-on-surface-variant">
            {counterLabel ?? `Question ${clamped} of ${safeTotal}`}
          </span>
        </div>
      )}
    </div>
  );
}
