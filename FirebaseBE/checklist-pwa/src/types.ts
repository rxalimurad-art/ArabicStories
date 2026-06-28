export type Group = 'deen' | 'projects' | 'growth';

/** A recurring task definition (static config — never stored in the DB). */
export interface TaskDef {
  key: string; // stable id used as the storage key — never change once shipped
  title: string;
  hint: string;
  group: Group;
}

/** One task's record for one calendar day. Primary key is [taskKey, date]. */
export interface Entry {
  taskKey: string;
  date: string; // 'YYYY-MM-DD' in the device's local timezone
  done: boolean;
  note: string;
}
