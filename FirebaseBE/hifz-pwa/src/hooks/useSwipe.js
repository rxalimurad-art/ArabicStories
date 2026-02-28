import { useRef, useCallback } from 'react'

// Swipe detection hook
export function useSwipe({
  onSwipeLeft,
  onSwipeRight,
  onSwipeUp,
  onSwipeDown,
  threshold = 50,     // Minimum distance to trigger swipe
  timeout = 300,      // Maximum time for swipe gesture
  preventDefault = true
} = {}) {
  const touchStart = useRef(null)
  const touchStartTime = useRef(null)

  const onTouchStart = useCallback((e) => {
    const touch = e.touches[0]
    touchStart.current = { x: touch.clientX, y: touch.clientY }
    touchStartTime.current = Date.now()
  }, [])

  const onTouchEnd = useCallback((e) => {
    if (!touchStart.current) return

    const touch = e.changedTouches[0]
    const endX = touch.clientX
    const endY = touch.clientY
    const startX = touchStart.current.x
    const startY = touchStart.current.y
    const startTime = touchStartTime.current

    // Reset
    touchStart.current = null
    touchStartTime.current = null

    // Check timeout
    if (Date.now() - startTime > timeout) return

    // Calculate distances
    const diffX = endX - startX
    const diffY = endY - startY
    const absX = Math.abs(diffX)
    const absY = Math.abs(diffY)

    // Determine primary direction
    if (absX > absY && absX > threshold) {
      // Horizontal swipe
      if (diffX > 0) {
        onSwipeRight?.()
      } else {
        onSwipeLeft?.()
      }
      if (preventDefault) e.preventDefault()
    } else if (absY > absX && absY > threshold) {
      // Vertical swipe
      if (diffY > 0) {
        onSwipeDown?.()
      } else {
        onSwipeUp?.()
      }
      if (preventDefault) e.preventDefault()
    }
  }, [onSwipeLeft, onSwipeRight, onSwipeUp, onSwipeDown, threshold, timeout, preventDefault])

  const onTouchMove = useCallback((e) => {
    if (!touchStart.current || !preventDefault) return
    
    const touch = e.touches[0]
    const diffX = Math.abs(touch.clientX - touchStart.current.x)
    const diffY = Math.abs(touch.clientY - touchStart.current.y)
    
    // Prevent scrolling if horizontal swipe detected
    if (diffX > diffY && diffX > 10) {
      e.preventDefault()
    }
  }, [preventDefault])

  return {
    onTouchStart,
    onTouchEnd,
    onTouchMove
  }
}

export default useSwipe
