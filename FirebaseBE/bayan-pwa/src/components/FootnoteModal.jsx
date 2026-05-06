import { useEffect } from 'react'

export default function FootnoteModal({ footnote, onClose }) {
  useEffect(() => {
    if (!footnote) return
    const onKey = (e) => e.key === 'Escape' && onClose()
    // prevent body scroll while open
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKey)
    return () => {
      document.body.style.overflow = ''
      window.removeEventListener('keydown', onKey)
    }
  }, [footnote, onClose])

  if (!footnote) return null

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-sheet" onClick={(e) => e.stopPropagation()}>
        {/* Drag handle (mobile only) */}
        <div className="modal-drag-handle" />

        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
          <h2
            className="text-lg font-bold text-forest-800"
            style={{ fontFamily: "'Noto Nastaliq Urdu', serif" }}
          >
            حاشیہ [{footnote.cid}]
          </h2>
          <button
            onClick={onClose}
            className="w-9 h-9 flex items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 active:bg-gray-200 transition-colors text-lg"
            aria-label="بند کریں"
          >
            ✕
          </button>
        </div>

        {/* Body */}
        <div className="px-5 py-5 pb-[env(safe-area-inset-bottom,1.25rem)]">
          <div
            className="urdu-text tafseer-html leading-relaxed"
            dangerouslySetInnerHTML={{ __html: footnote.comment }}
          />
        </div>
      </div>
    </div>
  )
}
