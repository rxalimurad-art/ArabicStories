import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  StatusBar,
  Dimensions,
} from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import RenderHtml from 'react-native-render-html';

import { RootStackParamList, SurahData, SurahParagraph } from '../types';
import { getSurahByNumber } from '../data/surahs';
import { DataManager } from '../utils/DataManager';

type SurahReaderScreenNavigationProp = StackNavigationProp<RootStackParamList, 'SurahReader'>;
type SurahReaderScreenRouteProp = {
  key: string;
  name: 'SurahReader';
  params: { surahNumber: number; initialParagraph?: number };
};

const SurahReaderScreen: React.FC = () => {
  const navigation = useNavigation<SurahReaderScreenNavigationProp>();
  const route = useRoute<SurahReaderScreenRouteProp>();
  const { surahNumber, initialParagraph = 0 } = route.params;
  
  const [surahData, setSurahData] = useState<SurahData | null>(null);
  const [loading, setLoading] = useState(true);
  const [showTranslation, setShowTranslation] = useState(true);
  const [fontSize, setFontSize] = useState(18);
  const [arabicFontSize, setArabicFontSize] = useState(24);
  
  const scrollViewRef = useRef<ScrollView>(null);
  const { width } = Dimensions.get('window');

  const surahInfo = getSurahByNumber(surahNumber);

  useEffect(() => {
    loadSurahData();
  }, [surahNumber]);

  useEffect(() => {
    if (surahInfo) {
      navigation.setOptions({
        title: `${surahInfo.number}. ${surahInfo.transliteration}`,
      });
    }
  }, [surahInfo]);

  const loadSurahData = async () => {
    try {
      setLoading(true);
      const dataManager = DataManager.getInstance();
      const data = await dataManager.loadSurah(surahNumber);
      setSurahData(data);
    } catch (error) {
      console.error('Error loading surah data:', error);
      Alert.alert('خرابی', 'سورت لوڈ کرنے میں مسئلہ ہوا');
    } finally {
      setLoading(false);
    }
  };

  const renderParagraph = (paragraph: SurahParagraph, index: number) => {
    // Skip paragraph 0 (title) for actual content
    if (paragraph.paragraph === '0') {
      return (
        <View key={index} style={styles.titleContainer}>
          <Text style={styles.surahTitle}>{paragraph.arabic}</Text>
          {surahInfo && (
            <Text style={styles.surahSubtitle}>
              {surahInfo.transliteration} • {surahInfo.ayahCount} آیات • {surahInfo.revelationType}
            </Text>
          )}
        </View>
      );
    }

    return (
      <View key={index} style={styles.paragraphContainer}>
        {/* Ayah numbers */}
        {paragraph.ayat.length > 0 && paragraph.ayat[0] !== 0 && (
          <View style={styles.ayahNumbers}>
            <Text style={styles.ayahNumbersText}>
              آیت {paragraph.ayat.join('-')}
            </Text>
          </View>
        )}

        {/* Arabic text */}
        <View style={styles.arabicContainer}>
          <Text style={[styles.arabicText, { fontSize: arabicFontSize }]}>
            {paragraph.arabic}
          </Text>
        </View>

        {/* Translation */}
        {showTranslation && (
          <View style={styles.translationContainer}>
            <RenderHtml
              contentWidth={width - 40}
              source={{ html: paragraph.albtraur || paragraph.tadtraur }}
              tagsStyles={{
                p: { fontSize, lineHeight: fontSize * 1.5, textAlign: 'right', color: '#444' },
                span: { fontSize, color: '#444' },
                strong: { fontWeight: 'bold', color: '#333' },
              }}
            />
          </View>
        )}

        {/* Commentary button */}
        {(paragraph.albcomur.length > 0 || paragraph.tadcomur.length > 0) && (
          <TouchableOpacity
            style={styles.commentaryButton}
            onPress={() => navigation.navigate('Commentary', {
              surahNumber,
              paragraphIndex: index,
              commentaryType: paragraph.albcomur.length > 0 ? 'albcomur' : 'tadcomur'
            })}
          >
            <Text style={styles.commentaryButtonText}>تفسیر دیکھیں</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const renderControls = () => (
    <View style={styles.controlsContainer}>
      <TouchableOpacity
        style={[styles.controlButton, showTranslation && styles.controlButtonActive]}
        onPress={() => setShowTranslation(!showTranslation)}
      >
        <Text style={[
          styles.controlButtonText,
          showTranslation && styles.controlButtonTextActive
        ]}>
          ترجمہ
        </Text>
      </TouchableOpacity>

      <View style={styles.fontControls}>
        <TouchableOpacity
          style={styles.fontButton}
          onPress={() => {
            setFontSize(Math.max(12, fontSize - 2));
            setArabicFontSize(Math.max(16, arabicFontSize - 2));
          }}
        >
          <Text style={styles.fontButtonText}>A-</Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={styles.fontButton}
          onPress={() => {
            setFontSize(Math.min(24, fontSize + 2));
            setArabicFontSize(Math.min(32, arabicFontSize + 2));
          }}
        >
          <Text style={styles.fontButtonText}>A+</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2e7d32" />
        <Text style={styles.loadingText}>سورت لوڈ ہو رہی ہے...</Text>
      </View>
    );
  }

  if (!surahData) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>سورت لوڈ نہیں ہو سکی</Text>
        <TouchableOpacity style={styles.retryButton} onPress={loadSurahData}>
          <Text style={styles.retryButtonText}>دوبارہ کوشش</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      {renderControls()}
      
      <ScrollView
        ref={scrollViewRef}
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Bismillah */}
        {surahNumber !== 1 && surahNumber !== 9 && (
          <View style={styles.bismillahContainer}>
            <Text style={styles.bismillahText}>
              بِسْمِ اللّٰہِ الرَّحْمٰنِ الرَّحِیْمِ
            </Text>
          </View>
        )}

        {surahData.paragraphs.map(renderParagraph)}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
    padding: 20,
  },
  errorText: {
    fontSize: 18,
    color: '#666',
    marginBottom: 20,
    textAlign: 'center',
  },
  retryButton: {
    backgroundColor: '#2e7d32',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  controlsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  controlButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  controlButtonActive: {
    backgroundColor: '#2e7d32',
    borderColor: '#2e7d32',
  },
  controlButtonText: {
    fontSize: 14,
    color: '#666',
  },
  controlButtonTextActive: {
    color: '#ffffff',
    fontWeight: 'bold',
  },
  fontControls: {
    flexDirection: 'row',
    gap: 8,
  },
  fontButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fontButtonText: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
  },
  bismillahContainer: {
    alignItems: 'center',
    marginBottom: 20,
    paddingVertical: 15,
  },
  bismillahText: {
    fontSize: 22,
    color: '#2e7d32',
    fontWeight: 'bold',
  },
  titleContainer: {
    alignItems: 'center',
    marginBottom: 20,
    paddingVertical: 15,
  },
  surahTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#2e7d32',
    marginBottom: 8,
  },
  surahSubtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  paragraphContainer: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  ayahNumbers: {
    alignSelf: 'flex-start',
    backgroundColor: '#e8f5e8',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginBottom: 12,
  },
  ayahNumbersText: {
    fontSize: 12,
    color: '#2e7d32',
    fontWeight: 'bold',
  },
  arabicContainer: {
    marginBottom: 16,
  },
  arabicText: {
    textAlign: 'right',
    lineHeight: 36,
    color: '#333',
    fontWeight: 'bold',
  },
  translationContainer: {
    marginTop: 8,
  },
  commentaryButton: {
    alignSelf: 'flex-start',
    backgroundColor: '#2196f3',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    marginTop: 12,
  },
  commentaryButtonText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: 'bold',
  },
});

export default SurahReaderScreen;