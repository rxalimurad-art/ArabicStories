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
  seed: () => `${CONFIG.apiBaseUrl}/api/seed`
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
  limit: 20
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
  
  // Story form actions
  document.getElementById('add-segment-btn')?.addEventListener('click', () => addSegment());
  document.getElementById('add-word-btn')?.addEventListener('click', () => addWord());
  document.getElementById('validate-btn')?.addEventListener('click', validateCurrentStory);
  document.getElementById('publish-btn')?.addEventListener('click', publishStory);
  document.getElementById('save-draft-btn')?.addEventListener('click', saveDraft);
  
  // Stories list actions
  document.getElementById('refresh-stories')?.addEventListener('click', loadStories);
  document.getElementById('story-search')?.addEventListener('input', debounce(filterStories, 300));
  
  // Import/Export
  document.getElementById('import-btn')?.addEventListener('click', handleImport);
  document.getElementById('import-file')?.addEventListener('change', handleFileSelect);
  document.getElementById('export-all-btn')?.addEventListener('click', exportAllStories);
  document.getElementById('export-template-btn')?.addEventListener('click', downloadTemplate);
  
  // Modal
  document.getElementById('cancel-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('confirm-delete')?.addEventListener('click', confirmDelete);
  
  // Pagination
  document.getElementById('prev-page')?.addEventListener('click', () => changePage(-1));
  document.getElementById('next-page')?.addEventListener('click', () => changePage(1));
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
  }
}

