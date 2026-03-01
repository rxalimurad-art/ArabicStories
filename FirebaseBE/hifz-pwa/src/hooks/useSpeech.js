import { useState, useCallback, useEffect, useRef } from 'react'

const STORAGE_KEY = 'hifz_tts_config'

// Get stored config
const getConfig = () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  return stored ? JSON.parse(stored) : { provider: 'web', voice: 'chirp-female' }
}

// Get API base URL - returns array of URLs to try
const getApiUrls = () => {
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    return [
      '/api',
      'https://us-central1-arabicstories-82611.cloudfunctions.net/api'
    ]
  }
  return ['http://127.0.0.1:5002/arabicstories-82611/us-central1/api']
}

export function useSpeech() {
  const [speaking, setSpeaking] = useState(false)
  const [config, setConfig] = useState(getConfig())
  const [error, setError] = useState(null)
  const [lastVoiceUsed, setLastVoiceUsed] = useState(null)
  const [audioDuration, setAudioDuration] = useState(0)
  const [currentWordIndex, setCurrentWordIndex] = useState(-1)
  const audioRef = useRef(null)
  const utteranceRef = useRef(null)
  
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
    
    utteranceRef.current = utterance
    
    // Estimate duration based on word count and rate
    const words = text.trim().split(/\s+/).length
    const estimatedDuration = (words / 2.5) * (1 / rate) // ~2.5 words/sec at normal rate
    setAudioDuration(estimatedDuration)
    
    utterance.onstart = () => {
      setSpeaking(true)
      setCurrentWordIndex(0)
      setError(null)
      setLastVoiceUsed('Browser TTS')
    }
    utterance.onboundary = (event) => {
      // Update word index based on character position
      if (event.name === 'word') {
        const textBefore = text.substring(0, event.charIndex)
        const wordIndex = textBefore.trim().split(/\s+/).filter(w => w.length > 0).length
        setCurrentWordIndex(wordIndex)
      }
    }
    utterance.onend = () => {
      setSpeaking(false)
      setCurrentWordIndex(-1)
    }
    utterance.onerror = () => {
      setSpeaking(false)
      setCurrentWordIndex(-1)
    }
    
    window.speechSynthesis.speak(utterance)
  }, [webSupported])
  
  const speakGoogle = useCallback(async (text) => {
    setSpeaking(true)
    setError(null)
    
    const voiceToUse = config.voice || 'chirp-female'
    const apiUrls = getApiUrls()
    let lastError = null
    
    for (const apiUrl of apiUrls) {
      try {
        console.log('Trying TTS API:', apiUrl, 'with voice:', voiceToUse)
        
        const response = await fetch(`${apiUrl}/tts`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ text, voiceType: voiceToUse }),
          cache: 'no-store'
        })
        
        if (response.ok) {
          const data = await response.json()
          console.log('TTS Response from', apiUrl, ':', data)
          
          if (audioRef.current) {
            audioRef.current.pause()
            audioRef.current.src = ''
          }
          
          const newAudio = new Audio(`data:audio/mp3;base64,${data.audioContent}`)
          audioRef.current = newAudio
          
          // Set duration when metadata is loaded
          newAudio.onloadedmetadata = () => {
            setAudioDuration(newAudio.duration)
          }
          
          newAudio.onended = () => {
            setSpeaking(false)
            setCurrentWordIndex(-1)
            setLastVoiceUsed(data.voice || voiceToUse)
          }
          newAudio.onerror = () => {
            setSpeaking(false)
            setCurrentWordIndex(-1)
            setError('Audio playback failed')
          }
          
          // Track playback progress for word highlighting
          const trackProgress = () => {
            if (newAudio.duration && newAudio.currentTime) {
              const progress = newAudio.currentTime / newAudio.duration
              const words = text.trim().split(/\s+/).length
              const wordIndex = Math.floor(progress * words)
              setCurrentWordIndex(Math.min(wordIndex, words - 1))
            }
            if (!newAudio.paused && !newAudio.ended) {
              requestAnimationFrame(trackProgress)
            }
          }
          newAudio.onplay = () => {
            trackProgress()
          }
          
          await newAudio.play()
          setLastVoiceUsed(data.voice || voiceToUse)
          return // Success - exit function
        }
        
        // Not OK response, try next URL
        lastError = `HTTP ${response.status}`
        
      } catch (err) {
        console.log(`TTS API failed for ${apiUrl}:`, err.message)
        lastError = err.message
        // Continue to next URL
      }
    }
    
    // All URLs failed
    console.error('All TTS APIs failed. Last error:', lastError)
    setError(`${lastError}. Check Debug Info for details.`)
    setSpeaking(false)
    
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
    setCurrentWordIndex(-1)
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
    audioDuration,
    currentWordIndex,
    clearError: () => setError(null)
  }
}
