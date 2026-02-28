import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

function Groups() {
  const { groups, loading, getGroupProgress } = useStore()
  
  const getStatusColor = (progress) => {
    if (progress === 100) return 'bg-emerald-500'
    if (progress > 50) return 'bg-yellow-500'
    if (progress > 0) return 'bg-orange-500'
    return 'bg-gray-300'
  }

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-emerald-500 border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-gray-900">My Groups</h2>
        <Link
          to="/admin"
          className="bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium touch-btn"
        >
          + Add Group
        </Link>
      </div>
      
      {groups.length === 0 ? (
        <div className="text-center py-12">
          <span className="text-4xl">📖</span>
          <p className="text-gray-500 mt-4">No groups yet</p>
          <Link
            to="/admin"
            className="inline-block mt-4 text-emerald-600 font-medium"
          >
            Create your first group →
          </Link>
        </div>
      ) : (
        <div className="space-y-3">
          {groups.map(group => {
            const progress = getGroupProgress(group.id)
            const lineCount = group.lines?.length || 0
            const memorized = group.lines?.filter(l => l.status === 'memorized').length || 0
            
            return (
              <Link
                key={group.id}
                to={`/memorize/${group.id}`}
                className="block bg-white rounded-xl p-4 shadow-sm border border-gray-100 touch-btn"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h3 className="font-semibold text-gray-900">{group.name}</h3>
                    <p className="text-sm text-gray-500 mt-1">
                      {lineCount} lines • {memorized} memorized
                    </p>
                    
                    {/* Progress bar */}
                    <div className="mt-3">
                      <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
                        <div 
                          className={`h-full ${getStatusColor(progress)} transition-all duration-500`}
                          style={{ width: `${progress}%` }}
                        />
                      </div>
                      <p className="text-xs text-gray-400 mt-1">{progress}% complete</p>
                    </div>
                  </div>
                  
                  <div className="ml-4">
                    {progress === 100 ? (
                      <span className="text-2xl">✅</span>
                    ) : progress > 0 ? (
                      <span className="text-2xl">📖</span>
                    ) : (
                      <span className="text-2xl">🆕</span>
                    )}
                  </div>
                </div>
              </Link>
            )
          })}
        </div>
      )}
    </div>
  )
}

export default Groups
