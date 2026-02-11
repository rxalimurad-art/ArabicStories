# Story Format Specification

This document defines the exact data structure for stories in both Mixed and Bilingual formats.

## Word/Vocabulary Structure (Both Formats)

### Firestore/JSON Format
```json
{
  "id": "uuid-string",
  "arabic": "اللَّهُ",
  "english": "God",
  "transliteration": "Allah",
  "partOfSpeech": "noun",
  "rootLetters": "أ-ل-ه",
  "difficulty": 1
}
```

### iOS Swift Model Mapping
- `arabic` → `arabicText` (via CodingKeys)
- `english` → `englishMeaning` (via CodingKeys)

---

## Format 1: MIXED (Level 1 - Beginner)

Use for Level 1 stories where learners build vocabulary by tapping Arabic words embedded in English text.

### Top-Level Fields
```json
{
  "id": "story-uuid",
  "title": "Ahmad's Journey",
  "titleArabic": "رحلة أحمد",
  "storyDescription": "A story about finding peace",
  "storyDescriptionArabic": "قصة عن إيجاد السلام",
  "author": "Author Name",
  "format": "mixed",
  "difficultyLevel": 1,
  "category": "religious",
  "tags": ["beginner", "vocabulary"],
  "coverImageURL": "https://...",
  
  // Format-specific content
  "mixedSegments": [...],
  "words": [...]
}
```

### Mixed Segment Structure
```json
{
  "id": "segment-uuid",
  "index": 0,
  "contentParts": [
    {
      "id": "part-1",
      "type": "text",
      "text": "Once upon a time, Ahmad turned to "
    },
    {
      "id": "part-2",
      "type": "arabicWord",
      "text": "اللَّهُ",
      "transliteration": "(Allah)",
      "wordId": "word-uuid-or-id"
    },
    {
      "id": "part-3",
      "type": "text",
      "text": " for guidance."
    }
  ],
  "culturalNote": "Optional cultural context"
}
```

### Content Part Types
- `type: "text"` - Plain English text
- `type: "arabicWord"` - Arabic vocabulary word (must have `wordId` linking to words array)

---

## Format 2: BILINGUAL (Level 2+)

Use for Level 2+ stories with full Arabic text and English translation.

### Top-Level Fields
```json
{
  "id": "story-uuid",
  "title": "The Wise Merchant",
  "titleArabic": "التاجر الحكيم",
  "storyDescription": "A story about wisdom",
  "storyDescriptionArabic": "قصة عن الحكمة",
  "author": "Traditional",
  "format": "bilingual",
  "difficultyLevel": 2,
  "category": "folktale",
  "tags": ["wisdom", "traditional"],
  "coverImageURL": "https://...",
  
  // Format-specific content
  "segments": [...],
  "words": [...]
}
```

### Bilingual Segment Structure
```json
{
  "id": "segment-uuid",
  "index": 0,
  "arabicText": "كان يا ما كان...",
  "englishText": "Once upon a time...",
  "transliteration": "Kana ya ma kan...",
  "audioStartTime": 0.0,
  "audioEndTime": 5.5,
  "culturalNote": "Optional note",
  "grammarNote": "Optional grammar"
}
```

---

## Important Field Mappings

### Swift Model → Firestore/JSON

| Swift Model | Firestore Field | Notes |
|------------|-----------------|-------|
| `arabicText` | `arabic` | Via CodingKeys |
| `englishMeaning` | `english` | Via CodingKeys |
| `mixedSegments` | `mixedSegments` | Level 1 only |
| `segments` | `segments` | Level 2+ only |
| `contentParts` | `contentParts` | Inside mixedSegments |
| `part.type` | `type` | `"text"` or `"arabicWord"` |
| `part.text` | `text` | Display text |
| `part.wordId` | `wordId` | Link to vocabulary |

### Common Mistakes to Avoid

1. **Don't use `arabicText` in JSON** - Use `arabic` (Swift maps it internally)
2. **Don't use `englishMeaning` in JSON** - Use `english` (Swift maps it internally)
3. **Mixed format MUST have `mixedSegments`** not `segments`
4. **Bilingual format MUST have `segments`** not `mixedSegments`
5. **Content parts in mixed format MUST have correct `type`** values: `"text"` or `"arabicWord"`

---

## Complete Mixed Format Example

```json
{
  "id": "ahmad-journey-v1",
  "title": "Ahmad's Journey to Peace",
  "storyDescription": "A beginner story about spiritual journey",
  "author": "Hikaya Learning",
  "format": "mixed",
  "difficultyLevel": 1,
  "category": "religious",
  "tags": ["beginner", "vocabulary"],
  "coverImageURL": "https://images.unsplash.com/photo-1519817914152-22d216bb9170?w=800",
  
  "mixedSegments": [
    {
      "id": "seg-1",
      "index": 0,
      "contentParts": [
        {
          "id": "part-1",
          "type": "text",
          "text": "Once upon a time, Ahmad turned to "
        },
        {
          "id": "part-2",
          "type": "arabicWord",
          "text": "اللَّهُ",
          "transliteration": "(Allah)",
          "wordId": "word-allah"
        },
        {
          "id": "part-3",
          "type": "text",
          "text": " for guidance."
        }
      ]
    }
  ],
  
  "words": [
    {
      "id": "word-allah",
      "arabic": "اللَّهُ",
      "english": "God",
      "transliteration": "Allah",
      "difficulty": 1
    }
  ]
}
```

---

## Firebase Function Field Handling

The Firebase function (`index.js`) accepts both naming conventions:

```javascript
// Words - accepts both formats
arabic: word.arabic || word.arabicText || ''
english: word.english || word.englishMeaning || ''

// Story description - accepts variations  
storyDescription: story.storyDescription || story.description || story.desc || ''
```

This ensures compatibility regardless of which field names are used in the import JSON.
