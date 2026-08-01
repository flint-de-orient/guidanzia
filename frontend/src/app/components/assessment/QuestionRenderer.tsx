import { Textarea } from '../ui/textarea';
import { OptionCard, OptionGroup } from './OptionCard';
import { SelectTile } from './SelectTile';
import { RankingRow } from './RankingRow';
import { MarksBlock, MarksBand } from './MarksBlock';
import type { QuestionDef, AnswerValue } from './questionTypes';

interface QuestionRendererProps {
  question: QuestionDef;
  value: AnswerValue | undefined;
  onChange: (v: AnswerValue) => void;
  error?: string | null;
  /** Dynamic subjects for the marks question (from the favouriteSubjects answer). */
  subjects?: string[];
  showUnanswered?: boolean;
}

export function QuestionRenderer({
  question,
  value,
  onChange,
  error,
  subjects = [],
  showUnanswered = false,
}: QuestionRendererProps) {
  switch (question.type) {
    case 'single': {
      const v = (value as string) ?? '';
      return (
        <OptionGroup error={error} ariaLabel={question.prompt}>
          {question.options?.map((opt) => (
            <OptionCard
              key={opt.value}
              label={opt.label}
              description={opt.description}
              selected={v === opt.value}
              error={!!error}
              onSelect={() => onChange(opt.value)}
            />
          ))}
        </OptionGroup>
      );
    }

    case 'multi': {
      const v = (value as string[]) ?? [];
      const cap = question.maxSelect ?? Infinity;
      const capReached = v.length >= cap;
      return (
        <div>
          <div className="grid grid-cols-2 gap-3" role="group" aria-label={question.prompt}>
            {question.options?.map((opt) => {
              const selected = v.includes(opt.value);
              return (
                <SelectTile
                  key={opt.value}
                  label={opt.label}
                  selected={selected}
                  capReached={capReached}
                  error={!!error}
                  onToggle={() => {
                    if (selected) onChange(v.filter((x) => x !== opt.value));
                    else if (!capReached) onChange([...v, opt.value]);
                  }}
                />
              );
            })}
          </div>
          {error && (
            <p className="mt-3 text-sm font-medium text-danger" role="alert">
              {error}
            </p>
          )}
        </div>
      );
    }

    case 'ranking': {
      const v = (value as string[]) ?? [];
      const cap = question.maxSelect ?? Infinity;
      return (
        <div>
          <div className="flex flex-col gap-3" role="group" aria-label={question.prompt}>
            {question.options?.map((opt) => {
              const idx = v.indexOf(opt.value);
              const rank = idx >= 0 ? idx + 1 : null;
              return (
                <RankingRow
                  key={opt.value}
                  label={opt.label}
                  rank={rank}
                  error={!!error}
                  onToggle={() => {
                    if (rank) onChange(v.filter((x) => x !== opt.value));
                    else if (v.length < cap) onChange([...v, opt.value]);
                  }}
                />
              );
            })}
          </div>
          {error && (
            <p className="mt-3 text-sm font-medium text-danger" role="alert">
              {error}
            </p>
          )}
        </div>
      );
    }

    case 'text': {
      const v = (value as string) ?? '';
      return (
        <Textarea
          value={v}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Type your answer…"
          className="min-h-[180px] rounded-card border-2 border-outline bg-surface-lowest text-on-surface focus-visible:border-gold-deep"
        />
      );
    }

    case 'marks': {
      const v = (value as Record<string, string>) ?? {};
      const list = subjects.length ? subjects : ['Mathematics', 'Physics', 'Computer Science'];
      return (
        <div className="space-y-6">
          {list.map((subject) => (
            <MarksBlock
              key={subject}
              subject={subject}
              value={(v[subject] as MarksBand) ?? ''}
              showUnanswered={showUnanswered}
              onSelect={(band) => onChange({ ...v, [subject]: band })}
            />
          ))}
        </div>
      );
    }

    default:
      return null;
  }
}

/** Whether an answer satisfies the question's constraints. */
export function isAnswerValid(
  question: QuestionDef,
  value: AnswerValue | undefined,
  subjects: string[] = []
): boolean {
  if (question.optional) return true;
  switch (question.type) {
    case 'single':
      return typeof value === 'string' && value.length > 0;
    case 'multi': {
      const v = (value as string[]) ?? [];
      return v.length >= (question.minSelect ?? 1);
    }
    case 'ranking': {
      const v = (value as string[]) ?? [];
      return v.length >= (question.minSelect ?? 1);
    }
    case 'text':
      return true;
    case 'marks': {
      const v = (value as Record<string, string>) ?? {};
      const list = subjects.length ? subjects : [];
      return list.length > 0 && list.every((s) => !!v[s]);
    }
    default:
      return false;
  }
}
