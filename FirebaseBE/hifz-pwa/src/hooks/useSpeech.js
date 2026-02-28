import { useState, useCallback, useEffect, useRef } from 'react'

const STORAGE_KEY = 'hifz_tts_config'

// Get stored config
const getConfig = () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  return stored ? JSON.parse(stored) : { provider: 'web', voice: 'chirp-female' }
}

// Get API base URL
const getApiUrl = () => {
  // In production, use Firebase hosting URL
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    return '/api'
  }
  // In development, use emulator
  return 'http://127.0.0.1:5002/arabicstories-82611/us-central1/api'
}

export function useSpeech() {
  const [speaking, setSpeaking] = useState(false)
  const [config, setConfig] = useState(getConfig())
  const audioRef = useRef(null)
  
  // Web Speech API support check
  const webSupported = 'speechSynthesis' in window
  
  // Load config on mount
  useEffect(() => {
    const handleStorage = () => {
      setConfig(getConfig())
    }
    window.addEventListener('storage', handleStorage)
    return () => window.removeEventListener('storage', handleStorage)
  }, [])
  
  // Cleanup audio on unmount
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current.src = ''
      }
    }
  }, [])
  
  // Web Speech API
  const speakWeb = useCallback((text, rate = 0.8) => {
    if (!webSupported) return
    
    window.speechSynthesis.cancel()
    
    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = 'ar-SA'
    utterance.rate = rate
    utterance.pitch = 1
    
    const voices = window.speechSynthesis.getVoices()
    const arabicVoice = voices.find(v => v.lang.includes('ar'))
    if (arabicVoice) utterance.voice = arabicVoice
    
    utterance.onstart = () => setSpeaking(true)
    utterance.onend = () => setSpeaking(false)
    utterance.onerror = () => setSpeaking(false)
    
    window.speechSynthesis.speak(utterance)
  }, [webSupported])
  
  // Google Cloud TTS via Firebase Function
  const speakGoogle = useCallback(async (text) => {
    setSpeaking(true)
    
    try {
      const voiceToUse = config.voice || 'chirp-female'
      console.log('Requesting voice:', voiceToUse)
      
      const response = await fetch(`${getApiUrl()}/tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          text,
          voiceType: voiceToUse
        })
      })
      
      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'TTS request failed')
      }
      
      const data = await response.json()
      console.log('Voice used:', data.voice)
      
      // Stop previous audio
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current.src = ''
      }
      
      // Play new audio
      const newAudio = new Audio(`data:audio/mp3;base64,${data.audioContent}`)
      audioRef.current = newAudio
      
      newAudio.onended = () => setSpeaking(false)
      newAudio.onerror = () => {
        setSpeaking(false)
        console.error('Audio playback error')
      }
      
      await newAudio.play()
      
    } catch (err) {
      console.error('Google TTS error:', err)
      setSpeaking(false)
      // Fallback to Web Speech
      speakWeb(text)
    }
  }, [config.voice, speakWeb])
  
  // Main speak function
  const speak = useCallback((text, rate = 0.8) => {
    if (config.provider === 'google') {
      speakGoogle(text)
    } else {
      speakWeb(text, rate)
    }
  }, [config.provider, speakWeb, speakGoogle])
  
  // Stop speaking
  const stop = useCallback(() => {
    if (audioRef.current) {
      audioRef.current.pause()
      audioRef.current.currentTime = 0
    }
    if (webSupported) {
      window.speechSynthesis.cancel()
    }
    setSpeaking(false)
  }, [webSupported])
  
  // Update config
  const updateConfig = useCallback((newConfig) => {
    const updated = { ...config, ...newConfig }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
    setConfig(updated)
  }, [config])
  
  return { 
    speak, 
    stop, 
    speaking, 
    config,
    updateConfig,
    webSupported 
  }
}
