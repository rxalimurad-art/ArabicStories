import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

function Home() {
  const { groups, loading, getGroupProgress } = useStore()
  
  // Get groups to review (not fully memorized)
  const groupsToReview = groups
    .map(g => ({ ...g, progress: getGroupProgress(g.id) }))
    .filter(g => g.progress < 100)
    .sort((a, b) => b.progress - a.progress)
    .slice(0, 3)

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-4 border-emerald-500 border-t-transparent mx-auto" />
          <p className="mt-4 text-gray-500">Loading...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4 space-y-4">
      {/* Top Actions */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-gray-900">My Groups</h2>
        <Link
          to="/admin"
          className="bg-emerald-600 text-white px-3 py-1.5 rounded-lg text-sm font-medium touch-btn flex items-center gap-1"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Add
        </Link>
      </div>
      
      {/* Continue Learning */}
      {groupsToReview.length > 0 && (
        <div>
          <h3 className="font-semibold text-gray-900 mb-3">Continue Learning</h3>
          <div className="space-y-3">
            {groupsToReview.map(group => (
              <Link
                key={group.id}
                to={`/memorize/${group.id}`}
                className="block bg-white rounded-xl p-4 shadow-sm border border-gray-100 touch-btn"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="font-medium text-gray-900">{group.name}</h4>
                    <p className="text-sm text-gray-500 mt-0.5">
                      {group.lines?.length || 0} lines • {group.progress}% complete
                    </p>
                  </div>
                  <div className="w-12 h-12 relative">
                    <svg className="w-full h-full transform -rotate-90">
                      <circle
                        cx="24"
                        cy="24"
                        r="20"
                        fill="none"
                        stroke="#e5e7eb"
                        strokeWidth="4"
                      />
                      <circle
                        cx="24"
                        cy="24"
                        r="20"
                        fill="none"
                        stroke="#10b981"
                        strokeWidth="4"
                        strokeLinecap="round"
                        strokeDasharray={`${group.progress * 1.26} 126`}
                      />
                    </svg>
                    <span className="absolute inset-0 flex items-center justify-center text-xs font-medium text-emerald-600">
                      {group.progress}%
                    </span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}
      
      {/* View All Groups */}
      <Link
        to="/groups"
        className="block bg-white rounded-xl p-4 border border-gray-200 text-center touch-btn"
      >
        <span className="text-2xl">📚</span>
        <p className="text-sm font-medium text-gray-700 mt-1">View All Groups</p>
      </Link>
    </div>
  )
}

export default Home
