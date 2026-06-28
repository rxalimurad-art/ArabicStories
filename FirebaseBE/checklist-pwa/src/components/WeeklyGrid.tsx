import type { TaskDef } from '../types';
import type { TaskState } from '../App';
import { dayLabel } from '../lib/date';

interface Props {
  tasks: TaskDef[];
  states: Record<string, TaskState>;
  weekDates: string[]; // oldest → newest, length 7
  today: string;
}

/** Compact "am I being consistent?" grid: one row per task, last 7 days. */
export function WeeklyGrid({ tasks, states, weekDates, today }: Props) {
  return (
    <section className="grid" aria-label="Last 7 days">
      <div className="grid__head">
        <span className="grid__corner">Last 7 days</span>
        {weekDates.map((d) => {
          const { dow, dom } = dayLabel(d);
          return (
            <span key={d} className={`grid__col ${d === today ? 'grid__col--today' : ''}`}>
              <span className="grid__dow">{dow}</span>
              <span className="grid__dom">{dom}</span>
            </span>
          );
        })}
      </div>

      {tasks.map((t) => {
        const week = states[t.key]?.week ?? [];
        return (
          <div key={t.key} className="grid__row">
            <span className="grid__name" title={t.title}>
              {t.title}
            </span>
            {weekDates.map((d, i) => (
              <span
                key={d}
                className={[
                  'grid__cell',
                  week[i] ? 'grid__cell--on' : '',
                  d === today ? 'grid__cell--today' : '',
                ].join(' ')}
                aria-hidden="true"
              />
            ))}
          </div>
        );
      })}
    </section>
  );
}