// ============================================
// Stories Management
// ============================================
async function loadStories() {
  const container = document.getElementById('stories-list');
  container.innerHTML = '<div class="loading">Loading stories...</div>';
  
  try {
    const data = await apiRequest(`${API.stories()}?limit=${state.limit}&offset=${(state.page - 1) * state.limit}`);
    
    state.stories = data.stories || [];
    renderStories(state.stories);
  } catch (error) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1;">
        <p>Error loading stories: ${error.message}</p>
        <button onclick="seedSampleStories()" class="btn btn-primary" style="margin-top: 16px;">
          🌱 Seed Sample Stories
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
            Level ${story.difficultyLevel}
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
function addSegment(data = null) {
  const index = state.segments.length;
  const container = document.getElementById('segments-container');
  const template = document.getElementById('segment-template');
  
  const clone = template.content.cloneNode(true);
  const card = clone.querySelector('.segment-card');
  
  card.dataset.index = index;
  card.querySelector('.segment-number').textContent = `Segment ${index + 1}`;
  
  // Setup remove button
  card.querySelector('.remove-segment').addEventListener('click', () => removeSegment(index));
  
  // Fill data if provided
  if (data) {
    card.querySelector('.segment-arabic').value = data.arabicText || '';
    card.querySelector('.segment-english').value = data.englishText || '';
    card.querySelector('.segment-transliteration').value = data.transliteration || '';
    card.querySelector('.segment-audio-start').value = data.audioStartTime || '';
    card.querySelector('.segment-audio-end').value = data.audioEndTime || '';
  }
  
  container.appendChild(card);
  state.segments.push({ id: generateId() });
  
  document.getElementById('empty-segments')?.classList.add('hidden');
  
  // Scroll to new segment
  card.scrollIntoView({ behavior: 'smooth', block: 'center' });
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
  
  card.dataset.index = index;
  card.querySelector('.word-number').textContent = `Word ${index + 1}`;
  
  // Setup remove button
  card.querySelector('.remove-word').addEventListener('click', () => removeWord(index));
  
  // Fill data if provided
  if (data) {
    card.querySelector('.word-arabic').value = data.arabic || '';
    card.querySelector('.word-english').value = data.english || '';
    card.querySelector('.word-transliteration').value = data.transliteration || '';
    card.querySelector('.word-pos').value = data.partOfSpeech || '';
    card.querySelector('.word-root').value = data.rootLetters || '';
    card.querySelector('.word-example').value = data.exampleSentence || '';
  }
  
  container.appendChild(card);
  state.words.push({ id: generateId() });
  
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
  const segments = [];
  document.querySelectorAll('.segment-card').forEach((card, idx) => {
    segments.push({
      index: idx,
      arabicText: card.querySelector('.segment-arabic').value.trim(),
      englishText: card.querySelector('.segment-english').value.trim(),
      transliteration: card.querySelector('.segment-transliteration').value.trim() || null,
      audioStartTime: parseFloat(card.querySelector('.segment-audio-start').value) || null,
      audioEndTime: parseFloat(card.querySelector('.segment-audio-end').value) || null
    });
  });
  
  const words = [];
  document.querySelectorAll('.word-card').forEach(card => {
    words.push({
      arabic: card.querySelector('.word-arabic').value.trim(),
      english: card.querySelector('.word-english').value.trim(),
      transliteration: card.querySelector('.word-transliteration').value.trim() || null,
      partOfSpeech: card.querySelector('.word-pos').value || null,
      rootLetters: card.querySelector('.word-root').value.trim() || null,
      exampleSentence: card.querySelector('.word-example').value.trim() || null
    });
  });
  
  return {
    id: document.getElementById('story-id').value || undefined,
    title: document.getElementById('story-title').value.trim(),
    titleArabic: document.getElementById('story-title-arabic').value.trim() || null,
    storyDescription: document.getElementById('story-desc').value.trim(),
    storyDescriptionArabic: document.getElementById('story-desc-arabic').value.trim() || null,
    author: document.getElementById('story-author').value.trim(),
    difficultyLevel: parseInt(document.getElementById('story-difficulty').value),
    category: document.getElementById('story-category').value,
    tags: document.getElementById('story-tags').value.split(',').map(t => t.trim()).filter(Boolean),
    coverImageURL: document.getElementById('story-cover').value.trim() || null,
    audioNarrationURL: document.getElementById('story-audio').value.trim() || null,
    segments,
    words: words.filter(w => w.arabic && w.english)
  };
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
  document.getElementById('words-container').innerHTML = '';
  state.segments = [];
  state.words = [];
  
  document.getElementById('empty-segments')?.classList.remove('hidden');
  document.getElementById('empty-words')?.classList.remove('hidden');
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
  document.getElementById('story-tags').value = (data.tags || []).join(', ');
  document.getElementById('story-cover').value = data.coverImageURL || '';
  document.getElementById('story-audio').value = data.audioNarrationURL || '';
  
  // Clear and repopulate segments
  document.getElementById('segments-container').innerHTML = '';
  state.segments = [];
  
  if (data.segments?.length > 0) {
    data.segments.forEach(seg => addSegment(seg));
  } else {
    addSegment();
  }
  
  // Clear and repopulate words
  document.getElementById('words-container').innerHTML = '';
  state.words = [];
  
  if (data.words?.length > 0) {
    data.words.forEach(word => addWord(word));
  }
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
  document.getElementById('delete-modal').classList.add('hidden');
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
    const stories = Array.isArray(data) ? data : [data];
    
    let successCount = 0;
    
    for (const story of stories) {
      try {
        await apiRequest(API.stories(), {
          method: 'POST',
          body: JSON.stringify(story)
        });
        successCount++;
      } catch (error) {
        console.error('Failed to import story:', story.title, error);
      }
    }
    
    showToast(`Imported ${successCount}/${stories.length} stories`, 
      successCount === stories.length ? 'success' : 'warning');
    
    switchView('stories');
    loadStories();
  } catch (error) {
    showToast(`Import failed: ${error.message}`, 'error');
  }
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

function downloadTemplate() {
  const template = {
    title: "Story Title",
    titleArabic: "عنوان القصة",
    storyDescription: "Brief description of the story",
    storyDescriptionArabic: "وصف موجز للقصة",
    author: "Author Name",
    difficultyLevel: 1,
    category: "children",
    tags: ["tag1", "tag2"],
    coverImageURL: "https://example.com/image.jpg",
    segments: [
      {
        arabicText: "النص العربي",
        englishText: "English translation",
        transliteration: "Transliteration"
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
  
  const blob = new Blob([JSON.stringify(template, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = 'story-template.json';
  a.click();
  
  URL.revokeObjectURL(url);
}

async function seedSampleStories() {
  try {
    const result = await apiRequest(API.seed(), {
      method: 'POST'
    });
    
    showToast(result.message, 'success');
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

// Make functions available globally for onclick handlers
window.switchView = switchView;
window.editStory = editStory;
window.promptDelete = promptDelete;
window.seedSampleStories = seedSampleStories;
