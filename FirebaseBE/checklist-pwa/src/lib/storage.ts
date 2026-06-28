import { db } from './db';
import type { Entry } from '../types';
import { firestoreStorage } from './firestoreStorage';

/**
 * The persistence seam. The UI talks ONLY to this interface — never to Dexie
 * directly — so a future cloud-synced backend (Supabase, Firestore, …) can be
 * dropped in by writing another implementation and swapping the export below.
 */
export interface Storage {
  getEntry(taskKey: string, date: string): Promise<Entry | undefined>;
  setEntry(entry: Entry): Promise<void>;
  getRange(taskKey: string, fromDate: string, toDate: string): Promise<Entry[]>;
  getDay(date: string): Promise<Entry[]>;
}

/** Local-first implementation backed by IndexedDB (Dexie). */
export const dexieStorage: Storage = {
  getEntry(taskKey, date) {
    return db.entries.get([taskKey, date]);
  },

  async setEntry(entry) {
    await db.entries.put(entry);
  },

  getRange(taskKey, fromDate, toDate) {
    return db.entries
      .where('taskKey')
      .equals(taskKey)
      .and((e) => e.date >= fromDate && e.date <= toDate)
      .toArray();
  },

  getDay(date) {
    return db.entries.where('date').equals(date).toArray();
  },
};

/**
 * The single storage instance the app uses.
 *
 * Active backend: Firestore (cloud, single shared space) with offline IndexedDB
 * caching. The local-only `dexieStorage` above remains as a drop-in alternative
 * — swapping this one line is the whole seam.
 */
export const storage: Storage = firestoreStorage;
