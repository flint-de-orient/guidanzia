import { ReactNode } from 'react';
import { Check } from 'lucide-react';
import { TranslatedText } from '../TranslatedText';

interface SelectTileProps {
  label: string;
  icon?: ReactNode;
  selected: boolean;
  onToggle: () => void;
  /** True when the selection cap is reached and this tile isn't selected — dims but stays tappable to swap. */
  capReached?: boolean;
  error?: boolean;
}

/**
 * Multi-select tile (checkbox semantics). Square, icon-over-label. Selected =
 * gold fill + check badge. When the group's cap is hit, unselected tiles dim
 * but remain interactive so users can swap a choice.
 */
export function SelectTile({
  label,
  icon,
  selected,
  onToggle,
  capReached = false,
  error = false,
}: SelectTileProps) {
  const dim = capReached && !selected;

  const stateClass = selected
    ? 'bg-gold border-gold text-gold-ink'
    : error
    ? 'bg-surface-lowest border-danger'
    : 'bg-surface-low border-outline hover:border-gold-deep';

  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={selected}
      onClick={onToggle}
      className={
        'relative aspect-square flex flex-col items-center justify-center gap-2 p-4 rounded-card border-2 transition-all ' +
        'active:scale-[0.98] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
        'focus-visible:ring-offset-2 focus-visible:ring-offset-surface ' +
        stateClass + (dim ? ' opacity-40' : '')
      }
    >
      {selected && (
        <span className="absolute top-3 right-3 text-gold-ink">
          <Check className="w-5 h-5" strokeWidth={3} />
        </span>
      )}
      {icon && (
        <span className={selected ? 'text-gold-ink' : 'text-on-surface-variant'}>{icon}</span>
      )}
      <span className={'text-[15px] font-bold text-center leading-tight ' + (selected ? 'text-gold-ink' : 'text-on-surface')}>
        <TranslatedText>{label}</TranslatedText>
      </span>
    </button>
  );
}
