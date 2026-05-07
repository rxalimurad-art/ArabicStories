import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  StatusBar,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import AsyncStorage from '@react-native-async-storage/async-storage';

import { RootStackParamList, Bookmark } from '../types';
import { getSurahByNumber } from '../data/surahs';

type BookmarksScreenNavigationProp = StackNavigationProp<RootStackParamList, 'Bookmarks'>;

const BookmarksScreen: React.FC = () => {
  const navigation = useNavigation<BookmarksScreenNavigationProp>();
  const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadBookmarks();
  }, []);

  const loadBookmarks = async () => {
    try {
      const saved = await AsyncStorage.getItem('quran_bookmarks');
      if (saved) {
        const parsedBookmarks = JSON.parse(saved);
        setBookmarks(parsedBookmarks.sort((a: Bookmark, b: Bookmark) => b.timestamp - a.timestamp));
      }
    } catch (error) {
      console.error('Error loading bookmarks:', error);
    } finally {
      setLoading(false);
    }
  };

  const deleteBookmark = async (bookmarkToDelete: Bookmark) => {
    Alert.alert(
      'نشان زد شدہ حذف کریں',
      'کیا آپ واقعی اس نشان زد شدہ آیت کو حذف کرنا چاہتے ہیں؟',
      [
        { text: 'منسوخ', style: 'cancel' },
        {
          text: 'حذف کریں',
          style: 'destructive',
          onPress: async () => {
            try {
              const updated = bookmarks.filter(
                bookmark => 
                  !(bookmark.surahNumber === bookmarkToDelete.surahNumber &&
                    bookmark.paragraphIndex === bookmarkToDelete.paragraphIndex &&
                    bookmark.ayahNumber === bookmarkToDelete.ayahNumber)
              );
              setBookmarks(updated);
              await AsyncStorage.setItem('quran_bookmarks', JSON.stringify(updated));
            } catch (error) {
              console.error('Error deleting bookmark:', error);
            }
          }
        }
      ]
    );
  };

  const formatDate = (timestamp: number) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString('ur-PK', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const renderBookmark = ({ item }: { item: Bookmark }) => {
    const surahInfo = getSurahByNumber(item.surahNumber);
    
    return (
      <TouchableOpacity
        style={styles.bookmarkItem}
        onPress={() => navigation.navigate('SurahReader', {
          surahNumber: item.surahNumber,
          initialParagraph: item.paragraphIndex
        })}
        activeOpacity={0.7}
      >
        <View style={styles.bookmarkContent}>
          <View style={styles.bookmarkHeader}>
            <Text style={styles.surahName}>
              {surahInfo?.transliteration || `سورہ ${item.surahNumber}`}
            </Text>
            <TouchableOpacity
              style={styles.deleteButton}
              onPress={() => deleteBookmark(item)}
            >
              <Text style={styles.deleteButtonText}>✕</Text>
            </TouchableOpacity>
          </View>
          
          <Text style={styles.ayahInfo}>
            آیت {item.ayahNumber} • {surahInfo?.revelationType}
          </Text>
          
          {item.note && (
            <Text style={styles.noteText}>{item.note}</Text>
          )}
          
          <Text style={styles.dateText}>
            {formatDate(item.timestamp)}
          </Text>
        </View>
      </TouchableOpacity>
    );
  };

  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyTitle}>کوئی نشان زد شدہ آیات نہیں</Text>
      <Text style={styles.emptySubtitle}>
        آیات پڑھتے وقت نشان زد کرنے کے لیے آیت پر لمبا دبائیں
      </Text>
      <TouchableOpacity
        style={styles.browseButton}
        onPress={() => navigation.navigate('SurahList')}
      >
        <Text style={styles.browseButtonText}>قرآن پڑھنا شروع کریں</Text>
      </TouchableOpacity>
    </View>
  );

  const clearAllBookmarks = () => {
    Alert.alert(
      'تمام نشان زد شدہ حذف کریں',
      'کیا آپ واقعی تمام نشان زد شدہ آیات کو حذف کرنا چاہتے ہیں؟',
      [
        { text: 'منسوخ', style: 'cancel' },
        {
          text: 'تمام حذف کریں',
          style: 'destructive',
          onPress: async () => {
            try {
              setBookmarks([]);
              await AsyncStorage.removeItem('quran_bookmarks');
            } catch (error) {
              console.error('Error clearing bookmarks:', error);
            }
          }
        }
      ]
    );
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      {bookmarks.length > 0 && (
        <View style={styles.headerActions}>
          <Text style={styles.bookmarkCount}>
            {bookmarks.length} نشان زد شدہ آیات
          </Text>
          <TouchableOpacity
            style={styles.clearAllButton}
            onPress={clearAllBookmarks}
          >
            <Text style={styles.clearAllButtonText}>تمام حذف کریں</Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={bookmarks}
        renderItem={renderBookmark}
        keyExtractor={(item, index) => `${item.surahNumber}-${item.paragraphIndex}-${item.ayahNumber}-${index}`}
        contentContainerStyle={[
          styles.listContent,
          bookmarks.length === 0 && styles.listContentEmpty
        ]}
        ListEmptyComponent={renderEmptyState}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  headerActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  bookmarkCount: {
    fontSize: 14,
    color: '#666',
  },
  clearAllButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    backgroundColor: '#f44336',
  },
  clearAllButtonText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: 'bold',
  },
  listContent: {
    padding: 16,
  },
  listContentEmpty: {
    flex: 1,
    justifyContent: 'center',
  },
  bookmarkItem: {
    backgroundColor: '#ffffff',
    borderRadius: 8,
    marginBottom: 12,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  bookmarkContent: {
    padding: 16,
  },
  bookmarkHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  surahName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#2e7d32',
  },
  deleteButton: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#f44336',
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButtonText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  ayahInfo: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
    textAlign: 'right',
  },
  noteText: {
    fontSize: 14,
    color: '#333',
    fontStyle: 'italic',
    marginBottom: 8,
    textAlign: 'right',
    backgroundColor: '#f5f5f5',
    padding: 8,
    borderRadius: 4,
  },
  dateText: {
    fontSize: 12,
    color: '#888',
    textAlign: 'right',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    paddingHorizontal: 20,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
    textAlign: 'center',
  },
  emptySubtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 30,
  },
  browseButton: {
    backgroundColor: '#2e7d32',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  browseButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default BookmarksScreen;