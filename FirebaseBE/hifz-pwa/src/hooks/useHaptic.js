import { useCallback } from 'react'

// Check if vibration is supported
const isSupported = () => {
  return 'vibrate' in navigator
}

// Haptic patterns
const PATTERNS = {
  light: 15,      // Subtle feedback
  medium: 30,     // Standard button press
  heavy: 50,      // Important action
  success: [30, 50, 30],  // Success pattern
  error: [50, 30, 50],    // Error pattern
  swipe: 20       // Swipe gesture
}

export function useHaptic() {
  const trigger = useCallback((type = 'medium') => {
    if (!isSupported()) return
    
    try {
      const pattern = PATTERNS[type] || PATTERNS.medium
      navigator.vibrate(pattern)
    } catch (err) {
      // Silently fail if vibration not allowed
    }
  }, [])

  const light = useCallback(() => trigger('light'), [trigger])
  const medium = useCallback(() => trigger('medium'), [trigger])
  const heavy = useCallback(() => trigger('heavy'), [trigger])
  const success = useCallback(() => trigger('success'), [trigger])
  const error = useCallback(() => trigger('error'), [trigger])
  const swipe = useCallback(() => trigger('swipe'), [trigger])

  return {
    trigger,
    light,
    medium,
    heavy,
    success,
    error,
    swipe,
    supported: isSupported()
  }
}

export default useHaptic
