import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { SURAHS } from '../data/surahs'
import { getLastRead, getBookmarks, getOverallProgress, getStreak, getSurahPercent } from '../utils/progress'

function timeAgo(ts) {
  const diff = Date.now() - ts
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'ابھی'
  if (m < 60) return `${m} منٹ پہلے`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h} گھنٹے پہلے`
  return `${Math.floor(h / 24)} دن پہلے`
}

const TABS = ['سورتیں', 'بک مارک']

export default function Home() {
  const navigate = useNavigate()
  const [query, setQuery]         = useState('')
  const [tab, setTab]             = useState(0)
  const [lastRead, setLastRead]   = useState(null)
  const [bookmarks, setBookmarks] = useState([])
  const [overall, setOverall]     = useState({ completedSurahs: 0, percent: 0 })
  const [streak, setStreak]       = useState({ count: 0 })

  useEffect(() => {
    setLastRead(getLastRead())
    setBookmarks(getBookmarks())
    setOverall(getOverallProgress())
    setStreak(getStreak())
  }, [])

  const filtered = query.trim()
    ? SURAHS.filter(([num, ar, ur]) =>
        ar.includes(query) || ur.includes(query) || String(num) === query.trim()
      )
    : SURAHS

  const sortedBookmarks = [...bookmarks].sort((a, b) => b.ts - a.ts)

  return (
    <div className="min-h-screen bg-cream" dir="rtl"
      style={{ paddingTop: 'env(safe-area-inset-top, 0)' }}>

      {/* ── Header ── */}
      <header className="sticky top-0 z-10 shadow-xl"
        style={{
          paddingTop: 'env(safe-area-inset-top, 0)',
          background: 'linear-gradient(135deg, #4c1d95 0%, #6d28d9 60%, #7c3aed 100%)',
        }}>
        <div className="max-w-3xl mx-auto px-4 pt-4 pb-3">

          {/* Title + streak */}
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              {streak.count > 0 && (
                <div className="flex items-center gap-1 bg-white/15 rounded-full px-3 py-1">
                  <span className="text-base">🔥</span>
                  <span className="text-white font-bold text-sm">{streak.count}</span>
                  <span className="text-white/60 text-xs"
                    style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>دن</span>
                </div>
              )}
            </div>

            <h1 className="text-2xl sm:text-3xl text-yellow-300"
              style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
              بَيَان
            </h1>

            <div className="flex items-center gap-1.5 bg-white/15 rounded-full px-3 py-1">
              <span className="text-white font-bold text-sm">{overall.completedSurahs}</span>
              <span className="text-white/60 text-xs"
                style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>سورتیں</span>
            </div>
          </div>

          {/* Overall progress */}
          {overall.percent > 0 && (
            <div className="mb-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-white/50 text-xs"
                  style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                  قرآن کریم پڑھا
                </span>
                <span className="text-yellow-300 text-xs font-semibold">{overall.percent}%</span>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${overall.percent}%` }} />
              </div>
            </div>
          )}

          {/* Search */}
          {tab === 0 && (
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="سورہ تلاش کریں..."
              className="w-full rounded-xl px-4 py-2 bg-white/10 text-white placeholder-white/40 border border-white/20 focus:outline-none focus:border-yellow-300/60 text-right text-sm"
              style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
              dir="rtl"
            />
          )}
        </div>

        {/* Tabs */}
        <div className="flex max-w-3xl mx-auto px-4 pb-0 gap-1">
          {TABS.map((label, i) => (
            <button key={i} onClick={() => setTab(i)}
              className={`px-4 py-2 text-sm rounded-t-lg transition-colors ${
                tab === i
                  ? 'bg-cream text-violet-900 font-semibold'
                  : 'text-white/60 hover:text-white hover:bg-white/10'
              }`}
              style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
              {label}
            </button>
          ))}
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-3 py-4"
        style={{ paddingBottom: 'calc(1.5rem + env(safe-area-inset-bottom, 0px))' }}>

        {/* ── SURAH LIST TAB ── */}
        {tab === 0 && (
          <>
            {/* Continue reading banner */}
            {lastRead && !query && (
              <button
                onClick={() => navigate(`/surah/${lastRead.surah}`)}
                className="w-full flex items-center gap-3 mb-4 rounded-2xl px-4 py-3 shadow-lg active:opacity-90 transition-all text-right"
                style={{ background: 'linear-gradient(135deg, #5b21b6, #7c3aed)' }}
              >
                <div className="w-10 h-10 flex-shrink-0 rounded-full bg-white/20 flex items-center justify-center text-xl">
                  ▶
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-white/60 mb-0.5"
                    style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                    جاری رکھیں · {timeAgo(lastRead.ts)}
                  </p>
                  <p className="text-base font-semibold text-yellow-300 truncate"
                    style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                    {lastRead.surahName}
                  </p>
                </div>
                <span className="text-white/40 text-lg">›</span>
              </button>
            )}

            {/* Bismillah */}
            {!query && (
              <div className="text-center py-3 mb-3">
                <span className="text-lg sm:text-xl text-violet-800"
                  style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                  بِسۡمِ اللّٰہِ الرَّحۡمٰنِ الرَّحِیۡمِ
                </span>
              </div>
            )}

            {/* Surah list */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
              {filtered.map(([num, ar, ur, ayahCount, revelation]) => {
                const pct = getSurahPercent(num)
                return (
                  <button
                    key={num}
                    onClick={() => navigate(`/surah/${num}`)}
                    className="flex items-center gap-3 bg-white rounded-2xl shadow-sm border border-violet-100 px-3 sm:px-4 py-2.5 sm:py-3 hover:shadow-md active:bg-violet-50 hover:border-violet-300 transition-all text-right"
                  >
                    {/* Number badge */}
                    <div className="w-9 h-9 sm:w-10 sm:h-10 flex-shrink-0 rounded-full flex items-center justify-center text-xs sm:text-sm font-bold text-white"
                      style={{ background: pct === 100 ? '#059669' : 'linear-gradient(135deg, #6d28d9, #8b5cf6)' }}>
                      {pct === 100 ? '✓' : num}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="text-lg sm:text-xl text-violet-950 leading-tight"
                        style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                        {ar}
                      </div>
                      <div className="text-xs sm:text-sm text-gray-500 leading-tight mt-0.5"
                        style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                        {ur}
                      </div>
                      {/* Per-surah progress bar */}
                      {pct > 0 && pct < 100 && (
                        <div className="mt-1.5 h-1 rounded-full bg-violet-100 overflow-hidden w-full">
                          <div className="h-full rounded-full bg-violet-500 transition-all"
                            style={{ width: `${pct}%` }} />
                        </div>
                      )}
                    </div>

                    <div className="text-left flex-shrink-0 text-xs text-gray-400 space-y-0.5">
                      <div>{ayahCount} آیات</div>
                      <div className={revelation === 'مکی' ? 'text-amber-500' : 'text-violet-500'}>
                        {revelation}
                      </div>
                    </div>
                  </button>
                )
              })}
            </div>

            {filtered.length === 0 && (
              <p className="text-center text-gray-400 mt-10 text-sm"
                style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                کوئی سورہ نہیں ملی
              </p>
            )}
          </>
        )}

        {/* ── BOOKMARKS TAB ── */}
        {tab === 1 && (
          <div>
            {sortedBookmarks.length === 0 ? (
              <div className="text-center py-20">
                <div className="text-5xl mb-4">🔖</div>
                <p className="text-gray-400 text-sm"
                  style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                  ابھی تک کوئی بک مارک نہیں۔
                </p>
                <p className="text-gray-300 text-xs mt-2"
                  style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                  پڑھتے وقت 🔖 آئیکن دبائیں
                </p>
              </div>
            ) : (
              <div className="space-y-2">
                {sortedBookmarks.map((b, i) => (
                  <button key={i}
                    onClick={() => {
                      navigate(`/surah/${b.surah}`)
                      setTimeout(() => {
                        document.getElementById(`p-${b.paragraphIndex}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                      }, 600)
                    }}
                    className="w-full flex items-center gap-3 bg-white rounded-2xl border border-violet-100 shadow-sm px-4 py-3 hover:shadow-md active:bg-violet-50 transition-all text-right"
                  >
                    <div className="text-violet-500 flex-shrink-0">
                      <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                        <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-base text-violet-900 font-medium truncate"
                        style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                        {b.surahName}
                      </p>
                      {b.ayatLabel && (
                        <p className="text-xs text-gray-400 mt-0.5"
                          style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                          {b.ayatLabel}
                        </p>
                      )}
                    </div>
                    <span className="text-xs text-gray-300 flex-shrink-0">{timeAgo(b.ts)}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  )
}
