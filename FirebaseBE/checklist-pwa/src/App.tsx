import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { GROUPS, TASKS } from './config/tasks';
import type { TaskDef } from './types';
import { storage } from './lib/storage';
import { addDays, lastNDates, todayStr } from './lib/date';
import { computeStreak } from './lib/streak';
import { ProgressRing } from './components/ProgressRing';
import { Section } from './components/Section';
import { TaskRow } from './components/TaskRow';
import { WeeklyGrid } from './components/WeeklyGrid';

const LOOKBACK_DAYS = 400; // enough history for long streaks

export interface TaskState {
  done: boolean;
  note: string;
  streak: number;
  week: boolean[]; // aligned to weekDates (oldest → newest)
}

export default function App() {
  const [today, setToday] = useState(todayStr());
  const weekDates = useMemo(() => lastNDates(7, today), [today]);

  const [states, setStates] = useState<Record<string, TaskState>>({});
  const [loaded, setLoaded] = useState(false);
  // Source of truth for each task's completed dates (kept in sync with the DB).
  const doneSets = useRef<Record<string, Set<string>>>({});

  // ── Load (and reload whenever the calendar day changes) ──────────────────
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoaded(false);
      const from = addDays(today, -LOOKBACK_DAYS);
      const next: Record<string, TaskState> = {};
      for (const t of TASKS) {
        const entries = await storage.getRange(t.key, from, today);
        const done = new Set(entries.filter((e) => e.done).map((e) => e.date));
        const todayEntry = entries.find((e) => e.date === today);
        doneSets.current[t.key] = done;
        next[t.key] = {
          done: todayEntry?.done ?? false,
          note: todayEntry?.note ?? '',
          streak: computeStreak(done, today),
          week: weekDates.map((d) => done.has(d)),
        };
      }
      if (!cancelled) {
        setStates(next);
        setLoaded(true);
      }
    })();
    return () => {
      cancelled = true;
    };
    // weekDates is derived from today, so today alone is the right dependency
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [today]);

  // ── Roll over to the new day automatically (focus / visibility / tick) ───
  useEffect(() => {
    const check = () => {
      const t = todayStr();
      setToday((prev) => (prev === t ? prev : t));
    };
    document.addEventListener('visibilitychange', check);
    window.addEventListener('focus', check);
    const id = window.setInterval(check, 60_000);
    return () => {
      document.removeEventListener('visibilitychange', check);
      window.removeEventListener('focus', check);
      window.clearInterval(id);
    };
  }, []);

  const recalc = useCallback(
    (key: string, patch: Partial<TaskState>) => {
      const set = doneSets.current[key];
      setStates((s) => ({
        ...s,
        [key]: {
          ...s[key],
          ...patch,
          streak: computeStreak(set, today),
          week: weekDates.map((d) => set.has(d)),
        },
      }));
    },
    [today, weekDates],
  );

  const toggle = useCallback(
    async (t: TaskDef) => {
      const cur = states[t.key];
      if (!cur) return;
      const done = !cur.done;
      const set = doneSets.current[t.key];
      if (done) set.add(today);
      else set.delete(today);
      recalc(t.key, { done });
      await storage.setEntry({ taskKey: t.key, date: today, done, note: cur.note });
    },
    [states, today, recalc],
  );

  const setNote = useCallback(
    (t: TaskDef, note: string) => {
      setStates((s) => ({ ...s, [t.key]: { ...s[t.key], note } }));
      const done = doneSets.current[t.key]?.has(today) ?? false;
      void storage.setEntry({ taskKey: t.key, date: today, done, note });
    },
    [today],
  );

  const doneCount = TASKS.reduce((n, t) => n + (states[t.key]?.done ? 1 : 0), 0);
  const total = TASKS.length;

  const headerDate = useMemo(() => {
    const [y, m, d] = today.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString(undefined, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    });
  }, [today]);

  return (
    <main className="app" aria-busy={!loaded}>
      <header className="hero">
        <div className="hero__text">
          <p className="hero__eyebrow">Today</p>
          <h1 className="hero__date">{headerDate}</h1>
        </div>
        <ProgressRing done={doneCount} total={total} />
      </header>

      <WeeklyGrid tasks={TASKS} states={states} weekDates={weekDates} today={today} />

      <div className="sections">
        {GROUPS.map((g) => (
          <Section key={g.key} label={g.label} accentVar={g.accentVar}>
            {TASKS.filter((t) => t.group === g.key).map((t) => (
              <TaskRow
                key={t.key}
                task={t}
                accentVar={g.accentVar}
                state={states[t.key]}
                onToggle={() => toggle(t)}
                onNote={(note) => setNote(t, note)}
              />
            ))}
          </Section>
        ))}
      </div>

      <footer className="footnote">Stored on this device · works offline</footer>
    </main>
  );
}
