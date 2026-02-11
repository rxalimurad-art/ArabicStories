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
  words: () => `${CONFIG.apiBaseUrl}/api/words`,
  word: (id) => `${CONFIG.apiBaseUrl}/api/words/${id}`,
  wordCategories: () => `${CONFIG.apiBaseUrl}/api/words/categories/list`,
  bulkWords: () => `${CONFIG.apiBaseUrl}/api/words/bulk`
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
  wordsLimit: 20,
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
  
  // Bulk Words Import
  document.getElementById('import-words-btn')?.addEventListener('click', handleImportWords);
  document.getElementById('import-words-file')?.addEventListener('change', handleWordsFileSelect);
  document.getElementById('download-words-template-btn')?.addEventListener('click', downloadWordsTemplate);
  
  // Modal
  document.getElementById('cancel-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('confirm-delete')?.addEventListener('click', confirmDelete);
  
  // Pagination
  document.getElementById('prev-page')?.addEventListener('click', () => changePage(-1));
  document.getElementById('next-page')?.addEventListener('click', () => changePage(1));
  
  // Words view
  document.getElementById('refresh-words')?.addEventListener('click', loadWords);
  document.getElementById('add-word-main-btn')?.addEventListener('click', () => openWordModal());
  document.getElementById('word-search')?.addEventListener('input', debounce(filterWords, 300));
  document.getElementById('word-category-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-difficulty-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-prev-page')?.addEventListener('click', () => changeWordsPage(-1));
  document.getElementById('word-next-page')?.addEventListener('click', () => changeWordsPage(1));
  
  // Word modal
  document.getElementById('cancel-word')?.addEventListener('click', closeWordModal);
  document.getElementById('save-word')?.addEventListener('click', saveWord);
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
    
    <div class="content-parts-container"></div>
    
    <div class="segment-actions">
      <button type="button" class="btn btn-small btn-secondary add-text-part">+ Text</button>
      <button type="button" class="btn btn-small btn-secondary add-word-part">+ Arabic Word</button>
    </div>
  `;
  
  // Setup remove button
  card.querySelector('.remove-segment').addEventListener('click', () => removeSegment(index));
  
  // Setup add part buttons
  card.querySelector('.add-text-part').addEventListener('click', () => {
    addContentPartToCard(card, { type: 'text' });
  });
  
  card.querySelector('.add-word-part').addEventListener('click', () => {
    addContentPartToCard(card, { type: 'arabicWord' });
  });
  
  // Add existing content parts if data provided
  if (data?.contentParts?.length > 0) {
    data.contentParts.forEach(part => addContentPartToCard(card, part));
  }
  
  container.appendChild(card);
  state.segments.push({ id: card.dataset.segmentId, format: 'mixed' });
  
  document.getElementById('empty-segments')?.classList.add('hidden');
  card.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function addContentPartToCard(card, data = {}) {
  const container = card.querySelector('.content-parts-container');
  if (!container) return;
  
  const partDiv = document.createElement('div');
  partDiv.className = 'content-part';
  partDiv.dataset.type = data.type || 'text';
  partDiv.dataset.partId = data.id || generateId();
  
  if (data.type === 'arabicWord') {
    partDiv.innerHTML = `
      <div class="part-header">
        <div>
          <span class="part-label">🎯 Arabic Word</span>
          <span class="part-type-badge">Word</span>
        </div>
        <button type="button" class="remove-part">×</button>
      </div>
      <input type="text" class="part-text" placeholder="Arabic text (e.g., اللَّهُ)" value="${data.text || ''}">
      <input type="text" class="part-transliteration" placeholder="Transliteration (e.g., Allah)" value="${data.transliteration || ''}">
      <input type="text" class="part-word-id" placeholder="Word ID from General Words" value="${data.wordId || ''}">
    `;
  } else {
    partDiv.innerHTML = `
      <div class="part-header">
        <div>
          <span class="part-label">📝 Text</span>
          <span class="part-type-badge">Text</span>
        </div>
        <button type="button" class="remove-part">×</button>
      </div>
      <textarea class="part-text" rows="2" placeholder="English text...">${data.text || ''}</textarea>
    `;
  }
  
  // Setup remove button
  partDiv.querySelector('.remove-part').addEventListener('click', () => {
    partDiv.remove();
  });
  
  container.appendChild(partDiv);
}

// Keep old function for backward compatibility
function addContentPart(segmentIndex, type) {
  const cards = document.querySelectorAll('.segment-card.mixed-format');
  if (cards[segmentIndex]) {
    addContentPartToCard(cards[segmentIndex], { type });
  }
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
  
  // Fill data if provided
  if (data) {
    card.querySelector('.word-arabic').value = data.arabic || data.arabicText || '';
    card.querySelector('.word-english').value = data.english || data.englishMeaning || '';
    card.querySelector('.word-transliteration').value = data.transliteration || '';
    card.querySelector('.word-pos').value = data.partOfSpeech || '';
    card.querySelector('.word-root').value = data.rootLetters || '';
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
  
  const result = {
    id: document.getElementById('story-id').value || undefined,
    title: document.getElementById('story-title').value.trim(),
    titleArabic: document.getElementById('story-title-arabic').value.trim() || null,
    storyDescription: document.getElementById('story-desc').value.trim(),
    storyDescriptionArabic: document.getElementById('story-desc-arabic').value.trim() || null,
    author: document.getElementById('story-author').value.trim(),
    format: format,
    difficultyLevel: parseInt(document.getElementById('story-difficulty').value) || 1,
    category: document.getElementById('story-category').value,
    tags: document.getElementById('story-tags').value.split(',').map(t => t.trim()).filter(Boolean),
    coverImageURL: document.getElementById('story-cover').value.trim() || null
    // No audioNarrationURL - removed per requirements
    // No vocabulary words - using general words only
  };
  
  // Collect format-specific content
  if (format === 'mixed') {
    // Single/Mixed format: English text with embedded Arabic words
    result.mixedSegments = [];
    document.querySelectorAll('.segment-card[data-format="mixed"]').forEach((card, idx) => {
      const contentParts = [];
      card.querySelectorAll('.content-part').forEach((part) => {
        const type = part.dataset.type || 'text';
        const partData = {
          id: part.dataset.partId || undefined,
          type: type,
          text: part.querySelector('.part-text').value.trim()
        };
        
        if (type === 'arabicWord') {
          partData.wordId = part.querySelector('.part-word-id').value || null;
          partData.transliteration = part.querySelector('.part-transliteration').value.trim() || null;
        }
        
        if (partData.text) {
          contentParts.push(partData);
        }
      });
      
      if (contentParts.length > 0) {
        result.mixedSegments.push({
          id: card.dataset.segmentId || undefined,
          index: idx,
          contentParts: contentParts
          // No culturalNote - removed per requirements
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
    const result = await apiRequest(API.story(storyId));
    
    if (result.story) {
      populateForm(result.story);
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
 */
function normalizeWords(words) {
  if (!Array.isArray(words)) return [];
  
  return words.map(word => ({
    id: word.id || generateId(),
    arabic: word.arabic || word.arabicText || '',
    english: word.english || word.englishMeaning || word.translation || '',
    transliteration: word.transliteration || null,
    partOfSpeech: word.partOfSpeech || word.pos || null,
    rootLetters: word.rootLetters || word.root || null,
    difficulty: parseInt(word.difficulty) || 1,
    exampleSentence: word.exampleSentence || word.example || null
  })).filter(w => w.arabic && w.english);
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
          contentParts: [
            { type: "text", text: "Once upon a time, there was a young man who turned to " },
            { type: "arabicWord", text: "اللَّهُ", transliteration: "(Allah)", wordId: "word-1" },
            { type: "text", text: " for guidance." }
          ],
          culturalNote: "Allah is the Arabic word for God"
        }
      ],
      words: [
        {
          id: "word-1",
          arabic: "اللَّهُ",
          english: "God - The one and only God in Islam",
          transliteration: "Allah",
          partOfSpeech: "noun",
          difficulty: 1
        }
      ]
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
        author: "Hikaya Learning",
        format: "mixed",
        difficultyLevel: 1,
        category: "religious",
        tags: ["beginner", "vocabulary", "spiritual", "level1"],
        coverImageURL: "https://images.unsplash.com/photo-1519817914152-22d216bb9170?w=800",
        mixedSegments: [
          {
            contentParts: [
              { type: "text", text: "Once upon a time, there was a young man named Ahmad who wanted to find true peace. He turned to " },
              { type: "arabicWord", text: "اللَّهُ", transliteration: "(Allah)", wordId: "word-allah" },
              { type: "text", text: ", the Most Merciful." }
            ],
            culturalNote: "Allah is the Arabic word for God, used by Muslims and Arab Christians alike."
          },
          {
            contentParts: [
              { type: "text", text: "He opened the " },
              { type: "arabicWord", text: "الْكِتَابُ", transliteration: "(Al-Kitab)", wordId: "word-kitab" },
              { type: "text", text: " and learned that " },
              { type: "arabicWord", text: "السَّلَامُ", transliteration: "(As-Salaam)", wordId: "word-salaam" },
              { type: "text", text: " comes from submission to God." }
            ]
          }
        ],
        words: [
          { id: "word-allah", arabic: "اللَّهُ", english: "God", transliteration: "Allah", difficulty: 1 },
          { id: "word-kitab", arabic: "الْكِتَابُ", english: "The Book (Quran)", transliteration: "Al-Kitab", difficulty: 1 },
          { id: "word-salaam", arabic: "السَّلَامُ", english: "Peace", transliteration: "As-Salaam", difficulty: 1 }
        ]
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
// Words Management
// ============================================
async function loadWords() {
  const container = document.getElementById('words-list');
  container.innerHTML = '<div class="loading">Loading words...</div>';
  
  try {
    const category = document.getElementById('word-category-filter')?.value || '';
    const difficulty = document.getElementById('word-difficulty-filter')?.value || '';
    
    let url = `${API.words()}?limit=${state.wordsLimit}&offset=${(state.wordsPage - 1) * state.wordsLimit}`;
    if (category) url += `&category=${encodeURIComponent(category)}`;
    if (difficulty) url += `&difficulty=${encodeURIComponent(difficulty)}`;
    
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
      w.arabic?.toLowerCase().includes(searchQuery) ||
      w.english?.toLowerCase().includes(searchQuery) ||
      w.transliteration?.toLowerCase().includes(searchQuery)
    );
  }
  
  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>No words found. Create your first word!</p>
        <button onclick="openWordModal()" class="btn btn-primary" style="margin-top: 16px;">
          Add Word
        </button>
      </div>
    `;
    return;
  }
  
  container.innerHTML = filtered.map(word => `
    <div class="word-card-compact" data-id="${word.id}">
      <div class="word-card-header">
        <div class="word-arabic" dir="rtl">${escapeHtml(word.arabic)} ${word.audioPronunciationURL || word.audioURL ? '🔊' : ''}</div>
        <span class="word-badge difficulty-${word.difficulty || 1}">L${word.difficulty || 1}</span>
      </div>
      <div class="word-english">${escapeHtml(word.english)}</div>
      ${word.transliteration ? `<div class="word-transliteration">${escapeHtml(word.transliteration)}</div>` : ''}
      <div class="word-meta">
        ${word.partOfSpeech ? `<span class="word-badge pos">${word.partOfSpeech}</span>` : ''}
        <span class="word-badge">${word.category || 'general'}</span>
        <span class="word-badge" style="background: #e3f2fd; color: #1976d2;">ID: ${word.id?.substring(0, 8)}...</span>
      </div>
      ${word.exampleSentence ? `<div class="word-example" dir="rtl">💡 ${escapeHtml(word.exampleSentence)}</div>` : ''}
      <div class="word-actions">
        <button class="btn btn-small btn-secondary" onclick="editWord('${word.id}')">Edit</button>
        <button class="btn btn-small btn-danger" onclick="promptDeleteWord('${word.id}')">Delete</button>
      </div>
    </div>
  `).join('');
}

