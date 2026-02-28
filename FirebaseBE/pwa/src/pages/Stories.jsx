import { useEffect, useState } from 'react'
import StoryCard from '../components/StoryCard'

const categories = [
  { id: 'all', label: 'All' },
  { id: 'children', label: 'Children' },
  { id: 'culture', label: 'Culture' },
  { id: 'adventure', label: 'Adventure' },
]

function Stories() {
  const [stories, setStories] = useState([])
  const [loading, setLoading] = useState(true)
  const [activeCategory, setActiveCategory] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
  
  useEffect(() => {
    // TODO: Fetch from your Firebase API
    const mockStories = Array.from({ length: 10 }, (_, i) => ({
      id: String(i + 1),
      title: `Story ${i + 1}`,
      titleArabic: `قصة ${i + 1}`,
      storyDescription: 'An interesting Arabic story for language learners.',
      difficultyLevel: Math.floor(Math.random() * 5) + 1,
      category: ['children', 'culture', 'adventure'][i % 3],
      segments: [{}, {}, {}]
    }))
    
    setTimeout(() => {
      setStories(mockStories)
      setLoading(false)
    }, 500)
  }, [])
  
  const filteredStories = stories.filter((story) => {
    const matchesCategory = activeCategory === 'all' || story.category === activeCategory
    const matchesSearch = story.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         story.titleArabic?.includes(searchQuery)
    return matchesCategory && matchesSearch
  })
  
  return (
    <div className="h-full flex flex-col">
      {/* Search Bar */}
      <div className="p-4 bg-white sticky top-0 z-10">
        <div className="relative">
          <input
            type="text"
            placeholder="Search stories..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-gray-100 rounded-xl px-4 py-3 pl-10 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
          <svg className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
      </div>
      
      {/* Category Filter */}
      <div className="px-4 pb-4 bg-white border-b border-gray-100">
        <div className="flex gap-2 overflow-x-auto no-scrollbar">
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setActiveCategory(cat.id)}
              className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
                activeCategory === cat.id
                  ? 'bg-primary-600 text-white'
                  : 'bg-gray-100 text-gray-600'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>
      
      {/* Stories Grid */}
      <div className="flex-1 overflow-y-auto p-4">
        {loading ? (
          <div className="animate-pulse space-y-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="bg-white rounded-2xl h-48" />
            ))}
          </div>
        ) : (
          <div className="space-y-4">
            {filteredStories.map((story) => (
              <StoryCard key={story.id} story={story} />
            ))}
            
            {filteredStories.length === 0 && (
              <div className="text-center py-12">
                <span className="text-4xl">🔍</span>
                <p className="text-gray-500 mt-4">No stories found</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default Stories
