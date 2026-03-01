import { useState, useEffect, useCallback, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useStore } from '../hooks/useStore'
import { useSpeech } from '../hooks/useSpeech'
import { useFont } from '../hooks/useFont'
import { useHaptic } from '../hooks/useHaptic'
import { useSwipe } from '../hooks/useSwipe'
import WordHighlighter from '../components/WordHighlighter'

function Memorize() {
  const { groupId } = useParams()
  const navigate = useNavigate()
  const { groups, updateLineStatus, getGroupProgress } = useStore()
  const { speak, stop, speaking, currentWordIndex } = useSpeech()
  const { font, fontSize } = useFont()
  const { light, medium, success, error: hapticError } = useHaptic()
  
  const group = groups.find(g => g.id === groupId)
  const [currentIndex, setCurrentIndex] = useState(0)
  const [showTranslation, setShowTranslation] = useState(false)
  const cardRef = useRef(null)
  
  // Stop audio on unmount
  useEffect(() => {
    return () => stop()
  }, [stop])
  
  const handlePlay = useCallback(() => {
    light()
    speak(group.lines[currentIndex].arabic)
  }, [group, currentIndex, speak, light])
  
  const handleStatus = useCallback((status) => {
    // Haptic feedback based on status
    if (status === 'memorized') success()
    else if (status === 'not_started') hapticError()
    else medium()
    
    updateLineStatus(groupId, group.lines[currentIndex].id, status)
    
    if (currentIndex < group.lines.length - 1) {
      setCurrentIndex(prev => prev + 1)
      setShowTranslation(false)
      stop()
    } else {
      stop()
      success()
      // Simple completion message without alert
      setTimeout(() => {
        if (confirm('Great job! You\'ve reviewed all lines. Start over?')) {
          setCurrentIndex(0)
          setShowTranslation(false)
        }
      }, 100)
    }
  }, [group, currentIndex, groupId, updateLineStatus, stop, success, hapticError, medium])
  
  const handleNext = useCallback(() => {
    if (currentIndex < group.lines.length - 1) {
      light()
      setCurrentIndex(prev => prev + 1)
      setShowTranslation(false)
      stop()
    }
  }, [currentIndex, group, stop, light])
  
  const handlePrev = useCallback(() => {
    if (currentIndex > 0) {
      light()
      setCurrentIndex(prev => prev - 1)
      setShowTranslation(false)
      stop()
    }
  }, [currentIndex, stop, light])
  
  // Swipe handlers
  const swipeHandlers = useSwipe({
    onSwipeLeft: () => {
      medium()
      handleNext()
    },
    onSwipeRight: () => {
      medium()
      handlePrev()
    },
    threshold: 60,
    timeout: 400
  })
  
  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'ArrowLeft') handlePrev()
      if (e.key === 'ArrowRight') handleNext()
      if (e.key === ' ') {
        e.preventDefault()
        handlePlay()
      }
      if (e.key === '1') handleStatus('not_started')
      if (e.key === '2') handleStatus('learning')
      if (e.key === '3') handleStatus('memorized')
    }
    
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [handleNext, handlePrev, handlePlay, handleStatus])
  
  if (!group) {
    return (
      <div className="h-full flex items-center justify-center">
        <p>Group not found</p>
      </div>
    )
  }
  
  if (group.lines.length === 0) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-4">
        <span className="text-4xl">📝</span>
        <p className="mt-4 text-gray-600">No lines in this group yet</p>
        <button
          onClick={() => navigate('/groups')}
          className="mt-4 text-emerald-600 font-medium"
        >
          Add lines →
        </button>
      </div>
    )
  }
  
  const currentLine = group.lines[currentIndex]
  const progress = ((currentIndex + 1) / group.lines.length) * 100
  
  return (
    <div className="h-full flex flex-col bg-white">
      {/* Compact Header */}
      <div className="bg-white px-3 py-2 border-b border-gray-100 flex items-center gap-2">
        <button 
          onClick={() => navigate('/')}
          className="p-1.5 -ml-1.5 rounded-lg hover:bg-gray-100 touch-btn"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <div className="flex-1">
          <h1 className="font-medium text-gray-900 text-sm truncate">{group.name}</h1>
          <p className="text-xs text-gray-500">{currentIndex + 1} / {group.lines.length}</p>
        </div>
        {/* Mini Status */}
        <div className="text-xs">
          {currentLine.status === 'memorized' && <span className="text-emerald-600">✅</span>}
          {currentLine.status === 'learning' && <span className="text-yellow-600">📖</span>}
          {currentLine.status === 'not_started' && <span className="text-gray-400">🆕</span>}
        </div>
      </div>
      
      {/* Progress bar */}
      <div className="h-1 bg-gray-100">
        <div 
          className="h-full bg-emerald-500 transition-all duration-300"
          style={{ width: `${progress}%` }}
        />
      </div>
      
      {/* Card - With Swipe Support */}
      <div className="flex-1 flex flex-col p-3">
        <div 
          ref={cardRef}
          className="flex-1 bg-gray-50 rounded-2xl p-4 flex flex-col justify-center select-none"
          onClick={() => setShowTranslation(!showTranslation)}
          {...swipeHandlers}
        >
          {/* Arabic Text - With Word Highlighting */}
          <div className="leading-normal text-center">
            {speaking ? (
              <WordHighlighter
                text={currentLine.arabic}
                currentWordIndex={currentWordIndex}
                fontFamily={font.family}
                fontSize={fontSize}
              />
            ) : (
              <span 
                dir="rtl"
                style={{ fontFamily: font.family, fontSize: `${fontSize}px` }}
                className="text-gray-900"
              >
                {currentLine.arabic}
              </span>
            )}
          </div>
          
          {/* Translation - Compact */}
          <div className="mt-3 text-center">
            {showTranslation && currentLine.translation ? (
              <p className="text-gray-600 text-sm animate-fade-in px-2">
                {currentLine.translation}
              </p>
            ) : currentLine.translation ? (
              <p className="text-gray-400 text-xs">Tap to show translation</p>
            ) : null}
          </div>
          
          {/* Swipe Hint */}
          <p className="text-center text-xs text-gray-400 mt-4">
            ← Swipe left/right →
          </p>
          
          {/* Play Button - At the end of card */}
          <button
            onClick={(e) => {
              e.stopPropagation()
              handlePlay()
            }}
            disabled={speaking}
            className="mt-auto mb-2 w-14 h-14 bg-emerald-500 rounded-full flex items-center justify-center mx-auto touch-btn disabled:opacity-50 shadow-lg"
          >
            {speaking ? (
              <span className="text-xl">🔊</span>
            ) : (
              <svg className="w-6 h-6 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            )}
          </button>
        </div>
        
        {/* Navigation Dots - Compact */}
        <div className="flex justify-center gap-1.5 mt-2">
          {group.lines.map((_, idx) => (
            <button
              key={idx}
              onClick={() => {
                light()
                setCurrentIndex(idx)
                setShowTranslation(false)
                setAudioDuration(0)
                stop()
              }}
              className={`h-1.5 rounded-full transition-all ${
                idx === currentIndex ? 'bg-emerald-500 w-4' : 'bg-gray-300 w-1.5'
              }`}
            />
          ))}
        </div>
      </div>
      
      {/* Action Buttons - Compact */}
      <div className="bg-white border-t border-gray-100 px-3 py-2 pb-safe">
        {/* Status Buttons */}
        <div className="grid grid-cols-3 gap-2">
          <button
            onClick={() => handleStatus('not_started')}
            className="py-2.5 rounded-lg bg-gray-100 text-gray-700 font-medium text-sm touch-btn active:scale-95 transition-transform"
          >
            😅 Forgot
          </button>
          <button
            onClick={() => handleStatus('learning')}
            className="py-2.5 rounded-lg bg-yellow-100 text-yellow-700 font-medium text-sm touch-btn active:scale-95 transition-transform"
          >
            🤔 Partial
          </button>
          <button
            onClick={() => handleStatus('memorized')}
            className="py-2.5 rounded-lg bg-emerald-100 text-emerald-700 font-medium text-sm touch-btn active:scale-95 transition-transform"
          >
            ✅ Got it
          </button>
        </div>
        
        {/* Prev/Next - Compact */}
        <div className="flex gap-2 mt-2">
          <button
            onClick={handlePrev}
            disabled={currentIndex === 0}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-40 active:scale-95 transition-transform"
          >
            ← Prev
          </button>
          <button
            onClick={handleNext}
            disabled={currentIndex === group.lines.length - 1}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-40 active:scale-95 transition-transform"
          >
            Next →
          </button>
        </div>
      </div>
    </div>
  )
}

export default Memorize