function filterWords() {
  renderWords(state.wordsList);
}

function changeWordsPage(delta) {
  state.wordsPage = Math.max(1, state.wordsPage + delta);
  document.getElementById('word-page-info').textContent = `Page ${state.wordsPage}`;
  loadWords();
}

function openWordModal(word = null) {
  const modal = document.getElementById('word-modal');
  const title = document.getElementById('word-modal-title');
  const form = document.getElementById('word-form');
  
  // Reset audio tabs to URL mode
  switchAudioTab('url');
  document.getElementById('word-audio-file').value = '';
  
  if (word) {
    title.textContent = '✏️ Edit Word';
    document.getElementById('word-id').value = word.id || '';
    document.getElementById('word-arabic-input').value = word.arabic || '';
    document.getElementById('word-english-input').value = word.english || '';
    document.getElementById('word-transliteration-input').value = word.transliteration || '';
    document.getElementById('word-pos-input').value = word.partOfSpeech || '';
    document.getElementById('word-root-input').value = word.rootLetters || '';
    document.getElementById('word-difficulty-input').value = word.difficulty || 1;
    document.getElementById('word-category-input').value = word.category || 'general';
    document.getElementById('word-example-input').value = word.exampleSentence || '';
    document.getElementById('word-example-translation-input').value = word.exampleSentenceTranslation || '';
    document.getElementById('word-audio-input').value = word.audioPronunciationURL || word.audioURL || '';
  } else {
    title.textContent = '➕ Add New Word';
    form.reset();
    document.getElementById('word-id').value = '';
    document.getElementById('word-difficulty-input').value = 1;
    document.getElementById('word-category-input').value = 'general';
  }
  
  modal.classList.remove('hidden');
}

