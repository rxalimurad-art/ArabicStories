import type { Group, TaskDef } from '../types';

/** Section metadata — colored dot + uppercase label per group. */
export interface GroupDef {
  key: Group;
  label: string;
  accentVar: string; // CSS variable used for the dot / completed accent
}

export const GROUPS: GroupDef[] = [
  { key: 'deen', label: 'Deen & Arabic', accentVar: 'var(--teal)' },
  { key: 'projects', label: 'Projects', accentVar: 'var(--violet)' },
  { key: 'growth', label: 'Growth', accentVar: 'var(--gold)' },
];

/**
 * The whole checklist, data-driven. Add / rename / reorder freely.
 * `key` is the persisted identifier — keep it stable once a task has history.
 */
export const TASKS: TaskDef[] = [
  { key: 'arabic-memorization', group: 'deen', title: 'Arabic memorization', hint: '15 min after Fajr' },
  { key: 'bayyinah-lectures', group: 'deen', title: 'Bayyinah lectures', hint: 'watch or review' },
  { key: 'quran-reading', group: 'deen', title: "Daily Qur'an reading", hint: 'after Maghrib' },

  { key: 'cap-mobile', group: 'projects', title: 'CAP Mobile', hint: 'client · as scheduled' },
  { key: 'vida-driver', group: 'projects', title: 'VIDA Driver', hint: 'client · as scheduled' },
  { key: 'my-app', group: 'projects', title: 'My app', hint: 'App Store project' },

  { key: 'career-learning', group: 'growth', title: 'New career learning', hint: 'keep sharpening' },
];
