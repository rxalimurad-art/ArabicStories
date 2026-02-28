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

const COLLECTION_NAME = 'hifz_groups'

export function useStore() {
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  
  // Subscribe to Firestore updates
  useEffect(() => {
    const q = query(collection(db, COLLECTION_NAME), orderBy('createdAt', 'desc'))
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const groupsData = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          // Ensure lines is always an array
          lines: doc.data().lines || []
        }))
        setGroups(groupsData)
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
  
  // Group operations
  const addGroup = useCallback(async (name) => {
    try {
      const docRef = await addDoc(collection(db, COLLECTION_NAME), {
        name,
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
  
  const deleteGroup = useCallback(async (groupId) => {
    try {
      await deleteDoc(doc(db, COLLECTION_NAME, groupId))
    } catch (err) {
      console.error('Error deleting group:', err)
      throw err
    }
  }, [])
  
  // Line operations
  const addLine = useCallback(async (groupId, arabic, translation = '') => {
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = groups.find(g => g.id === groupId)
      
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
  }, [groups])
  
  const updateLineStatus = useCallback(async (groupId, lineId, status) => {
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = groups.find(g => g.id === groupId)
      
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
  }, [groups])
  
  const deleteLine = useCallback(async (groupId, lineId) => {
    try {
      const groupRef = doc(db, COLLECTION_NAME, groupId)
      const group = groups.find(g => g.id === groupId)
      
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
  }, [groups])
  
  // Get progress
  const getGroupProgress = useCallback((groupId) => {
    const group = groups.find(g => g.id === groupId)
    if (!group || !group.lines || group.lines.length === 0) return 0
    
    const memorized = group.lines.filter(l => l.status === 'memorized').length
    const learning = group.lines.filter(l => l.status === 'learning').length
    
    return Math.round(((memorized * 1 + learning * 0.5) / group.lines.length) * 100)
  }, [groups])
  
  return {
    groups,
    loading,
    error,
    addGroup,
    deleteGroup,
    addLine,
    updateLineStatus,
    deleteLine,
    getGroupProgress
  }
}
