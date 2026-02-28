import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Admin from './pages/Admin'
import Memorize from './pages/Memorize'
import Groups from './pages/Groups'

function App() {
  return (
    <div className="h-full bg-gray-50">
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="groups" element={<Groups />} />
          <Route path="memorize/:groupId" element={<Memorize />} />
          <Route path="admin" element={<Admin />} />
        </Route>
      </Routes>
    </div>
  )
}

export default App
