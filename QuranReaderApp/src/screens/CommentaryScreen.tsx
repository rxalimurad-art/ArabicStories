import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  StatusBar,
  Dimensions,
  TouchableOpacity,
} from 'react-native';
import { useRoute, useNavigation } from '@react-navigation/native';
import RenderHtml from 'react-native-render-html';

import { RootStackParamList, SurahData, SurahParagraph, Commentary } from '../types';
import { getSurahByNumber } from '../data/surahs';
import { DataManager } from '../utils/DataManager';

type CommentaryScreenRouteProp = {
  key: string;
  name: 'Commentary';
  params: {
    surahNumber: number;
    paragraphIndex: number;
    commentaryType: 'albcomur' | 'tadcomur';
  };
};

const CommentaryScreen: React.FC = () => {
  const route = useRoute<CommentaryScreenRouteProp>();
  const navigation = useNavigation();
  const { surahNumber, paragraphIndex, commentaryType } = route.params;

  const [surahData, setSurahData] = useState<SurahData | null>(null);
  const [loading, setLoading] = useState(true);
  const [fontSize, setFontSize] = useState(16);
  
  const { width } = Dimensions.get('window');
  const surahInfo = getSurahByNumber(surahNumber);

  useEffect(() => {
    loadSurahData();
    if (surahInfo) {
      navigation.setOptions({
        title: `${surahInfo.transliteration} - تفسیر`,
      });
    }
  }, [surahNumber, surahInfo]);

  const loadSurahData = async () => {
    try {
      setLoading(true);
      const dataManager = DataManager.getInstance();
      const data = await dataManager.loadSurah(surahNumber);
      setSurahData(data);
    } catch (error) {
      console.error('Error loading surah data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2e7d32" />
        <Text style={styles.loadingText}>تفسیر لوڈ ہو رہی ہے...</Text>
      </View>
    );
  }

  if (!surahData || !surahData.paragraphs[paragraphIndex]) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>تفسیر دستیاب نہیں ہے</Text>
      </View>
    );
  }

  const paragraph = surahData.paragraphs[paragraphIndex];

  const renderGhamiCommentary = (commentaries: Commentary[]) => {
    return commentaries.map((commentary, index) => (
      <View key={commentary.cid} style={styles.commentaryItem}>
        <View style={styles.commentaryHeader}>
          <Text style={styles.commentaryNumber}>{commentary.cid}</Text>
          <Text style={styles.commentaryLabel}>غامدی تفسیر</Text>
        </View>
        <View style={styles.commentaryContent}>
          <RenderHtml
            contentWidth={width - 40}
            source={{ html: commentary.comment }}
            tagsStyles={{
              p: { 
                fontSize, 
                lineHeight: fontSize * 1.6, 
                textAlign: 'right', 
                color: '#444',
                marginBottom: 8
              },
              strong: { 
                fontWeight: 'bold', 
                color: '#2e7d32',
                fontSize: fontSize + 1
              },
              blockquote: {
                backgroundColor: '#f5f5f5',
                paddingHorizontal: 12,
                paddingVertical: 8,
                borderRightWidth: 4,
                borderRightColor: '#2e7d32',
                fontStyle: 'italic',
                marginVertical: 8
              },
              h5: {
                fontSize: fontSize + 2,
                fontWeight: 'bold',
                color: '#2e7d32',
                marginBottom: 8,
                textAlign: 'right'
              },
              br: { height: 8 }
            }}
          />
        </View>
      </View>
    ));
  };

  const renderTraditionalCommentary = (commentaries: string[]) => {
    return commentaries.map((commentary, index) => (
      <View key={index} style={styles.commentaryItem}>
        <View style={styles.commentaryHeader}>
          <Text style={styles.commentaryNumber}>{index + 1}</Text>
          <Text style={styles.commentaryLabel}>روایتی تفسیر</Text>
        </View>
        <View style={styles.commentaryContent}>
          <RenderHtml
            contentWidth={width - 40}
            source={{ html: commentary }}
            tagsStyles={{
              p: { 
                fontSize, 
                lineHeight: fontSize * 1.6, 
                textAlign: 'right', 
                color: '#444',
                marginBottom: 8
              },
              strong: { 
                fontWeight: 'bold', 
                color: '#2e7d32',
                fontSize: fontSize + 1
              },
              h5: {
                fontSize: fontSize + 2,
                fontWeight: 'bold',
                color: '#2e7d32',
                marginBottom: 8,
                textAlign: 'right'
              },
              blockquote: {
                backgroundColor: '#f5f5f5',
                paddingHorizontal: 12,
                paddingVertical: 8,
                borderRightWidth: 4,
                borderRightColor: '#2e7d32',
                fontStyle: 'italic',
                marginVertical: 8
              },
              br: { height: 8 }
            }}
          />
        </View>
      </View>
    ));
  };

  const renderFontControls = () => (
    <View style={styles.fontControls}>
      <TouchableOpacity
        style={styles.fontButton}
        onPress={() => setFontSize(Math.max(12, fontSize - 1))}
      >
        <Text style={styles.fontButtonText}>A-</Text>
      </TouchableOpacity>
      
      <Text style={styles.fontSizeText}>{fontSize}</Text>
      
      <TouchableOpacity
        style={styles.fontButton}
        onPress={() => setFontSize(Math.min(24, fontSize + 1))}
      >
        <Text style={styles.fontButtonText}>A+</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      {/* Header with context */}
      <View style={styles.contextContainer}>
        <Text style={styles.contextTitle}>
          {surahInfo?.transliteration} - آیت {paragraph.ayat.join('-')}
        </Text>
        <Text style={styles.contextArabic}>{paragraph.arabic}</Text>
        {renderFontControls()}
      </View>

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {commentaryType === 'albcomur' && paragraph.albcomur.length > 0 ? (
          renderGhamiCommentary(paragraph.albcomur)
        ) : commentaryType === 'tadcomur' && paragraph.tadcomur.length > 0 ? (
          renderTraditionalCommentary(paragraph.tadcomur)
        ) : (
          <View style={styles.noCommentaryContainer}>
            <Text style={styles.noCommentaryText}>
              اس آیت کے لیے تفسیر دستیاب نہیں ہے
            </Text>
          </View>
        )}
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
    textAlign: 'center',
  },
  contextContainer: {
    backgroundColor: '#ffffff',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  contextTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#2e7d32',
    textAlign: 'center',
    marginBottom: 8,
  },
  contextArabic: {
    fontSize: 20,
    color: '#333',
    textAlign: 'center',
    lineHeight: 30,
    marginBottom: 12,
    fontWeight: 'bold',
  },
  fontControls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  fontButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fontButtonText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#333',
  },
  fontSizeText: {
    fontSize: 14,
    color: '#666',
    minWidth: 20,
    textAlign: 'center',
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
  },
  commentaryItem: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    marginBottom: 16,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    overflow: 'hidden',
  },
  commentaryHeader: {
    backgroundColor: '#e8f5e8',
    paddingHorizontal: 16,
    paddingVertical: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  commentaryNumber: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#2e7d32',
  },
  commentaryLabel: {
    fontSize: 14,
    color: '#2e7d32',
    fontWeight: 'bold',
  },
  commentaryContent: {
    padding: 16,
  },
  noCommentaryContainer: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  noCommentaryText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
});

export default CommentaryScreen;