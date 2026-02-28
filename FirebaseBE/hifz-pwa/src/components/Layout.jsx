import { Outlet, useNavigate } from 'react-router-dom'
import { useHaptic } from '../hooks/useHaptic'

function Layout() {
  const navigate = useNavigate()
  const { light } = useHaptic()
  
  const goToSettings = () => {
    light()
    navigate('/settings')
  }
  
  const goToGroups = () => {
    light()
    navigate('/groups')
  }

  return (
    <div className="h-full flex flex-col">
      {/* Header with Settings and Add buttons */}
      <header className="bg-emerald-600 text-white pt-safe">
        <div className="px-4 py-3 flex items-center justify-between">
          {/* Settings Button */}
          <button 
            onClick={goToSettings}
            className="p-2 -ml-2 rounded-lg hover:bg-emerald-700 touch-btn"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>

          {/* Title */}
          <h1 className="text-xl font-bold">Memorizer</h1>

          {/* Add Button */}
          <button 
            onClick={goToGroups}
            className="p-2 -mr-2 rounded-lg hover:bg-emerald-700 touch-btn"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
          </button>
        </div>
      </header>
      
      {/* Main Content */}
      <main className="flex-1 overflow-y-auto no-scrollbar">
        <Outlet />
      </main>
    </div>
  )
}

export default Layout
