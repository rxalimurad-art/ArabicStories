import { SurahData, SurahParagraph } from '../types';

export class DataManager {
  private static instance: DataManager;
  private surahCache: Map<number, SurahData> = new Map();

  static getInstance(): DataManager {
    if (!DataManager.instance) {
      DataManager.instance = new DataManager();
    }
    return DataManager.instance;
  }

  async loadSurah(surahNumber: number): Promise<SurahData> {
    // Check cache first
    if (this.surahCache.has(surahNumber)) {
      return this.surahCache.get(surahNumber)!;
    }

    try {
      // In React Native, we'll use require for bundled JSON files
      const jsonData = this.requireSurahData(surahNumber);
      
      const surahData: SurahData = {
        paragraphs: jsonData as SurahParagraph[]
      };

      // Cache the loaded data
      this.surahCache.set(surahNumber, surahData);
      
      return surahData;
    } catch (error) {
      throw new Error(`Failed to load Surah ${surahNumber}: ${error}`);
    }
  }

  private requireSurahData(surahNumber: number): any {
    // Dynamically require JSON file based on surah number
    try {
      // This approach works for bundled assets in React Native
      const surahData = require(`../data/json/surah-${surahNumber}.json`);
      return surahData;
    } catch (error) {
      throw new Error(`Surah ${surahNumber} data not available. Make sure surah-${surahNumber}.json exists in src/data/json/`);
    }
  }

  getAyahsFromParagraph(paragraph: SurahParagraph): Array<{number: number, text: string}> {
    // Extract individual ayah texts from the paragraph
    // This is a simplified version - in practice you'd need more sophisticated parsing
    const ayahs = [];
    for (let i = 0; i < paragraph.ayat.length; i++) {
      ayahs.push({
        number: paragraph.ayat[i],
        text: paragraph.arabic // This would need actual ayah splitting logic
      });
    }
    return ayahs;
  }

  clearCache(): void {
    this.surahCache.clear();
  }

  searchInSurah(surahData: SurahData, query: string, searchType: 'arabic' | 'translation' = 'translation'): SurahParagraph[] {
    const results: SurahParagraph[] = [];
    
    surahData.paragraphs.forEach(paragraph => {
      const searchText = searchType === 'arabic' ? paragraph.arabic : paragraph.tadtraur;
      if (searchText.toLowerCase().includes(query.toLowerCase())) {
        results.push(paragraph);
      }
    });
    
    return results;
  }
}