import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

const TAG_COLORS = {
  nahw: 'bg-blue-100 text-blue-700 border-blue-200',
  sarf: 'bg-purple-100 text-purple-700 border-purple-200',
  quran: 'bg-emerald-100 text-emerald-700 border-emerald-200',
  dua: 'bg-amber-100 text-amber-700 border-amber-200',
  hadith: 'bg-rose-100 text-rose-700 border-rose-200'
}

const TAG_LABELS = {
  nahw: 'Nahw',
  sarf: 'Sarf',
  quran: 'Quran',
  dua: 'Dua',
  hadith: 'Hadith'
}

function Home() {
  const { groups, loading, getGroupProgress, MAIN_TAGS } = useStore()
  const [selectedTag, setSelectedTag] = useState('all')
  
  // Filter groups by selected tag
  const filteredGroups = groups
    .filter(g => selectedTag === 'all' || (g.tags || []).includes(selectedTag))
    .map(g => ({ ...g, progress: getGroupProgress(g.id) }))
    .sort((a, b) => {
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
      
      {/* Tag Filter */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setSelectedTag('all')}
          className={`px-3 py-1.5 rounded-full text-sm font-medium touch-btn transition-colors ${
            selectedTag === 'all'
              ? 'bg-gray-800 text-white'
              : 'bg-gray-100 text-gray-600'
          }`}
        >
          All
        </button>
        {MAIN_TAGS.map(tag => (
          <button
            key={tag}
            onClick={() => setSelectedTag(tag)}
            className={`px-3 py-1.5 rounded-full text-sm font-medium touch-btn transition-colors border ${
              selectedTag === tag
                ? TAG_COLORS[tag]
                : 'bg-white text-gray-600 border-gray-200'
            }`}
          >
            {TAG_LABELS[tag]}
          </button>
        ))}
      </div>
      
      {/* Groups List */}
      {filteredGroups.length === 0 ? (
        <div className="text-center py-12">
          <span className="text-4xl">📖</span>
          <p className="text-gray-500 mt-4">
            {selectedTag === 'all' ? 'No groups yet' : `No ${TAG_LABELS[selectedTag]} groups`}
          </p>
          <p className="text-sm text-gray-400 mt-2">Go to Manage tab to add</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredGroups.map(group => (
            <Link
              key={group.id}
              to={`/memorize/${group.id}`}
              className="block bg-white rounded-xl p-4 shadow-sm border border-gray-100 touch-btn"
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h4 className="font-medium text-gray-900">{group.name}</h4>
                    {group.progress === 100 && (
                      <span className="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">
                        Done
                      </span>
                    )}
                  </div>
                  
                  {/* Tags */}
                  {group.tags && group.tags.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-1.5">
                      {group.tags.map(tag => (
                        <span 
                          key={tag} 
                          className={`text-xs px-2 py-0.5 rounded-full ${TAG_COLORS[tag] || 'bg-gray-100 text-gray-600'}`}
                        >
                          {TAG_LABELS[tag] || tag}
                        </span>
                      ))}
                    </div>
                  )}
                  
                  <p className="text-sm text-gray-500 mt-2">
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
