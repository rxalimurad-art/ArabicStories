import React from 'react'

// Parses albtraur HTML containing =N= footnote markers into React elements.
export function parseTranslation(html, onFootnoteClick) {
  if (!html) return null
  const parts = html.split(/(=\d+=)/g)
  return parts.map((part, i) => {
    const match = part.match(/^=(\d+)=$/)
    if (match) {
      const num = parseInt(match[1], 10)
      return (
        <button key={i} className="footnote-btn" onClick={() => onFootnoteClick(num)}>
          [{num}]
        </button>
      )
    }
    return <span key={i} dangerouslySetInnerHTML={{ __html: part }} />
  })
}

// Returns the footnote comment object matching the given cid, or null.
export function findFootnote(albcomur, cid) {
  if (!Array.isArray(albcomur)) return null
  return albcomur.find((c) => c.cid === cid) ?? null
}
