/**
 * Quran Words Importer
 * Imports top 200 Quran words to Firestore with TTS audio
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const { generateTTS } = require('./tts');

// ==================== CONFIGURATION ====================
const CONFIG = {
  SOURCE_FILE: '/Users/murad/Downloads/quran_words_2026-02-17.json',
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  DATABASE_LOCATION: 'nam5',
  COLLECTION_NAME: 'quran_words',
  TOP_N_WORDS: 200,
  TTS_LANGUAGE: 'ar',
  DELAY_MS: 1000,
  MAX_RETRIES: 3,
  RETRY_DELAY_MS: 5000,
};

// ==================== QURAN EXAMPLES DATABASE ====================
const QURAN_EXAMPLES = {
  'فِى': { arabic: 'فِى ٱلْبَيْتِ', english: 'In the house' },
  'فِي': { arabic: 'فِي ٱلْجَنَّةِ', english: 'In Paradise' },
  'ٱللَّهِ': { arabic: 'بِسْمِ ٱللَّهِ', english: 'In the name of Allah' },
  'ٱللَّهُ': { arabic: 'ٱللَّهُ أَكْبَرُ', english: 'Allah is Greatest' },
  'ٱللَّهَ': { arabic: 'نَعْبُدُ ٱللَّهَ', english: 'We worship Allah' },
  'مِن': { arabic: 'مِنَ ٱلْمُؤْمِنِينَ', english: 'From the believers' },
  'مَا': { arabic: 'مَا شَاءَ ٱللَّهُ', english: 'What Allah wills' },
  'لَا': { arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّهُ', english: 'There is no god but Allah' },
  'إِنَّ': { arabic: 'إِنَّ ٱللَّهَ غَفُورٌ', english: 'Indeed Allah is Forgiving' },
  'إِلَىٰ': { arabic: 'إِلَىٰ ٱللَّهِ', english: 'To Allah' },
  'عَلَىٰ': { arabic: 'عَلَىٰ ٱلصِّرَاطِ', english: 'Upon the straight path' },
  'أَن': { arabic: 'أَن تَشْكُرُوا۟', english: 'That you be grateful' },
  'عَن': { arabic: 'عَنِ ٱلذُّنُوبِ', english: 'From the sins' },
  'كَانَ': { arabic: 'كَانَ ٱللَّهُ', english: 'Allah was/is' },
  'كُلُّ': { arabic: 'كُلُّ نَفْسٍۢ', english: 'Every soul' },
  'هُوَ': { arabic: 'هُوَ ٱللَّهُ', english: 'He is Allah' },
  'أَنْ': { arabic: 'أَنْ تَعْبُدُوا۟', english: 'That you worship' },
  'قَالَ': { arabic: 'قَالَ ٱللَّهُ', english: 'Allah said' },
  'فَإِن': { arabic: 'فَإِن مَّعِىَ', english: 'So indeed with me' },
  'بِٱللَّهِ': { arabic: 'ءَامَنتُ بِٱللَّهِ', english: 'I believe in Allah' },
  'قَدْ': { arabic: 'قَدْ أَفْلَحَ', english: 'Indeed succeeded' },
  'يَوْمَ': { arabic: 'يَوْمَ ٱلْقِيَٰمَةِ', english: 'Day of Resurrection' },
  'إِن': { arabic: 'إِن شَاءَ ٱللَّهُ', english: 'If Allah wills' },
  'أَوْ': { arabic: 'أَوْ تَصْدَقُوا۟', english: 'Or you give charity' },
  'ذَٰلِكَ': { arabic: 'ذَٰلِكَ ٱلْكِتَٰبُ', english: 'That is the Book' },
  'لَمْ': { arabic: 'لَمْ يَلِدْ', english: 'He did not beget' },
  'لَهُۥ': { arabic: 'لَهُۥ ٱلْمُلْكُ', english: 'To Him belongs the dominion' },
  'كَانَتْ': { arabic: 'كَانَتْ تَعْمَلُ', english: 'She was doing' },
  'ٱلَّذِى': { arabic: 'ٱلَّذِى خَلَقَ', english: 'The one who created' },
  'هَٰذَا': { arabic: 'هَٰذَا كِتَٰبُنَا', english: 'This is our Book' },
  'وَٱللَّهُ': { arabic: 'وَٱللَّهُ عَلَىٰ', english: 'And Allah is over' },
  'عَلِيمٌ': { arabic: 'ٱللَّهُ عَلِيمٌۢ', english: 'Allah is Knowing' },
  'حَتَّىٰ': { arabic: 'حَتَّىٰ يُؤْذِنَ', english: 'Until He permits' },
  'أَمْ': { arabic: 'أَمْ حَسِبْتُمْ', english: 'Or do you think' },
  'ٱلَّتِى': { arabic: 'ٱلَّتِىٓ أَحْصَنَتْ', english: 'The one who guarded' },
  'بَعْدَ': { arabic: 'بَعْدَ ذَٰلِكَ', english: 'After that' },
  'بِمَا': { arabic: 'بِمَا كَسَبُوا۟', english: 'For what they earned' },
  'كَيْفَ': { arabic: 'كَيْفَ تَكْفُرُونَ', english: 'How do you disbelieve' },
  'بِٱلْقِسْطِ': { arabic: 'يَقُومُ بِٱلْقِسْطِ', english: 'Establishes justice' },
  'بِٱلْمُؤْمِنِينَ': { arabic: 'وَعْدًا عَلَى ٱلْمُؤْمِنِينَ', english: 'A promise upon the believers' },
};

// Root meanings database
const ROOT_MEANINGS = {
  'أله': { meaning: 'to worship, deify', transliteration: 'a-l-h' },
  'ءمن': { meaning: 'to be secure, faithful', transliteration: 'a-m-n' },
  'علم': { meaning: 'to know, have knowledge', transliteration: 'al-m' },
  'قول': { meaning: 'to say, speak', transliteration: 'q-w-l' },
  'عمل': { meaning: 'to do, work', transliteration: 'a-m-l' },
  'علو': { meaning: 'to be high, exalted', transliteration: 'a-l-w' },
  'كفر': { meaning: 'to disbelieve, cover', transliteration: 'k-f-r' },
  'ربب': { meaning: 'to lord, nurture', transliteration: 'r-b-b' },
  'خلق': { meaning: 'to create', transliteration: 'kh-l-q' },
  'ءتى': { meaning: 'to come, bring', transliteration: 'a-t-y' },
  'ءكل': { meaning: 'to eat', transliteration: 'a-k-l' },
  'جعل': { meaning: 'to make, place', transliteration: 'j-a-l' },
  'نصر': { meaning: 'to help, support', transliteration: 'n-s-r' },
  'هدى': { meaning: 'to guide', transliteration: 'h-d-y' },
  'كتب': { meaning: 'to write', transliteration: 'k-t-b' },
  'ءخر': { meaning: 'other, last', transliteration: 'a-kh-r' },
  'شيء': { meaning: 'thing', transliteration: 'sh-y' },
  'حكم': { meaning: 'to judge, wisdom', transliteration: 'h-k-m' },
  'صدق': { meaning: 'to be true, truthful', transliteration: 's-d-q' },
  'ءمر': { meaning: 'to command, matter', transliteration: 'a-m-r' },
  'جاء': { meaning: 'to come', transliteration: 'j-a-y' },
  'رءي': { meaning: 'to see', transliteration: 'r-y' },
  'ظلم': { meaning: 'to wrong, oppress', transliteration: 'z-l-m' },
  'قبل': { meaning: 'before, to accept', transliteration: 'q-b-l' },
  'حسن': { meaning: 'to be good, beautiful', transliteration: 'h-s-n' },
  'شرك': { meaning: 'to associate partners', transliteration: 'sh-r-k' },
  'دخل': { meaning: 'to enter', transliteration: 'd-kh-l' },
  'خرو': { meaning: 'to go out', transliteration: 'kh-r-j' },
  'امن': { meaning: 'to be safe, secure', transliteration: 'a-m-n' },
  'سلم': { meaning: 'to submit, be at peace', transliteration: 's-l-m' },
  'رحم': { meaning: 'to have mercy', transliteration: 'r-h-m' },
  'غفر': { meaning: 'to forgive', transliteration: 'gh-f-r' },
  'ملك': { meaning: 'to possess, king', transliteration: 'm-l-k' },
  'قدم': { meaning: 'to bring forward', transliteration: 'q-d-m' },
  'فعل': { meaning: 'to do', transliteration: 'f-a-l' },
  'علي': { meaning: 'to be high, above', transliteration: 'a-l-y' },
  'نزل': { meaning: 'to descend', transliteration: 'n-z-l' },
  'قوم': { meaning: 'to stand, people', transliteration: 'q-w-m' },
  'ءخذ': { meaning: 'to take', transliteration: 'a-kh-dh' },
  'جمع': { meaning: 'to gather', transliteration: 'j-m' },
  'بعد': { meaning: 'after', transliteration: 'b-d' },
  'نعم': { meaning: 'favor, blessing', transliteration: 'n-m' },
  'شهد': { meaning: 'to witness', transliteration: 'sh-h-d' },
  'وجد': { meaning: 'to find', transliteration: 'w-j-d' },
  'ذكر': { meaning: 'to remember, mention', transliteration: 'dh-k-r' },
  'سءل': { meaning: 'to ask', transliteration: 's-l' },
  'قضي': { meaning: 'to decree, judge', transliteration: 'q-dh-y' },
  'دين': { meaning: 'religion, judgment', transliteration: 'd-y-n' },
  'حيي': { meaning: 'life, to live', transliteration: 'h-y-y' },
  'مات': { meaning: 'to die', transliteration: 'm-w-t' },
  'يوم': { meaning: 'day', transliteration: 'y-w-m' },
  'ليل': { meaning: 'night', transliteration: 'l-y-l' },
  'نهار': { meaning: 'daytime', transliteration: 'n-h-a-r' },
  'ارض': { meaning: 'earth, land', transliteration: 'a-r-dh' },
  'سمع': { meaning: 'to hear', transliteration: 's-m' },
  'بصر': { meaning: 'to see', transliteration: 'b-s-r' },
  'يدي': { meaning: 'hand', transliteration: 'y-d-y' },
  'وجه': { meaning: 'face', transliteration: 'w-j-h' },
  'قلب': { meaning: 'heart', transliteration: 'q-l-b' },
  'لسن': { meaning: 'tongue, language', transliteration: 'l-s-n' },
  'نفس': { meaning: 'soul, self', transliteration: 'n-f-s' },
  'روح': { meaning: 'spirit', transliteration: 'r-w-h' },
  'جنه': { meaning: 'paradise, garden', transliteration: 'j-n-n' },
  'نار': { meaning: 'fire, hell', transliteration: 'n-a-r' },
  'عذاب': { meaning: 'punishment', transliteration: 'a-dh-a-b' },
  'ثواب': { meaning: 'reward', transliteration: 'th-w-a-b' },
  'ناس': { meaning: 'people, mankind', transliteration: 'n-a-s' },
  'رجل': { meaning: 'man', transliteration: 'r-j-l' },
  'مرء': { meaning: 'human being', transliteration: 'm-r' },
  'نسو': { meaning: 'women', transliteration: 'n-s-w' },
  'ولد': { meaning: 'child, to give birth', transliteration: 'w-l-d' },
  'صغير': { meaning: 'small, young', transliteration: 's-gh-y-r' },
  'كبير': { meaning: 'big, great', transliteration: 'k-b-y-r' },
  'خير': { meaning: 'good, better', transliteration: 'kh-y-r' },
  'شرر': { meaning: 'evil, harm', transliteration: 'sh-r-r' },
  'صلاة': { meaning: 'prayer', transliteration: 's-l-a-h' },
  'زكوة': { meaning: 'purification, charity', transliteration: 'z-k-w' },
  'صوم': { meaning: 'fasting', transliteration: 's-w-m' },
  'حج': { meaning: 'pilgrimage', transliteration: 'h-j-j' },
  'سر': { meaning: 'secret, hidden', transliteration: 's-r-r' },
  'عهد': { meaning: 'covenant, promise', transliteration: 'a-h-d' },
  'شكر': { meaning: 'gratitude', transliteration: 'sh-k-r' },
  'توكل': { meaning: 'trust, reliance', transliteration: 't-w-k-l' },
  'خوف': { meaning: 'fear', transliteration: 'kh-w-f' },
  'رجاء': { meaning: 'hope', transliteration: 'r-j-a' },
  'حبب': { meaning: 'love', transliteration: 'h-b-b' },
  'بغض': { meaning: 'hatred', transliteration: 'b-gh-dh' },
  'رضي': { meaning: 'pleasure, contentment', transliteration: 'r-dh-y' },
  'نور': { meaning: 'light', transliteration: 'n-w-r' },
  'ضلل': { meaning: 'misguidance', transliteration: 'd-l-l' },
  'فوز': { meaning: 'success', transliteration: 'f-w-z' },
  'خسر': { meaning: 'loss', transliteration: 'kh-s-r' },
  'نجح': { meaning: 'to be saved', transliteration: 'n-j-h' },
  'هلك': { meaning: 'to perish', transliteration: 'h-l-k' },
  'حياة': { meaning: 'life', transliteration: 'h-y-a-h' },
  'موت': { meaning: 'death', transliteration: 'm-w-t' },
  'بعث': { meaning: 'resurrection', transliteration: 'b-th' },
  'حشر': { meaning: 'gathering', transliteration: 'h-sh-r' },
  'حساب': { meaning: 'reckoning, accounting', transliteration: 'h-s-a-b' },
  'ميزان': { meaning: 'balance, scale', transliteration: 'm-y-z-a-n' },
  'صراط': { meaning: 'path, way', transliteration: 's-i-r-a-t' },
  'جزاء': { meaning: 'recompense', transliteration: 'j-z-a' },
  'ثمر': { meaning: 'fruit, result', transliteration: 'th-m-r' },
  'زرع': { meaning: 'sowing, cultivation', transliteration: 'z-r' },
  'حصد': { meaning: 'harvesting', transliteration: 'h-s-a-d' },
  'بشرى': { meaning: 'good news', transliteration: 'b-sh-r-y' },
  'نذير': { meaning: 'warner', transliteration: 'n-dh-y-r' },
  'رسل': { meaning: 'messengers', transliteration: 'r-s-l' },
  'نبي': { meaning: 'prophet', transliteration: 'n-b-y' },
  'كتاب': { meaning: 'book, writing', transliteration: 'k-i-a-b' },
  'قرءن': { meaning: 'Quran, recitation', transliteration: 'q-r-n' },
  'سورة': { meaning: 'chapter', transliteration: 's-u-r-a-h' },
  'ءاية': { meaning: 'sign, verse', transliteration: 'a-y-a-h' },
  'حرف': { meaning: 'letter, edge', transliteration: 'h-r-f' },
  'كلمه': { meaning: 'word', transliteration: 'k-l-m-a-h' },
  'لسان': { meaning: 'tongue, language', transliteration: 'l-s-a-n' },
  'بيان': { meaning: 'clarification', transliteration: 'b-y-a-n' },
  'بلغ': { meaning: 'to reach, convey', transliteration: 'b-l-gh' },
  'فهم': { meaning: 'understanding', transliteration: 'f-h-m' },
  'جهل': { meaning: 'ignorance', transliteration: 'j-h-l' },
  'عقل': { meaning: 'intellect', transliteration: 'a-q-l' },
  'فكر': { meaning: 'thought', transliteration: 'f-k-r' },
  'نسي': { meaning: 'forgetting', transliteration: 'n-s-y' },
};

// POS tags mapping
const POS_TAGS = {
  'N': ['noun'],
  'V': ['verb'],
  'P': ['preposition', 'particle'],
  'D': ['demonstrative'],
  'A': ['adjective'],
  'T': ['time'],
  'C': ['conjunction'],
  'I': ['interrogative'],
  'NEG': ['negative'],
  'COND': ['conditional'],
  'EXL': ['exclamation'],
  'EQ': ['equalization'],
  'REM': ['resumption'],
  'INC': ['inceptive'],
  'AMD': ['amendment'],
  'EXP': ['explanation'],
  'CERT': ['certainty'],
  'SUR': ['surprise'],
  'SUP': ['supplement'],
  'AVR': ['aversion'],
  'IMPV': ['imperative'],
  'PRP': ['purpose'],
  'CIRC': ['circumstantial'],
  'COM': ['compound'],
  'LOC': ['location'],
  'EMPH': ['emphatic'],
  'PRON': ['pronoun'],
  'DET': ['determiner'],
  'ADJ': ['adjective'],
  'ADV': ['adverb'],
  'INJ': ['interjection'],
};

const POS_DESCRIPTIONS = {
  'N': 'noun',
  'V': 'verb',
  'P': 'particle/preposition',
  'D': 'demonstrative pronoun',
  'A': 'adjective',
  'T': 'time adverb',
  'C': 'conjunction',
  'I': 'interrogative',
};

// ==================== FIREBASE INITIALIZATION ====================

function initializeFirebase() {
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    console.log('Using service account authentication');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  } else {
    console.log('Using application default credentials');
    console.log('Run "gcloud auth application-default login" if authentication fails');
    admin.initializeApp({
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  }
  
  return {
    db: admin.firestore(),
    storage: admin.storage(),
  };
}

// ==================== AUDIO UPLOAD ====================

async function uploadAudio(storage, audioBuffer, wordId) {
  try {
    const filename = `word-audio/${wordId}.mp3`;
    const bucket = storage.bucket();
    const file = bucket.file(filename);
    
    await file.save(audioBuffer, {
      metadata: {
        contentType: 'audio/mpeg',
        metadata: {
          firebaseStorageDownloadTokens: uuidv4(),
        },
      },
    });
    
    await file.makePublic();
    return `https://storage.googleapis.com/${CONFIG.STORAGE_BUCKET}/${filename}`;
  } catch (error) {
    console.error(`Failed to upload audio: ${error.message}`);
    return null;
  }
}

// ==================== DATA ENRICHMENT ====================

function getExample(word) {
  if (QURAN_EXAMPLES[word.arabicText]) {
    return QURAN_EXAMPLES[word.arabicText];
  }
  if (QURAN_EXAMPLES[word.arabicWithoutDiacritics]) {
    return QURAN_EXAMPLES[word.arabicWithoutDiacritics];
  }
  if (word.morphology?.lemma && QURAN_EXAMPLES[word.morphology.lemma]) {
    return QURAN_EXAMPLES[word.morphology.lemma];
  }
  return generateGenericExample(word, word.morphology?.partOfSpeech || 'N');
}

function generateGenericExample(word, pos) {
  const templates = {
    'P': { arabic: `${word.arabicText} ٱلْكِتَٰبِ`, english: `${word.englishMeaning} the book` },
    'V': { arabic: `قَدْ ${word.arabicText}`, english: `Indeed ${word.englishMeaning}` },
    'N': { arabic: `هَٰذَا ${word.arabicText}`, english: `This is ${word.englishMeaning}` },
    'A': { arabic: `${word.arabicText} كِتَٰبٌ`, english: `${word.englishMeaning} book` },
    'D': { arabic: `${word.arabicText} كِتَٰبٌ`, english: `${word.englishMeaning} book` },
    'T': { arabic: `${word.arabicText} ٱلنَّاسُ`, english: `${word.englishMeaning} the people` },
    'C': { arabic: `${word.arabicText} ٱللَّهُ`, english: `${word.englishMeaning} Allah` },
    'NEG': { arabic: `${word.arabicText} يَشَكُونَ`, english: `${word.englishMeaning} they doubt` },
  };
  return templates[pos] || { arabic: `${word.arabicText}`, english: `${word.englishMeaning}` };
}

function getTags(word) {
  const tags = [];
  const pos = word.morphology?.partOfSpeech;
  
  if (POS_TAGS[pos]) {
    tags.push(...POS_TAGS[pos]);
  }
  
  if (word.rank <= 10) tags.push('most-frequent');
  else if (word.rank <= 50) tags.push('very-frequent');
  else if (word.rank <= 100) tags.push('frequent');
  
  if (word.occurrenceCount >= 500) tags.push('high-frequency');
  
  if (word.morphology?.grammaticalCase) {
    tags.push(word.morphology.grammaticalCase.toLowerCase());
  }
  if (word.morphology?.number) {
    tags.push(word.morphology.number.toLowerCase());
  }
  if (word.morphology?.gender) {
    tags.push(word.morphology.gender.toLowerCase());
  }
  if (word.morphology?.tense) {
    tags.push(word.morphology.tense.toLowerCase());
  }
  if (word.morphology?.passive) {
    tags.push('passive');
  }
  
  return [...new Set(tags)];
}

function getRootInfo(word) {
  const rootArabic = word.root?.arabic;
  
  if (!rootArabic || rootArabic === 'null') {
    return { arabic: 'N/A', transliteration: 'N/A', meaning: 'N/A' };
  }
  
  const rootData = ROOT_MEANINGS[rootArabic] || {};
  return {
    arabic: rootArabic,
    transliteration: rootData.transliteration || word.root?.transliteration || 'N/A',
    meaning: rootData.meaning || 'N/A',
  };
}

function generateNotes(word) {
  const notes = [];
  
  if (word.rank === 1) notes.push('Most frequent word in the Quran.');
  else if (word.rank <= 10) notes.push(`Top ${word.rank} most frequent word in the Quran.`);
  
  notes.push(`Occurs ${word.occurrenceCount} times in the Quran.`);
  
  if (word.morphology?.posDescription) {
    notes.push(`Grammatical category: ${word.morphology.posDescription}.`);
  }
  
  return notes.join(' ');
}

// ==================== CHECK EXISTING WORDS ====================

async function checkExistingWords(db) {
  console.log('Checking existing words in Firestore...');
  console.log('----------------------------------------');
  
  try {
    // Get total count
    const snapshot = await db.collection(CONFIG.COLLECTION_NAME).get();
    const totalCount = snapshot.size;
    
    console.log(`Total words already in collection: ${totalCount}`);
    
    if (totalCount > 0) {
      // Get words with audio
      const withAudio = await db.collection(CONFIG.COLLECTION_NAME)
        .where('audioURL', '!=', '')
        .count()
        .get();
      const withAudioCount = withAudio.data().count;
      
      // Get words without audio
      const withoutAudio = await db.collection(CONFIG.COLLECTION_NAME)
        .where('audioURL', '==', '')
        .count()
        .get();
      const withoutAudioCount = withoutAudio.data().count;
      
      // Get rank range
      const lowestRank = await db.collection(CONFIG.COLLECTION_NAME)
        .orderBy('rank', 'desc')
        .limit(1)
        .get();
      
      const highestRank = await db.collection(CONFIG.COLLECTION_NAME)
        .orderBy('rank', 'asc')
        .limit(1)
        .get();
      
      console.log(`  Words with audio: ${withAudioCount}`);
      console.log(`  Words without audio: ${withoutAudioCount}`);
      
      if (!highestRank.empty) {
        console.log(`  Highest rank (best): ${highestRank.docs[0].data().rank}`);
      }
      if (!lowestRank.empty) {
        console.log(`  Lowest rank: ${lowestRank.docs[0].data().rank}`);
      }
      
      // Show some sample words
      console.log('\nSample existing words:');
      const sample = await db.collection(CONFIG.COLLECTION_NAME)
        .orderBy('rank', 'asc')
        .limit(5)
        .get();
      
      sample.forEach(doc => {
        const data = doc.data();
        console.log(`  Rank ${data.rank}: ${data.arabicText} - ${data.englishMeaning}`);
      });
    }
    
    console.log('----------------------------------------\n');
    return totalCount;
    
  } catch (error) {
    console.error(`Error checking existing words: ${error.message}`);
    console.log('Assuming collection is empty\n');
    return 0;
  }
}

// ==================== MAIN IMPORT ====================

async function importWords() {
  console.log('========================================');
  console.log('Quran Words Importer');
  console.log('========================================\n');
  
  console.log('Initializing Firebase...');
  const { db, storage } = initializeFirebase();
  console.log('Firebase initialized\n');
  
  // Check existing words first
  const existingCount = await checkExistingWords(db);
  
  console.log(`Reading source file: ${CONFIG.SOURCE_FILE}`);
  if (!fs.existsSync(CONFIG.SOURCE_FILE)) {
    console.error(`Source file not found: ${CONFIG.SOURCE_FILE}`);
    process.exit(1);
  }
  
  const sourceData = JSON.parse(fs.readFileSync(CONFIG.SOURCE_FILE, 'utf8'));
  console.log(`Loaded ${sourceData.length} words from source\n`);
  
  const topWords = sourceData.slice(0, CONFIG.TOP_N_WORDS);
  console.log(`Source file has ${sourceData.length} total words`);
  console.log(`Will process top ${CONFIG.TOP_N_WORDS} words from source\n`);
  
  // Check which words already exist
  const existingTexts = new Set();
  if (existingCount > 0) {
    const existingSnapshot = await db.collection(CONFIG.COLLECTION_NAME)
      .select('arabicText')
      .get();
    existingSnapshot.forEach(doc => {
      existingTexts.add(doc.data().arabicText);
    });
    console.log(`Found ${existingTexts.size} unique words already in collection`);
  }
  
  // Filter out existing words
  const newWords = topWords.filter(w => !existingTexts.has(w.arabicText));
  const alreadyExisting = topWords.filter(w => existingTexts.has(w.arabicText));
  
  console.log(`New words to import: ${newWords.length}`);
  console.log(`Words already existing (will skip): ${alreadyExisting.length}\n`);
  
  if (alreadyExisting.length > 0) {
    console.log('Words that will be skipped:');
    alreadyExisting.slice(0, 10).forEach(w => {
      console.log(`  - ${w.arabicText} (rank ${w.rank})`);
    });
    if (alreadyExisting.length > 10) {
      console.log(`  ... and ${alreadyExisting.length - 10} more`);
    }
    console.log('');
  }
  
  let success = 0;
  let failed = 0;
  let skipped = 0;
  const failedWords = [];
  
  for (let i = 0; i < newWords.length; i++) {
    const word = newWords[i];
    const wordId = uuidv4();
    
    console.log(`[${i + 1}/${newWords.length}] Processing: ${word.arabicText} (${word.englishMeaning}) (rank ${word.rank})`);
    
    try {
      
      console.log(`  Generating TTS audio...`);
      const audioBuffer = await generateTTS(word.arabicText);
      
      let audioURL = '';
      if (audioBuffer) {
        console.log(`  Uploading audio to Storage...`);
        audioURL = await uploadAudio(storage, audioBuffer, wordId);
        if (audioURL) {
          console.log(`  Audio uploaded`);
        }
      } else {
        console.log(`  No audio generated (will continue without audio)`);
      }
      
      const example = getExample(word);
      const rootInfo = getRootInfo(word);
      const tags = getTags(word);
      const notes = generateNotes(word);
      
      const doc = {
        id: wordId,
        arabicText: word.arabicText,
        arabicWithoutDiacritics: word.arabicWithoutDiacritics,
        buckwalter: word.buckwalter,
        englishMeaning: word.englishMeaning,
        audioURL: audioURL,
        exampleArabic: example.arabic,
        exampleEnglish: example.english,
        morphology: {
          breakdown: word.morphology?.breakdown || `${word.arabicText}[${word.morphology?.partOfSpeech || 'N'}]`,
          form: word.morphology?.form || null,
          gender: word.morphology?.gender || null,
          grammaticalCase: word.morphology?.grammaticalCase || null,
          lemma: word.morphology?.lemma || word.arabicWithoutDiacritics,
          number: word.morphology?.number || null,
          partOfSpeech: word.morphology?.partOfSpeech || 'N',
          passive: word.morphology?.passive || false,
          posDescription: word.morphology?.posDescription || POS_DESCRIPTIONS[word.morphology?.partOfSpeech] || 'noun',
          state: word.morphology?.state || null,
          tense: word.morphology?.tense || null,
        },
        root: rootInfo,
        occurrenceCount: word.occurrenceCount || 0,
        rank: word.rank || 0,
        tags: tags,
        notes: notes,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      await db.collection(CONFIG.COLLECTION_NAME).doc(wordId).set(doc);
      console.log(`  Saved to Firestore\n`);
      success++;
      
      await new Promise(resolve => setTimeout(resolve, CONFIG.DELAY_MS));
      
    } catch (error) {
      console.error(`  Error: ${error.message}\n`);
      failedWords.push({ word, error: error.message });
      failed++;
    }
  }
  
  console.log('========================================');
  console.log('Import Summary');
  console.log('========================================');
  console.log(`Previous words in collection: ${existingCount}`);
  console.log(`New words imported: ${success}`);
  console.log(`Total words in collection: ${existingCount + success}`);
  console.log(`Failed: ${failed}`);
  console.log('========================================');
  
  if (failedWords.length > 0) {
    console.log('\nFailed words:');
    failedWords.forEach(({ word, error }) => {
      console.log(`  - ${word.arabicText}: ${error}`);
    });
  }
  
  process.exit(0);
}

process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

importWords().catch(console.error);
