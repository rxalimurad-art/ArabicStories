import { Link } from 'react-router-dom'

function StoryCard({ story }) {
  return (
    <Link 
      to={`/stories/${story.id}`}
      className="block bg-white rounded-2xl shadow-sm overflow-hidden touch-feedback"
    >
      <div className="aspect-video bg-gradient-to-br from-primary-400 to-primary-600 relative">
        {story.coverImageURL ? (
          <img 
            src={story.coverImageURL} 
            alt={story.title}
            className="w-full h-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center text-white">
            <span className="text-4xl">📖</span>
          </div>
        )}
        <div className="absolute top-2 right-2 bg-black/50 backdrop-blur-sm text-white text-xs px-2 py-1 rounded-full">
          Level {story.difficultyLevel}
        </div>
      </div>
      
      <div className="p-4">
        <h3 className="font-semibold text-gray-900 line-clamp-1">{story.title}</h3>
        {story.titleArabic && (
          <p className="text-gray-600 text-sm mt-0.5 line-clamp-1" dir="rtl">{story.titleArabic}</p>
        )}
        <p className="text-gray-500 text-xs mt-2 line-clamp-2">{story.storyDescription}</p>
        
        <div className="flex items-center gap-2 mt-3">
          <span className="text-xs text-primary-600 bg-primary-50 px-2 py-0.5 rounded-full capitalize">
            {story.category}
          </span>
          <span className="text-xs text-gray-400">
            {story.segments?.length || story.mixedSegments?.length || 0} parts
          </span>
        </div>
      </div>
    </Link>
  )
}

export default StoryCard
