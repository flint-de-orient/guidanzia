import { ReactNode } from 'react';
import { AlertCircle } from 'lucide-react';
import { TranslatedText } from '../TranslatedText';

/* ── OptionGroup: radiogroup wrapper + error region ─────────────────────── */

interface OptionGroupProps {
  children: ReactNode;
  /** Error message shown below the options; also flips cards to their error state. */
  error?: string | null;
  ariaLabel?: string;
}

export function OptionGroup({ children, error, ariaLabel }: OptionGroupProps) {
  return (
    <div>
      <div
        role="radiogroup"
        aria-label={ariaLabel}
        aria-invalid={!!error}
        className="flex flex-col gap-3"
      >
        {children}
      </div>
      {error && (
        <p className="mt-3 flex items-center gap-1.5 text-sm font-medium text-danger" role="alert">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <TranslatedText>{error}</TranslatedText>
        </p>
      )}
    </div>
  );
}

/* ── OptionCard: one selectable answer ──────────────────────────────────── */

interface OptionCardProps {
  label: string;
  description?: string;
  icon?: ReactNode;
  selected: boolean;
  onSelect: () => void;
  error?: boolean;
  disabled?: boolean;
}

export function OptionCard({
  label,
  description,
  icon,
  selected,
  onSelect,
  error = false,
  disabled = false,
}: OptionCardProps) {
  const base =
    'w-full min-h-[72px] flex items-center gap-4 p-4 rounded-card border-2 text-left transition-all ' +
    'active:scale-[0.99] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
    'focus-visible:ring-offset-2 focus-visible:ring-offset-surface';

  const stateClass = disabled
    ? 'bg-surface-container border-outline opacity-50 cursor-not-allowed'
    : selected
    ? 'bg-gold border-gold text-gold-ink shadow-md'
    : error
    ? 'bg-surface-lowest border-danger'
    : 'bg-surface-lowest border-outline hover:border-gold-deep';

  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      disabled={disabled}
      onClick={onSelect}
      className={`${base} ${stateClass}`}
    >
      {icon && (
        <span
          className={
            'w-12 h-12 rounded-input flex items-center justify-center flex-shrink-0 ' +
            (selected ? 'bg-gold-ink/10 text-gold-ink' : 'bg-surface-container text-on-surface-variant')
          }
        >
          {icon}
        </span>
      )}
      <span className="flex-1 min-w-0">
        <span className={'block font-bold text-[17px] ' + (selected ? 'text-gold-ink' : 'text-on-surface')}>
          <TranslatedText>{label}</TranslatedText>
        </span>
        {description && (
          <span className={'block text-sm line-clamp-1 ' + (selected ? 'text-gold-ink/80' : 'text-on-surface-variant')}>
            <TranslatedText>{description}</TranslatedText>
          </span>
        )}
      </span>
    </button>
  );
}
