import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  StatusBar,
  Dimensions,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types';

type HomeScreenNavigationProp = StackNavigationProp<RootStackParamList, 'Home'>;

const HomeScreen: React.FC = () => {
  const navigation = useNavigation<HomeScreenNavigationProp>();
  const { width } = Dimensions.get('window');

  const menuItems = [
    {
      title: 'قرآن کریم پڑھیں',
      subtitle: 'تمام سورتوں کی فہرست',
      onPress: () => navigation.navigate('SurahList'),
      color: '#4caf50',
    },
    {
      title: 'تلاش کریں',
      subtitle: 'آیات میں تلاش کریں',
      onPress: () => navigation.navigate('Search'),
      color: '#2196f3',
    },
    {
      title: 'نشان زد شدہ',
      subtitle: 'محفوظ کردہ آیات',
      onPress: () => navigation.navigate('Bookmarks'),
      color: '#ff9800',
    },
    {
      title: 'ترتیبات',
      subtitle: 'ایپ کی سیٹنگز',
      onPress: () => navigation.navigate('Settings'),
      color: '#9c27b0',
    },
  ];

  const quickAccessSurahs = [
    { number: 1, name: 'الفاتحہ', transliteration: 'Al-Fatiha' },
    { number: 2, name: 'البقرہ', transliteration: 'Al-Baqarah' },
    { number: 36, name: 'یٰس', transliteration: 'Ya-Sin' },
    { number: 67, name: 'الملک', transliteration: 'Al-Mulk' },
    { number: 112, name: 'الاخلاص', transliteration: 'Al-Ikhlas' },
  ];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>بِسْمِ اللّٰہِ الرَّحْمٰنِ الرَّحِیْمِ</Text>
        <Text style={styles.headerSubtitle}>القرآن الکریم</Text>
      </View>

      {/* Main Menu */}
      <View style={styles.menuContainer}>
        <Text style={styles.sectionTitle}>مینو</Text>
        {menuItems.map((item, index) => (
          <TouchableOpacity
            key={index}
            style={[styles.menuItem, { backgroundColor: item.color }]}
            onPress={item.onPress}
            activeOpacity={0.8}
          >
            <View style={styles.menuItemContent}>
              <Text style={styles.menuItemTitle}>{item.title}</Text>
              <Text style={styles.menuItemSubtitle}>{item.subtitle}</Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      {/* Quick Access */}
      <View style={styles.quickAccessContainer}>
        <Text style={styles.sectionTitle}>مشہور سورتیں</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {quickAccessSurahs.map((surah) => (
            <TouchableOpacity
              key={surah.number}
              style={styles.quickAccessItem}
              onPress={() => navigation.navigate('SurahReader', { surahNumber: surah.number })}
            >
              <Text style={styles.quickAccessNumber}>{surah.number}</Text>
              <Text style={styles.quickAccessName}>{surah.name}</Text>
              <Text style={styles.quickAccessTransliteration}>{surah.transliteration}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          "وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ"
        </Text>
        <Text style={styles.footerTranslation}>
          "اور ہم قرآن میں سے وہ چیز نازل کرتے ہیں جو مؤمنوں کے لیے شفا اور رحمت ہے"
        </Text>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  contentContainer: {
    paddingBottom: 20,
  },
  header: {
    backgroundColor: '#2e7d32',
    paddingVertical: 30,
    paddingHorizontal: 20,
    alignItems: 'center',
    borderBottomLeftRadius: 25,
    borderBottomRightRadius: 25,
  },
  headerTitle: {
    fontSize: 20,
    color: '#ffffff',
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  headerSubtitle: {
    fontSize: 24,
    color: '#ffffff',
    fontWeight: 'bold',
  },
  menuContainer: {
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 15,
    textAlign: 'right',
  },
  menuItem: {
    borderRadius: 15,
    marginBottom: 15,
    elevation: 3,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  menuItemContent: {
    padding: 20,
  },
  menuItemTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#ffffff',
    textAlign: 'right',
    marginBottom: 5,
  },
  menuItemSubtitle: {
    fontSize: 14,
    color: '#ffffff',
    opacity: 0.9,
    textAlign: 'right',
  },
  quickAccessContainer: {
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  quickAccessItem: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 15,
    marginRight: 12,
    alignItems: 'center',
    minWidth: 100,
    elevation: 2,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  quickAccessNumber: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2e7d32',
    marginBottom: 5,
  },
  quickAccessName: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
    textAlign: 'center',
    marginBottom: 2,
  },
  quickAccessTransliteration: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
  footer: {
    margin: 20,
    padding: 20,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    elevation: 2,
  },
  footerText: {
    fontSize: 16,
    color: '#2e7d32',
    textAlign: 'center',
    marginBottom: 8,
    lineHeight: 24,
  },
  footerTranslation: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    fontStyle: 'italic',
  },
});

export default HomeScreen;