import { Outlet, NavLink, useLocation } from 'react-router-dom'

function Layout() {
  const location = useLocation()
  
  // Hide bottom nav on story detail page for immersive reading
  const hideNav = location.pathname.includes('/stories/') && location.pathname !== '/stories'

  return (
    <div className="h-full flex flex-col">
      {/* Status bar background */}
      <div className="bg-primary-600 pt-safe" />
      
      {/* Header */}
      {!hideNav && (
        <header className="bg-primary-600 text-white px-4 py-3 safe-top">
          <h1 className="text-xl font-bold text-center">Arabic Stories</h1>
        </header>
      )}
      
      {/* Main content */}
      <main className="flex-1 overflow-y-auto no-scrollbar">
        <Outlet />
      </main>
      
      {/* Bottom Navigation */}
      {!hideNav && (
        <nav className="bg-white border-t border-gray-200 pb-safe safe-bottom">
          <div className="flex justify-around items-center h-14">
            <NavLink 
              to="/" 
              className={({ isActive }) => 
                `flex flex-col items-center justify-center w-full h-full touch-feedback ${
                  isActive ? 'text-primary-600' : 'text-gray-400'
                }`
              }
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
              <span className="text-xs mt-0.5">Home</span>
            </NavLink>
            
            <NavLink 
              to="/stories"
              className={({ isActive }) => 
                `flex flex-col items-center justify-center w-full h-full touch-feedback ${
                  isActive ? 'text-primary-600' : 'text-gray-400'
                }`
              }
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
              <span className="text-xs mt-0.5">Stories</span>
            </NavLink>
            
            <NavLink 
              to="/profile"
              className={({ isActive }) => 
                `flex flex-col items-center justify-center w-full h-full touch-feedback ${
                  isActive ? 'text-primary-600' : 'text-gray-400'
                }`
              }
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              <span className="text-xs mt-0.5">Profile</span>
            </NavLink>
          </div>
        </nav>
      )}
    </div>
  )
}

export default Layout
