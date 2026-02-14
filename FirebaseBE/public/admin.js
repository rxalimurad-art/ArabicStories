/**
 * Arabic Stories Admin - Frontend JavaScript
 * No password required - open access
 */

// ============================================
// Configuration
// ============================================
const CONFIG = {
  // API base URL - empty for same-origin, or set for local emulator
  apiBaseUrl: localStorage.getItem('apiBaseUrl') || ''
};

// API Endpoints
const API = {
  stories: () => `${CONFIG.apiBaseUrl}/api/stories`,
  story: (id) => `${CONFIG.apiBaseUrl}/api/stories/${id}`,
  validate: () => `${CONFIG.apiBaseUrl}/api/stories/validate`,
  categories: () => `${CONFIG.apiBaseUrl}/api/categories`,
  seed: () => `${CONFIG.apiBaseUrl}/api/seed`,
  // Quran data endpoints (read-only)
  quranWords: () => `${CONFIG.apiBaseUrl}/api/quran-words`,
  quranWord: (id) => `${CONFIG.apiBaseUrl}/api/quran-words/${id}`,
  quranWordSearch: (text) => `${CONFIG.apiBaseUrl}/api/quran-words/search/${encodeURIComponent(text)}`,
  quranStats: () => `${CONFIG.apiBaseUrl}/api/quran-stats`,
  quranRoots: () => `${CONFIG.apiBaseUrl}/api/quran-roots`,
  quranRoot: (id) => `${CONFIG.apiBaseUrl}/api/quran-roots/${id}`,
  quranRootWords: (root) => `${CONFIG.apiBaseUrl}/api/quran-roots/${encodeURIComponent(root)}/words`
};

// ============================================
// State Management
// ============================================
const state = {
  currentView: 'stories',
  stories: [],
  currentStory: null,
  segments: [],
  words: [],
  storyToDelete: null,
  page: 1,
  limit: 20,
  // Words state
  wordsList: [],
  wordsPage: 1,
  wordsLimit: 100,
  wordToDelete: null,
  wordCategories: []
};

// ============================================
// Initialization
// ============================================
document.addEventListener('DOMContentLoaded', () => {
  initializeApp();
});

function initializeApp() {
  setupEventListeners();
  loadStories();
  
  // Load any saved draft
  const hasDraft = localStorage.getItem('storyDraft');
  if (hasDraft) {
    showToast('💡 You have a saved draft. Go to "New Story" to restore it.', 'info', 6000);
  }
}

function setupEventListeners() {
  // Navigation
  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => switchView(btn.dataset.view));
  });
  
  // Settings
  document.getElementById('settings-btn')?.addEventListener('click', openSettings);
  document.getElementById('cancel-settings')?.addEventListener('click', closeSettings);
  document.getElementById('save-settings')?.addEventListener('click', saveSettings);
  
  // Format selector - only format selector changes the segment type
  document.getElementById('story-format')?.addEventListener('change', onFormatChange);
  
  // Story form actions
  document.getElementById('add-segment-btn')?.addEventListener('click', () => {
    const format = document.getElementById('story-format')?.value || 'mixed';
    
    if (format === 'mixed') {
      addMixedSegment();
    } else {
      addBilingualSegment();
    }
  });
  
  document.getElementById('validate-btn')?.addEventListener('click', validateCurrentStory);
  document.getElementById('publish-btn')?.addEventListener('click', publishStory);
  document.getElementById('save-draft-btn')?.addEventListener('click', saveDraft);
  
  // Stories list actions
  document.getElementById('refresh-stories')?.addEventListener('click', loadStories);
  document.getElementById('story-search')?.addEventListener('input', debounce(filterStories, 300));
  document.getElementById('story-format-filter')?.addEventListener('change', loadStories);
  
  // Import/Export
  document.getElementById('import-btn')?.addEventListener('click', handleImport);
  document.getElementById('import-file')?.addEventListener('change', handleFileSelect);
  document.getElementById('export-all-btn')?.addEventListener('click', exportAllStories);
  
  // Quran Stats
  loadQuranStats();
  
  // Modal
  document.getElementById('cancel-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('confirm-delete')?.addEventListener('click', confirmDelete);
  
  // Pagination
  document.getElementById('prev-page')?.addEventListener('click', () => changePage(-1));
  document.getElementById('next-page')?.addEventListener('click', () => changePage(1));
  
  // Words view
  document.getElementById('refresh-words')?.addEventListener('click', loadWords);
  document.getElementById('word-search')?.addEventListener('input', debounce(filterWords, 300));
  document.getElementById('word-pos-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-form-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-sort')?.addEventListener('change', loadWords);
  document.getElementById('word-limit')?.addEventListener('change', (e) => {
    state.wordsLimit = parseInt(e.target.value);
    loadWords();
  });
  document.getElementById('word-prev-page')?.addEventListener('click', () => changeWordsPage(-1));
  document.getElementById('word-next-page')?.addEventListener('click', () => changeWordsPage(1));
  
  // Word modal
  document.getElementById('cancel-word')?.addEventListener('click', closeWordModal);
}

// ============================================
// Settings Modal
// ============================================
function openSettings() {
  document.getElementById('api-base-url').value = CONFIG.apiBaseUrl;
  document.getElementById('settings-modal').classList.remove('hidden');
}

function closeSettings() {
  document.getElementById('settings-modal').classList.add('hidden');
}

function saveSettings() {
  const url = document.getElementById('api-base-url').value.trim();
  CONFIG.apiBaseUrl = url;
  localStorage.setItem('apiBaseUrl', url);
  closeSettings();
  showToast('Settings saved', 'success');
  loadStories(); // Reload with new URL
}

// ============================================
// API Helpers
// ============================================
async function apiRequest(url, options = {}) {
  const defaultOptions = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    }
  };
  
  try {
    const response = await fetch(url, { ...defaultOptions, ...options });
    const data = await response.json();
    
    if (!response.ok) {
      throw new Error(data.error || `HTTP ${response.status}`);
    }
    
    return data;
  } catch (error) {
    console.error('API Error:', error);
    throw error;
  }
}

