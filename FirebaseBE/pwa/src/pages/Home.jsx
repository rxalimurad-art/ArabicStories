import { useEffect, useState } from 'react'
import StoryCard from '../components/StoryCard'

function Home() {
  const [stories, setStories] = useState([])
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    // TODO: Fetch from your Firebase API
    // For now, using mock data
    const mockStories = [
      {
        id: '1',
        title: 'The Friendly Cat',
        titleArabic: 'القطة الودودة',
        storyDescription: 'A simple story about a friendly cat who helps a lost bird.',
        difficultyLevel: 1,
        category: 'children',
        segments: [{}, {}]
      },
      {
        id: '2',
        title: 'The Old Market',
        titleArabic: 'السوق القديم',
        storyDescription: 'Exploring the vibrant old market of Cairo.',
        difficultyLevel: 3,
        category: 'culture',
        segments: [{}, {}, {}]
      }
    ]
    
    setTimeout(() => {
      setStories(mockStories)
      setLoading(false)
    }, 500)
  }, [])
  
  if (loading) {
    return (
      <div className="p-4">
        <div className="animate-pulse space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-white rounded-2xl h-48" />
          ))}
        </div>
      </div>
    )
  }
  
  return (
    <div className="pb-4">
      {/* Hero Section */}
      <div className="bg-gradient-to-br from-primary-500 to-primary-700 text-white p-6 rounded-b-3xl">
        <h2 className="text-2xl font-bold">Welcome Back! 👋</h2>
        <p className="text-primary-100 mt-1">Continue your Arabic learning journey</p>
        
        <div className="flex gap-4 mt-6">
          <div className="bg-white/20 backdrop-blur-sm rounded-xl p-3 flex-1">
            <p className="text-2xl font-bold">3</p>
            <p className="text-xs text-primary-100">Stories Read</p>
          </div>
          <div className="bg-white/20 backdrop-blur-sm rounded-xl p-3 flex-1">
            <p className="text-2xl font-bold">12</p>
            <p className="text-xs text-primary-100">Words Learned</p>
          </div>
        </div>
      </div>
      
      {/* Continue Reading */}
      <div className="px-4 mt-6">
        <h3 className="font-semibold text-gray-900 mb-3">Continue Reading</h3>
        {stories[0] && <StoryCard story={stories[0]} />}
      </div>
      
      {/* Recommended */}
      <div className="px-4 mt-6">
        <h3 className="font-semibold text-gray-900 mb-3">Recommended for You</h3>
        <div className="space-y-4">
          {stories.slice(1).map((story) => (
            <StoryCard key={story.id} story={story} />
          ))}
        </div>
      </div>
    </div>
  )
}

export default Home
