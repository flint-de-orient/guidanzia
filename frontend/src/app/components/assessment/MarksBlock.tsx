import { TranslatedText } from '../TranslatedText';

export const MARKS_BANDS = ['Below 50', '50–65', '65–80', '80–90', '90+'] as const;
export type MarksBand = (typeof MARKS_BANDS)[number];

interface MarksBlockProps {
  /** Subject name — dynamic, comes from the subjects the student picked earlier. */
  subject: string;
  value: MarksBand | '';
  onSelect: (band: MarksBand) => void;
  /** Marks a still-unanswered block with an amber dot. */
  showUnanswered?: boolean;
}

/**
 * One subject's marks-band picker. Rendered once per dynamically-chosen
 * subject. A horizontally-scrolling row of pills; selected = gold.
 */
export function MarksBlock({ subject, value, onSelect, showUnanswered = false }: MarksBlockProps) {
  const unanswered = showUnanswered && !value;
  return (
    <section className="pb-2">
      <div className="flex items-center gap-2 mb-3">
        <span className="text-[10px] uppercase tracking-widest font-bold text-gold-deep">
          {subject}
        </span>
        {unanswered && (
          <span
            className="w-1.5 h-1.5 rounded-full bg-danger"
            aria-label="Not yet answered"
          />
        )}
      </div>
      <div
        className="flex flex-wrap gap-2.5"
        role="radiogroup"
        aria-label={`${subject} marks band`}
      >
        {MARKS_BANDS.map((band) => {
          const selected = value === band;
          return (
            <button
              key={band}
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => onSelect(band)}
              className={
                'px-4 py-2.5 rounded-pill border-2 font-label text-sm font-bold shrink-0 transition-all ' +
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
                'focus-visible:ring-offset-2 focus-visible:ring-offset-surface ' +
                (selected
                  ? 'bg-gold border-gold text-gold-ink'
                  : 'bg-surface-low border-outline text-on-surface hover:border-gold-deep')
              }
            >
              <TranslatedText>{band}</TranslatedText>
            </button>
          );
        })}
      </div>
      <div className="mt-4 h-px w-full bg-outline" />
    </section>
  );
}
