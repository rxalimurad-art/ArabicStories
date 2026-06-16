const LAST_READ_KEY = 'bayan-last-read'
const BOOKMARKS_KEY = 'bayan-bookmarks'
const PROGRESS_KEY  = 'bayan-surah-progress'
const STREAK_KEY    = 'bayan-streak'

function read(key) {
  try { return JSON.parse(localStorage.getItem(key)) } catch { return null }
}
function write(key, val) {
  try { localStorage.setItem(key, JSON.stringify(val)) } catch {}
}

// ── Last Read ──────────────────────────────────────────────────
export function getLastRead() { return read(LAST_READ_KEY) }

export function saveLastRead(surah, paragraphIndex, surahName) {
  write(LAST_READ_KEY, { surah, paragraphIndex, surahName, ts: Date.now() })
}

// ── Bookmarks ──────────────────────────────────────────────────
export function getBookmarks() { return read(BOOKMARKS_KEY) || [] }

export function toggleBookmark(surah, paragraphIndex, meta) {
  const all = getBookmarks()
  const exists = all.find((b) => b.surah === surah && b.paragraphIndex === paragraphIndex)
  const next = exists
    ? all.filter((b) => !(b.surah === surah && b.paragraphIndex === paragraphIndex))
    : [...all, { surah, paragraphIndex, ...meta, ts: Date.now() }]
  write(BOOKMARKS_KEY, next)
  return next
}

export function isBookmarked(surah, paragraphIndex) {
  return getBookmarks().some((b) => b.surah === surah && b.paragraphIndex === paragraphIndex)
}

// ── Surah Progress ─────────────────────────────────────────────
// Structure: { [surahNum]: { read: N, total: N } }
export function getAllProgress() { return read(PROGRESS_KEY) || {} }

export function getSurahProgress(surahNum) {
  const all = getAllProgress()
  return all[surahNum] || { read: 0, total: 0 }
}

export function getSurahPercent(surahNum) {
  const { read, total } = getSurahProgress(surahNum)
  if (!total) return 0
  return Math.round((read / total) * 100)
}

// Called as user scrolls — updates the furthest paragraph read
export function updateSurahProgress(surahNum, paragraphIndex, total) {
  const all = getAllProgress()
  const cur = all[surahNum] || { read: 0, total }
  const newRead = Math.max(cur.read, paragraphIndex + 1)
  all[surahNum] = { read: Math.min(newRead, total), total }
  write(PROGRESS_KEY, all)
}

// Mark entire surah as done
export function markSurahComplete(surahNum, total) {
  const all = getAllProgress()
  all[surahNum] = { read: total, total }
  write(PROGRESS_KEY, all)
}

// Overall Quran coverage
export function getOverallProgress() {
  const all = getAllProgress()
  const entries = Object.entries(all)
  if (!entries.length) return { completedSurahs: 0, percent: 0 }

  let totalRead = 0, totalParagraphs = 0
  let completedSurahs = 0

  for (const [, { read, total }] of entries) {
    if (!total) continue
    totalRead += read
    totalParagraphs += total
    if (read >= total) completedSurahs++
  }

  // Quran coverage: weight completed paragraphs across started surahs,
  // then scale to 114 surahs total.
  const startedPercent = totalParagraphs > 0 ? totalRead / totalParagraphs : 0
  const percent = Math.round((startedPercent * entries.length / 114) * 100)

  return { completedSurahs, percent: Math.min(percent, 100) }
}

// ── Streaks ────────────────────────────────────────────────────
function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

export function getStreak() {
  return read(STREAK_KEY) || { count: 0, lastDate: null }
}

export function updateStreak() {
  const streak = getStreak()
  const today = todayStr()
  if (streak.lastDate === today) return streak // already counted today

  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  const yStr = yesterday.toISOString().slice(0, 10)

  const newStreak = {
    count: streak.lastDate === yStr ? streak.count + 1 : 1,
    lastDate: today,
  }
  write(STREAK_KEY, newStreak)
  return newStreak
}
