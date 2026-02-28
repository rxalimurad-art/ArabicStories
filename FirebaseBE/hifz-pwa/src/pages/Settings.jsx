import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { useSpeech } from '../hooks/useSpeech'
import { useFont, FONTS } from '../hooks/useFont'
import { useFontSize, FONT_SIZES } from '../hooks/useFontSize'

function Settings() {
  const { speak, speaking, config, updateConfig, error, lastVoiceUsed, clearError } = useSpeech()
  const { font, fontKey, setFont, fonts } = useFont()
  const { fontSize, sizeKey, setFontSize, fontSizes } = useFontSize()
  
  const [provider, setProvider] = useState(config.provider || 'web')
  const [voice, setVoice] = useState(config.voice || 'chirp-female')
  const [tempFont, setTempFont] = useState(fontKey)
  const [tempSize, setTempSize] = useState(sizeKey)
  const [saved, setSaved] = useState(false)
  const [apiStatus, setApiStatus] = useState('checking')
  const [showDebug, setShowDebug] = useState(false)
  
  // Check if API is available
  useEffect(() => {
    const checkApi = async () => {
      try {
        const apiUrl = window.location.hostname !== 'localhost' 
          ? '/api' 
          : 'http://127.0.0.1:5002/arabicstories-82611/us-central1/api'
        
        const response = await fetch(`${apiUrl}/`, { method: 'GET' })
        if (response.ok) {
          setApiStatus('online')
        } else {
          setApiStatus('error')
        }
      } catch (err) {
        setApiStatus('offline')
      }
    }
    checkApi()
  }, [])
  
  useEffect(() => {
    setProvider(config.provider || 'web')
    setVoice(config.voice || 'chirp-female')
  }, [config])
  
  const handleSave = () => {
    updateConfig({ provider, voice })
    setFont(tempFont)
    setFontSize(tempSize)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }
  
  const testTTS = () => {
    clearError()
    speak('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ')
  }
  
  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
        <Link to="/groups" className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn">
          <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </Link>
        <h2 className="text-lg font-semibold text-gray-900">Settings</h2>
      </div>
      
      <div className="flex-1 overflow-y-auto p-4 pb-20 space-y-6">
        {/* API Status */}
        <div className={`rounded-xl p-3 text-center ${
          apiStatus === 'online' ? 'bg-emerald-50 text-emerald-700' :
          apiStatus === 'checking' ? 'bg-gray-50 text-gray-600' :
          'bg-red-50 text-red-700'
        }`}>
          <p className="text-sm font-medium">
            {apiStatus === 'online' && '✅ TTS API Online'}
            {apiStatus === 'checking' && '⏳ Checking TTS API...'}
            {apiStatus === 'offline' && '❌ TTS API Offline - Functions not deployed'}
            {apiStatus === 'error' && '⚠️ TTS API Error'}
          </p>
          {apiStatus === 'offline' && (
            <p className="text-xs mt-1">Run: firebase deploy --only functions</p>
          )}
        </div>
        
        {/* Font Settings */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-4">Arabic Font</h3>
          
          {/* Font Family */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Font Style</label>
            <select
              value={tempFont}
              onChange={(e) => setTempFont(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
            >
              {Object.entries(fonts).map(([key, f]) => (
                <option key={key} value={key}>{f.name}</option>
              ))}
            </select>
          </div>
          
          {/* Font Size */}
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Font Size</label>
            <div className="grid grid-cols-4 gap-2">
              {Object.entries(fontSizes).map(([key, size]) => (
                <button
                  key={key}
                  onClick={() => setTempSize(key)}
                  className={`py-2 px-1 rounded-lg text-sm font-medium touch-btn transition-colors ${
                    tempSize === key
                      ? 'bg-emerald-600 text-white'
                      : 'bg-gray-100 text-gray-700'
                  }`}
                >
                  {size.label}
                </button>
              ))}
            </div>
          </div>
          
          {/* Preview */}
          <div 
            className="bg-gray-50 rounded-lg p-4 text-center border border-gray-100"
            style={{ fontFamily: fonts[tempFont]?.family || font.family }}
          >
            <p className={`leading-relaxed ${fontSizes[tempSize]?.class || fontSize.class}`} dir="rtl">
              بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ
            </p>
            <p className="text-xs text-gray-500 mt-2 font-sans">
              {fonts[tempFont]?.desc || font.desc}
            </p>
          </div>
        </div>
        
        {/* TTS Provider */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-4">Text to Speech</h3>
          
          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-red-600 text-sm">{error}</p>
            </div>
          )}
          
          {/* Provider Selection */}
          <div className="space-y-3 mb-6">
            <label className={`flex items-center gap-3 p-3 border rounded-lg cursor-pointer touch-btn ${
              provider === 'web' ? 'border-emerald-500 bg-emerald-50' : 'border-gray-200'
            }`}>
              <input
                type="radio"
                name="provider"
                value="web"
                checked={provider === 'web'}
                onChange={(e) => setProvider(e.target.value)}
                className="w-5 h-5 text-emerald-600"
              />
              <div className="flex-1">
                <p className="font-medium text-gray-900">Browser TTS</p>
                <p className="text-xs text-gray-500">Free, offline, basic quality</p>
              </div>
            </label>
            
            <label className={`flex items-center gap-3 p-3 border rounded-lg cursor-pointer touch-btn ${
              provider === 'google' ? 'border-emerald-500 bg-emerald-50' : 'border-gray-200'
            }`}>
              <input
                type="radio"
                name="provider"
                value="google"
                checked={provider === 'google'}
                onChange={(e) => setProvider(e.target.value)}
                className="w-5 h-5 text-emerald-600"
              />
              <div className="flex-1">
                <p className="font-medium text-gray-900">Google Cloud TTS ⭐</p>
                <p className="text-xs text-emerald-600">Premium, natural voice</p>
              </div>
            </label>
          </div>
          
          {/* Voice Selection */}
          {provider === 'google' && (
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">Voice Model</label>
              <select
                value={voice}
                onChange={(e) => setVoice(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
              >
                <optgroup label="⭐ Chirp (Best - Most Natural)">
                  <option value="chirp-female">Chirp HD - Female</option>
                  <option value="chirp-male">Chirp HD - Male</option>
                </optgroup>
                <optgroup label="WaveNet (Good)">
                  <option value="wavenet-female">WaveNet - Female</option>
                  <option value="wavenet-male">WaveNet - Male</option>
                </optgroup>
                <optgroup label="Standard (Basic)">
                  <option value="standard-female">Standard - Female</option>
                  <option value="standard-male">Standard - Male</option>
                </optgroup>
              </select>
              
              {lastVoiceUsed && (
                <p className="text-xs text-emerald-600 mt-2">
                  ✅ Last used: {lastVoiceUsed}
                </p>
              )}
            </div>
          )}
          
          {/* Test Button */}
          <button
            onClick={testTTS}
            disabled={speaking}
            className="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium touch-btn disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {speaking ? (
              <><span className="animate-pulse">🔊</span> Playing...</>
            ) : (
              <><svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg> Test Voice</>
            )}
          </button>
        </div>
        
        {/* Save Button */}
        <button
          onClick={handleSave}
          className="w-full bg-gray-900 text-white py-3 rounded-xl font-medium touch-btn shadow-lg"
        >
          {saved ? '✅ Saved!' : 'Save All Settings'}
        </button>
        
        {/* Debug Info */}
        <button onClick={() => setShowDebug(!showDebug)} className="text-xs text-gray-400 underline">
          {showDebug ? 'Hide' : 'Show'} Debug Info
        </button>
        
        {showDebug && (
          <div className="bg-gray-100 rounded-lg p-3 text-xs font-mono space-y-1">
            <p>Provider: {config.provider}</p>
            <p>Voice: {config.voice}</p>
            <p>API Status: {apiStatus}</p>
            <p>Last Voice: {lastVoiceUsed || 'None'}</p>
            <p>Font: {fontKey}</p>
            <p>Font Size: {sizeKey}</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default Settings
