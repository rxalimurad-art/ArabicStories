import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  FlatList,
  ActivityIndicator,
  StatusBar,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';

import { RootStackParamList, SearchResult } from '../types';
import { SURAHS } from '../data/surahs';
import { DataManager } from '../utils/DataManager';

type SearchScreenNavigationProp = StackNavigationProp<RootStackParamList, 'Search'>;

const SearchScreen: React.FC = () => {
  const navigation = useNavigation<SearchScreenNavigationProp>();
  
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchType, setSearchType] = useState<'translation' | 'arabic'>('translation');

  const performSearch = async () => {
    if (!searchQuery.trim()) return;

    setLoading(true);
    setSearchResults([]);

    try {
      const dataManager = DataManager.getInstance();
      const results: SearchResult[] = [];

      // Search in available surahs (1, 2, 112 for demo)
      const availableSurahs = [1, 2, 112];
      
      for (const surahNumber of availableSurahs) {
        try {
          const surahData = await dataManager.loadSurah(surahNumber);
          const matches = dataManager.searchInSurah(surahData, searchQuery, searchType);
          
          matches.forEach((paragraph, index) => {
            if (paragraph.ayat.length > 0 && paragraph.ayat[0] !== 0) {
              results.push({
                surahNumber,
                paragraphIndex: index,
                ayahNumbers: paragraph.ayat,
                arabicText: paragraph.arabic,
                translationText: paragraph.tadtraur,
                matchType: searchType,
              });
            }
          });
        } catch (error) {
          console.log(`Surah ${surahNumber} not available for search`);
        }
      }

      setSearchResults(results);
    } catch (error) {
      console.error('Search error:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderSearchResult = ({ item }: { item: SearchResult }) => {
    const surahInfo = SURAHS.find(s => s.number === item.surahNumber);
    
    return (
      <TouchableOpacity
        style={styles.resultItem}
        onPress={() => navigation.navigate('SurahReader', {
          surahNumber: item.surahNumber,
          initialParagraph: item.paragraphIndex
        })}
        activeOpacity={0.7}
      >
        <View style={styles.resultHeader}>
          <Text style={styles.resultSurah}>
            {surahInfo?.transliteration} ({item.surahNumber})
          </Text>
          <Text style={styles.resultAyah}>
            آیت {item.ayahNumbers.join('-')}
          </Text>
        </View>
        
        <Text style={styles.resultArabic} numberOfLines={2}>
          {item.arabicText}
        </Text>
        
        <Text style={styles.resultTranslation} numberOfLines={3}>
          {item.translationText.replace(/<[^>]*>/g, '').replace(/=\d+=/g, '')}
        </Text>
      </TouchableOpacity>
    );
  };

  const renderSearchTypeButtons = () => (
    <View style={styles.searchTypeContainer}>
      <TouchableOpacity
        style={[
          styles.searchTypeButton,
          searchType === 'translation' && styles.searchTypeButtonActive
        ]}
        onPress={() => setSearchType('translation')}
      >
        <Text style={[
          styles.searchTypeButtonText,
          searchType === 'translation' && styles.searchTypeButtonTextActive
        ]}>
          ترجمے میں تلاش
        </Text>
      </TouchableOpacity>
      
      <TouchableOpacity
        style={[
          styles.searchTypeButton,
          searchType === 'arabic' && styles.searchTypeButtonActive
        ]}
        onPress={() => setSearchType('arabic')}
      >
        <Text style={[
          styles.searchTypeButtonText,
          searchType === 'arabic' && styles.searchTypeButtonTextActive
        ]}>
          عربی میں تلاش
        </Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="آیات میں تلاش کریں..."
          placeholderTextColor="#888"
          value={searchQuery}
          onChangeText={setSearchQuery}
          textAlign="right"
          onSubmitEditing={performSearch}
        />
        
        {renderSearchTypeButtons()}
        
        <TouchableOpacity
          style={[styles.searchButton, loading && styles.searchButtonDisabled]}
          onPress={performSearch}
          disabled={loading || !searchQuery.trim()}
        >
          <Text style={styles.searchButtonText}>
            {loading ? 'تلاش کر رہے ہیں...' : 'تلاش کریں'}
          </Text>
        </TouchableOpacity>
      </View>

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#2e7d32" />
        </View>
      ) : (
        <FlatList
          data={searchResults}
          renderItem={renderSearchResult}
          keyExtractor={(item, index) => `${item.surahNumber}-${item.paragraphIndex}-${index}`}
          contentContainerStyle={styles.resultsContainer}
          ListEmptyComponent={
            searchQuery && !loading ? (
              <View style={styles.noResultsContainer}>
                <Text style={styles.noResultsText}>کوئی نتیجہ نہیں ملا</Text>
                <Text style={styles.noResultsSubtext}>
                  مختلف الفاظ استعمال کر کے دوبارہ کوشش کریں
                </Text>
              </View>
            ) : null
          }
          showsVerticalScrollIndicator={false}
        />
      )}

      {searchResults.length > 0 && (
        <View style={styles.resultsCount}>
          <Text style={styles.resultsCountText}>
            {searchResults.length} نتائج ملے
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  searchContainer: {
    backgroundColor: '#ffffff',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  searchInput: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    marginBottom: 12,
    backgroundColor: '#f8f9fa',
  },
  searchTypeContainer: {
    flexDirection: 'row',
    marginBottom: 12,
    gap: 8,
  },
  searchTypeButton: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    alignItems: 'center',
  },
  searchTypeButtonActive: {
    backgroundColor: '#2e7d32',
    borderColor: '#2e7d32',
  },
  searchTypeButtonText: {
    fontSize: 14,
    color: '#666',
  },
  searchTypeButtonTextActive: {
    color: '#ffffff',
    fontWeight: 'bold',
  },
  searchButton: {
    backgroundColor: '#2e7d32',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  searchButtonDisabled: {
    backgroundColor: '#ccc',
  },
  searchButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  resultsContainer: {
    padding: 16,
  },
  resultItem: {
    backgroundColor: '#ffffff',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  resultHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  resultSurah: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#2e7d32',
  },
  resultAyah: {
    fontSize: 12,
    color: '#666',
  },
  resultArabic: {
    fontSize: 18,
    color: '#333',
    textAlign: 'right',
    marginBottom: 8,
    lineHeight: 28,
    fontWeight: 'bold',
  },
  resultTranslation: {
    fontSize: 14,
    color: '#666',
    textAlign: 'right',
    lineHeight: 20,
  },
  noResultsContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  noResultsText: {
    fontSize: 18,
    color: '#666',
    marginBottom: 8,
  },
  noResultsSubtext: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
  },
  resultsCount: {
    backgroundColor: '#ffffff',
    padding: 8,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    alignItems: 'center',
  },
  resultsCountText: {
    fontSize: 12,
    color: '#666',
  },
});

export default SearchScreen;