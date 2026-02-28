import { useState, useEffect, useCallback } from 'react'

const FONT_SIZE_STORAGE_KEY = 'hifz_font_size'

export const FONT_SIZES = {
  small: { label: 'Small', class: 'text-lg', px: '18px' },
  medium: { label: 'Medium', class: 'text-xl', px: '20px' },
  large: { label: 'Large', class: 'text-2xl', px: '24px' },
  xlarge: { label: 'Extra Large', class: 'text-3xl', px: '30px' }
}

export const DEFAULT_FONT_SIZE = 'medium'

export function useFontSize() {
  const [sizeKey, setSizeKey] = useState(() => {
    const stored = localStorage.getItem(FONT_SIZE_STORAGE_KEY)
    return stored || DEFAULT_FONT_SIZE
  })
  
  const fontSize = FONT_SIZES[sizeKey] || FONT_SIZES[DEFAULT_FONT_SIZE]
  
  // Apply font size CSS variable
  useEffect(() => {
    document.documentElement.style.setProperty('--arabic-font-size', fontSize.px)
  }, [fontSize.px])
  
  // Update font size
  const setFontSize = useCallback((key) => {
    if (FONT_SIZES[key]) {
      localStorage.setItem(FONT_SIZE_STORAGE_KEY, key)
      setSizeKey(key)
    }
  }, [])
  
  return {
    fontSize,
    sizeKey,
    setFontSize,
    fontSizes: FONT_SIZES
  }
}
