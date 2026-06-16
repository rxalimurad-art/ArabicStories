import { useState } from 'react'
import { parseTranslation } from '../utils/textUtils'

function BookmarkIcon({ filled }) {
  return (
    <svg viewBox="0 0 24 24" className="w-4 h-4"
      fill={filled ? 'currentColor' : 'none'}
      stroke="currentColor" strokeWidth={2}
      strokeLinecap="round" strokeLinejoin="round">
      <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
    </svg>
  )
}

export default function ParagraphCard({
  paragraph, paragraphIndex, surahNum,
  onFootnoteClick, bookmarked, onBookmarkToggle,
}) {
  const [tafseerOpen, setTafseerOpen] = useState(false)

  const { paragraph: pNum, ayat, arabic, albtraur, tadcomur, albparagraph } = paragraph

  const isHeader = pNum === '0' || pNum === 0

  const ayatLabel =
    ayat && ayat.length > 0 && ayat[0] !== 0
      ? ayat.length === 1
        ? `آیت ${ayat[0]}`
        : `آیات ${ayat[0]}–${ayat[ayat.length - 1]}`
      : null

  const hasTafseer = Array.isArray(tadcomur) && tadcomur.length > 0

  if (isHeader) {
    return (
      <div className="text-center py-3">
        <span className="text-yellow-200 text-lg"
          style={{ fontFamily: "'IndoPak', 'Amiri Quran', serif" }}>
          {arabic}
        </span>
      </div>
    )
  }

  return (
    <div id={`p-${paragraphIndex}`} className="mb-5 sm:mb-6">

      {/* ── White Arabic card ── */}
      <div className="bg-white rounded-2xl shadow-xl overflow-hidden">

        {/* Card top bar: ayat label + bookmark */}
        <div className="flex items-center justify-between px-4 pt-3 pb-1">
          <div className="flex items-center gap-2">
            {ayatLabel && (
              <span className="text-xs bg-violet-100 text-violet-700 rounded-full px-2.5 py-0.5 font-medium">
                {ayatLabel}
              </span>
            )}
          </div>
          <button
            onClick={() => onBookmarkToggle(paragraphIndex, { ayatLabel, arabic: arabic?.slice(0, 40) })}
            className={`p-2 rounded-full transition-colors ${
              bookmarked
                ? 'text-violet-600 bg-violet-50'
                : 'text-gray-300 hover:text-violet-500 hover:bg-violet-50'
            }`}
            aria-label={bookmarked ? 'بک مارک ہٹائیں' : 'بک مارک کریں'}
          >
            <BookmarkIcon filled={bookmarked} />
          </button>
        </div>

        {/* Arabic text — large, centered */}
        {arabic && (
          <div className="px-4 sm:px-6 pt-2 pb-5">
            <p className="arabic-text">{arabic}</p>
          </div>
        )}
      </div>

      {/* ── Urdu translation — on purple background ── */}
      {albtraur && (
        <div className="px-4 sm:px-5 py-4">
          <div className="urdu-text leading-loose">
            {parseTranslation(albtraur, onFootnoteClick)}
          </div>
        </div>
      )}

      {/* ── Tafseer toggle ── */}
      {hasTafseer && (
        <div className="px-4 sm:px-5">
          <button
            onClick={() => setTafseerOpen((v) => !v)}
            className="flex items-center gap-2 py-2 px-4 rounded-xl bg-white/10 hover:bg-white/20 active:bg-white/30 text-white/80 hover:text-white transition-colors text-sm border border-white/15"
            style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
          >
            <span className="text-yellow-300 text-xs">{tafseerOpen ? '▲' : '▼'}</span>
            <span>{tafseerOpen ? 'تفسیر بند کریں' : 'تفسیر پڑھیں'}</span>
          </button>

          {tafseerOpen && (
            <div className="mt-3 bg-white/10 backdrop-blur-sm rounded-2xl border border-white/15 px-4 sm:px-5 py-4 space-y-4">
              {tadcomur.map((item, idx) => (
                <div key={idx} className={idx > 0 ? 'pt-4 border-t border-white/10' : ''}>
                  <div
                    className="urdu-text tafseer-html"
                    dangerouslySetInnerHTML={{ __html: item }}
                  />
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Separator */}
      <div className="mt-4 mx-4 h-px bg-white/10" />
    </div>
  )
}
