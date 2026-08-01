import { TranslatedText } from '../TranslatedText';

interface RankingRowProps {
  label: string;
  /** 1-based rank, or null/0 if unranked. */
  rank: number | null;
  onToggle: () => void;
  error?: boolean;
}

/**
 * Ranked-select row for "pick your top N, in order". Tapping assigns the next
 * rank; tapping a ranked row clears it. Rank 1 = gold badge, rank 2 = lime,
 * others tinted from a small palette. A coloured left bar reinforces the rank.
 */
export function RankingRow({ label, rank, onToggle, error = false }: RankingRowProps) {
  const ranked = !!rank;

  const badge =
    rank === 1
      ? 'bg-gold text-gold-ink'
      : rank === 2
      ? 'bg-lime text-lime-ink'
      : 'bg-cyan text-cyan-ink';

  const bar =
    rank === 1 ? 'bg-gold' : rank === 2 ? 'bg-lime' : 'bg-cyan';

  return (
    <button
      type="button"
      aria-pressed={ranked}
      onClick={onToggle}
      className={
        'relative w-full min-h-[64px] flex items-center gap-4 pl-5 pr-4 py-3 rounded-card border-2 text-left overflow-hidden transition-all ' +
        'active:scale-[0.99] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
        'focus-visible:ring-offset-2 focus-visible:ring-offset-surface ' +
        (ranked
          ? 'bg-surface-lowest border-gold-deep'
          : error
          ? 'bg-surface-lowest border-danger'
          : 'bg-surface-lowest border-outline hover:border-gold-deep')
      }
    >
      {ranked && <span className={'absolute left-0 top-0 bottom-0 w-1.5 ' + bar} />}
      <span
        className={
          'w-9 h-9 rounded-full flex items-center justify-center font-bold flex-shrink-0 ' +
          (ranked ? badge : 'bg-surface-container text-on-surface-variant')
        }
      >
        {rank ?? ''}
      </span>
      <span className="flex-1 font-bold text-[17px] text-on-surface">
        <TranslatedText>{label}</TranslatedText>
      </span>
    </button>
  );
}
