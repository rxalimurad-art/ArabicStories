import { useEffect, useState, useCallback, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import ParagraphCard from '../components/ParagraphCard'
import FootnoteModal from '../components/FootnoteModal'
import { SURAHS } from '../data/surahs'
import { findFootnote } from '../utils/textUtils'
import {
  saveLastRead, getLastRead,
  toggleBookmark, isBookmarked, getBookmarks,
  updateSurahProgress, markSurahComplete,
  getSurahPercent, updateStreak,
} from '../utils/progress'

const API = '/data/surah'

export default function SurahView() {
  const { id } = useParams()
  const navigate = useNavigate()
  const surahNum = parseInt(id, 10)

  const [paragraphs, setParagraphs]           = useState([])
  const [loading, setLoading]                 = useState(true)
  const [error, setError]                     = useState(null)
  const [activeFootnote, setActiveFootnote]   = useState(null)
  const [bookmarks, setBookmarks]             = useState(() => getBookmarks())
  const [scrolledToSaved, setScrolledToSaved] = useState(false)
  const [surahPct, setSurahPct]               = useState(0)

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

  // On load: update streak, save last-read, scroll to saved position
  useEffect(() => {
    if (!paragraphs.length || scrolledToSaved) return
    updateStreak()
    saveLastRead(surahNum, 0, surahName)
    setSurahPct(getSurahPercent(surahNum))
    const saved = getLastRead()
    if (saved?.surah === surahNum && saved.paragraphIndex > 0) {
      setTimeout(() => {
        document.getElementById(`p-${saved.paragraphIndex}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }, 150)
    }
    setScrolledToSaved(true)
  }, [paragraphs, surahNum, surahName, scrolledToSaved])

  // IntersectionObserver: track reading progress as paragraphs come into view
  useEffect(() => {
    if (!paragraphs.length) return
    const total = paragraphs.filter((p) => p.paragraph !== '0' && p.paragraph !== 0).length
    const els = document.querySelectorAll('[id^="p-"]')

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            const idx = parseInt(e.target.id.replace('p-', ''), 10)
            saveLastRead(surahNum, idx, surahName)
            updateSurahProgress(surahNum, idx, total)
            setSurahPct(getSurahPercent(surahNum))
          }
        })
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

  const handleDone = () => {
    const total = paragraphs.filter((p) => p.paragraph !== '0' && p.paragraph !== 0).length
    markSurahComplete(surahNum, total)
    setSurahPct(100)
    if (nextSurah) navigate(`/surah/${nextSurah}`)
    else navigate('/')
  }

  const prevSurah = surahNum > 1   ? surahNum - 1 : null
  const nextSurah = surahNum < 114 ? surahNum + 1 : null

  return (
    <div className="min-h-screen" dir="rtl"
      style={{ background: 'linear-gradient(160deg, #3b0764 0%, #4c1d95 40%, #5b21b6 100%)' }}>

      {/* ── Sticky Header ── */}
      <header className="sticky top-0 z-10 shadow-lg"
        style={{
          paddingTop: 'env(safe-area-inset-top, 0)',
          background: 'linear-gradient(135deg, #3b0764 0%, #4c1d95 100%)',
        }}>
        <div className="max-w-3xl mx-auto px-3 sm:px-4 py-2 sm:py-3 flex items-center gap-2">
          {/* Back */}
          <button onClick={() => navigate('/')}
            className="flex-shrink-0 w-10 h-10 flex items-center justify-center rounded-xl bg-white/10 hover:bg-white/20 active:bg-white/30 transition-colors text-white text-xl"
            aria-label="فہرست">
            ←
          </button>

          {/* Surah name */}
          <div className="flex-1 text-center min-w-0">
            {surahMeta && (
              <>
                <span className="text-lg sm:text-xl text-yellow-300 block leading-tight"
                  style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
                  {surahMeta[1]}
                </span>
                <span className="text-xs text-white/50 block"
                  style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                  {surahMeta[4]} · {surahMeta[3]} آیات
                </span>
              </>
            )}
          </div>

          {/* Prev/Next surah */}
          <div className="flex-shrink-0 flex gap-0.5">
            {nextSurah && (
              <button onClick={() => navigate(`/surah/${nextSurah}`)}
                className="w-10 h-10 flex items-center justify-center rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors"
                aria-label="اگلی سورہ">‹</button>
            )}
            {prevSurah && (
              <button onClick={() => navigate(`/surah/${prevSurah}`)}
                className="w-10 h-10 flex items-center justify-center rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors"
                aria-label="پچھلی سورہ">›</button>
            )}
          </div>
        </div>

        {/* Surah progress bar */}
        {surahPct > 0 && (
          <div className="max-w-3xl mx-auto px-3 pb-2">
            <div className="flex items-center justify-between mb-1">
              <span className="text-white/40 text-xs"
                style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
                {surahPct === 100 ? '✓ مکمل' : 'پیش رفت'}
              </span>
              <span className="text-yellow-300 text-xs font-semibold">{surahPct}%</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: `${surahPct}%` }} />
            </div>
          </div>
        )}
      </header>

      <main ref={mainRef} className="max-w-3xl mx-auto px-3 sm:px-4 py-4 sm:py-5"
        style={{ paddingBottom: 'calc(5rem + env(safe-area-inset-bottom, 0px))' }}>

        {/* Bismillah */}
        {surahNum !== 9 && !loading && !error && (
          <div className="text-center mb-5 py-4 bg-white/10 backdrop-blur-sm rounded-2xl border border-white/20">
            <span className="text-xl sm:text-2xl text-yellow-200"
              style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif", lineHeight: '3rem' }}>
              بِسۡمِ اللّٰہِ الرَّحۡمٰنِ الرَّحِیۡمِ
            </span>
          </div>
        )}

        {loading && (
          <div className="text-center py-20">
            <div className="inline-block w-10 h-10 border-4 border-violet-300/30 border-t-yellow-300 rounded-full animate-spin" />
            <p className="text-white/50 mt-4 text-sm" style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
              لوڈ ہو رہا ہے...
            </p>
          </div>
        )}

        {error && (
          <div className="text-center py-20 text-red-300 text-sm"
            style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}>
            خرابی: {error}
          </div>
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

        {/* ── Bottom navigation ── */}
        {!loading && !error && (
          <div className="flex items-center gap-2 mt-6">
            {/* Prev surah */}
            {prevSurah ? (
              <button onClick={() => navigate(`/surah/${prevSurah}`)}
                className="w-12 h-12 flex-shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white text-xl transition-colors border border-white/20"
                aria-label="پچھلی سورہ">›</button>
            ) : <div className="w-12" />}

            {/* Done button */}
            <button onClick={handleDone}
              className="flex-1 py-3.5 rounded-full font-semibold text-sm sm:text-base transition-all active:scale-95 shadow-lg"
              style={{
                background: surahPct === 100
                  ? 'linear-gradient(135deg, #059669, #10b981)'
                  : '#1a1a2e',
                color: '#fff',
                fontFamily: "'Noto Nastaliq Urdu', serif",
              }}>
              {surahPct === 100 ? '✓ مکمل — اگلی سورہ' : 'مکمل کیا'}
            </button>

            {/* Next surah */}
            {nextSurah ? (
              <button onClick={() => navigate(`/surah/${nextSurah}`)}
                className="w-12 h-12 flex-shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white text-xl transition-colors border border-white/20"
                aria-label="اگلی سورہ">‹</button>
            ) : <div className="w-12" />}
          </div>
        )}
      </main>

      <FootnoteModal footnote={activeFootnote} onClose={() => setActiveFootnote(null)} />
    </div>
  )
}