function closeWordModal() {
  document.getElementById('word-modal').classList.add('hidden');
  document.getElementById('word-form').reset();
}

async function saveWord() {
  const wordId = document.getElementById('word-id').value;
  const audioFile = document.getElementById('word-audio-file').files[0];
  
  let audioURL = document.getElementById('word-audio-input').value.trim() || null;
  
  // If audio file is selected, upload it first
  if (audioFile) {
    try {
      showToast('Uploading audio file...', 'info');
      audioURL = await uploadAudioFile(audioFile);
    } catch (error) {
      showToast(`Failed to upload audio: ${error.message}`, 'error');
      return;
    }
  }
  
  const wordData = {
    id: wordId || undefined,
    arabic: document.getElementById('word-arabic-input').value.trim(),
    english: document.getElementById('word-english-input').value.trim(),
    transliteration: document.getElementById('word-transliteration-input').value.trim() || null,
    partOfSpeech: document.getElementById('word-pos-input').value || null,
    rootLetters: document.getElementById('word-root-input').value.trim() || null,
    difficulty: parseInt(document.getElementById('word-difficulty-input').value),
    category: document.getElementById('word-category-input').value,
    exampleSentence: document.getElementById('word-example-input').value.trim() || null,
    exampleSentenceTranslation: document.getElementById('word-example-translation-input').value.trim() || null,
    audioPronunciationURL: audioURL
  };
  
  if (!wordData.arabic || !wordData.english) {
    showToast('Arabic and English are required', 'error');
    return;
  }
  
  try {
    const isUpdate = !!wordId;
    const url = isUpdate ? API.word(wordId) : API.words();
    const method = isUpdate ? 'PUT' : 'POST';
    
    await apiRequest(url, {
      method,
      body: JSON.stringify(wordData)
    });
    
    showToast(isUpdate ? 'Word updated successfully' : 'Word created successfully', 'success');
    closeWordModal();
    loadWords();
  } catch (error) {
    showToast(`Failed to save word: ${error.message}`, 'error');
  }
}