// ============================================
// Navigation & Views
// ============================================
function switchView(viewName) {
  // Update nav buttons
  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.view === viewName);
  });
  
  // Hide all views
  document.querySelectorAll('.view').forEach(view => {
    view.classList.add('hidden');
  });
  
  // Show selected view
  document.getElementById(`${viewName}-view`)?.classList.remove('hidden');
  
  state.currentView = viewName;
  
  // View-specific initialization
  if (viewName === 'create') {
    if (state.segments.length === 0) {
      // Check for draft first
      const draft = localStorage.getItem('storyDraft');
      if (draft) {
        try {
          const data = JSON.parse(draft);
          populateForm(data);
          localStorage.removeItem('storyDraft');
          showToast('Draft restored', 'success');
        } catch (e) {
          addSegment();
        }
      } else {
        addSegment();
      }
    }
  } else if (viewName === 'words') {
    if (state.wordsList.length === 0) {
      loadWords();
    }
  }
}

// ============================================
// Stories Management
// ============================================
async function loadStories() {
  const container = document.getElementById('stories-list');
  container.innerHTML = '<div class="loading">Loading stories...</div>';
  
  try {
    const formatFilter = document.getElementById('story-format-filter')?.value || '';
    let url = `${API.stories()}?limit=${state.limit}&offset=${(state.page - 1) * state.limit}`;
    
    if (formatFilter) {
      url += `&format=${encodeURIComponent(formatFilter)}`;
    }
    
    const data = await apiRequest(url);
    
    state.stories = data.stories || [];
    renderStories(state.stories);
  } catch (error) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>Error loading stories: ${error.message}</p>
        <button onclick="seedSampleStories('mixed')" class="btn btn-primary" style="margin-top: 16px;">
          🌱 Seed Level 1 Mixed Story
        </button>
        <button onclick="seedSampleStories('bilingual')" class="btn btn-secondary" style="margin-top: 8px;">
          🌱 Seed Level 2+ Bilingual Story
        </button>
      </div>
    `;
  }
}

function renderStories(stories) {
  const container = document.getElementById('stories-list');
  
  if (stories.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>No stories found. Create your first story!</p>
        <button onclick="switchView('create')" class="btn btn-primary" style="margin-top: 16px;">
          Create Story
        </button>
      </div>
    `;
    return;
  }
  
  container.innerHTML = stories.map(story => `
    <div class="story-card" data-id="${story.id}">
      <div class="story-card-cover" style="${story.coverImageURL ? `background-image: url('${story.coverImageURL}')` : ''}">
        ${!story.coverImageURL ? '📚' : ''}
      </div>
      <div class="story-card-content">
        <div class="story-card-title">${escapeHtml(story.title)}</div>
        ${story.titleArabic ? `<div class="story-card-title-arabic" dir="rtl">${escapeHtml(story.titleArabic)}</div>` : ''}
        <div class="story-card-meta">
          <span class="story-card-badge badge-difficulty-${story.difficultyLevel}">
            L${story.difficultyLevel}
          </span>
          <span class="story-card-badge badge-format-${story.format || 'bilingual'}">
            ${story.format === 'mixed' ? '🎯 Mixed' : '📖 Bilingual'}
          </span>
          <span class="story-card-badge badge-category">${story.category}</span>
        </div>
        <div class="story-card-stats">
          <span>📝 ${story.segmentCount} segments</span>
          <span>📖 ${story.wordCount} words</span>
        </div>
      </div>
      <div class="story-card-actions">
        <button class="btn btn-small btn-secondary" onclick="editStory('${story.id}')">Edit</button>
        <button class="btn btn-small btn-danger" onclick="promptDelete('${story.id}')">Delete</button>
      </div>
    </div>
  `).join('');
}

function filterStories(e) {
  const query = e.target.value.toLowerCase();
  
  if (!query) {
    renderStories(state.stories);
    return;
  }
  
  const filtered = state.stories.filter(story => 
    story.title?.toLowerCase().includes(query) ||
    story.titleArabic?.includes(query) ||
    story.author?.toLowerCase().includes(query) ||
    story.category?.toLowerCase().includes(query)
  );
  
  renderStories(filtered);
}

function changePage(delta) {
  state.page = Math.max(1, state.page + delta);
  document.getElementById('page-info').textContent = `Page ${state.page}`;
  loadStories();
}

