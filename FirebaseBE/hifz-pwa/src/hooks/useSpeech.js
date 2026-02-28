import { useState, useCallback, useEffect, useRef } from 'react'

const STORAGE_KEY = 'hifz_tts_config'

// Get stored config
const getConfig = () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  return stored ? JSON.parse(stored) : { provider: 'web', voice: 'chirp-female' }
}

// Get API base URL
const getApiUrl = () => {
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    return '/api'
  }
  return 'http://127.0.0.1:5002/arabicstories-82611/us-central1/api'
}

export function useSpeech() {
  const [speaking, setSpeaking] = useState(false)
  const [config, setConfig] = useState(getConfig())
  const [error, setError] = useState(null)
  const [lastVoiceUsed, setLastVoiceUsed] = useState(null)
  const audioRef = useRef(null)
  
  const webSupported = 'speechSynthesis' in window
  
  useEffect(() => {
    const handleStorage = (e) => {
      if (e.key === STORAGE_KEY) {
        setConfig(getConfig())
      }
    }
    window.addEventListener('storage', handleStorage)
    return () => window.removeEventListener('storage', handleStorage)
  }, [])
  
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current.src = ''
      }
    }
  }, [])
  
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
    
    utterance.onstart = () => {
      setSpeaking(true)
      setError(null)
      setLastVoiceUsed('Browser TTS')
    }
    utterance.onend = () => setSpeaking(false)
    utterance.onerror = () => setSpeaking(false)
    
    window.speechSynthesis.speak(utterance)
  }, [webSupported])
  
  const speakGoogle = useCallback(async (text) => {
    setSpeaking(true)
    setError(null)
    
    try {
      const voiceToUse = config.voice || 'chirp-female'
      const apiUrl = getApiUrl()
      
      console.log('Calling TTS API:', apiUrl, 'with voice:', voiceToUse)
      
      const response = await fetch(`${apiUrl}/tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text, voiceType: voiceToUse })
      })
      
      // Check if API is available
      if (response.status === 404) {
        throw new Error('TTS API not found. Functions may not be deployed.')
      }
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ error: 'Unknown error' }))
        throw new Error(errorData.error || `HTTP ${response.status}`)
      }
      
      const data = await response.json()
      console.log('TTS Response:', data)
      
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current.src = ''
      }
      
      const newAudio = new Audio(`data:audio/mp3;base64,${data.audioContent}`)
      audioRef.current = newAudio
      
      newAudio.onended = () => {
        setSpeaking(false)
        setLastVoiceUsed(data.voice || voiceToUse)
      }
      newAudio.onerror = () => {
        setSpeaking(false)
        setError('Audio playback failed')
      }
      
      await newAudio.play()
      setLastVoiceUsed(data.voice || voiceToUse)
      
    } catch (err) {
      console.error('Google TTS error:', err)
      setError(`${err.message}. Falling back to browser TTS.`)
      setSpeaking(false)
      // Fallback to Web Speech
      speakWeb(text)
    }
  }, [config.voice, speakWeb])
  
  const speak = useCallback((text, rate = 0.8) => {
    setError(null)
    
    if (config.provider === 'google') {
      speakGoogle(text)
    } else {
      speakWeb(text, rate)
    }
  }, [config.provider, speakWeb, speakGoogle])
  
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
  
  const updateConfig = useCallback((newConfig) => {
    const updated = { ...config, ...newConfig }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
    setConfig(updated)
    console.log('Config updated:', updated)
  }, [config])
  
  return { 
    speak, 
    stop, 
    speaking, 
    config,
    updateConfig,
    webSupported,
    error,
    lastVoiceUsed,
    clearError: () => setError(null)
  }
}