async function uploadAudioFile(file) {
  // For now, we'll use a data URL approach for small files
  // In production, you might want to use Firebase Storage
  return new Promise((resolve, reject) => {
    // Check file size (max 5MB for data URLs)
    if (file.size > 5 * 1024 * 1024) {
      reject(new Error('Audio file too large. Max 5MB allowed.'));
      return;
    }
    
    const reader = new FileReader();
    reader.onload = (e) => {
      resolve(e.target.result);
    };
    reader.onerror = () => {
      reject(new Error('Failed to read audio file'));
    };
    reader.readAsDataURL(file);
  });
}

async function editWord(wordId) {
  try {
    const result = await apiRequest(API.word(wordId));
    
    if (result.word) {
      openWordModal(result.word);
    }
  } catch (error) {
    showToast(`Failed to load word: ${error.message}`, 'error');
  }
}

function promptDeleteWord(wordId) {
  state.wordToDelete = wordId;
  
  // Reuse the delete modal but update the message
  const modal = document.getElementById('delete-modal');
  modal.querySelector('h3').textContent = '⚠️ Confirm Delete Word';
  modal.querySelector('p').textContent = 'Are you sure you want to delete this word? This action cannot be undone.';
  
  // Update confirm button to call confirmDeleteWord
  const confirmBtn = document.getElementById('confirm-delete');
  confirmBtn.onclick = confirmDeleteWord;
  
  modal.classList.remove('hidden');
}

