// Main data types for the Quran app

export interface Commentary {
  cid: number;
  comment: string;
}

export interface SurahParagraph {
  paragraph: string;
  ayat: number[];
  arabic: string;
  tadsection: string;
  tadtraur: string;
  tadparagraph: string;
  albparagraph: string;
  albtraur: string;
  chapter: string;
  ratio: string;
  bookmark: string;
  albcomur: Commentary[];
  tadcomur: string[];
}

export interface SurahData {
  paragraphs: SurahParagraph[];
}

export interface SurahInfo {
  number: number;
  arabicName: string;
  transliteration: string;
  ayahCount: number;
  revelationType: 'مکی' | 'مدنی';
}

export interface Bookmark {
  surahNumber: number;
  paragraphIndex: number;
  ayahNumber: number;
  timestamp: number;
  note?: string;
}

export interface SearchResult {
  surahNumber: number;
  paragraphIndex: number;
  ayahNumbers: number[];
  arabicText: string;
  translationText: string;
  matchType: 'arabic' | 'translation' | 'transliteration';
}

export interface AppSettings {
  fontSize: number;
  arabicFontSize: number;
  theme: 'light' | 'dark';
  showTranslation: boolean;
  showTafseer: boolean;
  language: 'urdu' | 'english';
}

// Navigation types
export type RootStackParamList = {
  Home: undefined;
  SurahList: undefined;
  SurahReader: {
    surahNumber: number;
    initialParagraph?: number;
  };
  Search: undefined;
  Bookmarks: undefined;
  Settings: undefined;
  Commentary: {
    surahNumber: number;
    paragraphIndex: number;
    commentaryType: 'albcomur' | 'tadcomur';
  };
};