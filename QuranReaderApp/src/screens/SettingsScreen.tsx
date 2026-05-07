import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Switch,
  ScrollView,
  StatusBar,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

import { AppSettings } from '../types';

const SettingsScreen: React.FC = () => {
  const [settings, setSettings] = useState<AppSettings>({
    fontSize: 16,
    arabicFontSize: 24,
    theme: 'light',
    showTranslation: true,
    showTafseer: true,
    language: 'urdu',
  });

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const saved = await AsyncStorage.getItem('app_settings');
      if (saved) {
        setSettings(JSON.parse(saved));
      }
    } catch (error) {
      console.error('Error loading settings:', error);
    }
  };

  const saveSettings = async (newSettings: AppSettings) => {
    try {
      setSettings(newSettings);
      await AsyncStorage.setItem('app_settings', JSON.stringify(newSettings));
    } catch (error) {
      console.error('Error saving settings:', error);
    }
  };

  const resetSettings = () => {
    Alert.alert(
      'ری سیٹ کریں',
      'کیا آپ واقعی تمام سیٹنگز کو ڈیفالٹ پر واپس کرنا چاہتے ہیں؟',
      [
        { text: 'منسوخ', style: 'cancel' },
        {
          text: 'ری سیٹ کریں',
          style: 'destructive',
          onPress: async () => {
            const defaultSettings: AppSettings = {
              fontSize: 16,
              arabicFontSize: 24,
              theme: 'light',
              showTranslation: true,
              showTafseer: true,
              language: 'urdu',
            };
            await saveSettings(defaultSettings);
          }
        }
      ]
    );
  };

  const renderSection = (title: string, children: React.ReactNode) => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );

  const renderSettingRow = (
    title: string,
    subtitle?: string,
    rightComponent?: React.ReactNode
  ) => (
    <View style={styles.settingRow}>
      <View style={styles.settingInfo}>
        <Text style={styles.settingTitle}>{title}</Text>
        {subtitle && <Text style={styles.settingSubtitle}>{subtitle}</Text>}
      </View>
      {rightComponent}
    </View>
  );

  const renderFontSizeControl = (
    title: string,
    value: number,
    onDecrease: () => void,
    onIncrease: () => void,
    min: number = 12,
    max: number = 32
  ) => (
    <View style={styles.fontSizeControl}>
      <Text style={styles.settingTitle}>{title}</Text>
      <View style={styles.fontSizeButtons}>
        <TouchableOpacity
          style={[styles.fontButton, value <= min && styles.fontButtonDisabled]}
          onPress={onDecrease}
          disabled={value <= min}
        >
          <Text style={styles.fontButtonText}>A-</Text>
        </TouchableOpacity>
        
        <Text style={styles.fontSizeValue}>{value}</Text>
        
        <TouchableOpacity
          style={[styles.fontButton, value >= max && styles.fontButtonDisabled]}
          onPress={onIncrease}
          disabled={value >= max}
        >
          <Text style={styles.fontButtonText}>A+</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBar barStyle="light-content" backgroundColor="#2e7d32" />
      
      {/* Display Settings */}
      {renderSection('ڈسپلے سیٹنگز', (
        <>
          {renderFontSizeControl(
            'ترجمہ فونٹ سائز',
            settings.fontSize,
            () => saveSettings({ ...settings, fontSize: Math.max(12, settings.fontSize - 1) }),
            () => saveSettings({ ...settings, fontSize: Math.min(24, settings.fontSize + 1) }),
            12,
            24
          )}
          
          {renderFontSizeControl(
            'عربی فونٹ سائز',
            settings.arabicFontSize,
            () => saveSettings({ ...settings, arabicFontSize: Math.max(16, settings.arabicFontSize - 2) }),
            () => saveSettings({ ...settings, arabicFontSize: Math.min(36, settings.arabicFontSize + 2) }),
            16,
            36
          )}
          
          {renderSettingRow(
            'ترجمہ دکھائیں',
            'آیات کے ساتھ اردو ترجمہ',
            <Switch
              value={settings.showTranslation}
              onValueChange={(value) => saveSettings({ ...settings, showTranslation: value })}
              trackColor={{ false: '#e0e0e0', true: '#4caf50' }}
              thumbColor={settings.showTranslation ? '#2e7d32' : '#f4f3f4'}
            />
          )}
          
          {renderSettingRow(
            'تفسیر دکھائیں',
            'آیات کے ساتھ تفسیری نوٹس',
            <Switch
              value={settings.showTafseer}
              onValueChange={(value) => saveSettings({ ...settings, showTafseer: value })}
              trackColor={{ false: '#e0e0e0', true: '#4caf50' }}
              thumbColor={settings.showTafseer ? '#2e7d32' : '#f4f3f4'}
            />
          )}
        </>
      ))}

      {/* Theme Settings */}
      {renderSection('تھیم', (
        <View style={styles.themeButtons}>
          <TouchableOpacity
            style={[
              styles.themeButton,
              settings.theme === 'light' && styles.themeButtonActive
            ]}
            onPress={() => saveSettings({ ...settings, theme: 'light' })}
          >
            <Text style={[
              styles.themeButtonText,
              settings.theme === 'light' && styles.themeButtonTextActive
            ]}>
              روشن
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity
            style={[
              styles.themeButton,
              settings.theme === 'dark' && styles.themeButtonActive
            ]}
            onPress={() => saveSettings({ ...settings, theme: 'dark' })}
          >
            <Text style={[
              styles.themeButtonText,
              settings.theme === 'dark' && styles.themeButtonTextActive
            ]}>
              تاریک
            </Text>
          </TouchableOpacity>
        </View>
      ))}

      {/* Language Settings */}
      {renderSection('زبان', (
        <View style={styles.languageButtons}>
          <TouchableOpacity
            style={[
              styles.languageButton,
              settings.language === 'urdu' && styles.languageButtonActive
            ]}
            onPress={() => saveSettings({ ...settings, language: 'urdu' })}
          >
            <Text style={[
              styles.languageButtonText,
              settings.language === 'urdu' && styles.languageButtonTextActive
            ]}>
              اردو
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity
            style={[
              styles.languageButton,
              settings.language === 'english' && styles.languageButtonActive
            ]}
            onPress={() => saveSettings({ ...settings, language: 'english' })}
          >
            <Text style={[
              styles.languageButtonText,
              settings.language === 'english' && styles.languageButtonTextActive
            ]}>
              English
            </Text>
          </TouchableOpacity>
        </View>
      ))}

      {/* App Info */}
      {renderSection('ایپ کی معلومات', (
        <>
          {renderSettingRow(
            'ورژن',
            '1.0.0'
          )}
          
          {renderSettingRow(
            'ڈویلپر',
            'Quran Reader Team'
          )}
        </>
      ))}

      {/* Reset Button */}
      <TouchableOpacity
        style={styles.resetButton}
        onPress={resetSettings}
      >
        <Text style={styles.resetButtonText}>
          ڈیفالٹ سیٹنگز بحالی
        </Text>
      </TouchableOpacity>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  content: {
    paddingBottom: 20,
  },
  section: {
    backgroundColor: '#ffffff',
    marginVertical: 8,
    paddingVertical: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2e7d32',
    paddingHorizontal: 16,
    marginBottom: 12,
    textAlign: 'right',
  },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  settingInfo: {
    flex: 1,
    alignItems: 'flex-end',
  },
  settingTitle: {
    fontSize: 16,
    color: '#333',
    textAlign: 'right',
  },
  settingSubtitle: {
    fontSize: 14,
    color: '#666',
    textAlign: 'right',
    marginTop: 2,
  },
  fontSizeControl: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  fontSizeButtons: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  fontButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#2e7d32',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fontButtonDisabled: {
    backgroundColor: '#ccc',
  },
  fontButtonText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  fontSizeValue: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    minWidth: 20,
    textAlign: 'center',
  },
  themeButtons: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    gap: 12,
  },
  themeButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    alignItems: 'center',
  },
  themeButtonActive: {
    backgroundColor: '#2e7d32',
    borderColor: '#2e7d32',
  },
  themeButtonText: {
    fontSize: 16,
    color: '#666',
  },
  themeButtonTextActive: {
    color: '#ffffff',
    fontWeight: 'bold',
  },
  languageButtons: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    gap: 12,
  },
  languageButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    alignItems: 'center',
  },
  languageButtonActive: {
    backgroundColor: '#2e7d32',
    borderColor: '#2e7d32',
  },
  languageButtonText: {
    fontSize: 16,
    color: '#666',
  },
  languageButtonTextActive: {
    color: '#ffffff',
    fontWeight: 'bold',
  },
  resetButton: {
    backgroundColor: '#f44336',
    marginHorizontal: 16,
    marginTop: 20,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  resetButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default SettingsScreen;