import { useEffect, useState, useCallback, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import ParagraphCard from '../components/ParagraphCard'
import FootnoteModal from '../components/FootnoteModal'
import { SURAHS } from '../data/surahs'
import { findFootnote } from '../utils/textUtils'
import { saveLastRead, getLastRead, toggleBookmark, isBookmarked, getBookmarks } from '../utils/progress'

const API = '/data/surah'

export default function SurahView() {
  const { id } = useParams()
  const navigate = useNavigate()
  const surahNum = parseInt(id, 10)

  const [paragraphs, setParagraphs]       = useState([])
  const [loading, setLoading]             = useState(true)
  const [error, setError]                 = useState(null)
  const [activeFootnote, setActiveFootnote] = useState(null)
  const [bookmarks, setBookmarks]         = useState(() => getBookmarks())
  const [scrolledToSaved, setScrolledToSaved] = useState(false)

  const surahMeta  = SURAHS[surahNum - 1]
  const surahName  = surahMeta?.[1] ?? `سورہ ${surahNum}`
  const mainRef    = useRef(null)

  // Load surah data
  useEffect(() => {
    setLoading(true)
    setError(null)
    setParagraphs([])
    setScrolledToSaved(false)
    fetch(`${API}-${surahNum}.json`)
      .then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json() })
      .then((data) => setParagraphs(Array.isArray(data) ? data : data.data))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [surahNum])

  // Save last-read surah on enter; scroll to saved paragraph if returning
  useEffect(() => {
    if (!paragraphs.length || scrolledToSaved) return
    saveLastRead(surahNum, 0, surahName)
    const saved = getLastRead()
    if (saved?.surah === surahNum && saved.paragraphIndex > 0) {
      setTimeout(() => {
        document.getElementById(`p-${saved.paragraphIndex}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }, 150)
    }
    setScrolledToSaved(true)
  }, [paragraphs, surahNum, surahName, scrolledToSaved])

  // Track visible paragraph → update last-read position
  useEffect(() => {
    if (!paragraphs.length) return
    const els = document.querySelectorAll('[id^="p-"]')
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((e) => e.isIntersecting)
        if (visible) {
          const idx = parseInt(visible.target.id.replace('p-', ''), 10)
          saveLastRead(surahNum, idx, surahName)
        }
      },
      { threshold: 0.3 }
    )
    els.forEach((el) => observer.observe(el))
    return () => observer.disconnect()
  }, [paragraphs, surahNum, surahName])

  const handleFootnoteClick = useCallback(
    (cid) => {
      for (const p of paragraphs) {
        const fn = findFootnote(p.albcomur, cid)
        if (fn) { setActiveFootnote(fn); return }
      }
    },
    [paragraphs]
  )

  const handleBookmarkToggle = useCallback((paragraphIndex, meta) => {
    const next = toggleBookmark(surahNum, paragraphIndex, { surahName, ...meta })
    setBookmarks(next)
  }, [surahNum, surahName])

  const prevSurah = surahNum > 1   ? surahNum - 1 : null
  const nextSurah = surahNum < 114 ? surahNum + 1 : null

  return (
    <div className="min-h-screen bg-cream" dir="rtl">
      {/* Sticky header */}
      <header className="sticky top-0 z-10 bg-forest-900 text-white shadow-lg"
        style={{ paddingTop: 'env(safe-area-inset-top, 0)' }}>
        <div className="max-w-3xl mx-auto px-3 sm:px-4 py-2 sm:py-3 flex items-center gap-2">
          <button
            onClick={() => navigate('/')}
            className="flex-shrink-0 w-10 h-10 flex items-center justify-center rounded-xl hover:bg-white/10 active:bg-white/20 transition-colors text-xl"
            aria-label="فہرست"
          >
            ←
          </button>

          <div className="flex-1 text-center min-w-0">
            {surahMeta && (
              <>
                <span
                  className="text-lg sm:text-xl text-yellow-200 block leading-tight"
                  style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}
                >
                  {surahMeta[1]}
                </span>
                <span
                  className="text-xs text-white/60 block"
                  style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
                >
                  {surahMeta[4]} · {surahMeta[3]} آیات
                </span>
              </>
            )}
          </div>

          <div className="flex-shrink-0 flex gap-0.5">
            {nextSurah && (
              <button
                onClick={() => navigate(`/surah/${nextSurah}`)}
                className="w-10 h-10 flex items-center justify-center rounded-xl hover:bg-white/10 active:bg-white/20 transition-colors"
                aria-label="اگلی سورہ"
              >
                ‹
              </button>
            )}
            {prevSurah && (
              <button
                onClick={() => navigate(`/surah/${prevSurah}`)}
                className="w-10 h-10 flex items-center justify-center rounded-xl hover:bg-white/10 active:bg-white/20 transition-colors"
                aria-label="پچھلی سورہ"
              >
                ›
              </button>
            )}
          </div>
        </div>
      </header>

      <main ref={mainRef} className="max-w-3xl mx-auto px-2 sm:px-3 py-4 sm:py-5"
        style={{ paddingBottom: 'calc(4rem + env(safe-area-inset-bottom, 0px))' }}>

        {/* Bismillah */}
        {surahNum !== 9 && (
          <div className="text-center mb-4 py-3 sm:py-4 bg-white rounded-2xl shadow-sm border border-gray-100">
            <span
              className="text-xl sm:text-2xl text-forest-900"
              style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif", lineHeight: '3rem' }}
            >
              بِسۡمِ اللّٰہِ الرَّحۡمٰنِ الرَّحِیۡمِ
            </span>
          </div>
        )}

        {loading && (
          <div className="text-center py-20">
            <div className="inline-block w-10 h-10 border-4 border-forest-200 border-t-forest-700 rounded-full animate-spin" />
            <p className="urdu-text text-gray-400 mt-4 text-sm">لوڈ ہو رہا ہے...</p>
          </div>
        )}

        {error && (
          <div className="text-center py-20 text-red-500 urdu-text text-sm">خرابی: {error}</div>
        )}

        {!loading && !error && paragraphs.map((p, i) => (
          <ParagraphCard
            key={i}
            paragraph={p}
            paragraphIndex={i}
            surahNum={surahNum}
            onFootnoteClick={handleFootnoteClick}
            bookmarked={isBookmarked(surahNum, i)}
            onBookmarkToggle={handleBookmarkToggle}
          />
        ))}

        {/* Bottom nav */}
        {!loading && !error && (
          <div className="flex gap-2 mt-6">
            {nextSurah ? (
              <button
                onClick={() => navigate(`/surah/${nextSurah}`)}
                className="flex-1 py-3 bg-forest-800 text-white rounded-xl text-sm sm:text-base hover:bg-forest-700 active:bg-forest-900 transition-colors"
                style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
              >
                اگلی سورہ ›
              </button>
            ) : <div className="flex-1" />}

            {prevSurah ? (
              <button
                onClick={() => navigate(`/surah/${prevSurah}`)}
                className="flex-1 py-3 bg-white text-forest-800 rounded-xl border border-forest-200 text-sm sm:text-base hover:bg-forest-50 active:bg-forest-100 transition-colors"
                style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
              >
                ‹ پچھلی سورہ
              </button>
            ) : <div className="flex-1" />}
          </div>
        )}
      </main>

      <FootnoteModal footnote={activeFootnote} onClose={() => setActiveFootnote(null)} />
    </div>
  )
}
