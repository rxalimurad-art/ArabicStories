import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  TextInput,
  StatusBar,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types';
import { SURAHS, SurahInfo } from '../data/surahs';

type SurahListScreenNavigationProp = StackNavigationProp<RootStackParamList, 'SurahList'>;

const SurahListScreen: React.FC = () => {
  const navigation = useNavigation<SurahListScreenNavigationProp>();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'مکی' | 'مدنی'>('all');

  const filteredSurahs = useMemo(() => {
    let filtered = SURAHS;

    // Filter by revelation type
    if (filterType !== 'all') {
      filtered = filtered.filter(surah => surah.revelationType === filterType);
    }

    // Filter by search query
    if (searchQuery.trim()) {
      filtered = filtered.filter(surah => 
        surah.arabicName.includes(searchQuery) ||
        surah.transliteration.includes(searchQuery) ||
        surah.number.toString().includes(searchQuery)
      );
    }

    return filtered;
  }, [searchQuery, filterType]);

  const renderSurahItem = ({ item }: { item: SurahInfo }) => (
    <TouchableOpacity
      style={styles.surahItem}
      onPress={() => navigation.navigate('SurahReader', { surahNumber: item.number })}
      activeOpacity={0.7}
    >
      <View style={styles.surahContent}>
        <View style={styles.surahNumber}>
          <Text style={styles.surahNumberText}>{item.number}</Text>
        </View>
        
        <View style={styles.surahInfo}>
          <Text style={styles.arabicName}>{item.arabicName}</Text>
          <Text style={styles.transliteration}>{item.transliteration}</Text>
          <Text style={styles.surahDetails}>
            {item.ayahCount} آیات • {item.revelationType}
          </Text>
        </View>
        
        <View style={[
          styles.revelationTypeIndicator,
          { backgroundColor: item.revelationType === 'مکی' ? '#4caf50' : '#2196f3' }
        ]}>
          <Text style={styles.revelationTypeText}>{item.revelationType}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );

  const renderHeader = () => (
    <View style={styles.headerContainer}>
      <TextInput
        style={styles.searchInput}
        placeholder="سورت تلاش کریں..."
        placeholderTextColor="#888"
        value={searchQuery}
        onChangeText={setSearchQuery}
        textAlign="right"
      />
      
      <View style={styles.filterContainer}>
        {['all', 'مکی', 'مدنی'].map((type) => (
          <TouchableOpacity
            key={type}
            style={[
              styles.filterButton,
              filterType === type && styles.filterButtonActive
            ]}
            onPress={() => setFilterType(type as any)}
          >
            <Text style={[
              styles.filterButtonText,
              filterType === type && styles.filterButtonTextActive
            ]}>
              {type === 'all' ? 'تمام' : type}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
      
      <Text style={styles.resultCount}>
        {filteredSurahs.length} سورتیں ملیں
      </Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      <FlatList
        data={filteredSurahs}
        renderItem={renderSurahItem}
        keyExtractor={(item) => item.number.toString()}
        ListHeaderComponent={renderHeader}
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  listContent: {
    padding: 16,
  },
  headerContainer: {
    marginBottom: 20,
  },
  searchInput: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    marginBottom: 12,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  filterContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 12,
  },
  filterButton: {
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  filterButtonActive: {
    backgroundColor: '#2e7d32',
    borderColor: '#2e7d32',
  },
  filterButtonText: {
    fontSize: 14,
    color: '#666',
  },
  filterButtonTextActive: {
    color: '#ffffff',
    fontWeight: 'bold',
  },
  resultCount: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  surahItem: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    marginBottom: 12,
    elevation: 3,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 3,
  },
  surahContent: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
  },
  surahNumber: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  surahNumberText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2e7d32',
  },
  surahInfo: {
    flex: 1,
    alignItems: 'flex-end',
  },
  arabicName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  transliteration: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  surahDetails: {
    fontSize: 14,
    color: '#888',
  },
  revelationTypeIndicator: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    marginLeft: 12,
  },
  revelationTypeText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: 'bold',
  },
});

export default SurahListScreen;