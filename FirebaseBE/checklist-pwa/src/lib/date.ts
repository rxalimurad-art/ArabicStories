// All dates are 'YYYY-MM-DD' strings in the *device's local* timezone.
// (For the author that's Lahore / UTC+5, but we never hardcode an offset —
// the local calendar day is what defines "today".)

export function toDateStr(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todayStr(): string {
  return toDateStr(new Date());
}

/** Add (or subtract) whole days to a 'YYYY-MM-DD' string, staying local. */
export function addDays(dateStr: string, delta: number): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  dt.setDate(dt.getDate() + delta);
  return toDateStr(dt);
}

/** The last `n` dates ending at `endStr` (inclusive), oldest first. */
export function lastNDates(n: number, endStr: string = todayStr()): string[] {
  const out: string[] = [];
  for (let i = n - 1; i >= 0; i--) out.push(addDays(endStr, -i));
  return out;
}

/** Single-letter weekday + day-of-month, for the weekly grid header. */
export function dayLabel(dateStr: string): { dow: string; dom: number } {
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  return {
    dow: dt.toLocaleDateString(undefined, { weekday: 'narrow' }),
    dom: d,
  };
}
