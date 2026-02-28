import { useParams, useNavigate } from 'react-router-dom'
import { useEffect, useState } from 'react'

function StoryDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [story, setStory] = useState(null)
  const [currentSegment, setCurrentSegment] = useState(0)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    // TODO: Fetch from your Firebase API
    const mockStory = {
      id,
      title: 'The Friendly Cat',
      titleArabic: 'القطة الودودة',
      storyDescription: 'A simple story about a friendly cat who helps a lost bird find its way home.',
      author: 'Arabicly',
      difficultyLevel: 1,
      category: 'children',
      segments: [
        {
          arabicText: 'في يوم مشمس، كانت هناك قطة صغيرة اسمها لولو.',
          englishText: 'On a sunny day, there was a small cat named Lulu.',
          transliteration: 'Fī yawm mushmis, kānat hunā qiṭṭa ṣaghīra ismuhā Lūlū.'
        },
        {
          arabicText: 'سمعت لولو صوتاً ضعيفاً قادماً من الشجرة.',
          englishText: 'Lulu heard a weak voice coming from the tree.',
          transliteration: 'Samiʿat Lūlū ṣawtan ḍaʿīfan qādiman min al-shajara.'
        },
        {
          arabicText: 'كانت عصفوراً صغيراً عالقاً ولا يستطيع الطيران.',
          englishText: 'It was a small bird stuck and unable to fly.',
          transliteration: 'Kānat ʿaṣfūran ṣaghīran ʿāliqan wa-lā yastaṭīʿ al-ṭayarān.'
        }
      ]
    }
    
    setTimeout(() => {
      setStory(mockStory)
      setLoading(false)
    }, 300)
  }, [id])
  
  const handleComplete = async () => {
    // TODO: Call your Firebase completion API
    // await fetch('/api/completions/story', {
    //   method: 'POST',
    //   body: JSON.stringify({ userId, storyId: id })
    // })
    
    alert('Story completed! 🎉')
    navigate('/')
  }
  
  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-primary-500 border-t-transparent" />
      </div>
    )
  }
  
  const segment = story.segments[currentSegment]
  const progress = ((currentSegment + 1) / story.segments.length) * 100
  
  return (
    <div className="h-full flex flex-col bg-white">
      {/* Progress Bar */}
      <div className="h-1 bg-gray-200">
        <div 
          className="h-full bg-primary-500 transition-all duration-300"
          style={{ width: `${progress}%` }}
        />
      </div>
      
      {/* Header */}
      <div className="px-4 py-3 border-b border-gray-100 flex items-center">
        <button 
          onClick={() => navigate('/stories')}
          className="p-2 -ml-2 touch-feedback"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <div className="flex-1 ml-2">
          <h1 className="font-semibold text-lg line-clamp-1">{story.title}</h1>
          <p className="text-xs text-gray-500">{currentSegment + 1} of {story.segments.length}</p>
        </div>
      </div>
      
      {/* Content */}
      <div className="flex-1 overflow-y-auto p-6">
        {/* Arabic Text */}
        <div className="mb-8">
          <p className="text-2xl leading-relaxed text-right font-medium text-gray-900" dir="rtl">
            {segment.arabicText}
          </p>
        </div>
        
        {/* Transliteration */}
        <div className="mb-6">
          <p className="text-sm text-gray-500 italic">
            {segment.transliteration}
          </p>
        </div>
        
        {/* English Translation */}
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-gray-700 leading-relaxed">
            {segment.englishText}
          </p>
        </div>
      </div>
      
      {/* Navigation */}
      <div className="p-4 border-t border-gray-100 safe-bottom pb-safe">
        <div className="flex gap-3">
          <button
            onClick={() => setCurrentSegment(Math.max(0, currentSegment - 1))}
            disabled={currentSegment === 0}
            className="flex-1 py-3 rounded-xl font-medium border-2 border-gray-200 text-gray-700 disabled:opacity-50 disabled:cursor-not-allowed touch-feedback"
          >
            Previous
          </button>
          
          {currentSegment < story.segments.length - 1 ? (
            <button
              onClick={() => setCurrentSegment(currentSegment + 1)}
              className="flex-1 py-3 rounded-xl font-medium bg-primary-600 text-white touch-feedback"
            >
              Next
            </button>
          ) : (
            <button
              onClick={handleComplete}
              className="flex-1 py-3 rounded-xl font-medium bg-green-500 text-white touch-feedback"
            >
              Complete 🎉
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

export default StoryDetail
