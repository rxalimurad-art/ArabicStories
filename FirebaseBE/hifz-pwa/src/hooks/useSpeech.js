import { useState, useCallback } from 'react'

export function useSpeech() {
  const [speaking, setSpeaking] = useState(false)
  const [supported, setSupported] = useState(() => 'speechSynthesis' in window)
  
  const speak = useCallback((text, rate = 0.8) => {
    if (!supported) {
      console.log('TTS not supported')
      return
    }
    
    // Cancel any ongoing speech
    window.speechSynthesis.cancel()
    
    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = 'ar-SA'
    utterance.rate = rate
    utterance.pitch = 1
    
    // Try to find Arabic voice
    const voices = window.speechSynthesis.getVoices()
    const arabicVoice = voices.find(v => v.lang.includes('ar'))
    if (arabicVoice) {
      utterance.voice = arabicVoice
    }
    
    utterance.onstart = () => setSpeaking(true)
    utterance.onend = () => setSpeaking(false)
    utterance.onerror = () => setSpeaking(false)
    
    window.speechSynthesis.speak(utterance)
  }, [supported])
  
  const stop = useCallback(() => {
    if (supported) {
      window.speechSynthesis.cancel()
      setSpeaking(false)
    }
  }, [supported])
  
  return { speak, stop, speaking, supported }
}
