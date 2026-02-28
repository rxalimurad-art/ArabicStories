import { useState } from 'react'

function Profile() {
  const [user] = useState({
    name: 'Arabic Learner',
    email: 'learner@example.com',
    avatar: null,
    joinedDate: '2024-01-01'
  })
  
  const stats = {
    storiesCompleted: 3,
    wordsLearned: 12,
    currentStreak: 5,
    totalReadingTime: 45
  }
  
  return (
    <div className="pb-4">
      {/* Header with Avatar */}
      <div className="bg-gradient-to-br from-primary-500 to-primary-700 text-white p-6 rounded-b-3xl">
        <div className="flex items-center gap-4">
          <div className="w-20 h-20 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-3xl">
            {user.avatar ? (
              <img src={user.avatar} alt="" className="w-full h-full rounded-full object-cover" />
            ) : (
              '👤'
            )}
          </div>
          <div>
            <h2 className="text-xl font-bold">{user.name}</h2>
            <p className="text-primary-100 text-sm">{user.email}</p>
          </div>
        </div>
      </div>
      
      {/* Stats Grid */}
      <div className="px-4 mt-6">
        <h3 className="font-semibold text-gray-900 mb-3">Your Progress</h3>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <p className="text-2xl font-bold text-primary-600">{stats.storiesCompleted}</p>
            <p className="text-xs text-gray-500 mt-1">Stories Completed</p>
          </div>
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <p className="text-2xl font-bold text-primary-600">{stats.wordsLearned}</p>
            <p className="text-xs text-gray-500 mt-1">Words Learned</p>
          </div>
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <p className="text-2xl font-bold text-orange-500">{stats.currentStreak}🔥</p>
            <p className="text-xs text-gray-500 mt-1">Day Streak</p>
          </div>
          <div className="bg-white rounded-xl p-4 shadow-sm">
            <p className="text-2xl font-bold text-green-500">{stats.totalReadingTime}m</p>
            <p className="text-xs text-gray-500 mt-1">Reading Time</p>
          </div>
        </div>
      </div>
      
      {/* Settings */}
      <div className="px-4 mt-6">
        <h3 className="font-semibold text-gray-900 mb-3">Settings</h3>
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <button className="w-full px-4 py-3 flex items-center justify-between border-b border-gray-100 touch-feedback">
            <div className="flex items-center gap-3">
              <span className="text-xl">🔔</span>
              <span className="text-gray-700">Notifications</span>
            </div>
            <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
          
          <button className="w-full px-4 py-3 flex items-center justify-between border-b border-gray-100 touch-feedback">
            <div className="flex items-center gap-3">
              <span className="text-xl">🌙</span>
              <span className="text-gray-700">Dark Mode</span>
            </div>
            <div className="w-11 h-6 bg-gray-200 rounded-full relative">
              <div className="w-5 h-5 bg-white rounded-full absolute top-0.5 left-0.5 shadow-sm" />
            </div>
          </button>
          
          <button className="w-full px-4 py-3 flex items-center justify-between touch-feedback">
            <div className="flex items-center gap-3">
              <span className="text-xl">ℹ️</span>
              <span className="text-gray-700">About</span>
            </div>
            <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>
      
      {/* Install PWA */}
      <div className="px-4 mt-6">
        <button className="w-full py-3 bg-gray-900 text-white rounded-xl font-medium touch-feedback">
          📲 Add to Home Screen
        </button>
      </div>
    </div>
  )
}

export default Profile
