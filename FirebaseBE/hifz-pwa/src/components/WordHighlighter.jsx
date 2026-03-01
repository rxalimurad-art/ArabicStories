import { useMemo } from 'react'

// Split Arabic text into words (handles Arabic punctuation)
const splitWords = (text) => {
  if (!text) return []
  // Split by whitespace and Arabic punctuation
  return text.trim().split(/[\s\u060C\u061B\u061F]+/).filter(w => w.length > 0)
}

// Word highlighter component - uses actual speech progress
function WordHighlighter({ 
  text, 
  currentWordIndex = -1, // Direct word index from speech
  fontFamily,
  fontSize,
}) {
  const words = useMemo(() => splitWords(text), [text])

  if (words.length === 0) return null

  return (
    <span dir="rtl" style={{ fontFamily, fontSize: `${fontSize}px` }}>
      {words.map((word, index) => (
        <span
          key={index}
          className={`transition-all duration-150 rounded px-0.5 ${
            index === currentWordIndex 
              ? 'bg-emerald-200 text-emerald-900 font-medium' 
              : 'text-gray-900'
          }`}
          style={{
            opacity: currentWordIndex === -1 || index <= currentWordIndex ? 1 : 0.4
          }}
        >
          {word}
          {index < words.length - 1 && ' '}
        </span>
      ))}
    </span>
  )
}

export default WordHighlighter
