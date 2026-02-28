import { useState, useEffect, useCallback, useRef } from 'react'

// Split Arabic text into words (handles Arabic punctuation)
const splitWords = (text) => {
  if (!text) return []
  // Split by whitespace and Arabic punctuation
  return text.trim().split(/[\s\u060C\u061B\u061F]+/).filter(w => w.length > 0)
}

// Word highlighter component
function WordHighlighter({ 
  text, 
  isPlaying, 
  duration = 0, 
  fontFamily,
  fontSize,
  onWordChange 
}) {
  const words = splitWords(text)
  const [currentIndex, setCurrentIndex] = useState(-1)
  const intervalRef = useRef(null)
  const startTimeRef = useRef(null)

  const startHighlighting = useCallback(() => {
    if (words.length === 0 || duration <= 0) return
    
    // Calculate time per word (with slight adjustment for natural rhythm)
    const avgTimePerWord = (duration * 1000) / words.length
    // Add 20% extra for first word, reduce for later words
    const timePerWord = avgTimePerWord * 0.9
    
    startTimeRef.current = Date.now()
    setCurrentIndex(0)
    
    intervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTimeRef.current
      const index = Math.min(Math.floor(elapsed / timePerWord), words.length - 1)
      
      if (index !== currentIndex) {
        setCurrentIndex(index)
        onWordChange?.(index)
      }
      
      if (index >= words.length - 1) {
        clearInterval(intervalRef.current)
      }
    }, 50) // Check every 50ms for smooth updates
  }, [words, duration, currentIndex, onWordChange])

  const stopHighlighting = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
    setCurrentIndex(-1)
    startTimeRef.current = null
  }, [])

  useEffect(() => {
    if (isPlaying) {
      // Small delay to sync with audio start
      const timeout = setTimeout(startHighlighting, 100)
      return () => clearTimeout(timeout)
    } else {
      stopHighlighting()
    }
  }, [isPlaying, startHighlighting, stopHighlighting])

  useEffect(() => {
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
  }, [])

  if (words.length === 0) return null

  return (
    <span dir="rtl" style={{ fontFamily, fontSize: `${fontSize}px` }}>
      {words.map((word, index) => (
        <span
          key={index}
          className={`transition-all duration-150 rounded px-0.5 ${
            index === currentIndex 
              ? 'bg-emerald-200 text-emerald-900 font-medium' 
              : 'text-gray-900'
          }`}
          style={{
            opacity: currentIndex === -1 || index <= currentIndex ? 1 : 0.4
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
