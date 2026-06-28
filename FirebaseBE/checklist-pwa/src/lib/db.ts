import Dexie, { type Table } from 'dexie';
import type { Entry } from '../types';

/**
 * IndexedDB (via Dexie). One row per (taskKey, date).
 *
 * Schema versioning: bump `version(n)` and add an upgrade callback when the
 * shape changes — existing data is preserved across app updates and reloads.
 */
export class ChecklistDB extends Dexie {
  entries!: Table<Entry, [string, string]>; // compound primary key [taskKey, date]

  constructor() {
    super('daily-checklist');
    this.version(1).stores({
      // '&' not needed — a compound key is implicitly unique.
      // Secondary indexes on taskKey and date power range / per-day queries.
      entries: '[taskKey+date], taskKey, date',
    });
  }
}

export const db = new ChecklistDB();
