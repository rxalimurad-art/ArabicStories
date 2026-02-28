import { useEffect } from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Groups from './pages/Groups'
import Memorize from './pages/Memorize'
import Settings from './pages/Settings'
import { useFont } from './hooks/useFont'

function FontApplier() {
  const { font } = useFont()
  
  useEffect(() => {
    // Apply font to root element
    document.documentElement.style.setProperty('--arabic-font', font.family)
    
    // Apply to all elements with Arabic text
    const style = document.getElementById('dynamic-arabic-font') || document.createElement('style')
    style.id = 'dynamic-arabic-font'
    style.textContent = `
      .font-arabic, 
      [dir="rtl"], 
      .arabic-text,
      .group-name-arabic,
      input[dir="rtl"],
      textarea[dir="rtl"] {
        font-family: ${font.family} !important;
      }
    `
    if (!document.getElementById('dynamic-arabic-font')) {
      document.head.appendChild(style)
    }
  }, [font.family])
  
  return null
}

function App() {
  return (
    <div className="h-full bg-gray-50">
      <FontApplier />
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="groups" element={<Groups />} />
          <Route path="memorize/:groupId" element={<Memorize />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    </div>
  )
}

export default App
