import { useState, useEffect, useCallback } from 'react'

const FONT_STORAGE_KEY = 'hifz_font_config'
const FONT_SIZE_KEY = 'hifz_font_size'

// Available fonts with Indo-Pak Arabic support
export const FONTS = {
  'amiri': {
    name: 'Amiri (Classic)',
    family: "'Amiri', serif",
    url: 'https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&display=swap',
    desc: 'Traditional Arabic, good for reading'
  },
  'scheherazade': {
    name: 'Scheherazade New (Indo-Pak)',
    family: "'Scheherazade New', serif",
    url: 'https://fonts.googleapis.com/css2?family=Scheherazade+New:wght@400;700&display=swap',
    desc: 'Recommended - Indo-Pak style, clear letters'
  },
  'noto-naskh': {
    name: 'Noto Naskh Arabic',
    family: "'Noto Naskh Arabic', serif",
    url: 'https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;700&display=swap',
    desc: 'Modern Naskh style'
  },
  'noto-sans': {
    name: 'Noto Sans Arabic',
    family: "'Noto Sans Arabic', sans-serif",
    url: 'https://fonts.googleapis.com/css2?family=Noto+Sans+Arabic:wght@400;700&display=swap',
    desc: 'Clean sans-serif style'
  },
  'lateef': {
    name: 'Lateef (Large)',
    family: "'Lateef', cursive",
    url: 'https://fonts.googleapis.com/css2?family=Lateef:wght@400;700&display=swap',
    desc: 'Larger letters, good for learning'
  },
  'reem-kufi': {
    name: 'Reem Kufi',
    family: "'Reem Kufi', sans-serif",
    url: 'https://fonts.googleapis.com/css2?family=Reem+Kufi:wght@400;700&display=swap',
    desc: 'Kufic style, geometric'
  }
}

export const DEFAULT_FONT = 'scheherazade'

// Font size options (px)
export const FONT_SIZE_MIN = 14
export const FONT_SIZE_MAX = 48
export const FONT_SIZE_DEFAULT = 20

export function useFont() {
  const [fontKey, setFontKey] = useState(() => {
    const stored = localStorage.getItem(FONT_STORAGE_KEY)
    return stored || DEFAULT_FONT
  })
  
  const [fontSize, setFontSizeState] = useState(() => {
    const stored = localStorage.getItem(FONT_SIZE_KEY)
    const size = parseInt(stored, 10)
    return !isNaN(size) && size >= FONT_SIZE_MIN && size <= FONT_SIZE_MAX 
      ? size 
      : FONT_SIZE_DEFAULT
  })
  
  const [loaded, setLoaded] = useState(false)
  
  const font = FONTS[fontKey] || FONTS[DEFAULT_FONT]
  
  // Load font CSS
  useEffect(() => {
    const linkId = 'arabic-font-link'
    let link = document.getElementById(linkId)
    
    if (!link) {
      link = document.createElement('link')
      link.id = linkId
      link.rel = 'stylesheet'
      document.head.appendChild(link)
    }
    
    link.href = font.url
    
    // Apply font to document
    document.documentElement.style.setProperty('--arabic-font', font.family)
    
    setLoaded(true)
  }, [font.url, font.family])
  
  // Update font
  const setFont = useCallback((key) => {
    if (FONTS[key]) {
      localStorage.setItem(FONT_STORAGE_KEY, key)
      setFontKey(key)
    }
  }, [])
  
  // Update font size
  const setFontSize = useCallback((size) => {
    const newSize = Math.max(FONT_SIZE_MIN, Math.min(FONT_SIZE_MAX, parseInt(size, 10) || FONT_SIZE_DEFAULT))
    localStorage.setItem(FONT_SIZE_KEY, newSize.toString())
    setFontSizeState(newSize)
  }, [])
  
  return {
    font,
    fontKey,
    setFont,
    fontSize,
    setFontSize,
    loaded,
    fonts: FONTS,
    fontSizeMin: FONT_SIZE_MIN,
    fontSizeMax: FONT_SIZE_MAX
  }
}
