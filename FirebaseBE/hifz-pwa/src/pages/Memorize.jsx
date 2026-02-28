import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useStore } from '../hooks/useStore'
import { useSpeech } from '../hooks/useSpeech'

function Memorize() {
  const { groupId } = useParams()
  const navigate = useNavigate()
  const { groups, updateLineStatus, getGroupProgress } = useStore()
  const { speak, stop, speaking } = useSpeech()
  
  const group = groups.find(g => g.id === groupId)
  const [currentIndex, setCurrentIndex] = useState(0)
  const [showTranslation, setShowTranslation] = useState(false)
  
  useEffect(() => {
    return () => stop()
  }, [stop])
  
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
          onClick={() => navigate('/admin')}
          className="mt-4 text-emerald-600 font-medium"
        >
          Add lines →
        </button>
      </div>
    )
  }
  
  const currentLine = group.lines[currentIndex]
  const progress = ((currentIndex + 1) / group.lines.length) * 100
  const groupProgress = getGroupProgress(groupId)
  
  const handlePlay = () => {
    speak(currentLine.arabic)
  }
  
  const handleStatus = (status) => {
    updateLineStatus(groupId, currentLine.id, status)
    
    // Move to next line
    if (currentIndex < group.lines.length - 1) {
      setCurrentIndex(prev => prev + 1)
      setShowTranslation(false)
      stop()
    } else {
      // Finished all lines
      stop()
      alert('Great job! You\'ve reviewed all lines. 🎉')
      setCurrentIndex(0)
    }
  }
  
  const handleNext = () => {
    if (currentIndex < group.lines.length - 1) {
      setCurrentIndex(prev => prev + 1)
      setShowTranslation(false)
      stop()
    }
  }
  
  const handlePrev = () => {
    if (currentIndex > 0) {
      setCurrentIndex(prev => prev - 1)
      setShowTranslation(false)
      stop()
    }
  }
  
  return (
    <div className="h-full flex flex-col bg-gradient-to-b from-emerald-50 to-white">
      {/* Header */}
      <div className="bg-white px-4 py-3 border-b border-gray-100">
        <div className="flex items-center justify-between">
          <button 
            onClick={() => navigate('/groups')}
            className="p-2 -ml-2 touch-btn"
          >
            <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div className="text-center">
            <h1 className="font-semibold text-gray-900">{group.name}</h1>
            <p className="text-xs text-gray-500">
              {currentIndex + 1} / {group.lines.length}
            </p>
          </div>
          <div className="w-10" /> {/* Spacer */}
        </div>
        
        {/* Progress bar */}
        <div className="mt-3 h-1 bg-gray-100 rounded-full overflow-hidden">
          <div 
            className="h-full bg-emerald-500 transition-all duration-300"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>
      
      {/* Card */}
      <div className="flex-1 flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          {/* Main Card */}
          <div 
            className="bg-white rounded-3xl shadow-lg p-8 text-center card-enter"
            onClick={() => setShowTranslation(!showTranslation)}
          >
            {/* Arabic Text */}
            <p 
              className="font-arabic text-3xl leading-relaxed text-gray-900"
              dir="rtl"
            >
              {currentLine.arabic}
            </p>
            
            {/* Play Button */}
            <button
              onClick={(e) => {
                e.stopPropagation()
                handlePlay()
              }}
              disabled={speaking}
              className="mt-6 w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto touch-btn disabled:opacity-50"
            >
              {speaking ? (
                <span className="text-2xl">🔊</span>
              ) : (
                <svg className="w-8 h-8 text-emerald-600 ml-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
              )}
            </button>
            
            {/* Translation (Tap to reveal) */}
            <div className="mt-6 min-h-[60px]">
              {showTranslation && currentLine.translation ? (
                <p className="text-gray-600 text-sm animate-fade-in">
                  {currentLine.translation}
                </p>
              ) : (
                <p className="text-gray-400 text-sm">
                  {currentLine.translation ? 'Tap to show translation' : ''}
                </p>
              )}
            </div>
            
            {/* Status Indicator */}
            <div className="mt-4">
              {currentLine.status === 'memorized' && (
                <span className="inline-flex items-center gap-1 text-emerald-600 text-sm font-medium">
                  ✅ Memorized
                </span>
              )}
              {currentLine.status === 'learning' && (
                <span className="inline-flex items-center gap-1 text-yellow-600 text-sm font-medium">
                  📖 Learning
                </span>
              )}
              {currentLine.status === 'not_started' && (
                <span className="inline-flex items-center gap-1 text-gray-400 text-sm">
                  🆕 New
                </span>
              )}
            </div>
          </div>
          
          {/* Navigation Dots */}
          <div className="flex justify-center gap-2 mt-6">
            {group.lines.map((_, idx) => (
              <button
                key={idx}
                onClick={() => {
                  setCurrentIndex(idx)
                  setShowTranslation(false)
                  stop()
                }}
                className={`w-2 h-2 rounded-full transition-all ${
                  idx === currentIndex ? 'bg-emerald-500 w-4' : 'bg-gray-300'
                }`}
              />
            ))}
          </div>
        </div>
      </div>
      
      {/* Action Buttons */}
      <div className="bg-white border-t border-gray-100 px-4 py-4 pb-safe space-y-3">
        {/* Status Buttons */}
        <div className="grid grid-cols-3 gap-3">
          <button
            onClick={() => handleStatus('not_started')}
            className="py-3 rounded-xl bg-gray-100 text-gray-700 font-medium text-sm touch-btn"
          >
            😅 Forgot
          </button>
          <button
            onClick={() => handleStatus('learning')}
            className="py-3 rounded-xl bg-yellow-100 text-yellow-700 font-medium text-sm touch-btn"
          >
            🤔 Partial
          </button>
          <button
            onClick={() => handleStatus('memorized')}
            className="py-3 rounded-xl bg-emerald-100 text-emerald-700 font-medium text-sm touch-btn"
          >
            ✅ Got it
          </button>
        </div>
        
        {/* Prev/Next */}
        <div className="flex gap-3">
          <button
            onClick={handlePrev}
            disabled={currentIndex === 0}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-50"
          >
            ← Previous
          </button>
          <button
            onClick={handleNext}
            disabled={currentIndex === group.lines.length - 1}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-50"
          >
            Next →
          </button>
        </div>
      </div>
    </div>
  )
}

export default Memorize
