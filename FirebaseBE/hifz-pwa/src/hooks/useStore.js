import { useState, useEffect, useCallback } from 'react'
import { 
  collection, 
  doc, 
  addDoc, 
  updateDoc, 
  deleteDoc,
  onSnapshot,
  query,
  orderBy,
  serverTimestamp 
} from 'firebase/firestore'
import { db } from '../firebase'
import { getStaticGroupsWithStatus, updateStaticLineStatus } from '../data/sarf-static'

const COLLECTION_NAME = 'hifz_groups'

// Predefined main tags
export const MAIN_TAGS = ['nahw', 'sarf', 'quran', 'dua', 'hadith']

export function useStore() {
  const [firebaseGroups, setFirebaseGroups] = useState([])
  const [staticGroups, setStaticGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  
  // Initialize static Sarf groups
  useEffect(() => {
    setStaticGroups(getStaticGroupsWithStatus())
  }, [])
  
  // Subscribe to Firestore updates
  useEffect(() => {
    const q = query(collection(db, COLLECTION_NAME), orderBy('createdAt', 'desc'))
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const groupsData = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          lines: doc.data().lines || [],
          tags: doc.data().tags || [],
          isStatic: false
        }))
        setFirebaseGroups(groupsData)
        setLoading(false)
      },
      (err) => {
        console.error('Firestore error:', err)
        setError(err.message)
        setLoading(false)
      }
    )
    
    return () => unsubscribe()
  }, [])
  
  // Merge static and Firebase groups
  const groups = [...staticGroups, ...firebaseGroups]
  
  // Group operations (Firebase only)
  const addGroup = useCallback(async (name, tags = []) => {
    try {
      const docRef = await addDoc(collection(db, COLLECTION_NAME), {
        name,
        tags,
        lines: [],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      })
      return docRef.id
    } catch (err) {
      console.error('Error adding group:', err)
      throw err
    }
  }, [])
  
  const updateGroupTags = useCallback(async (groupId, tags) => {
    // Check if it's a static group
    const staticGroup = staticGroups.find(g => g.id === groupId)
    if (staticGroup) {
      // Static groups don't support tag editing
      console.log('Cannot edit tags for static Sarf groups')
      return
    }
    
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      await updateDoc(groupRef, {
        tags,
        updatedAt: serverTimestamp()
      })
    } catch (err) {
      console.error('Error updating tags:', err)
      throw err
    }
  }, [staticGroups])
  
  const deleteGroup = useCallback(async (groupId) => {
    // Check if it's a static group
    const staticGroup = staticGroups.find(g => g.id === groupId)
    if (staticGroup) {
      // Static groups cannot be deleted
      console.log('Cannot delete static Sarf groups')
      return
    }
    
    try {
      await deleteDoc(doc(db, COLLECTION_NAME, groupId))
    } catch (err) {
      console.error('Error deleting group:', err)
      throw err
    }
  }, [staticGroups])
  
  // Line operations
  const addLine = useCallback(async (groupId, arabic, translation = '') => {
    // Check if it's a static group
    const staticGroup = staticGroups.find(g => g.id === groupId)
    if (staticGroup) {
      // Static groups don't support adding lines
      console.log('Cannot add lines to static Sarf groups')
      return
    }
    
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = firebaseGroups.find(g => g.id === groupId)
      
      if (!group) throw new Error('Group not found')
      
      const newLine = {
        id: Date.now().toString(),
        arabic,
        translation,
        status: 'not_started',
        createdAt: new Date().toISOString()
      }
      
      await updateDoc(groupRef, {
        lines: [...group.lines, newLine],
        updatedAt: serverTimestamp()
      })
    } catch (err) {
      console.error('Error adding line:', err)
      throw err
    }
  }, [firebaseGroups, staticGroups])
  
  const updateLineStatus = useCallback(async (groupId, lineId, status) => {
    // Check if it's a static group
    const staticGroup = staticGroups.find(g => g.id === groupId)
    if (staticGroup) {
      // Update in localStorage
      updateStaticLineStatus(groupId, lineId, status)
      // Update local state
      setStaticGroups(prev => prev.map(g => {
        if (g.id === groupId) {
          return {
            ...g,
            lines: g.lines.map(l => l.id === lineId ? { ...l, status } : l)
          }
        }
        return g
      }))
      return
    }
    
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = firebaseGroups.find(g => g.id === groupId)
      
      if (!group) throw new Error('Group not found')
      
      const updatedLines = group.lines.map(line => 
        line.id === lineId ? { ...line, status } : line
      )
      
      await updateDoc(groupRef, {
        lines: updatedLines,
        updatedAt: serverTimestamp()
      })
    } catch (err) {
      console.error('Error updating line:', err)
      throw err
    }
  }, [firebaseGroups, staticGroups])
  
  const deleteLine = useCallback(async (groupId, lineId) => {
    // Check if it's a static group
    const staticGroup = staticGroups.find(g => g.id === groupId)
    if (staticGroup) {
      // Static groups don't support deleting lines
      console.log('Cannot delete lines from static Sarf groups')
      return
    }
    
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = firebaseGroups.find(g => g.id === groupId)
      
      if (!group) throw new Error('Group not found')
      
      const updatedLines = group.lines.filter(line => line.id !== lineId)
      
      await updateDoc(groupRef, {
        lines: updatedLines,
        updatedAt: serverTimestamp()
      })
    } catch (err) {
      console.error('Error deleting line:', err)
      throw err
    }
  }, [firebaseGroups, staticGroups])
  
  // Get progress
  const getGroupProgress = useCallback((groupId) => {
    const group = groups.find(g => g.id === groupId)
    if (!group || !group.lines || group.lines.length === 0) return 0
    
    const memorized = group.lines.filter(l => l.status === 'memorized').length
    const learning = group.lines.filter(l => l.status === 'learning').length
    
    return Math.round(((memorized * 1 + learning * 0.5) / group.lines.length) * 100)
  }, [groups])
  
  // Filter groups by tag
  const getGroupsByTag = useCallback((tag) => {
    if (!tag || tag === 'all') return groups
    return groups.filter(g => g.tags?.includes(tag))
  }, [groups])
  
  return {
    groups,
    loading,
    error,
    addGroup,
    updateGroupTags,
    deleteGroup,
    addLine,
    updateLineStatus,
    deleteLine,
    getGroupProgress,
    getGroupsByTag,
    MAIN_TAGS
  }
}