async function confirmDeleteWord() {
  if (!state.wordToDelete) return;
  
  try {
    await apiRequest(API.word(state.wordToDelete), {
      method: 'DELETE'
    });
    
    showToast('Word deleted successfully', 'success');
    closeDeleteModal();
    loadWords();
  } catch (error) {
    showToast(`Failed to delete: ${error.message}`, 'error');
  }
  
  // Reset the onclick handler back to story delete
  document.getElementById('confirm-delete').onclick = confirmDelete;
}

// Make functions available globally for onclick handlers
window.switchView = switchView;
window.editStory = editStory;
window.promptDelete = promptDelete;
window.seedSampleStories = seedSampleStories;
window.editWord = editWord;
window.openWordModal = openWordModal;
window.promptDeleteWord = promptDeleteWord;
window.downloadTemplate = downloadTemplate;
window.addMixedSegment = addMixedSegment;
window.addContentPart = addContentPart;
window.handleImport = handleImport;
window.normalizeStoryData = normalizeStoryData;
window.normalizeWords = normalizeWords;

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

// ============================================
// Bulk Words Import
// ============================================
function handleWordsFileSelect(e) {
  console.log('handleWordsFileSelect called');
  const file = e.target.files[0];
  if (!file) {
    console.log('No file selected');
    return;
  }
  
  console.log('File selected:', file.name);
  const reader = new FileReader();
  reader.onload = (event) => {
    const textarea = document.getElementById('import-words-json');
    if (textarea) {
      textarea.value = event.target.result;
      console.log('File loaded into textarea');
    }
  };
  reader.readAsText(file);
}
window.handleWordsFileSelect = handleWordsFileSelect;

