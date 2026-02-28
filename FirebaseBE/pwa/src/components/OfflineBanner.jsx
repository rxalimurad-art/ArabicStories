import { useEffect, useState } from 'react'

function OfflineBanner() {
  const [isOffline, setIsOffline] = useState(!navigator.onLine)
  
  useEffect(() => {
    const handleOffline = () => setIsOffline(true)
    const handleOnline = () => setIsOffline(false)
    
    window.addEventListener('offline', handleOffline)
    window.addEventListener('online', handleOnline)
    
    return () => {
      window.removeEventListener('offline', handleOffline)
      window.removeEventListener('online', handleOnline)
    }
  }, [])
  
  if (!isOffline) return null
  
  return (
    <div className="fixed top-safe left-0 right-0 z-50 bg-yellow-500 text-white px-4 py-2 text-center text-sm font-medium animate-slide-down">
      <div className="flex items-center justify-center gap-2">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        You're offline
      </div>
    </div>
  )
}

export default OfflineBanner
