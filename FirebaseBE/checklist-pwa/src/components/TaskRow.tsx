import type { TaskDef } from '../types';
import type { TaskState } from '../App';

interface Props {
  task: TaskDef;
  accentVar: string;
  state: TaskState | undefined;
  onToggle: () => void;
  onNote: (note: string) => void;
}

export function TaskRow({ task, accentVar, state, onToggle, onNote }: Props) {
  const done = state?.done ?? false;
  const streak = state?.streak ?? 0;
  const note = state?.note ?? '';
  const auto = task.auto ?? false;

  return (
    <div
      className={`row ${done ? 'row--done' : ''} ${auto ? 'row--auto' : ''}`}
      style={{ ['--accent' as string]: accentVar }}
    >
      <button
        type="button"
        className="row__main"
        aria-pressed={done}
        disabled={auto}
        onClick={auto ? undefined : onToggle}
        title={auto ? 'Synced automatically from Quran Rifqah — managed for you' : undefined}
      >
        <span className="row__check" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="16" height="16">
            <path
              d="M5 12.5l4.2 4.2L19 7"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.6"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </span>

        <span className="row__body">
          <span className="row__title">{task.title}</span>
          <span className="row__hint">{task.hint}</span>
        </span>

        <span className="row__streak" title={`${streak}-day streak`}>
          <span className="row__streak-num">{streak}</span>
          <span className="row__streak-label">day{streak === 1 ? '' : 's'}</span>
        </span>

        {auto && (
          <span className="row__lock" aria-label="Auto-synced" title="Synced automatically — can't edit here">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="5" y="11" width="14" height="9" rx="2" />
              <path d="M8 11V8a4 4 0 0 1 8 0v3" strokeLinecap="round" />
            </svg>
          </span>
        )}
      </button>

      <input
        type="text"
        className="row__note"
        value={note}
        placeholder="add a note…"
        aria-label={`Note for ${task.title}`}
        onChange={(e) => onNote(e.target.value)}
      />
    </div>
  );
}
