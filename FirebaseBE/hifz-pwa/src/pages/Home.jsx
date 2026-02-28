import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

function Home() {
  const { groups, loading, getGroupProgress } = useStore()
  
  const groupsWithProgress = groups
    .map(g => ({ ...g, progress: getGroupProgress(g.id) }))
    .sort((a, b) => {
      // Not finished (incomplete) first, then by progress descending
      if (a.progress === 100 && b.progress !== 100) return 1
      if (a.progress !== 100 && b.progress === 100) return -1
      return b.progress - a.progress
    })

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
      {/* Header */}
      <h2 className="text-lg font-semibold text-gray-900">My Groups</h2>
      
      {/* All Groups List */}
      {groupsWithProgress.length === 0 ? (
        <div className="text-center py-12">
          <span className="text-4xl">📖</span>
          <p className="text-gray-500 mt-4">No groups yet</p>
          <p className="text-sm text-gray-400 mt-2">Go to Manage tab to add</p>
        </div>
      ) : (
        <div className="space-y-3">
          {groupsWithProgress.map(group => (
            <Link
              key={group.id}
              to={`/memorize/${group.id}`}
              className="block bg-white rounded-xl p-4 shadow-sm border border-gray-100 touch-btn"
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h4 className="font-medium text-gray-900">{group.name}</h4>
                    {group.progress === 100 && (
                      <span className="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">
                        Done
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-500 mt-1">
                    {group.lines?.length || 0} lines • {group.progress}% complete
                  </p>
                  
                  {/* Progress bar */}
                  <div className="mt-2 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                    <div 
                      className={`h-full transition-all duration-500 ${
                        group.progress === 100 ? 'bg-emerald-500' : 'bg-emerald-400'
                      }`}
                      style={{ width: `${group.progress}%` }}
                    />
                  </div>
                </div>
                
                <div className="ml-4 text-2xl">
                  {group.progress === 100 ? '✅' : group.progress > 0 ? '📖' : '🆕'}
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}

export default Home
