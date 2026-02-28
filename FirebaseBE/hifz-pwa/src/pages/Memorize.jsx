import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useStore } from '../hooks/useStore'
import { useSpeech } from '../hooks/useSpeech'
import { useFont } from '../hooks/useFont'

function Memorize() {
  const { groupId } = useParams()
  const navigate = useNavigate()
  const { groups, updateLineStatus, getGroupProgress } = useStore()
  const { speak, stop, speaking } = useSpeech()
  const { font, fontSize } = useFont()
  
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
  
  const handlePlay = () => {
    speak(currentLine.arabic)
  }
  
  const handleStatus = (status) => {
    updateLineStatus(groupId, currentLine.id, status)
    
    if (currentIndex < group.lines.length - 1) {
      setCurrentIndex(prev => prev + 1)
      setShowTranslation(false)
      stop()
    } else {
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
      
      {/* Card - Compact */}
      <div className="flex-1 flex flex-col p-3">
        <div 
          className="flex-1 bg-gray-50 rounded-2xl p-4 flex flex-col justify-center"
          onClick={() => setShowTranslation(!showTranslation)}
        >
          {/* Arabic Text - Compact */}
          <p 
            className="leading-normal text-gray-900 text-center"
            style={{ fontSize: `${fontSize}px`, fontFamily: font.family }}
            dir="rtl"
          >
            {currentLine.arabic}
          </p>
          
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
                setCurrentIndex(idx)
                setShowTranslation(false)
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
            className="py-2.5 rounded-lg bg-gray-100 text-gray-700 font-medium text-sm touch-btn"
          >
            😅 Forgot
          </button>
          <button
            onClick={() => handleStatus('learning')}
            className="py-2.5 rounded-lg bg-yellow-100 text-yellow-700 font-medium text-sm touch-btn"
          >
            🤔 Partial
          </button>
          <button
            onClick={() => handleStatus('memorized')}
            className="py-2.5 rounded-lg bg-emerald-100 text-emerald-700 font-medium text-sm touch-btn"
          >
            ✅ Got it
          </button>
        </div>
        
        {/* Prev/Next - Compact */}
        <div className="flex gap-2 mt-2">
          <button
            onClick={handlePrev}
            disabled={currentIndex === 0}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-40"
          >
            ← Prev
          </button>
          <button
            onClick={handleNext}
            disabled={currentIndex === group.lines.length - 1}
            className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm touch-btn disabled:opacity-40"
          >
            Next →
          </button>
        </div>
      </div>
    </div>
  )
}

export default Memorize
