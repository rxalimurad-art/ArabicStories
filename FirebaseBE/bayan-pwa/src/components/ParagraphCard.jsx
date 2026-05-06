import { useState } from 'react'
import { parseTranslation } from '../utils/textUtils'

function BookmarkIcon({ filled }) {
  return (
    <svg viewBox="0 0 24 24" className="w-5 h-5" fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
    </svg>
  )
}

export default function ParagraphCard({ paragraph, paragraphIndex, surahNum, onFootnoteClick, bookmarked, onBookmarkToggle }) {
  const [tafseerOpen, setTafseerOpen] = useState(false)

  const {
    paragraph: pNum,
    ayat,
    arabic,
    albtraur,
    tadtraur,
    tadcomur,
    albparagraph,
  } = paragraph

  const isHeader = pNum === '0' || pNum === 0

  const ayatLabel =
    ayat && ayat.length > 0 && ayat[0] !== 0
      ? ayat.length === 1
        ? `آیت ${ayat[0]}`
        : `آیات ${ayat[0]} – ${ayat[ayat.length - 1]}`
      : null

  const hasTafseer = Array.isArray(tadcomur) && tadcomur.length > 0

  if (isHeader) {
    return (
      <div className="text-center py-4">
        <span className="arabic-text font-bold text-forest-900">{arabic}</span>
      </div>
    )
  }

  return (
    <div
      id={`p-${paragraphIndex}`}
      className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-3 sm:mb-4"
    >
      {/* Top bar: paragraph label + ayat range + bookmark */}
      <div className="flex items-center justify-between px-3 sm:px-5 pt-3 pb-1">
        <div className="flex items-center gap-2">
          {ayatLabel && (
            <span className="text-xs bg-forest-100 text-forest-800 rounded-full px-2.5 py-0.5 font-medium">
              {ayatLabel}
            </span>
          )}
          <span className="text-xs text-gray-300">·</span>
          <span
            className="text-xs text-gray-400"
            style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
          >
            پیراگراف {albparagraph || pNum}
          </span>
        </div>

        {/* Bookmark button */}
        <button
          onClick={() => onBookmarkToggle(paragraphIndex, { ayatLabel, arabic: arabic?.slice(0, 40) })}
          className={`p-2 rounded-full transition-colors ${
            bookmarked
              ? 'text-forest-700 bg-forest-50'
              : 'text-gray-300 hover:text-forest-500 hover:bg-forest-50 active:bg-forest-100'
          }`}
          aria-label={bookmarked ? 'بک مارک ہٹائیں' : 'بک مارک کریں'}
        >
          <BookmarkIcon filled={bookmarked} />
        </button>
      </div>

      {/* Arabic text */}
      {arabic && (
        <div className="px-3 sm:px-5 py-3 sm:py-4 border-b border-gray-50">
          <p className="arabic-text">{arabic}</p>
        </div>
      )}

      {/* Al-Bayan Urdu translation */}
      {albtraur && (
        <div className="px-3 sm:px-5 py-3 sm:py-4">
          <div className="urdu-text leading-loose">
            {parseTranslation(albtraur, onFootnoteClick)}
          </div>
        </div>
      )}

      {/* Tadabbur translation (if different) */}
      {tadtraur && tadtraur !== albtraur && (
        <div className="px-3 sm:px-5 py-2 border-t border-dashed border-gray-100">
          <p className="text-xs text-gray-400 mb-1 text-left">ترجمہ – تدبر</p>
          <div className="urdu-text text-gray-600 leading-loose">{tadtraur}</div>
        </div>
      )}

      {/* Tafseer toggle */}
      {hasTafseer && (
        <div className="border-t border-gray-100">
          <button
            onClick={() => setTafseerOpen((v) => !v)}
            className="w-full flex items-center gap-2 px-3 sm:px-5 py-3 text-forest-700 hover:bg-forest-50 active:bg-forest-100 transition-colors"
          >
            <span className="text-xs">{tafseerOpen ? '▲' : '▼'}</span>
            <span
              className="text-sm sm:text-base text-forest-700"
              style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
            >
              {tafseerOpen ? 'تفسیر بند کریں' : 'تفسیر دیکھیں'}
            </span>
          </button>

          {tafseerOpen && (
            <div className="px-3 sm:px-5 pb-4 space-y-3 bg-gray-50">
              {tadcomur.map((item, idx) => (
                <div key={idx} className="pt-3 border-t border-gray-100 first:border-0">
                  <div
                    className="urdu-text tafseer-html text-gray-700"
                    dangerouslySetInnerHTML={{ __html: item }}
                  />
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
