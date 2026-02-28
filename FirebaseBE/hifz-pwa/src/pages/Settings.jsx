import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSpeech } from '../hooks/useSpeech'
import { useFont, FONTS } from '../hooks/useFont'

function Settings() {
  const { speak, speaking, config, updateConfig, webSupported } = useSpeech()
  const { font, fontKey, setFont, fonts } = useFont()
  const [provider, setProvider] = useState(config.provider || 'web')
  const [voice, setVoice] = useState(config.voice || 'chirp-female')
  const [tempFont, setTempFont] = useState(fontKey)
  const [saved, setSaved] = useState(false)
  
  const handleSave = () => {
    updateConfig({ provider, voice })
    setFont(tempFont)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }
  
  const testTTS = () => {
    speak('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ')
  }
  
  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
        <Link
          to="/groups"
          className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn"
        >
          <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </Link>
        <h2 className="text-lg font-semibold text-gray-900">Settings</h2>
      </div>
      
      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4 pb-20 space-y-6">
        {/* Font Selection */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-4">Arabic Font</h3>
          
          <select
            value={tempFont}
            onChange={(e) => setTempFont(e.target.value)}
            className="w-full px-3 py-2.5 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white mb-3"
          >
            {Object.entries(fonts).map(([key, f]) => (
              <option key={key} value={key}>
                {f.name}
              </option>
            ))}
          </select>
          
          {/* Font Preview */}
          <div 
            className="bg-gray-50 rounded-lg p-4 text-center"
            style={{ fontFamily: fonts[tempFont]?.family || font.family }}
          >
            <p className="text-2xl leading-relaxed" dir="rtl">
              بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ
            </p>
            <p className="text-xs text-gray-500 mt-2 font-sans">
              {fonts[tempFont]?.desc || font.desc}
            </p>
          </div>
          
          <p className="text-xs text-gray-400 mt-2">
            💡 Scheherazade New is recommended for Indo-Pak style
          </p>
        </div>
        
        {/* TTS Provider */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-4">Text to Speech</h3>
          
          {/* Provider Selection */}
          <div className="space-y-3 mb-6">
            <label className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg cursor-pointer touch-btn">
              <input
                type="radio"
                name="provider"
                value="web"
                checked={provider === 'web'}
                onChange={(e) => setProvider(e.target.value)}
                className="w-5 h-5 text-emerald-600"
              />
              <div className="flex-1">
                <p className="font-medium text-gray-900">Browser TTS (Free)</p>
                <p className="text-xs text-gray-500">Built-in, works offline, basic voice</p>
              </div>
            </label>
            
            <label className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg cursor-pointer touch-btn bg-emerald-50 border-emerald-200">
              <input
                type="radio"
                name="provider"
                value="google"
                checked={provider === 'google'}
                onChange={(e) => setProvider(e.target.value)}
                className="w-5 h-5 text-emerald-600"
              />
              <div className="flex-1">
                <p className="font-medium text-gray-900">Google Cloud Chirp ⭐</p>
                <p className="text-xs text-emerald-600">Premium quality, ultra natural</p>
              </div>
            </label>
          </div>
          
          {/* Voice Selection (only for Google) */}
          {provider === 'google' && (
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Voice
              </label>
              <select
                value={voice}
                onChange={(e) => setVoice(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
              >
                <optgroup label="⭐ Chirp (Best Quality)">
                  <option value="chirp-female">Chirp3 HD - Female (A)</option>
                  <option value="chirp-male">Chirp3 HD - Male (D)</option>
                </optgroup>
                <optgroup label="WaveNet (Good Quality)">
                  <option value="wavenet-female">WaveNet - Female (A)</option>
                  <option value="wavenet-male">WaveNet - Male (B)</option>
                </optgroup>
              </select>
              
              <div className="mt-3 bg-emerald-50 rounded-lg p-3">
                <p className="text-sm text-emerald-800 font-medium">
                  🎙️ Chirp3 voices are Google's newest
                </p>
                <p className="text-xs text-emerald-600 mt-1">
                  • 1 million characters free per month<br/>
                  • After that: $4 per 1M characters
                </p>
              </div>
            </div>
          )}
          
          {/* Test Button */}
          <button
            onClick={testTTS}
            disabled={speaking || (provider === 'web' && !webSupported)}
            className="w-full border border-gray-200 text-gray-700 py-2.5 rounded-lg font-medium touch-btn disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {speaking ? (
              <>
                <span className="animate-pulse">🔊</span>
                Playing...
              </>
            ) : (
              <>
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
                Test Voice
              </>
            )}
          </button>
        </div>
        
        {/* Save Button */}
        <button
          onClick={handleSave}
          className="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium touch-btn shadow-lg"
        >
          {saved ? '✅ Saved!' : 'Save All Settings'}
        </button>
        
        {/* About */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-2">About</h3>
          <p className="text-sm text-gray-600">
            Hifz - Personal Arabic Memorizer
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Version 1.1 • Chirp Voice • Indo-Pak Fonts
          </p>
        </div>
      </div>
    </div>
  )
}

export default Settings
