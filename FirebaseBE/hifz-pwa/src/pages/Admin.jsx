import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

function Admin() {
  const { groups, loading, addGroup, addLine, deleteGroup, deleteLine } = useStore()
  const [newGroupName, setNewGroupName] = useState('')
  const [selectedGroup, setSelectedGroup] = useState(null)
  const [newLine, setNewLine] = useState({ arabic: '', translation: '' })
  const [saving, setSaving] = useState(false)
  
  const handleAddGroup = async (e) => {
    e.preventDefault()
    if (newGroupName.trim() && !saving) {
      setSaving(true)
      try {
        await addGroup(newGroupName.trim())
        setNewGroupName('')
      } catch (err) {
        alert('Error adding group: ' + err.message)
      }
      setSaving(false)
    }
  }
  
  const handleAddLine = async (e) => {
    e.preventDefault()
    if (newLine.arabic.trim() && selectedGroup && !saving) {
      setSaving(true)
      try {
        await addLine(selectedGroup, newLine.arabic.trim(), newLine.translation.trim())
        setNewLine({ arabic: '', translation: '' })
      } catch (err) {
        alert('Error adding line: ' + err.message)
      }
      setSaving(false)
    }
  }
  
  const handleDeleteGroup = async (groupId, groupName) => {
    if (confirm(`Delete "${groupName}" and all its lines?`)) {
      try {
        await deleteGroup(groupId)
      } catch (err) {
        alert('Error deleting group: ' + err.message)
      }
    }
  }
  
  const handleDeleteLine = async (groupId, lineId) => {
    try {
      await deleteLine(groupId, lineId)
    } catch (err) {
      alert('Error deleting line: ' + err.message)
    }
  }
  
  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-emerald-500 border-t-transparent" />
      </div>
    )
  }
  
  return (
    <div className="h-full flex flex-col">
      {/* Header with Back Button */}
      <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
        <Link
          to="/"
          className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn"
        >
          <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </Link>
        <h2 className="text-lg font-semibold text-gray-900">Add Content</h2>
      </div>
      
      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4 pb-20 space-y-6">
        {/* Add Group */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-3">Add New Group</h3>
          <form onSubmit={handleAddGroup} className="flex gap-2">
            <input
              type="text"
              value={newGroupName}
              onChange={(e) => setNewGroupName(e.target.value)}
              placeholder="e.g., Al-Baqarah"
              className="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
            <button
              type="submit"
              disabled={saving}
              className="bg-emerald-600 text-white px-4 py-2 rounded-lg font-medium touch-btn disabled:opacity-50"
            >
              {saving ? '...' : 'Add'}
            </button>
          </form>
        </div>
        
        {/* Add Line */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-3">Add Line to Group</h3>
          
          <form onSubmit={handleAddLine} className="space-y-3">
            <select
              value={selectedGroup || ''}
              onChange={(e) => setSelectedGroup(e.target.value)}
              className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
            >
              <option value="">Select a group...</option>
              {groups.map(group => (
                <option key={group.id} value={group.id}>{group.name}</option>
              ))}
            </select>
            
            <textarea
              value={newLine.arabic}
              onChange={(e) => setNewLine({ ...newLine, arabic: e.target.value })}
              placeholder="Arabic text (required)"
              dir="rtl"
              rows={3}
              className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-arabic text-lg"
            />
            
            <textarea
              value={newLine.translation}
              onChange={(e) => setNewLine({ ...newLine, translation: e.target.value })}
              placeholder="Translation (optional)"
              rows={2}
              className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 text-sm"
            />
            
            <button
              type="submit"
              disabled={!selectedGroup || !newLine.arabic.trim() || saving}
              className="w-full bg-emerald-600 text-white py-2 rounded-lg font-medium touch-btn disabled:opacity-50"
            >
              {saving ? 'Adding...' : 'Add Line'}
            </button>
          </form>
        </div>
        
        {/* Manage Groups */}
        <div>
          <h3 className="font-semibold text-gray-900 mb-3">Manage Groups</h3>
          
          {groups.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No groups yet</p>
          ) : (
            <div className="space-y-3">
              {groups.map(group => (
                <div key={group.id} className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
                  <div className="flex items-center justify-between mb-3">
                    <h4 className="font-medium text-gray-900">{group.name}</h4>
                    <button
                      onClick={() => handleDeleteGroup(group.id, group.name)}
                      className="text-red-500 text-sm touch-btn"
                    >
                      Delete
                    </button>
                  </div>
                  
                  {/* Lines in this group */}
                  {group.lines && group.lines.length > 0 && (
                    <div className="space-y-2">
                      {group.lines.map((line, idx) => (
                        <div 
                          key={line.id} 
                          className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg"
                        >
                          <div className="flex-1 min-w-0">
                            <p className="font-arabic text-right truncate" dir="rtl">
                              {idx + 1}. {line.arabic?.substring(0, 30)}...
                            </p>
                          </div>
                          <button
                            onClick={() => handleDeleteLine(group.id, line.id)}
                            className="ml-2 text-red-400 text-sm touch-btn"
                          >
                            ×
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                  
                  <p className="text-xs text-gray-400 mt-2">
                    {group.lines?.length || 0} line{(group.lines?.length || 0) !== 1 ? 's' : ''}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default Admin
