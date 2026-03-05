// Static Sarf data - not stored in Firebase, served directly from code
export const STATIC_SARF_GROUPS = [
  {
    id: 'sarf-static-1',
    name: '🔥 Sarf - The 3 Main Families (Fa\'ala)',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's1-1',
        arabic: 'فَعَلَ / يَفْعَلُ — فَعَلَ يَفْعَلُ فِعْلٌ مَفْعُولٌ',
        translation: 'Pattern: U-AAA-U (past a, present a). Example: سَلَمَ / يَسْلَمُ (to be safe). Masdar: سَلَامَة. Ism fa\'il: مُسْلِم. Ism maf\'ool: مُسْلَم.',
        status: 'not_started'
      },
      {
        id: 's1-2',
        arabic: 'فَعَلَ / يَفْعِلُ — فَعَلَ يَفْعِلُ فِعْلٌ مَفْعُولٌ',
        translation: 'Pattern: UUU-I-A (past a, present i). Example: عَلِمَ / يَعْلَمُ (to know). Masdar: عِلْمٌ. Ism fa\'il: مُعْلِم. Ism maf\'ool: مُعْلَم.',
        status: 'not_started'
      },
      {
        id: 's1-3',
        arabic: 'فَعُلَ / يَفْعُلُ — فَعُلَ يَفْعُلُ فَعَالَةٌ / فُعُولٌ',
        translation: 'Pattern: U-AAA-U (past u, present u). Example: جَهُدَ / يَجْهُدُ (to strive). Masdar: جُهْدٌ / جَهَادٌ. Ism fa\'il: مُجَاهِد. Ism maf\'ool: مَجْهُود.',
        status: 'not_started'
      }
    ]
  },
  {
    id: 'sarf-static-2',
    name: '⚡ Sarf - The 2 Heavy Families (Taf\'eel)',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's2-1',
        arabic: 'فَعَّلَ / يُفَعِّلُ — تَفْعِيلٌ مُفَعَّلٌ',
        translation: 'Shadda on second letter (intensive/transitive). Example: عَلَّمَ / يُعَلِّمُ (to teach). Masdar: تَعْلِيمٌ. Ism fa\'il: مُعَلِّمٌ. Ism maf\'ool: مُعَلَّمٌ.',
        status: 'not_started'
      },
      {
        id: 's2-2',
        arabic: 'فَاعَلَ / يُفَاعِلُ — مُفَاعَلَةٌ مُفَاعَلٌ',
        translation: 'Alif after first letter (mutual action). Example: سَأَلَ / يُسَائِلُ (to ask). Masdar: مُسَاءَلَةٌ. Ism fa\'il: مُسَائِلٌ. Ism maf\'ool: مَسْئُولٌ.',
        status: 'not_started'
      }
    ]
  },
  {
    id: 'sarf-static-3',
    name: '🌙 Sarf - The 3 Hamza Families (Af\'ala)',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's3-1',
        arabic: 'أَفْعَلَ / يُفْعِلُ — إِفْعَالٌ مُفْعَلٌ',
        translation: 'Hamza + kasra in present (causative). Example: أَقْبَلَ / يُقْبِلُ (to approach). Masdar: إِقْبَالٌ. Ism fa\'il: مُقْبِلٌ. Ism maf\'ool: مُقْبَلٌ.',
        status: 'not_started'
      },
      {
        id: 's3-2',
        arabic: 'أَفْعَلَ / يُفْعَلُ — إِفْعَالٌ مُفْعَلٌ',
        translation: 'Hamza + fatha in present (passive causative). Example: أَنْقَذَ / يُنْقَذُ (to save). Masdar: إِنْقَاذٌ. Ism fa\'il: مُنْقِذٌ. Ism maf\'ool: مُنْقَذٌ.',
        status: 'not_started'
      },
      {
        id: 's3-3',
        arabic: 'اسْتَفْعَلَ / يَسْتَفْعِلُ — اسْتِفْعَالٌ مُسْتَفْعَلٌ',
        translation: 'Istif\'aal pattern (seek/request). Example: اسْتَغْفَرَ / يَسْتَغْفِرُ (seek forgiveness). Masdar: اسْتِغْفَارٌ. Ism fa\'il: مُسْتَغْفِرٌ.',
        status: 'not_started'
      }
    ]
  },
  {
    id: 'sarf-static-4',
    name: '✨ Sarf - The 6 Small Families',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's4-1',
        arabic: 'فَعَلَ / يَفْعُلُ — خَفِيفٌ (sukoon on middle)',
        translation: 'Light pattern with sukoon. Example: رَصَنَ / يَرْصُنُ (to anchor). Ism fa\'il: رَاصِنٌ. Ism maf\'ool: مَرْصُونٌ.',
        status: 'not_started'
      },
      {
        id: 's4-2',
        arabic: 'فَعَلَ / يَفْعِلُ — حَفِظَ pattern',
        translation: 'Light pattern with kasra. Example: حَفِظَ / يَحْفِظُ (to protect). Ism fa\'il: حَافِظٌ. Ism maf\'ool: مَحْفُوظٌ.',
        status: 'not_started'
      },
      {
        id: 's4-3',
        arabic: 'فَعِلَ / يَفْعَلُ — عَلِمَ variant',
        translation: 'Kasra in past, fatha in present. Example: بَرِضَ / يَبْرَضُ. Ism fa\'il: بَارِضٌ. Ism maf\'ool: مَبْرُوضٌ.',
        status: 'not_started'
      },
      {
        id: 's4-4',
        arabic: 'فَعِلَ / يَفْعَلُ — عَمِسَ pattern (rare)',
        translation: 'Rare intransitive pattern. Example: عَمِسَ / يَعْمَسُ (dry up). Ism fa\'il: عَامِسٌ. Ism maf\'ool: مَعْمُوسٌ.',
        status: 'not_started'
      },
      {
        id: 's4-5',
        arabic: 'فَعُلَ / يَفْعُلُ — بَسَحَ pattern',
        translation: 'Rare pattern with damma. Example: بَسَحَ / يَبْسَحُ (wash away). Ism fa\'il: بَاسِحٌ. Ism maf\'ool: مَبْسُوحٌ.',
        status: 'not_started'
      },
      {
        id: 's4-6',
        arabic: 'فَعُلَ / يَفْعُلُ — كَرُمَ pattern (color/defect)',
        translation: 'Color/defect pattern (صِفَة مُشْبِهَة). Example: كَرُمَ / يَكْرُمُ (be generous). Ism fa\'il: كَرِيمٌ. Ism maf\'ool: مَكْرُومٌ.',
        status: 'not_started'
      }
    ]
  },
  {
    id: 'sarf-static-5',
    name: '🧠 Sarf - Command & Forbidding',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's5-1',
        arabic: 'أَمْرٌ (Command) — اُكْتُبْ اُدْخُلْ اسْجُدْ',
        translation: 'Drop the ي from present tense. يَكْتُبُ → اُكْتُبْ (Write!), يَدْخُلُ → اُدْخُلْ (Enter!), يَسْجُدُ → اسْجُدْ (Prostrate!).',
        status: 'not_started'
      },
      {
        id: 's5-2',
        arabic: 'نَهْيٌ (Forbidding) — لا تَكْتُبْ لا تَذْهَبْ',
        translation: 'لَا + present jussive (sukoon). لا تَكْتُبْ (Don\'t write!), لا تَذْهَبْ (Don\'t go!), لا تَقْرَأْ (Don\'t read!).',
        status: 'not_started'
      },
      {
        id: 's5-3',
        arabic: 'مَصْدَرٌ (Verbal Noun) — فِعْلٌ فَاعِلٌ مَفْعُولٌ',
        translation: 'Abstract concept. كِتَابَةٌ (writing), قِرَاءَةٌ (reading), عِبَادَةٌ (worship). The "idea" of the verb.',
        status: 'not_started'
      },
      {
        id: 's5-4',
        arabic: 'زَمَانٌ وَمَكَانٌ (Time & Place) — مَفْعَلٌ / مَفْعِلٌ',
        translation: 'مَفْعَل: مَسْجِدٌ (mosque - place of sujood), مَقْبَرَةٌ (cemetery). مَفْعِل: مَلْعَبٌ (playground), مَشْرَبٌ (fountain).',
        status: 'not_started'
      }
    ]
  },
  {
    id: 'sarf-static-6',
    name: '📊 Sarf - The 14 Forms Summary',
    tags: ['sarf'],
    isStatic: true,
    lines: [
      {
        id: 's6-1',
        arabic: 'Form I: فَعَلَ / يَفْعَلُ — Base/root meaning',
        translation: 'The foundation. Example: كَتَبَ / يَكْتُبُ (to write). Most common. All other forms build on this.',
        status: 'not_started'
      },
      {
        id: 's6-2',
        arabic: 'Form II: فَعَّلَ / يُفَعِّلُ — Intensive or transitive',
        translation: 'Shadda = heavy/intensive. Example: كَسَّرَ (smash) from كَسَرَ (break). Makes intransitive → transitive.',
        status: 'not_started'
      },
      {
        id: 's6-3',
        arabic: 'Form III: فَاعَلَ / يُفَاعِلُ — Mutual/reciprocal',
        translation: 'Alif = partnership. Example: كَاتَبَ (correspond) from كَتَبَ (write). Action between two people.',
        status: 'not_started'
      },
      {
        id: 's6-4',
        arabic: 'Form IV: أَفْعَلَ / يُفْعِلُ — Causative',
        translation: 'Hamza = cause. Example: أَخْرَجَ (bring out) from خَرَجَ (exit). Causes action in another.',
        status: 'not_started'
      },
      {
        id: 's6-5',
        arabic: 'Form V: تَفَعَّلَ / يَتَفَعَّلُ — Reflexive of II',
        translation: 'Ta + shadda. Example: تَعَلَّمَ (learn) from عَلَّمَ (teach). Self-benefiting action.',
        status: 'not_started'
      },
      {
        id: 's6-6',
        arabic: 'Form VI: تَفَاعَلَ / يَتَفَاعَلُ — Reflexive of III',
        translation: 'Ta + alif. Example: تَكَاتَبَ (exchange letters). Mutual action done by oneself.',
        status: 'not_started'
      },
      {
        id: 's6-7',
        arabic: 'Form VII: انْفَعَلَ / يَنْفَعِلُ — Passive of I',
        translation: 'Nun + kasra. Example: انْكَسَرَ (become broken). Intransitive, happens to oneself.',
        status: 'not_started'
      },
      {
        id: 's6-8',
        arabic: 'Form VIII: افْتَعَلَ / يَفْتَعِلُ — Self-directed',
        translation: 'Ta after first letter. Example: اِفْتَحَرَ (dig for oneself). Direct benefit to self.',
        status: 'not_started'
      },
      {
        id: 's6-9',
        arabic: 'Form IX: افْعَلَّ / يَفْعَلُّ — Color/defect',
        translation: 'Shadda on last letter. Example: احْمَرَّ / يَحْمَرُّ (become red). Only for colors/defects.',
        status: 'not_started'
      },
      {
        id: 's6-10',
        arabic: 'Form X: اسْتَفْعَلَ / يَسْتَفْعِلُ — Seek/request',
        translation: 'Ist + f\'aal. Example: اسْتَعْلَمَ (ask for info) from عَلِمَ (know). Seeking the action.',
        status: 'not_started'
      }
    ]
  }
];

// Helper to get all static groups
export const getStaticSarfGroups = () => STATIC_SARF_GROUPS;

// Helper to update static line status (stored in localStorage)
export const updateStaticLineStatus = (groupId, lineId, status) => {
  const key = `hifz_static_status_${groupId}_${lineId}`;
  localStorage.setItem(key, status);
};

// Helper to get static line status from localStorage
export const getStaticLineStatus = (groupId, lineId) => {
  const key = `hifz_static_status_${groupId}_${lineId}`;
  return localStorage.getItem(key) || 'not_started';
};

// Get static groups with their saved statuses
export const getStaticGroupsWithStatus = () => {
  return STATIC_SARF_GROUPS.map(group => ({
    ...group,
    lines: group.lines.map(line => ({
      ...line,
      status: getStaticLineStatus(group.id, line.id)
    }))
  }));
};
