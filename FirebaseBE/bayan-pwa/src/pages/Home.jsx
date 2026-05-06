import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { SURAHS } from '../data/surahs'
import { getLastRead, getBookmarks } from '../utils/progress'

function timeAgo(ts) {
  const diff = Date.now() - ts
  const m = Math.floor(diff / 60000)
  if (m < 1)  return 'ابھی'
  if (m < 60) return `${m} منٹ پہلے`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h} گھنٹے پہلے`
  return `${Math.floor(h / 24)} دن پہلے`
}

const TABS = ['سورتیں', 'بک مارک']

export default function Home() {
  const navigate = useNavigate()
  const [query, setQuery]       = useState('')
  const [tab, setTab]           = useState(0)
  const [lastRead, setLastRead] = useState(null)
  const [bookmarks, setBookmarks] = useState([])

  useEffect(() => {
    setLastRead(getLastRead())
    setBookmarks(getBookmarks())
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

      {/* Header */}
      <header className="sticky top-0 z-10 bg-forest-900 text-white shadow-lg"
        style={{ paddingTop: 'env(safe-area-inset-top, 0)' }}>
        <div className="max-w-3xl mx-auto px-4 pt-3 pb-2">
          <h1
            className="text-2xl sm:text-3xl text-center mb-2 text-yellow-200"
            style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}
          >
            بَيَان
          </h1>
          {tab === 0 && (
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="سورہ تلاش کریں..."
              className="w-full rounded-xl px-4 py-2 bg-white/10 text-white placeholder-white/50 border border-white/20 focus:outline-none focus:border-yellow-300 text-right text-sm"
              style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
              dir="rtl"
            />
          )}
        </div>

        {/* Tabs */}
        <div className="flex max-w-3xl mx-auto px-4 pb-0 gap-1">
          {TABS.map((label, i) => (
            <button
              key={i}
              onClick={() => setTab(i)}
              className={`px-4 py-2 text-sm rounded-t-lg transition-colors ${
                tab === i
                  ? 'bg-cream text-forest-900 font-semibold'
                  : 'text-white/70 hover:text-white hover:bg-white/10'
              }`}
              style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
            >
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
                className="w-full flex items-center gap-3 mb-4 bg-forest-800 text-white rounded-2xl px-4 py-3 shadow-md active:bg-forest-900 transition-colors text-right"
              >
                <div className="w-10 h-10 flex-shrink-0 rounded-full bg-white/20 flex items-center justify-center text-lg">
                  ▶
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-white/60 mb-0.5"
                    style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                    جاری رکھیں · {timeAgo(lastRead.ts)}
                  </p>
                  <p className="text-base font-semibold text-yellow-200 truncate"
                    style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                    {lastRead.surahName}
                  </p>
                </div>
                <span className="text-white/40 text-sm">›</span>
              </button>
            )}

            {/* Bismillah */}
            {!query && (
              <div className="text-center py-3 mb-3">
                <span
                  className="text-lg sm:text-xl text-forest-800"
                  style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}
                >
                  بِسۡمِ اللّٰہِ الرَّحۡمٰنِ الرَّحِیۡمِ
                </span>
              </div>
            )}

            {/* Surah list */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
              {filtered.map(([num, ar, ur, ayahCount, revelation]) => (
                <button
                  key={num}
                  onClick={() => navigate(`/surah/${num}`)}
                  className="flex items-center gap-3 bg-white rounded-2xl shadow-sm border border-gray-100 px-3 sm:px-4 py-2.5 sm:py-3 hover:shadow-md active:bg-gray-50 hover:border-forest-200 transition-all text-right"
                >
                  <div className="w-9 h-9 sm:w-10 sm:h-10 flex-shrink-0 rounded-full bg-forest-800 text-white flex items-center justify-center text-xs sm:text-sm font-bold">
                    {num}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div
                      className="text-lg sm:text-xl text-forest-900 leading-tight"
                      style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}
                    >
                      {ar}
                    </div>
                    <div
                      className="text-xs sm:text-sm text-gray-500 leading-tight mt-0.5"
                      style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
                    >
                      {ur}
                    </div>
                  </div>
                  <div className="text-left flex-shrink-0 text-xs text-gray-400 space-y-0.5">
                    <div>{ayahCount} آیات</div>
                    <div className={revelation === 'مکی' ? 'text-amber-600' : 'text-blue-600'}>
                      {revelation}
                    </div>
                  </div>
                </button>
              ))}
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
                  پیراگراف کارڈ پر 🔖 آئیکن دبائیں
                </p>
              </div>
            ) : (
              <div className="space-y-2">
                {sortedBookmarks.map((b, i) => (
                  <button
                    key={i}
                    onClick={() => {
                      navigate(`/surah/${b.surah}`)
                      // scroll after nav
                      setTimeout(() => {
                        document.getElementById(`p-${b.paragraphIndex}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                      }, 600)
                    }}
                    className="w-full flex items-center gap-3 bg-white rounded-2xl border border-gray-100 shadow-sm px-4 py-3 hover:shadow-md active:bg-gray-50 transition-all text-right"
                  >
                    <div className="text-forest-600 flex-shrink-0">
                      <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                        <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p
                        className="text-base text-forest-900 font-medium truncate"
                        style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}
                      >
                        {b.surahName}
                      </p>
                      {b.ayatLabel && (
                        <p className="text-xs text-gray-400 mt-0.5">{b.ayatLabel}</p>
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
