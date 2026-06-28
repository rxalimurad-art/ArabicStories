import { collection, doc, getDoc, getDocs, query, setDoc, where } from 'firebase/firestore';
import { db } from './firebase';
import type { Storage } from './storage';
import type { Entry } from '../types';

// Single shared collection (no auth). Doc id = `${taskKey}__${date}`.
const COL = 'checklist_entries';
const idFor = (taskKey: string, date: string) => `${taskKey}__${date}`;

/**
 * Firestore-backed implementation of the storage seam.
 * Offline + local caching is handled by Firestore's IndexedDB persistence
 * (configured in firebase.ts), so reads/writes work offline and sync up later.
 */
export const firestoreStorage: Storage = {
  async getEntry(taskKey, date) {
    const snap = await getDoc(doc(db, COL, idFor(taskKey, date)));
    return snap.exists() ? (snap.data() as Entry) : undefined;
  },

  async setEntry(entry) {
    await setDoc(doc(db, COL, idFor(entry.taskKey, entry.date)), entry);
  },

  async getRange(taskKey, fromDate, toDate) {
    // Equality on taskKey (auto-indexed); filter the date window client-side
    // so no composite index is needed.
    const snap = await getDocs(query(collection(db, COL), where('taskKey', '==', taskKey)));
    return snap.docs
      .map((d) => d.data() as Entry)
      .filter((e) => e.date >= fromDate && e.date <= toDate);
  },

  async getDay(date) {
    const snap = await getDocs(query(collection(db, COL), where('date', '==', date)));
    return snap.docs.map((d) => d.data() as Entry);
  },
};
