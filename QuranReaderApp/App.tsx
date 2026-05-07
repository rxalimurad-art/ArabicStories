import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { StatusBar } from 'react-native';

import HomeScreen from './src/screens/HomeScreen';
import SurahListScreen from './src/screens/SurahListScreen';
import SurahReaderScreen from './src/screens/SurahReaderScreen';
import SearchScreen from './src/screens/SearchScreen';
import BookmarksScreen from './src/screens/BookmarksScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import CommentaryScreen from './src/screens/CommentaryScreen';

import { RootStackParamList } from './src/types';

const Stack = createStackNavigator<RootStackParamList>();

const App: React.FC = () => {
  return (
    <NavigationContainer>
      <StatusBar barStyle="dark-content" backgroundColor="#f8f9fa" />
      <Stack.Navigator
        initialRouteName="Home"
        screenOptions={{
          headerStyle: {
            backgroundColor: '#2e7d32',
          },
          headerTintColor: '#ffffff',
          headerTitleStyle: {
            fontWeight: 'bold',
            fontSize: 18,
          },
        }}
      >
        <Stack.Screen 
          name="Home" 
          component={HomeScreen}
          options={{ title: 'القرآن الکریم' }}
        />
        <Stack.Screen 
          name="SurahList" 
          component={SurahListScreen}
          options={{ title: 'سورت کی فہرست' }}
        />
        <Stack.Screen 
          name="SurahReader" 
          component={SurahReaderScreen}
          options={{ title: 'قرآن پڑھیں' }}
        />
        <Stack.Screen 
          name="Search" 
          component={SearchScreen}
          options={{ title: 'تلاش' }}
        />
        <Stack.Screen 
          name="Bookmarks" 
          component={BookmarksScreen}
          options={{ title: 'نشان زد شدہ' }}
        />
        <Stack.Screen 
          name="Settings" 
          component={SettingsScreen}
          options={{ title: 'ترتیبات' }}
        />
        <Stack.Screen 
          name="Commentary" 
          component={CommentaryScreen}
          options={{ title: 'تفسیر' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default App;