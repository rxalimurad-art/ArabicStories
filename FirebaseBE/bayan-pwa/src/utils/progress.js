const LAST_READ_KEY = 'bayan-last-read'
const BOOKMARKS_KEY = 'bayan-bookmarks'

function read(key) {
  try { return JSON.parse(localStorage.getItem(key)) } catch { return null }
}
function write(key, val) {
  try { localStorage.setItem(key, JSON.stringify(val)) } catch {}
}

// ── Last Read ──────────────────────────────────────────────────
export function getLastRead() {
  return read(LAST_READ_KEY)
}

export function saveLastRead(surah, paragraphIndex, surahName) {
  write(LAST_READ_KEY, { surah, paragraphIndex, surahName, ts: Date.now() })
}

// ── Bookmarks ──────────────────────────────────────────────────
export function getBookmarks() {
  return read(BOOKMARKS_KEY) || []
}

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
