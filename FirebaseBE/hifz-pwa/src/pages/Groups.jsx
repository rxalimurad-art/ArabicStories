import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../hooks/useStore'

function Groups() {
  const { groups, loading, error, addGroup, addLine, deleteGroup, deleteLine } = useStore()
  const [view, setView] = useState('list') // 'list', 'create', 'edit'
  const [editingGroup, setEditingGroup] = useState(null)
  const [newGroupName, setNewGroupName] = useState('')
  const [newLine, setNewLine] = useState({ arabic: '', translation: '' })
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState(null)
  
  const handleCreateGroup = async (e) => {
    e.preventDefault()
    if (newGroupName.trim() && !saving) {
      setSaving(true)
      setSaveError(null)
      try {
        const groupId = await addGroup(newGroupName.trim())
        setNewGroupName('')
        // Switch to edit view for the new group
        const newGroup = groups.find(g => g.id === groupId) || { id: groupId, name: newGroupName, lines: [] }
        setEditingGroup(newGroup)
        setView('edit')
      } catch (err) {
        setSaveError('Error creating group: ' + err.message)
      }
      setSaving(false)
    }
  }
  
  const handleAddLine = async (e) => {
    e.preventDefault()
    if (newLine.arabic.trim() && editingGroup && !saving) {
      setSaving(true)
      setSaveError(null)
      try {
        await addLine(editingGroup.id, newLine.arabic.trim(), newLine.translation.trim())
        setNewLine({ arabic: '', translation: '' })
        // Refresh editing group
        const updated = groups.find(g => g.id === editingGroup.id)
        if (updated) setEditingGroup(updated)
      } catch (err) {
        setSaveError('Error adding line: ' + err.message)
      }
      setSaving(false)
    }
  }
  
  const handleDeleteGroup = async (groupId, groupName) => {
    if (confirm(`Delete "${groupName}" and all its lines?`)) {
      try {
        await deleteGroup(groupId)
        if (view === 'edit' && editingGroup?.id === groupId) {
          setView('list')
          setEditingGroup(null)
        }
      } catch (err) {
        alert('Error deleting group: ' + err.message)
      }
    }
  }
  
  const handleDeleteLine = async (groupId, lineId) => {
    try {
      await deleteLine(groupId, lineId)
      // Refresh editing group
      const updated = groups.find(g => g.id === groupId)
      if (updated) setEditingGroup(updated)
    } catch (err) {
      alert('Error deleting line: ' + err.message)
    }
  }
  
  const openEditGroup = (group) => {
    setEditingGroup(group)
    setNewLine({ arabic: '', translation: '' })
    setView('edit')
    setSaveError(null)
  }
  
  const openCreateGroup = () => {
    setNewGroupName('')
    setNewLine({ arabic: '', translation: '' })
    setView('create')
    setSaveError(null)
  }
  
  const goBack = () => {
    setView('list')
    setEditingGroup(null)
    setSaveError(null)
  }
  
  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-emerald-500 border-t-transparent" />
      </div>
    )
  }
  
  // LIST VIEW - Show all groups
  if (view === 'list') {
    return (
      <div className="h-full flex flex-col">
        {/* Header with Back */}
        <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
          <Link
            to="/"
            className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn"
          >
            <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </Link>
          <h2 className="text-lg font-semibold text-gray-900">My Groups</h2>
        </div>
        
        {/* Error */}
        {error && (
          <div className="mx-4 mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-600 text-sm">{error}</p>
          </div>
        )}
        
        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4 pb-20 space-y-4">
          {/* Add Group Button */}
          <button
            onClick={openCreateGroup}
            className="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium touch-btn flex items-center justify-center gap-2"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Create New Group
          </button>
          
          {/* Groups List */}
          {groups.length === 0 ? (
            <div className="text-center py-12">
              <span className="text-4xl">📖</span>
              <p className="text-gray-500 mt-4">No groups yet</p>
              <p className="text-sm text-gray-400 mt-2">Create your first group</p>
            </div>
          ) : (
            <div className="space-y-3">
              {groups.map(group => (
                <button
                  key={group.id}
                  onClick={() => openEditGroup(group)}
                  className="w-full bg-white rounded-xl p-4 shadow-sm border border-gray-100 text-left touch-btn"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <h4 className="font-medium text-gray-900">{group.name}</h4>
                      <p className="text-sm text-gray-500 mt-1">
                        {group.lines?.length || 0} lines
                      </p>
                    </div>
                    <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                    </svg>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    )
  }
  
  // CREATE VIEW - Create new group
  if (view === 'create') {
    return (
      <div className="h-full flex flex-col">
        {/* Header */}
        <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
          <button
            onClick={goBack}
            className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn"
          >
            <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h2 className="text-lg font-semibold text-gray-900">Create Group</h2>
        </div>
        
        {/* Error */}
        {saveError && (
          <div className="mx-4 mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-600 text-sm">{saveError}</p>
          </div>
        )}
        
        {/* Form */}
        <div className="flex-1 overflow-y-auto p-4 pb-20">
          <form onSubmit={handleCreateGroup} className="space-y-6">
            {/* Group Name */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Group Name</label>
              <input
                type="text"
                value={newGroupName}
                onChange={(e) => setNewGroupName(e.target.value)}
                placeholder="e.g., Al-Baqarah, Daily Duas, etc."
                className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 text-lg"
                autoFocus
              />
            </div>
            
            {/* Info */}
            <div className="bg-blue-50 rounded-lg p-4">
              <p className="text-sm text-blue-700">
                💡 After creating the group, you'll be able to add lines to it.
              </p>
            </div>
            
            {/* Submit */}
            <button
              type="submit"
              disabled={!newGroupName.trim() || saving}
              className="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium touch-btn disabled:opacity-50"
            >
              {saving ? 'Creating...' : 'Create Group'}
            </button>
          </form>
        </div>
      </div>
    )
  }
  
  // EDIT VIEW - Edit group (add lines, delete group)
  const group = groups.find(g => g.id === editingGroup?.id) || editingGroup
  
  if (!group) return null
  
  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-4 py-3 flex items-center gap-3">
        <button
          onClick={goBack}
          className="p-2 -ml-2 rounded-lg hover:bg-gray-100 touch-btn"
        >
          <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h2 className="text-lg font-semibold text-gray-900 flex-1 truncate">{group.name}</h2>
        <button
          onClick={() => handleDeleteGroup(group.id, group.name)}
          className="text-red-500 text-sm touch-btn px-2 py-1 rounded hover:bg-red-50"
        >
          Delete
        </button>
      </div>
      
      {/* Error */}
      {saveError && (
        <div className="mx-4 mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-red-600 text-sm">{saveError}</p>
        </div>
      )}
      
      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4 pb-20 space-y-6">
        {/* Add Line Form */}
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <h3 className="font-semibold text-gray-900 mb-3">Add New Line</h3>
          
          <form onSubmit={handleAddLine} className="space-y-3">
            <textarea
              value={newLine.arabic}
              onChange={(e) => setNewLine({ ...newLine, arabic: e.target.value })}
              placeholder="Arabic text"
              dir="rtl"
              rows={3}
              className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-arabic text-lg"
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
              disabled={!newLine.arabic.trim() || saving}
              className="w-full bg-emerald-600 text-white py-2 rounded-lg font-medium touch-btn disabled:opacity-50"
            >
              {saving ? 'Adding...' : 'Add Line'}
            </button>
          </form>
        </div>
        
        {/* Lines List */}
        <div>
          <h3 className="font-semibold text-gray-900 mb-3">
            Lines ({group.lines?.length || 0})
          </h3>
          
          {!group.lines || group.lines.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No lines yet. Add one above!</p>
          ) : (
            <div className="space-y-2">
              {group.lines.map((line, idx) => (
                <div 
                  key={line.id} 
                  className="bg-white rounded-xl p-4 shadow-sm border border-gray-100"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1">
                      <p className="font-arabic text-right text-lg leading-relaxed" dir="rtl">
                        {line.arabic}
                      </p>
                      {line.translation && (
                        <p className="text-sm text-gray-500 mt-2">
                          {line.translation}
                        </p>
                      )}
                    </div>
                    <button
                      onClick={() => handleDeleteLine(group.id, line.id)}
                      className="text-red-400 text-xl touch-btn w-8 h-8 flex items-center justify-center rounded hover:bg-red-50 flex-shrink-0"
                    >
                      ×
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default Groups