// ============================================
// Story Form Management
// ============================================
// Bilingual format segment (Level 2+) - Simplified without grammar/cultural notes
function addBilingualSegment(data = null) {
  const index = state.segments.length;
  const container = document.getElementById('segments-container');
  
  const card = document.createElement('div');
  card.className = 'segment-card bilingual-format';
  card.dataset.index = index;
  card.dataset.segmentId = data?.id || generateId();
  card.dataset.format = 'bilingual';
  
  card.innerHTML = `
    <div class="segment-header">
      <span class="segment-format-label">📖 Bilingual</span>
      <span class="segment-number">Segment ${index + 1}</span>
      <button type="button" class="btn btn-icon btn-danger remove-segment">✕</button>
    </div>
    
    <div class="form-row">
      <div class="form-group form-group-wide">
        <label>Arabic Text *</label>
        <textarea class="segment-arabic" rows="3" dir="rtl" required placeholder="النص العربي">${data?.arabicText || ''}</textarea>
      </div>
    </div>
    
    <div class="form-row">
      <div class="form-group form-group-wide">
        <label>English Text *</label>
        <textarea class="segment-english" rows="3" required placeholder="English translation">${data?.englishText || ''}</textarea>
      </div>
    </div>
    
    <div class="form-row">
      <div class="form-group form-group-wide">
        <label>Transliteration</label>
        <input type="text" class="segment-transliteration" placeholder="Arabic transliteration" value="${data?.transliteration || ''}">
      </div>
    </div>
  `;
  
  // Setup remove button
  card.querySelector('.remove-segment').addEventListener('click', () => removeSegment(index));
  
  container.appendChild(card);
  state.segments.push({ id: card.dataset.segmentId, format: 'bilingual' });
  
  document.getElementById('empty-segments')?.classList.add('hidden');
  card.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

// Single/Mixed format segment (Level 1) - With content parts
function addMixedSegment(data = null) {
  const index = state.segments.length;
  const container = document.getElementById('segments-container');
  
  const card = document.createElement('div');
  card.className = 'segment-card mixed-format';
  card.dataset.index = index;
  card.dataset.segmentId = data?.id || generateId();
  card.dataset.format = 'mixed';
  
  card.innerHTML = `
    <div class="segment-header">
      <span class="segment-format-label">🎯 Single</span>
      <span class="segment-number">Segment ${index + 1}</span>
      <button type="button" class="btn btn-icon btn-danger remove-segment">✕</button>
    </div>
    
    <div class="form-group form-group-wide" style="margin-bottom: 12px;">
      <label>Segment Text *</label>
      <textarea class="segment-text" rows="4" required placeholder="Enter story text here..."></textarea>
    </div>
  `;
  
  // Setup remove button
  card.querySelector('.remove-segment').addEventListener('click', () => removeSegment(index));
  
  // Fill existing text if data provided
  if (data?.text) {
    card.querySelector('.segment-text').value = data.text;
  } else if (data?.contentParts?.length > 0) {
    // Backward compatibility: convert contentParts to simple text
    const text = data.contentParts.map(part => part.text || '').join('');
    card.querySelector('.segment-text').value = text;
  }
  
  container.appendChild(card);
  state.segments.push({ id: card.dataset.segmentId, format: 'mixed' });
  
  document.getElementById('empty-segments')?.classList.add('hidden');
  card.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

// Keep for backward compatibility - no longer used
function addContentPartToCard(card, data = {}) {
  console.log('addContentPartToCard is deprecated. Use simple text fields instead.');
}

// Keep old function for backward compatibility
function addContentPart(segmentIndex, type) {
  console.log('addContentPart is deprecated. Use simple text fields instead.');
}

function removeSegment(index) {
  const container = document.getElementById('segments-container');
  const cards = container.querySelectorAll('.segment-card');
  
  if (cards[index]) {
    cards[index].remove();
    state.segments.splice(index, 1);
    
    // Re-index remaining cards
    container.querySelectorAll('.segment-card').forEach((card, idx) => {
      card.dataset.index = idx;
      card.querySelector('.segment-number').textContent = `Segment ${idx + 1}`;
      // Update remove button
      const removeBtn = card.querySelector('.remove-segment');
      removeBtn.replaceWith(removeBtn.cloneNode(true));
      card.querySelector('.remove-segment').addEventListener('click', () => removeSegment(idx));
    });
    
    if (state.segments.length === 0) {
      document.getElementById('empty-segments')?.classList.remove('hidden');
    }
  }
}

function addWord(data = null) {
  const index = state.words.length;
  const container = document.getElementById('words-container');
  const template = document.getElementById('word-template');
  
  const clone = template.content.cloneNode(true);
  const card = clone.querySelector('.word-card');
  
  const wordId = data?.id || generateId();
  card.dataset.index = index;
  card.dataset.wordId = wordId;
  card.querySelector('.word-number').textContent = `Word ${index + 1}`;
  
  // Setup remove button
  card.querySelector('.remove-word').addEventListener('click', () => removeWord(index));
  
  // Fill data if provided (using new quran_words schema)
  if (data) {
    // Core fields
    card.querySelector('.word-arabic').value = data.arabicText || data.arabic || '';
    card.querySelector('.word-english').value = data.englishMeaning || data.english || '';
    card.querySelector('.word-transliteration').value = data.buckwalter || data.transliteration || '';
    
    // Morphology fields
    card.querySelector('.word-pos').value = data.morphology?.partOfSpeech || data.partOfSpeech || '';
    
    // Root fields
    card.querySelector('.word-root').value = data.root?.arabic || data.rootLetters || '';
    
    // Additional fields (if form elements exist)
    const posDescEl = card.querySelector('.word-pos-description');
    if (posDescEl) posDescEl.value = data.morphology?.posDescription || '';
    
    const lemmaEl = card.querySelector('.word-lemma');
    if (lemmaEl) lemmaEl.value = data.morphology?.lemma || '';
    
    const formEl = card.querySelector('.word-form');
    if (formEl) formEl.value = data.morphology?.form || '';
    
    const rankEl = card.querySelector('.word-rank');
    if (rankEl) rankEl.value = data.rank || '';
    
    const countEl = card.querySelector('.word-occurrence-count');
    if (countEl) countEl.value = data.occurrenceCount || '';
    
    card.querySelector('.word-example').value = data.exampleSentence || '';
  }
  
  // Set the word ID display
  const wordIdDisplay = card.querySelector('.word-id-display');
  if (wordIdDisplay) {
    wordIdDisplay.value = wordId;
  }
  
  container.appendChild(card);
  state.words.push({ id: wordId });
  
  document.getElementById('empty-words')?.classList.add('hidden');
}

function removeWord(index) {
  const container = document.getElementById('words-container');
  const cards = container.querySelectorAll('.word-card');
  
  if (cards[index]) {
    cards[index].remove();
    state.words.splice(index, 1);
    
    // Re-index remaining cards
    container.querySelectorAll('.word-card').forEach((card, idx) => {
      card.dataset.index = idx;
      card.querySelector('.word-number').textContent = `Word ${idx + 1}`;
      // Update remove button
      const removeBtn = card.querySelector('.remove-word');
      removeBtn.replaceWith(removeBtn.cloneNode(true));
      card.querySelector('.remove-word').addEventListener('click', () => removeWord(idx));
    });
    
    if (state.words.length === 0) {
      document.getElementById('empty-words')?.classList.remove('hidden');
    }
  }
}

function collectFormData() {
  const format = document.getElementById('story-format')?.value || 'mixed';
  
  const storyId = document.getElementById('story-id').value;
  
  const result = {
    id: storyId && storyId.trim() !== '' ? storyId : undefined,
    title: document.getElementById('story-title').value.trim(),
    titleArabic: document.getElementById('story-title-arabic').value.trim() || null,
    storyDescription: document.getElementById('story-desc').value.trim(),
    storyDescriptionArabic: document.getElementById('story-desc-arabic').value.trim() || null,
    author: document.getElementById('story-author').value.trim(),
    format: format,
    difficultyLevel: parseInt(document.getElementById('story-difficulty').value) || 1,
    category: document.getElementById('story-category').value,
    // Tags field removed from UI
    tags: [],
    coverImageURL: document.getElementById('story-cover').value.trim() || null
    // No audioNarrationURL - removed per requirements
    // No vocabulary words - using general words only
  };
  
  // Collect format-specific content
  if (format === 'mixed') {
    // Single/Mixed format: Simple text segments
    result.mixedSegments = [];
    document.querySelectorAll('.segment-card[data-format="mixed"]').forEach((card, idx) => {
      const text = card.querySelector('.segment-text')?.value.trim() || '';
      
      if (text) {
        result.mixedSegments.push({
          id: card.dataset.segmentId || undefined,
          index: idx,
          text: text
        });
      }
    });
  } else {
    // Bilingual format: Full Arabic with English translation
    result.segments = [];
    document.querySelectorAll('.segment-card[data-format="bilingual"]').forEach((card, idx) => {
      const arabicText = card.querySelector('.segment-arabic').value.trim();
      const englishText = card.querySelector('.segment-english').value.trim();
      
      if (arabicText || englishText) {
        result.segments.push({
          id: card.dataset.segmentId || undefined,
          index: idx,
          arabicText: arabicText,
          englishText: englishText,
          transliteration: card.querySelector('.segment-transliteration').value.trim() || null
          // No grammarNote, culturalNote, audio - removed per requirements
        });
      }
    });
  }
  
  return result;
}

async function validateCurrentStory() {
  const data = collectFormData();
  
  try {
    const result = await apiRequest(API.validate(), {
      method: 'POST',
      body: JSON.stringify(data)
    });
    
    showValidationResults(result);
    
    if (result.valid) {
      showToast('✅ Story is valid!', 'success');
    } else {
      showToast(`❌ Found ${result.errors.length} error(s)`, 'error');
    }
  } catch (error) {
    showToast(`Validation failed: ${error.message}`, 'error');
  }
}

function showValidationResults(result) {
  const panel = document.getElementById('validation-results');
  const content = document.getElementById('validation-content');
  
  panel.classList.remove('hidden');
  
  let html = '';
  
  if (result.valid) {
    html += `<div class="validation-success">✅ Story is valid and ready to publish!</div>`;
  }
  
  if (result.errors?.length > 0) {
    html += `<strong>Errors (${result.errors.length}):</strong>`;
    result.errors.forEach(error => {
      html += `<div class="validation-error">• ${escapeHtml(error)}</div>`;
    });
  }
  
  if (result.warnings?.length > 0) {
    html += `<strong>Warnings (${result.warnings.length}):</strong>`;
    result.warnings.forEach(warning => {
      html += `<div class="validation-warning">• ${escapeHtml(warning)}</div>`;
    });
  }
  
  html += `
    <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--gray-200);">
      <strong>Summary:</strong><br>
      Title: ${escapeHtml(result.summary?.title || 'N/A')}<br>
      Segments: ${result.summary?.segmentCount || 0}<br>
      Words: ${result.summary?.wordCount || 0}
    </div>
  `;
  
  content.innerHTML = html;
  
  // Auto-hide after 10 seconds
  setTimeout(() => {
    panel.classList.add('hidden');
  }, 10000);
}

async function publishStory() {
  const data = collectFormData();
  
  console.log('Publishing story:', { 
    hasId: !!data.id, 
    id: data.id,
    title: data.title 
  });
  
  // First validate
  try {
    const validation = await apiRequest(API.validate(), {
      method: 'POST',
      body: JSON.stringify(data)
    });
    
    if (!validation.valid) {
      showValidationResults(validation);
      showToast('Please fix validation errors before publishing', 'error');
      return;
    }
  } catch (error) {
    // Continue even if validation fails
    console.warn('Validation error:', error);
  }
  
  // Publish
  try {
    const isUpdate = !!data.id;
    const url = isUpdate ? API.story(data.id) : API.stories();
    const method = isUpdate ? 'PUT' : 'POST';
    
    const result = await apiRequest(url, {
      method,
      body: JSON.stringify(data)
    });
    
    showToast(result.message || 'Story saved successfully!', 'success');
    
    // Reset form
    resetForm();
    
    // Go back to stories list
    switchView('stories');
    loadStories();
  } catch (error) {
    showToast(`Failed to save story: ${error.message}`, 'error');
  }
}

function saveDraft() {
  const data = collectFormData();
  localStorage.setItem('storyDraft', JSON.stringify(data));
  showToast('Draft saved locally', 'success');
}

function resetForm() {
  document.getElementById('story-form').reset();
  document.getElementById('story-id').value = '';
  
  document.getElementById('segments-container').innerHTML = '';
  state.segments = [];
  
  document.getElementById('empty-segments')?.classList.remove('hidden');
  document.getElementById('validation-results')?.classList.add('hidden');
  
  document.getElementById('form-title').textContent = '➕ Create New Story';
  
  addSegment();
}

function populateForm(data) {
  document.getElementById('story-id').value = data.id || '';
  document.getElementById('story-title').value = data.title || '';
  document.getElementById('story-title-arabic').value = data.titleArabic || '';
  document.getElementById('story-desc').value = data.storyDescription || '';
  document.getElementById('story-desc-arabic').value = data.storyDescriptionArabic || '';
  document.getElementById('story-author').value = data.author || '';
  document.getElementById('story-difficulty').value = data.difficultyLevel || 1;
  document.getElementById('story-category').value = data.category || 'general';
  // Tags field removed - story-tags no longer exists
  document.getElementById('story-cover').value = data.coverImageURL || '';
  // No audio field - removed per requirements
  
  // Set format and update UI
  const format = data.format || 'mixed';
  const formatSelect = document.getElementById('story-format');
  if (formatSelect) {
    formatSelect.value = format;
    onFormatChange(); // Update UI based on format
  }
  
  // Handle format-specific content
  document.getElementById('segments-container').innerHTML = '';
  state.segments = [];
  
  if (format === 'mixed' && data.mixedSegments?.length > 0) {
    data.mixedSegments.forEach(seg => addMixedSegment(seg));
  } else if (format === 'mixed' && data.segments?.length > 0) {
    // Backward compatibility: convert old segments to new format
    data.segments.forEach(seg => addMixedSegment({ text: seg.englishText || '' }));
  } else if (data.segments?.length > 0) {
    data.segments.forEach(seg => addBilingualSegment(seg));
  } else {
    // Default: add one empty segment based on format
    if (format === 'mixed') {
      addMixedSegment();
    } else {
      addBilingualSegment();
    }
  }
  
  // Story vocabulary words section removed - words are now managed in General Words
}

// ============================================
// Edit & Delete
// ============================================
async function editStory(storyId) {
  try {
    console.log('Editing story:', storyId);
    const result = await apiRequest(API.story(storyId));
    
    if (result.story) {
      console.log('Loaded story:', { id: result.story.id, title: result.story.title });
      populateForm(result.story);
      
      // Verify ID was set
      const formId = document.getElementById('story-id').value;
      console.log('Form ID after populate:', formId);
      
      document.getElementById('form-title').textContent = '✏️ Edit Story';
      switchView('create');
    }
  } catch (error) {
    showToast(`Failed to load story: ${error.message}`, 'error');
  }
}

function promptDelete(storyId) {
  state.storyToDelete = storyId;
  document.getElementById('delete-modal').classList.remove('hidden');
}

function closeDeleteModal() {
  state.storyToDelete = null;
  state.wordToDelete = null;
  document.getElementById('delete-modal').classList.add('hidden');
  // Reset the modal text back to default (story delete)
  document.getElementById('delete-modal').querySelector('h3').textContent = '⚠️ Confirm Delete';
  document.getElementById('delete-modal').querySelector('p').textContent = 'Are you sure you want to delete this story? This action cannot be undone.';
  document.getElementById('confirm-delete').onclick = confirmDelete;
}

async function confirmDelete() {
  if (!state.storyToDelete) return;
  
  try {
    await apiRequest(API.story(state.storyToDelete), {
      method: 'DELETE'
    });
    
    showToast('Story deleted successfully', 'success');
    closeDeleteModal();
    loadStories();
  } catch (error) {
    showToast(`Failed to delete: ${error.message}`, 'error');
  }
}

// ============================================
// Import / Export
// ============================================
function handleFileSelect(e) {
  const file = e.target.files[0];
  if (!file) return;
  
  const reader = new FileReader();
  reader.onload = (event) => {
    document.getElementById('import-json').value = event.target.result;
    previewImport(event.target.result);
  };
  reader.readAsText(file);
}

function previewImport(jsonStr) {
  try {
    const data = JSON.parse(jsonStr);
    const preview = document.getElementById('import-preview');
    
    const isArray = Array.isArray(data);
    const stories = isArray ? data : [data];
    
    preview.innerHTML = `
      <strong>Preview:</strong> ${stories.length} story(s) found<br>
      <em>"${escapeHtml(stories[0].title || stories[0].titleArabic || 'Untitled')}"</em>
    `;
    preview.classList.remove('hidden');
  } catch (error) {
    showToast('Invalid JSON format', 'error');
  }
}

async function handleImport() {
  const jsonStr = document.getElementById('import-json').value.trim();
  
  if (!jsonStr) {
    showToast('Please paste JSON or select a file', 'error');
    return;
  }
  
  try {
    const data = JSON.parse(jsonStr);
    console.log('Parsed JSON:', data);
    
    const stories = Array.isArray(data) ? data : [data];
    console.log('Stories to import:', stories.length);
    
    let successCount = 0;
    const errors = [];
    
    for (let i = 0; i < stories.length; i++) {
      const story = stories[i];
      console.log(`Processing story ${i + 1}:`, story.title || 'Untitled');
      
      try {
        // Normalize field names and set defaults
        const normalizedStory = normalizeStoryData(story);
        console.log('Normalized story:', normalizedStory);
        
        // Validate required fields
        if (!normalizedStory.title || normalizedStory.title.trim() === '') {
          errors.push(`Story ${i + 1}: Missing title`);
          continue;
        }
        if (!normalizedStory.storyDescription || normalizedStory.storyDescription.trim() === '') {
          errors.push(`Story "${normalizedStory.title}": Missing description`);
          continue;
        }
        
        // Send to API
        console.log('Sending to API:', JSON.stringify(normalizedStory, null, 2));
        
        const result = await apiRequest(API.stories(), {
          method: 'POST',
          body: JSON.stringify(normalizedStory)
        });
        
        console.log('API response:', result);
        successCount++;
      } catch (error) {
        console.error('Failed to import story:', story.title || 'Untitled', error);
        errors.push(`"${story.title || `Story ${i + 1}`}": ${error.message}`);
      }
    }
    
    if (errors.length > 0) {
      console.error('Import errors:', errors);
      showToast(`Imported ${successCount}/${stories.length}. Check console for errors.`, 'warning');
    } else {
      showToast(`Imported ${successCount}/${stories.length} stories successfully!`, 'success');
    }
    
    if (successCount > 0) {
      switchView('stories');
      loadStories();
    }
  } catch (error) {
    console.error('Import parse error:', error);
    showToast(`Import failed: ${error.message}`, 'error');
  }
}

/**
 * Normalize story data - handles field name variations and sets defaults
 */
function normalizeStoryData(story) {
  const normalized = {
    // Required fields with fallbacks
    title: story.title || '',
    storyDescription: story.storyDescription || story.description || story.desc || '',
    author: story.author || story.authorName || 'Anonymous',
    difficultyLevel: parseInt(story.difficultyLevel) || 1,
    category: story.category || 'general',
    
    // Optional fields
    titleArabic: story.titleArabic || story.arabicTitle || null,
    storyDescriptionArabic: story.storyDescriptionArabic || story.arabicDescription || null,
    tags: story.tags || [],
    coverImageURL: story.coverImageURL || story.coverImage || story.imageURL || null,
    audioNarrationURL: story.audioNarrationURL || story.audioURL || null,
    
    // Format handling
    format: story.format || 'bilingual',
    
    // Format-specific content
    segments: story.segments || [],
    mixedSegments: story.mixedSegments || [],
    words: normalizeWords(story.words || []),
    grammarNotes: story.grammarNotes || []
  };
  
  // Auto-detect format if not specified
  if (!story.format) {
    if (story.mixedSegments && story.mixedSegments.length > 0) {
      normalized.format = 'mixed';
    } else if (story.segments && story.segments.length > 0) {
      normalized.format = 'bilingual';
    }
  }
  
  return normalized;
}

/**
 * Normalize words data - handles field name variations
 * Updated for quran_words schema from corpQuran/FIRESTORE_SCHEMA.md
 */
function normalizeWords(words) {
  if (!Array.isArray(words)) return [];
  
  return words.map(word => ({
    id: word.id || generateId(),
    // Core Arabic text fields
    arabicText: word.arabicText || word.arabic || '',
    arabicWithoutDiacritics: word.arabicWithoutDiacritics || word.arabic || '',
    buckwalter: word.buckwalter || word.transliteration || null,
    englishMeaning: word.englishMeaning || word.english || word.translation || '',
    
    // Root information (nested object)
    root: {
      arabic: word.root?.arabic || word.rootLetters || word.root || null,
      transliteration: word.root?.transliteration || null
    },
    
    // Morphology (nested object)
    morphology: {
      partOfSpeech: word.morphology?.partOfSpeech || word.partOfSpeech || word.pos || null,
      posDescription: word.morphology?.posDescription || null,
      lemma: word.morphology?.lemma || null,
      form: word.morphology?.form || null,
      tense: word.morphology?.tense || null,
      gender: word.morphology?.gender || null,
      number: word.morphology?.number || null,
      grammaticalCase: word.morphology?.grammaticalCase || null,
      passive: word.morphology?.passive || false,
      breakdown: word.morphology?.breakdown || null
    },
    
    // Statistics
    rank: parseInt(word.rank) || null,
    occurrenceCount: parseInt(word.occurrenceCount) || 0,
    
    // Legacy fields for backward compatibility
    difficulty: parseInt(word.difficulty) || 1,
    category: word.category || 'general',
    exampleSentence: word.exampleSentence || word.example || null
  })).filter(w => w.arabicText && w.englishMeaning);
}

async function exportAllStories() {
  try {
    const data = await apiRequest(`${API.stories()}?limit=1000`);
    
    const blob = new Blob([JSON.stringify(data.stories, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `arabic-stories-export-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    
    URL.revokeObjectURL(url);
    showToast('Stories exported successfully', 'success');
  } catch (error) {
    showToast(`Export failed: ${error.message}`, 'error');
  }
}

function downloadTemplate(type = 'bilingual') {
  let template;
  
  if (type === 'mixed' || type === 'level1') {
    // Mixed format template (Level 1)
    template = {
      title: "Ahmad's Journey to Peace",
      titleArabic: "رحلة أحمد إلى السلام",
      storyDescription: "A beginner-friendly story about Ahmad's spiritual journey, introducing essential Arabic vocabulary.",
      storyDescriptionArabic: "قصة مناسبة للمبتدئين عن الرحلة الروحية لأحمد، تقدم مفردات عربية أساسية.",
      author: "Author Name",
      format: "mixed",
      difficultyLevel: 1,
      category: "religious",
      tags: ["beginner", "vocabulary", "spiritual"],
      coverImageURL: "https://example.com/image.jpg",
      mixedSegments: [
        {
          text: "Once upon a time, there was a young man who turned to Allah for guidance."
        }
      ],
      words: []
    };
  } else {
    // Bilingual format template (Level 2+)
    template = {
      title: "Story Title",
      titleArabic: "عنوان القصة",
      storyDescription: "Brief description of the story",
      storyDescriptionArabic: "وصف موجز للقصة",
      author: "Author Name",
      format: "bilingual",
      difficultyLevel: 2,
      category: "children",
      tags: ["tag1", "tag2"],
      coverImageURL: "https://example.com/image.jpg",
      segments: [
        {
          arabicText: "النص العربي",
          englishText: "English translation",
          transliteration: "Transliteration",
          culturalNote: "Optional cultural context"
        }
      ],
      words: [
        {
          arabic: "كلمة",
          english: "word",
          transliteration: "kalima",
          partOfSpeech: "noun"
        }
      ]
    };
  }
  
  const blob = new Blob([JSON.stringify(template, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = `story-template-${template.format}.json`;
  a.click();
  
  URL.revokeObjectURL(url);
}

async function seedSampleStories(type = 'bilingual') {
  try {
    if (type === 'mixed' || type === 'level1') {
      // Seed a mixed format Level 1 story
      const mixedStory = {
        title: "Ahmad's Journey to Peace",
        titleArabic: "رحلة أحمد إلى السلام",
        storyDescription: "A beginner-friendly story introducing essential Arabic vocabulary. Learn 20 key words to unlock Level 2!",
        storyDescriptionArabic: "قصة للمبتدئين تقدم مفردات عربية أساسية. تعلم 20 كلمة لفتح المستوى الثاني!",
        author: "Arabicly",
        format: "mixed",
        difficultyLevel: 1,
        category: "religious",
        tags: ["beginner", "vocabulary", "spiritual", "level1"],
        coverImageURL: "https://images.unsplash.com/photo-1519817914152-22d216bb9170?w=800",
        mixedSegments: [
          {
            text: "Once upon a time, there was a young man named Ahmad who wanted to find true peace. He turned to Allah, the Most Merciful."
          },
          {
            text: "He opened the Al-Kitab and learned that As-Salaam comes from submission to God."
          }
        ],
        words: []
      };
      
      const result = await apiRequest(API.stories(), {
        method: 'POST',
        body: JSON.stringify(mixedStory)
      });
      
      showToast('Level 1 mixed format story created!', 'success');
    } else {
      // Use default seed endpoint for bilingual stories
      const result = await apiRequest(API.seed(), {
        method: 'POST'
      });
      showToast(result.message, 'success');
    }
    
    loadStories();
  } catch (error) {
    showToast(`Failed to seed stories: ${error.message}`, 'error');
  }
}

// ============================================
// Utilities
// ============================================
function showToast(message, type = 'info', duration = 4000) {
  const container = document.getElementById('toast-container');
  
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function generateId() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// ============================================
// Quran Words Management (from quran_words collection)
// ============================================
async function loadWords() {
  const container = document.getElementById('words-list');
  container.innerHTML = '<div class="loading">Loading Quran words...</div>';
  
  try {
    const pos = document.getElementById('word-pos-filter')?.value || '';
    const form = document.getElementById('word-form-filter')?.value || '';
    const sort = document.getElementById('word-sort')?.value || 'rank';
    const limit = parseInt(document.getElementById('word-limit')?.value) || state.wordsLimit;
    
    let url = `${API.quranWords()}?limit=${limit}&offset=${(state.wordsPage - 1) * limit}&sort=${sort}`;
    if (pos) url += `&pos=${encodeURIComponent(pos)}`;
    if (form) url += `&form=${encodeURIComponent(form)}`;
    
    const data = await apiRequest(url);
    
    state.wordsList = data.words || [];
    renderWords(state.wordsList);
  } catch (error) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>Error loading words: ${error.message}</p>
      </div>
    `;
  }
}

function renderWords(words) {
  const container = document.getElementById('words-list');
  const searchQuery = document.getElementById('word-search')?.value.toLowerCase() || '';
  
  let filtered = words;
  if (searchQuery) {
    filtered = words.filter(w => 
      w.arabicText?.toLowerCase().includes(searchQuery) ||
      w.arabicWithoutDiacritics?.toLowerCase().includes(searchQuery) ||
      w.englishMeaning?.toLowerCase().includes(searchQuery) ||
      w.buckwalter?.toLowerCase().includes(searchQuery)
    );
  }
  
  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>No words found.</p>
      </div>
    `;
    return;
  }
  
  container.innerHTML = filtered.map(word => {
    const arabicText = word.arabicText || '';
    const englishMeaning = word.englishMeaning || '';
    const transliteration = word.buckwalter || '';
    const pos = word.morphology?.partOfSpeech || '';
    const rootArabic = word.root?.arabic || '';
    const rank = word.rank || 0;
    
    return `
    <div class="word-card-compact" data-id="${word.id}" onclick="viewWordDetails('${word.id}')" style="cursor: pointer;">
      <div class="word-card-header">
        <div class="word-arabic" dir="rtl">${escapeHtml(arabicText)}</div>
        <span class="word-badge rank">#${rank}</span>
      </div>
      <div class="word-english">${escapeHtml(englishMeaning)}</div>
      ${transliteration ? `<div class="word-transliteration">${escapeHtml(transliteration)}</div>` : ''}
      <div class="word-meta">
        ${pos ? `<span class="word-badge pos" title="Part of Speech">${pos}</span>` : ''}
        ${rootArabic ? `<span class="word-badge root" dir="rtl" title="Root">${escapeHtml(rootArabic)}</span>` : ''}
        ${word.occurrenceCount ? `<span class="word-badge count" title="Occurrences">${word.occurrenceCount}x</span>` : ''}
        ${word.morphology?.form ? `<span class="word-badge form" title="Form">Form ${word.morphology.form}</span>` : ''}
      </div>
      ${word.morphology?.lemma ? `<div class="word-lemma" dir="rtl">Lemma: ${escapeHtml(word.morphology.lemma)}</div>` : ''}
    </div>
  `}).join('');
}

function filterWords() {
  renderWords(state.wordsList);
}

function changeWordsPage(delta) {
  state.wordsPage = Math.max(1, state.wordsPage + delta);
  document.getElementById('word-page-info').textContent = `Page ${state.wordsPage}`;
  loadWords();
}

// Word modal functions
async function viewWordDetails(wordId) {
  try {
    const result = await apiRequest(API.quranWord(wordId));
    if (result.word) {
      openWordModal(result.word);
    }
  } catch (error) {
    showToast(`Failed to load word: ${error.message}`, 'error');
  }
}

function openWordModal(word = null) {
  const modal = document.getElementById('word-modal');
  const title = document.getElementById('word-modal-title');
  const editBtn = document.getElementById('edit-word-btn');
  const saveBtn = document.getElementById('save-word-btn');
  
  // Reset to view mode
  setWordFormReadonly(true);
  editBtn.classList.remove('hidden');
  saveBtn.classList.add('hidden');
  
  if (word) {
    title.textContent = `📖 Word #${word.rank || 'N/A'} - ${word.arabicText || ''}`;
    document.getElementById('word-id').value = word.id || '';
    
    // Core fields
    document.getElementById('word-arabic-input').value = word.arabicText || '';
    document.getElementById('word-english-input').value = word.englishMeaning || '';
    document.getElementById('word-buckwalter-input').value = word.buckwalter || '';
    
    // POS
    document.getElementById('word-pos-input').value = word.morphology?.partOfSpeech || '';
    
    // Root
    document.getElementById('word-root-input').value = word.root?.arabic || '';
    document.getElementById('word-root-transliteration-input').value = word.root?.transliteration || '';
    
    // Statistics
    document.getElementById('word-rank-input').value = word.rank || '';
    document.getElementById('word-occurrence-count-input').value = word.occurrenceCount || '';
    
    // Morphology details
    document.getElementById('word-lemma-input').value = word.morphology?.lemma || '';
    document.getElementById('word-form-input').value = word.morphology?.form || '';
    document.getElementById('word-tense-input').value = word.morphology?.tense || '';
    document.getElementById('word-gender-input').value = word.morphology?.gender || '';
    document.getElementById('word-number-input').value = word.morphology?.number || '';
    document.getElementById('word-case-input').value = word.morphology?.grammaticalCase || '';
    document.getElementById('word-pos-description-input').value = word.morphology?.posDescription || '';
    document.getElementById('word-passive-input').value = word.morphology?.passive ? 'Yes' : 'No';
    document.getElementById('word-breakdown-input').value = word.morphology?.breakdown || '';
  }
  
  modal.classList.remove('hidden');
}

function setWordFormReadonly(readonly) {
  const inputs = document.querySelectorAll('#word-form input');
  inputs.forEach(input => {
    input.readOnly = readonly;
    if (readonly) {
      input.style.background = 'var(--gray-100)';
    } else {
      input.style.background = 'white';
    }
  });
}

function enableWordEdit() {
  setWordFormReadonly(false);
  document.getElementById('edit-word-btn').classList.add('hidden');
  document.getElementById('save-word-btn').classList.remove('hidden');
  document.getElementById('word-modal-title').textContent = '✏️ Edit Word';
}

function closeWordModal() {
  document.getElementById('word-modal').classList.add('hidden');
  document.getElementById('word-form').reset();
  setWordFormReadonly(true);
}

async function saveWord() {
  const wordId = document.getElementById('word-id').value;
  
  const wordData = {
    arabicText: document.getElementById('word-arabic-input').value.trim(),
    arabicWithoutDiacritics: document.getElementById('word-arabic-input').value.trim(),
    buckwalter: document.getElementById('word-buckwalter-input').value.trim() || null,
    englishMeaning: document.getElementById('word-english-input').value.trim(),
    
    root: {
      arabic: document.getElementById('word-root-input').value.trim() || null,
      transliteration: document.getElementById('word-root-transliteration-input').value.trim() || null
    },
    
    rank: parseInt(document.getElementById('word-rank-input').value) || null,
    occurrenceCount: parseInt(document.getElementById('word-occurrence-count-input').value) || 0,
    
    morphology: {
      partOfSpeech: document.getElementById('word-pos-input').value || null,
      posDescription: document.getElementById('word-pos-description-input').value.trim() || null,
      lemma: document.getElementById('word-lemma-input').value.trim() || null,
      form: document.getElementById('word-form-input').value || null,
      tense: document.getElementById('word-tense-input').value || null,
      gender: document.getElementById('word-gender-input').value || null,
      number: document.getElementById('word-number-input').value || null,
      grammaticalCase: document.getElementById('word-case-input').value || null,
      passive: document.getElementById('word-passive-input').value.toLowerCase() === 'yes' || 
               document.getElementById('word-passive-input').value.toLowerCase() === 'true',
      breakdown: document.getElementById('word-breakdown-input').value.trim() || null
    }
  };
  
  if (!wordData.arabicText || !wordData.englishMeaning) {
    showToast('Arabic and English are required', 'error');
    return;
  }
  
  try {
    await apiRequest(API.quranWord(wordId), {
      method: 'PUT',
      body: JSON.stringify(wordData)
    });
    
    showToast('Word updated successfully', 'success');
    closeWordModal();
    loadWords();
  } catch (error) {
    showToast(`Failed to save word: ${error.message}`, 'error');
  }
}

// ============================================
// Quran Statistics
// ============================================
async function loadQuranStats() {
  const container = document.getElementById('quran-stats-container');
  if (!container) return;
  
  try {
    const data = await apiRequest(API.quranStats());
    const stats = data.stats;
    
    container.innerHTML = `
      <div class="stats-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-top: 16px;">
        <div class="stat-card" style="background: var(--gray-100); padding: 16px; border-radius: 8px;">
          <div class="stat-value" style="font-size: 24px; font-weight: 700; color: var(--primary);">${stats.totalUniqueWords?.toLocaleString() || 0}</div>
          <div class="stat-label" style="color: var(--gray-600); font-size: 14px;">Unique Words</div>
        </div>
        <div class="stat-card" style="background: var(--gray-100); padding: 16px; border-radius: 8px;">
          <div class="stat-value" style="font-size: 24px; font-weight: 700; color: var(--primary);">${stats.totalTokens?.toLocaleString() || 0}</div>
          <div class="stat-label" style="color: var(--gray-600); font-size: 14px;">Total Tokens</div>
        </div>
        <div class="stat-card" style="background: var(--gray-100); padding: 16px; border-radius: 8px;">
          <div class="stat-value" style="font-size: 24px; font-weight: 700; color: var(--primary);">${stats.uniqueRoots?.toLocaleString() || 0}</div>
          <div class="stat-label" style="color: var(--gray-600); font-size: 14px;">Unique Roots</div>
        </div>
        <div class="stat-card" style="background: var(--gray-100); padding: 16px; border-radius: 8px;">
          <div class="stat-value" style="font-size: 24px; font-weight: 700; color: var(--primary);">${stats.wordsWithRoots?.toLocaleString() || 0}</div>
          <div class="stat-label" style="color: var(--gray-600); font-size: 14px;">Words with Roots</div>
        </div>
      </div>
      <div style="margin-top: 16px; color: var(--gray-600); font-size: 12px;">
        Generated: ${stats.generatedAt || 'N/A'} | Version: ${stats.version || 'N/A'}
      </div>
    `;
  } catch (error) {
    container.innerHTML = `<p style="color: var(--danger);">Error loading statistics: ${error.message}</p>`;
  }
}

// Make functions available globally for onclick handlers
window.switchView = switchView;
window.editStory = editStory;
window.promptDelete = promptDelete;
window.seedSampleStories = seedSampleStories;
window.downloadTemplate = downloadTemplate;
window.addMixedSegment = addMixedSegment;
window.addContentPart = addContentPart;
window.handleImport = handleImport;
window.normalizeStoryData = normalizeStoryData;
window.normalizeWords = normalizeWords;
window.viewWordDetails = viewWordDetails;
window.enableWordEdit = enableWordEdit;
window.saveWord = saveWord;

// Format switching for story form
function onFormatChange() {
  const formatSelect = document.getElementById('story-format');
  const formatDisplay = document.getElementById('current-format-display');
  const segmentsTitle = document.getElementById('segments-section-title');
  
  if (!formatSelect) return;
  
  const format = formatSelect.value; // 'mixed' or 'bilingual'
  
  // Update format display badge
  if (formatDisplay) {
    formatDisplay.className = 'format-display ' + format;
    formatDisplay.textContent = format === 'mixed' ? '🎯 Single' : '📖 Bilingual';
  }
  
  // Update section title
  if (segmentsTitle) {
    segmentsTitle.textContent = format === 'mixed' ? '📝 Single Format Segments' : '📝 Bilingual Segments';
  }
  
  // Show toast about format change
  if (window.event && window.event.type === 'change') {
    if (format === 'mixed') {
      showToast('🎯 Single format selected: Build story with English text + Arabic words', 'info');
    } else {
      showToast('📖 Bilingual format selected: Add Arabic text with English translation', 'info');
    }
  }
}

window.onFormatChange = onFormatChange;

// ============================================
// Audio Upload Tabs
// ============================================
function switchAudioTab(tab) {
  // Update tab buttons
  document.querySelectorAll('.audio-tab').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  
  // Show/hide panels
  document.getElementById('audio-url-panel').classList.toggle('hidden', tab !== 'url');
  document.getElementById('audio-upload-panel').classList.toggle('hidden', tab !== 'upload');
}

window.switchAudioTab = switchAudioTab;


