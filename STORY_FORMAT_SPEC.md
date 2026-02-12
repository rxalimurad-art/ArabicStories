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

### Mixed Segment Structure (Simplified)
```json
{
  "id": "segment-uuid",
  "index": 0,
  "text": "Once upon a time, Ahmad turned to اللَّهُ (Allah) for guidance.",
  "linkedWordIds": ["word-allah", "word-guidance"]
}
```

> **Note:** The admin panel uses a simplified format. Admin just enters plain text segments. Arabic words are managed separately in the Words section and linked by the admin via `linkedWordIds`.

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
| `mixedSegments[].text` | `text` | Plain text content |
| `mixedSegments[].linkedWordIds` | `linkedWordIds` | IDs of Arabic words linked by admin |

### Common Mistakes to Avoid

1. **Don't use `arabicText` in JSON** - Use `arabic` (Swift maps it internally)
2. **Don't use `englishMeaning` in JSON** - Use `english` (Swift maps it internally)
3. **Mixed format MUST have `mixedSegments`** not `segments`
4. **Bilingual format MUST have `segments`** not `mixedSegments`
5. **Mixed segments use simple `text` field** - admin links Arabic words separately via `linkedWordIds`

---

## Complete Mixed Format Example (Simplified)

```json
{
  "id": "ahmad-journey-v1",
  "title": "Ahmad's Journey to Peace",
  "storyDescription": "A beginner story about spiritual journey",
  "author": "Arabicly",
  "format": "mixed",
  "difficultyLevel": 1,
  "category": "religious",
  "tags": ["beginner", "vocabulary"],
  "coverImageURL": "https://images.unsplash.com/photo-1519817914152-22d216bb9170?w=800",
  
  "mixedSegments": [
    {
      "id": "seg-1",
      "index": 0,
      "text": "Once upon a time, Ahmad turned to Allah for guidance."
    },
    {
      "id": "seg-2",
      "index": 1,
      "text": "He opened the Al-Kitab and found peace in his heart."
    }
  ]
}
```

> **Note:** Arabic words (like "Allah", "Al-Kitab") in the text will be automatically linked to vocabulary entries by the system. Admin manages words separately in the Words section.

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