async function handleImportWords() {
  console.log('handleImportWords called');
  const jsonTextarea = document.getElementById('import-words-json');
  if (!jsonTextarea) {
    console.error('import-words-json textarea not found');
    showToast('Error: Textarea not found', 'error');
    return;
  }
  
  const jsonText = jsonTextarea.value.trim();
  console.log('JSON text length:', jsonText.length);
  
  if (!jsonText) {
    showToast('Please paste JSON or select a file', 'error');
    return;
  }
  
  let words;
  try {
    words = JSON.parse(jsonText);
    if (!Array.isArray(words)) {
      showToast('JSON must be an array of words', 'error');
      return;
    }
  } catch (error) {
    showToast('Invalid JSON format', 'error');
    return;
  }
  
  // Show preview
  const preview = document.getElementById('import-words-preview');
  if (!preview) {
    console.error('import-words-preview element not found');
  } else {
    preview.classList.remove('hidden');
    preview.innerHTML = `<p>Importing ${words.length} words...</p>`;
  }
  
  // Normalize word data
  const normalizedWords = words.map(word => ({
    arabic: word.arabic || word['Arabic with Araab'] || word.arabicText || '',
    english: word.english || word.Meaning || word.englishMeaning || '',
    transliteration: word.transliteration || word.Transliteration || '',
    partOfSpeech: normalizePartOfSpeech(word.partOfSpeech || word.POS || ''),
    rootLetters: word.rootLetters || word['Root Letters'] || null,
    exampleSentence: word.exampleSentence || word['Example Usage (Arabic)'] || null,
    exampleSentenceTranslation: word.exampleSentenceTranslation || word['Example Translation'] || null,
    difficulty: parseInt(word.difficulty) || 1,
    category: word.category || 'general'
  }));
  
  // Validate required fields
  const invalidWords = normalizedWords.filter(w => !w.arabic || !w.english);
  if (invalidWords.length > 0) {
    showToast(`${invalidWords.length} words missing required fields (arabic/english)`, 'error');
    return;
  }
  
  // Import words one by one
  let successCount = 0;
  let errorCount = 0;
  const results = [];
  
  for (let i = 0; i < normalizedWords.length; i++) {
    const word = normalizedWords[i];
    try {
      await apiRequest(API.words(), {
        method: 'POST',
        body: JSON.stringify(word)
      });
      successCount++;
      results.push({ status: 'success', word: word.arabic });
    } catch (error) {
      errorCount++;
      results.push({ status: 'error', word: word.arabic, error: error.message });
    }
    
    // Update progress
    if (preview && (i % 5 === 0 || i === normalizedWords.length - 1)) {
      preview.innerHTML = `
        <p>Progress: ${i + 1}/${normalizedWords.length} words processed</p>
        <p style="color: var(--success);">✓ ${successCount} successful</p>
        ${errorCount > 0 ? `<p style="color: var(--danger);">✗ ${errorCount} failed</p>` : ''}
      `;
    }
  }
  
  // Show final results
  if (preview) {
    preview.innerHTML = `
      <div class="words-preview-list">
        ${results.map(r => `
          <div class="word-preview-item">
            <span class="word-preview-arabic" dir="rtl">${r.word}</span>
            <span class="word-preview-status ${r.status}">${r.status === 'success' ? '✓' : '✗'}</span>
          </div>
        `).join('')}
      </div>
      <p style="margin-top: 12px; text-align: center;">
        <strong style="color: var(--success);">${successCount} imported</strong>
        ${errorCount > 0 ? ` | <strong style="color: var(--danger);">${errorCount} failed</strong>` : ''}
      </p>
    `;
  }
  
  showToast(`Imported ${successCount} words successfully${errorCount > 0 ? `, ${errorCount} failed` : ''}`, errorCount > 0 ? 'warning' : 'success');
  loadWords();
}
window.handleImportWords = handleImportWords;

function normalizePartOfSpeech(pos) {
  if (!pos) return null;
  const posMap = {
    'noun': 'noun',
    'Noun': 'noun',
    'verb': 'verb',
    'Verb': 'verb',
    'adj.': 'adjective',
    'Adj.': 'adjective',
    'adjective': 'adjective',
    'Adjective': 'adjective',
    'adv.': 'adverb',
    'Adv.': 'adverb',
    'adverb': 'adverb',
    'Adverb': 'adverb',
    'prep.': 'preposition',
    'Prep.': 'preposition',
    'preposition': 'preposition',
    'pronoun': 'pronoun',
    'Pronoun': 'pronoun',
    'particle': 'particle',
    'Particle': 'particle',
    'conj.': 'conjunction',
    'Conj.': 'conjunction',
    'conjunction': 'conjunction',
    'interjection': 'interjection',
    'Interjection': 'interjection',
    'proper noun': 'noun',
    'Proper Noun': 'noun',
    'noun (pl.)': 'noun',
    'Noun (pl.)': 'noun',
    'noun/adj.': 'noun',
    'Noun/Adj.': 'noun'
  };
  return posMap[pos] || pos.toLowerCase();
}

function downloadWordsTemplate() {
  const template = [
    {
      "arabic": "\u0643\u062a\u0627\u0628",
      "transliteration": "kit\u0101b",
      "english": "book",
      "partOfSpeech": "noun",
      "rootLetters": "\u0643 \u062a \u0628",
      "exampleSentence": "\u0647\u0630\u0627 \u0643\u062a\u0627\u0628 \u062c\u0645\u064a\u0644",
      "exampleSentenceTranslation": "This is a beautiful book",
      "difficulty": 1,
      "category": "general"
    },
    {
      "arabic": "\u0642\u0644\u0645",
      "transliteration": "qalam",
      "english": "pen",
      "partOfSpeech": "noun",
      "rootLetters": "\u0642 \u0644 \u0645",
      "difficulty": 1,
      "category": "general"
    }
  ];
  
  const blob = new Blob([JSON.stringify(template, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'words-template.json';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

window.downloadWordsTemplate = downloadWordsTemplate;
