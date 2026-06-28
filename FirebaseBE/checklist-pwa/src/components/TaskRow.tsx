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

  return (
    <div className={`row ${done ? 'row--done' : ''}`} style={{ ['--accent' as string]: accentVar }}>
      <button
        type="button"
        className="row__main"
        aria-pressed={done}
        onClick={onToggle}
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
