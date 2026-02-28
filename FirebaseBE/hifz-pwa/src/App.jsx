import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Groups from './pages/Groups'
import Memorize from './pages/Memorize'

function App() {
  return (
    <div className="h-full bg-gray-50">
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="groups" element={<Groups />} />
          <Route path="memorize/:groupId" element={<Memorize />} />
        </Route>
      </Routes>
    </div>
  )
}

export default App
