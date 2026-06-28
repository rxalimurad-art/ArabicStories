import { addDays, todayStr } from './date';

/**
 * Per-task streak: consecutive completed days counting back from today.
 *
 * Rule: if today is already done, count from today; otherwise count up to
 * yesterday — so the streak doesn't visually "break" earlier in the day before
 * you've ticked it.
 *
 * @param doneDates set of 'YYYY-MM-DD' dates the task was completed
 */
export function computeStreak(doneDates: Set<string>, today: string = todayStr()): number {
  let cursor = doneDates.has(today) ? today : addDays(today, -1);
  let streak = 0;
  while (doneDates.has(cursor)) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}
