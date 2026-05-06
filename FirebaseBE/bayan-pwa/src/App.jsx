import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import SurahView from './pages/SurahView'

export default function App() {
  return (
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/surah/:id" element={<SurahView />} />
      </Routes>
    </BrowserRouter>
  )
}
