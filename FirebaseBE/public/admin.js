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
  // Quran words endpoints
  quranWords: () => `${CONFIG.apiBaseUrl}/api/quran-words`,
  quranWord: (id) => `${CONFIG.apiBaseUrl}/api/quran-words/${id}`,
  quranWordSearch: (text) => `${CONFIG.apiBaseUrl}/api/quran-words/search/${encodeURIComponent(text)}`,
  quranWordAudio: (id) => `${CONFIG.apiBaseUrl}/api/quran-words/${id}/audio`
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
  wordCategories: [],
  // Debug state
  errorCount: 0,
  debugConsoleCollapsed: false
};

// ============================================
// Debug Console System
// ============================================
function addToDebugLog(type, message, details = null) {
  const timestamp = new Date().toLocaleTimeString();
  const logElement = document.getElementById('debug-log');
  const errorCountElement = document.getElementById('error-count');
  
  if (type === 'error') {
    state.errorCount++;
    errorCountElement.textContent = state.errorCount;
  }
  
  const typeColors = {
    info: '#00ff00',
    warn: '#ffff00', 
    error: '#ff4444',
    success: '#44ff44'
  };
  
  const typeIcons = {
    info: 'ℹ️',
    warn: '⚠️', 
    error: '❌',
    success: '✅'
  };
  
  let logEntry = `[${timestamp}] ${typeIcons[type]} ${message}`;
  if (details) {
    logEntry += `\n    Details: ${JSON.stringify(details, null, 2)}`;
  }
  
  const logLine = document.createElement('div');
  logLine.style.color = typeColors[type];
  logLine.style.marginBottom = '4px';
  logLine.textContent = logEntry;
  
  logElement.appendChild(logLine);
  logElement.scrollTop = logElement.scrollHeight;
}

function toggleDebugConsole() {
  const content = document.getElementById('debug-content');
  const toggle = document.getElementById('debug-toggle');
  
  state.debugConsoleCollapsed = !state.debugConsoleCollapsed;
  
  if (state.debugConsoleCollapsed) {
    content.style.display = 'none';
    toggle.textContent = '▲';
  } else {
    content.style.display = 'block';
    toggle.textContent = '▼';
  }
}

function clearDebugLog() {
  document.getElementById('debug-log').innerHTML = '';
  state.errorCount = 0;
  document.getElementById('error-count').textContent = '0';
  addToDebugLog('info', 'Debug log cleared');
}

function exportDebugLog() {
  const logContent = document.getElementById('debug-log').textContent;
  const blob = new Blob([logContent], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = `debug-log-${new Date().toISOString().split('T')[0]}.txt`;
  a.click();
  
  URL.revokeObjectURL(url);
  addToDebugLog('info', 'Debug log exported');
}

async function testApiConnection() {
  addToDebugLog('info', 'Testing API connection...');
  
  try {
    // Test 1: Basic health check
    const healthUrl = `${CONFIG.apiBaseUrl}/`;
    addToDebugLog('info', `Testing health endpoint: ${healthUrl}`);
    
    const healthResp = await fetch(healthUrl);
    const healthText = await healthResp.text();
    
    addToDebugLog('info', 'Health check response', {
      status: healthResp.status,
      statusText: healthResp.statusText,
      contentType: healthResp.headers.get('content-type'),
      response: healthText.substring(0, 200)
    });

    // Test 2: API endpoint
    if (healthResp.ok) {
      addToDebugLog('success', 'Health check passed, testing API endpoint...');
      
      const apiResp = await fetch(`${CONFIG.apiBaseUrl}/api/stories?limit=1`);
      const apiContentType = apiResp.headers.get('content-type');
      
      if (apiContentType && apiContentType.includes('application/json')) {
        const apiData = await apiResp.json();
        addToDebugLog('success', 'API endpoint working correctly', {
          status: apiResp.status,
          response: apiData
        });
        
        // Test 3: Audio upload route (GET test)
        addToDebugLog('info', 'Testing audio upload route...');
        const testWordId = 'test-word-id';
        const audioTestUrl = `${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio/test`;
        
        const audioTestResp = await fetch(audioTestUrl);
        if (audioTestResp.ok) {
          const audioTestData = await audioTestResp.json();
          addToDebugLog('success', 'Audio upload route is accessible', {
            response: audioTestData
          });
          
          // Test 4: POST to audio route (without file)
          const postTestResp = await fetch(`${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio/test`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ test: true })
          });
          
          if (postTestResp.ok) {
            const postTestData = await postTestResp.json();
            addToDebugLog('success', 'POST audio upload route is accessible', {
              response: postTestData
            });
            
            // Test 5: Simple audio route (no multer)
            const simpleTestResp = await fetch(`${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio/simple`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ test: 'simple upload test' })
            });
            
            if (simpleTestResp.ok) {
              const simpleTestData = await simpleTestResp.json();
              addToDebugLog('success', 'Simple audio route works (no multer)', {
                response: simpleTestData
              });
              
              // Test 6: Test actual multer route with fake FormData
              addToDebugLog('info', 'Testing multer route with FormData...');
              const formData = new FormData();
              formData.append('test', 'fake file test');
              
              const multerTestResp = await fetch(`${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio`, {
                method: 'POST',
                body: formData
              });
              
              const multerContentType = multerTestResp.headers.get('content-type');
              if (multerContentType && multerContentType.includes('application/json')) {
                const multerTestData = await multerTestResp.json();
                addToDebugLog('info', 'Multer route response (should show no file error)', {
                  status: multerTestResp.status,
                  response: multerTestData
                });
              } else {
                const multerText = await multerTestResp.text();
                addToDebugLog('error', 'Multer route returned HTML error (this is the problem!)', {
                  status: multerTestResp.status,
                  contentType: multerContentType,
                  response: multerText.substring(0, 300)
                });
              }
            } else {
              addToDebugLog('error', 'Simple audio route failed', {
                status: simpleTestResp.status
              });
            }
          } else {
            addToDebugLog('error', 'POST audio test failed', {
              status: postTestResp.status,
              statusText: postTestResp.statusText
            });
          }
        } else {
          addToDebugLog('error', 'Audio upload route test failed', {
            status: audioTestResp.status,
            statusText: audioTestResp.statusText
          });
        }
        
      } else {
        const apiText = await apiResp.text();
        addToDebugLog('error', 'API returned non-JSON response', {
          status: apiResp.status,
          contentType: apiContentType,
          response: apiText.substring(0, 200)
        });
      }
    }
  } catch (error) {
    addToDebugLog('error', 'API connection test failed', {
      error: error.message,
      stack: error.stack
    });
  }
}

async function testFileUpload() {
  addToDebugLog('info', 'Testing file upload with small test file...');
  
  try {
    // Create a small test file (Blob)
    const testContent = 'This is a test audio file content for debugging multer';
    const testBlob = new Blob([testContent], { type: 'audio/mpeg' });
    const testFile = new File([testBlob], 'test-audio.mp3', { type: 'audio/mpeg' });
    
    addToDebugLog('info', 'Created test file', {
      name: testFile.name,
      type: testFile.type,
      size: testFile.size
    });
    
    // Test with a known word ID (you might need to use a real word ID)
    const testWordId = 'bb5a2111-1b6f-4078-bc1f-5e8646ec9c36'; // Use your actual word ID
    
    const formData = new FormData();
    formData.append('audio', testFile);
    
    addToDebugLog('info', 'Sending test file upload...', {
      endpoint: `${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio`,
      formDataKeys: Array.from(formData.keys())
    });
    
    const resp = await fetch(`${CONFIG.apiBaseUrl}/api/quran-words/${testWordId}/audio`, {
      method: 'POST',
      body: formData
    });
    
    const contentType = resp.headers.get('content-type');
    
    if (contentType && contentType.includes('application/json')) {
      const data = await resp.json();
      if (resp.ok) {
        addToDebugLog('success', 'Test file upload succeeded!', {
          status: resp.status,
          response: data
        });
      } else {
        addToDebugLog('info', 'Test file upload failed with JSON error (expected)', {
          status: resp.status,
          error: data.error,
          details: data.details
        });
      }
    } else {
      const text = await resp.text();
      addToDebugLog('error', 'Test file upload returned HTML error', {
        status: resp.status,
        contentType,
        response: text.substring(0, 200)
      });
    }
    
  } catch (error) {
    addToDebugLog('error', 'Test file upload threw exception', {
      error: error.message,
      stack: error.stack
    });
  }
}

// Capture console errors
window.addEventListener('error', (event) => {
  addToDebugLog('error', `JavaScript Error: ${event.message}`, {
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
    stack: event.error?.stack
  });
});

// Capture unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
  addToDebugLog('error', `Unhandled Promise Rejection: ${event.reason}`, {
    reason: event.reason,
    promise: event.promise
  });
});

// ============================================
// Initialization
// ============================================
document.addEventListener('DOMContentLoaded', () => {
  initializeApp();
});

function initializeApp() {
  // Initialize debug console
  addToDebugLog('info', 'Arabic Stories Admin initialized');
  addToDebugLog('info', `API Base URL: ${CONFIG.apiBaseUrl || 'Same origin'}`);
  
  setupEventListeners();
  loadStories();
  
  // Prefetch word count
  fetchQuranWordsCount();
  
  // Load any saved draft
  const hasDraft = localStorage.getItem('storyDraft');
  if (hasDraft) {
    showToast('💡 You have a saved draft. Go to "New Story" to restore it.', 'info', 6000);
    addToDebugLog('info', 'Found saved draft in localStorage');
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
  
  // Word modal - create
  document.getElementById('add-word-btn')?.addEventListener('click', openCreateWordModal);
  document.getElementById('cancel-create-word')?.addEventListener('click', closeCreateWordModal);

  // Modal
  document.getElementById('cancel-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('confirm-delete')?.addEventListener('click', confirmDelete);
  
  // Pagination
  document.getElementById('prev-page')?.addEventListener('click', () => changePage(-1));
  document.getElementById('next-page')?.addEventListener('click', () => changePage(1));
  
  // Words view
  document.getElementById('refresh-words')?.addEventListener('click', () => {
    totalQuranWordsCount = 0;
    loadWords();
  });
  document.getElementById('export-words')?.addEventListener('click', exportAllWords);
  document.getElementById('word-search')?.addEventListener('input', debounce(filterWords, 300));
  document.getElementById('word-pos-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-form-filter')?.addEventListener('change', loadWords);
  document.getElementById('word-sort')?.addEventListener('change', loadWords);
  document.getElementById('word-limit')?.addEventListener('change', (e) => {
    const val = e.target.value;
    state.wordsLimit = val === 'all' ? 20000 : parseInt(val);
    state.wordsPage = 1;
    loadWords();
  });
  
  // Words pagination
  document.getElementById('word-first-page')?.addEventListener('click', () => goToWordsPage(1));
  document.getElementById('word-prev-page')?.addEventListener('click', () => changeWordsPage(-1));
  document.getElementById('word-next-page')?.addEventListener('click', () => changeWordsPage(1));
  document.getElementById('word-last-page')?.addEventListener('click', () => goToWordsPage(getMaxWordsPage()));
  document.getElementById('word-page-input')?.addEventListener('change', (e) => {
    const page = parseInt(e.target.value) || 1;
    goToWordsPage(page);
  });
  
  // Word modal
  document.getElementById('cancel-word')?.addEventListener('click', closeWordModal);
  
  // Cover image upload
  document.getElementById('story-cover-file')?.addEventListener('change', handleCoverImageUpload);
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
  
  // Log API request
  addToDebugLog('info', `API Request: ${options.method || 'GET'} ${url}`);
  
  try {
    const response = await fetch(url, { ...defaultOptions, ...options });
    const data = await response.json();
    
    if (!response.ok) {
      const errorMsg = data.error || `HTTP ${response.status}`;
      addToDebugLog('error', `API Error: ${errorMsg}`, {
        url,
        method: options.method || 'GET',
        status: response.status,
        response: data
      });
      throw new Error(errorMsg);
    }
    
    addToDebugLog('success', `API Success: ${options.method || 'GET'} ${url}`);
    return data;
  } catch (error) {
    if (error.name === 'TypeError' && error.message.includes('fetch')) {
      addToDebugLog('error', 'Network Error: Failed to connect to API', {
        url,
        error: error.message
      });
    } else if (!error.message.includes('HTTP')) {
      addToDebugLog('error', `API Request Failed: ${error.message}`, {
        url,
        error: error.message
      });
    }
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
    } else {
      updateWordsCountDisplay();
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
  
  container.innerHTML = stories.map(story => {
    // Use the Firestore document ID for edit/delete operations
    const docId = story.id;
    return `
    <div class="story-card" data-id="${docId}">
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
        <button class="btn btn-small btn-secondary" onclick="editStory('${docId}')">Edit</button>
        <button class="btn btn-small btn-danger" onclick="promptDelete('${docId}')">Delete</button>
      </div>
    </div>
  `}).join('');
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
    addToDebugLog('info', `Attempting to edit story: ${storyId}`);
    const result = await apiRequest(API.story(storyId));
    
    if (result.story) {
      addToDebugLog('success', 'Story loaded successfully', { 
        id: result.story.id, 
        title: result.story.title 
      });
      populateForm(result.story);
      
      // Verify ID was set
      const formId = document.getElementById('story-id').value;
      addToDebugLog('info', `Form ID after populate: ${formId}`);
      
      document.getElementById('form-title').textContent = '✏️ Edit Story';
      switchView('create');
    }
  } catch (error) {
    addToDebugLog('error', 'Failed to load story for editing', {
      storyId,
      error: error.message
    });
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
    addToDebugLog('info', `Attempting to delete story: ${state.storyToDelete}`);
    await apiRequest(API.story(state.storyToDelete), {
      method: 'DELETE'
    });
    
    addToDebugLog('success', 'Story deleted successfully', { storyId: state.storyToDelete });
    showToast('Story deleted successfully', 'success');
    closeDeleteModal();
    loadStories();
  } catch (error) {
    addToDebugLog('error', 'Failed to delete story', {
      storyId: state.storyToDelete,
      error: error.message
    });
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
let totalQuranWordsCount = 0;

async function fetchQuranWordsCount() {
  try {
    const data = await apiRequest(`${API.quranWords()}?limit=1`);
    totalQuranWordsCount = data.total || 0;
    updateWordsCountDisplay();
  } catch (error) {
    totalQuranWordsCount = 0;
  }
}

function updateWordsCountDisplay() {
  const countText = document.getElementById('words-count-text');
  const showingText = document.getElementById('words-showing-text');
  
  if (countText) {
    countText.textContent = `Total Quran Words: ${totalQuranWordsCount.toLocaleString()}`;
  }
  
  if (showingText && state.wordsList) {
    const limitSelect = document.getElementById('word-limit');
    const limitValue = limitSelect?.value || '100';
    const offset = (state.wordsPage - 1) * (limitValue === 'all' ? totalQuranWordsCount : parseInt(limitValue));
    const end = Math.min(offset + state.wordsList.length, totalQuranWordsCount);
    showingText.textContent = `Showing ${offset + 1}-${end} of ${totalQuranWordsCount.toLocaleString()}`;
  }
}

async function loadWords() {
  const container = document.getElementById('words-list');
  container.innerHTML = '<div class="loading">Loading Quran words...</div>';
  
  // Fetch total count if not already fetched
  if (totalQuranWordsCount === 0) {
    await fetchQuranWordsCount();
  }
  
  try {
    const pos = document.getElementById('word-pos-filter')?.value || '';
    const form = document.getElementById('word-form-filter')?.value || '';
    const sort = document.getElementById('word-sort')?.value || 'rank';
    const limitSelect = document.getElementById('word-limit')?.value || '100';
    const limit = limitSelect === 'all' ? 20000 : parseInt(limitSelect);
    
    if (limitSelect === 'all') {
      container.innerHTML = '<div class="loading">Loading all Quran words... This may take a moment.</div>';
    }
    
    let url = `${API.quranWords()}?limit=${limit}&offset=${(state.wordsPage - 1) * limit}&sort=${sort}`;
    if (pos) url += `&pos=${encodeURIComponent(pos)}`;
    if (form) url += `&form=${encodeURIComponent(form)}`;
    
    const data = await apiRequest(url);
    
    state.wordsList = data.words || [];
    
    // Update total count from API response if available
    if (data.total) {
      totalQuranWordsCount = data.total;
    }
    
    renderWords(state.wordsList);
    updateWordsCountDisplay();
    updateWordsPaginationUI();
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
      w.buckwalter?.toLowerCase().includes(searchQuery) ||
      w.root?.arabic?.toLowerCase().includes(searchQuery)
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
    const rootTrans = word.root?.transliteration || '';
    const rank = word.rank || 0;
    const count = word.occurrenceCount || 0;
    
    return `
    <div class="word-card-compact" data-id="${word.id}" style="position: relative; cursor: pointer; transition: all 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='none'">
      <div class="word-card-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; padding-right: 28px;">
        <div class="word-rank" style="font-size: 12px; color: var(--gray-500); font-weight: 600;">#${rank}</div>
        <div class="word-arabic" dir="rtl" style="font-size: 22px; font-weight: 600; color: var(--primary); flex: 1; text-align: center;" onclick="viewWordDetails('${word.id}')">${escapeHtml(arabicText)}</div>
        ${count > 0 ? `<div class="word-count" style="font-size: 11px; color: var(--success); font-weight: 600; white-space: nowrap;">${count}x</div>` : ''}
      </div>
      <div class="word-english" style="font-size: 14px; color: var(--gray-700); margin-bottom: 4px;" onclick="viewWordDetails('${word.id}')">${escapeHtml(englishMeaning)}</div>
      ${transliteration ? `<div class="word-transliteration" style="font-size: 12px; color: var(--gray-500); font-style: italic; margin-bottom: 8px;" onclick="viewWordDetails('${word.id}')">${escapeHtml(transliteration)}</div>` : ''}
      <div class="word-meta" style="display: flex; flex-wrap: wrap; gap: 4px; margin-top: 8px;" onclick="viewWordDetails('${word.id}')">
        ${pos ? `<span class="word-badge pos" title="Part of Speech" style="background: #e3f2fd; color: #1565c0; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">${pos}</span>` : ''}
        ${rootArabic ? `<span class="word-badge root" dir="rtl" title="Root: ${rootTrans}" style="background: #f3e5f5; color: #6a1b9a; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">${escapeHtml(rootArabic)}</span>` : ''}
        ${word.morphology?.form ? `<span class="word-badge form" title="Form" style="background: #e8f5e9; color: #2e7d32; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">Form ${word.morphology.form}</span>` : ''}
        ${word.morphology?.tense ? `<span class="word-badge tense" title="Tense" style="background: #fff3e0; color: #e65100; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">${word.morphology.tense}</span>` : ''}
      </div>
      ${word.morphology?.lemma ? `<div class="word-lemma" dir="rtl" style="font-size: 12px; color: var(--gray-600); margin-top: 6px; border-top: 1px solid var(--gray-200); padding-top: 6px;" onclick="viewWordDetails('${word.id}')">Lemma: ${escapeHtml(word.morphology.lemma)}</div>` : ''}
      <div class="word-actions" style="position: absolute; top: 8px; right: 8px; display: flex; gap: 4px; z-index: 10;">
        <button class="btn btn-icon btn-danger" onclick="event.stopPropagation(); promptDeleteWord('${word.id}', '${escapeHtml(arabicText)}')" title="Delete word" style="padding: 4px 6px; font-size: 12px; min-width: auto; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center;">✕</button>
      </div>
    </div>
  `}).join('');
}

function filterWords() {
  renderWords(state.wordsList);
}

function getMaxWordsPage() {
  const limitSelect = document.getElementById('word-limit')?.value || '100';
  if (limitSelect === 'all') return 1;
  const limit = parseInt(limitSelect);
  return Math.max(1, Math.ceil(totalQuranWordsCount / limit));
}

function goToWordsPage(page) {
  const limitSelect = document.getElementById('word-limit')?.value || '100';
  if (limitSelect === 'all') {
    showToast('Pagination is disabled when showing all words', 'info');
    return;
  }
  
  const maxPage = getMaxWordsPage();
  state.wordsPage = Math.max(1, Math.min(page, maxPage));
  updateWordsPaginationUI();
  loadWords();
}

function changeWordsPage(delta) {
  goToWordsPage(state.wordsPage + delta);
}

/**
 * Export all Quran words to JSON file
 */
async function exportAllWords() {
  const btn = document.getElementById('export-words');
  const originalText = btn.innerHTML;
  
  try {
    btn.innerHTML = '⏳ Exporting...';
    btn.disabled = true;
    
    // Fetch all words (maximum 20000)
    const url = `${API.quranWords()}?limit=20000&sort=rank`;
    showToast('Fetching all words from database...', 'info');
    
    const data = await apiRequest(url);
    const words = data.words || [];
    
    if (words.length === 0) {
      showToast('No words found to export', 'error');
      return;
    }
    
    // Create JSON blob
    const jsonStr = JSON.stringify(words, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    
    // Create download link
    const url_download = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url_download;
    
    // Generate filename with timestamp
    const timestamp = new Date().toISOString().split('T')[0];
    link.download = `quran_words_${timestamp}.json`;
    
    // Trigger download
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // Clean up
    URL.revokeObjectURL(url_download);
    
    showToast(`Successfully exported ${words.length.toLocaleString()} words`, 'success');
  } catch (error) {
    console.error('Export error:', error);
    showToast(`Export failed: ${error.message}`, 'error');
  } finally {
    btn.innerHTML = originalText;
    btn.disabled = false;
  }
}

function updateWordsPaginationUI() {
  const maxPage = getMaxWordsPage();
  const pageInput = document.getElementById('word-page-input');
  const pageOf = document.getElementById('word-page-of');
  
  if (pageInput) pageInput.value = state.wordsPage;
  if (pageOf) pageOf.textContent = `of ${maxPage}`;
  
  // Update button states
  const firstBtn = document.getElementById('word-first-page');
  const prevBtn = document.getElementById('word-prev-page');
  const nextBtn = document.getElementById('word-next-page');
  const lastBtn = document.getElementById('word-last-page');
  
  if (firstBtn) firstBtn.disabled = state.wordsPage <= 1;
  if (prevBtn) prevBtn.disabled = state.wordsPage <= 1;
  if (nextBtn) nextBtn.disabled = state.wordsPage >= maxPage;
  if (lastBtn) lastBtn.disabled = state.wordsPage >= maxPage;
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

    // Example sentences
    document.getElementById('word-example-arabic-input').value = word.exampleArabic || '';
    document.getElementById('word-example-english-input').value = word.exampleEnglish || '';

    // Tags & notes
    document.getElementById('word-tags-input').value = Array.isArray(word.tags) ? word.tags.join(', ') : (word.tags || '');
    document.getElementById('word-notes-input').value = word.notes || '';

    // Audio
    const audioPlayer = document.getElementById('word-audio-player');
    const audioStatus = document.getElementById('word-audio-status');
    const deleteAudioBtn = document.getElementById('delete-audio-btn');
    if (word.audioURL) {
      audioPlayer.src = word.audioURL;
      audioPlayer.style.display = 'block';
      audioStatus.style.display = 'none';
      if (deleteAudioBtn) deleteAudioBtn.style.display = 'inline-block';
    } else {
      audioPlayer.style.display = 'none';
      audioPlayer.src = '';
      audioStatus.style.display = 'inline';
      audioStatus.textContent = 'No audio';
      if (deleteAudioBtn) deleteAudioBtn.style.display = 'none';
    }
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
  const uploadArea = document.getElementById('word-audio-upload-area');
  if (uploadArea) uploadArea.style.display = 'block';
}

function closeWordModal() {
  document.getElementById('word-modal').classList.add('hidden');
  document.getElementById('word-form').reset();
  setWordFormReadonly(true);
  const uploadArea = document.getElementById('word-audio-upload-area');
  if (uploadArea) uploadArea.style.display = 'none';
}

async function saveWord() {
  const wordId = document.getElementById('word-id').value;
  const arabicText = document.getElementById('word-arabic-input').value.trim();
  const englishMeaning = document.getElementById('word-english-input').value.trim();

  if (!arabicText || !englishMeaning) {
    showToast('Arabic and English are required', 'error');
    return;
  }

  const tagsRaw = document.getElementById('word-tags-input').value.trim();
  const tags = tagsRaw ? tagsRaw.split(',').map(t => t.trim()).filter(Boolean) : [];

  const wordData = {
    arabicText,
    arabicWithoutDiacritics: arabicText,
    buckwalter: document.getElementById('word-buckwalter-input').value.trim() || null,
    englishMeaning,
    exampleArabic: document.getElementById('word-example-arabic-input').value.trim() || null,
    exampleEnglish: document.getElementById('word-example-english-input').value.trim() || null,
    root: {
      arabic: document.getElementById('word-root-input').value.trim() || null,
      transliteration: document.getElementById('word-root-transliteration-input').value.trim() || null,
      meaning: null
    },
    rank: parseInt(document.getElementById('word-rank-input').value) || null,
    occurrenceCount: parseInt(document.getElementById('word-occurrence-count-input').value) || 0,
    tags,
    notes: document.getElementById('word-notes-input').value.trim() || null,
    morphology: {
      partOfSpeech: document.getElementById('word-pos-input').value || null,
      posDescription: document.getElementById('word-pos-description-input').value.trim() || null,
      lemma: document.getElementById('word-lemma-input').value.trim() || null,
      form: document.getElementById('word-form-input').value || null,
      tense: document.getElementById('word-tense-input').value || null,
      gender: document.getElementById('word-gender-input').value || null,
      number: document.getElementById('word-number-input').value || null,
      grammaticalCase: document.getElementById('word-case-input').value || null,
      state: null,
      passive: document.getElementById('word-passive-input').value.toLowerCase() === 'yes' ||
               document.getElementById('word-passive-input').value.toLowerCase() === 'true',
      breakdown: document.getElementById('word-breakdown-input').value.trim() || null
    }
  };

  try {
    const btn = document.getElementById('save-word-btn');
    btn.disabled = true;
    btn.textContent = '⏳ Saving...';

    await apiRequest(API.quranWord(wordId), {
      method: 'PUT',
      body: JSON.stringify(wordData)
    });

    // Upload audio if a file was selected
    const audioFile = document.getElementById('word-audio-file')?.files?.[0];
    if (audioFile) {
      const formData = new FormData();
      formData.append('audio', audioFile);
      await fetch(API.quranWordAudio(wordId), { method: 'POST', body: formData });
    }

    showToast('Word updated successfully', 'success');
    closeWordModal();
    loadWords();
  } catch (error) {
    showToast(`Failed to save word: ${error.message}`, 'error');
  } finally {
    const btn = document.getElementById('save-word-btn');
    if (btn) { btn.disabled = false; btn.textContent = '💾 Save'; }
  }
}

// ============================================
// Create Word
// ============================================

function openCreateWordModal() {
  document.getElementById('create-word-form').reset();
  document.getElementById('create-word-modal').classList.remove('hidden');
}

function closeCreateWordModal() {
  document.getElementById('create-word-modal').classList.add('hidden');
  document.getElementById('create-word-form').reset();
}

async function createWord() {
  const arabicText = document.getElementById('cw-arabic').value.trim();
  const englishMeaning = document.getElementById('cw-english').value.trim();

  if (!arabicText || !englishMeaning) {
    showToast('Arabic text and English meaning are required', 'error');
    return;
  }

  const tagsRaw = document.getElementById('cw-tags').value.trim();
  const tags = tagsRaw ? tagsRaw.split(',').map(t => t.trim()).filter(Boolean) : [];

  const wordData = {
    arabicText,
    arabicWithoutDiacritics: document.getElementById('cw-arabic-plain').value.trim() || arabicText,
    buckwalter: document.getElementById('cw-buckwalter').value.trim() || null,
    englishMeaning,
    exampleArabic: document.getElementById('cw-example-arabic').value.trim() || null,
    exampleEnglish: document.getElementById('cw-example-english').value.trim() || null,
    root: {
      arabic: document.getElementById('cw-root-arabic').value.trim() || null,
      transliteration: document.getElementById('cw-root-trans').value.trim() || null,
      meaning: document.getElementById('cw-root-meaning').value.trim() || null
    },
    morphology: {
      partOfSpeech: document.getElementById('cw-pos').value || null,
      posDescription: document.getElementById('cw-pos-description').value.trim() || null,
      lemma: document.getElementById('cw-lemma').value.trim() || null,
      form: document.getElementById('cw-form').value || null,
      tense: document.getElementById('cw-tense').value || null,
      gender: document.getElementById('cw-gender').value || null,
      number: document.getElementById('cw-number').value || null,
      grammaticalCase: document.getElementById('cw-case').value || null,
      state: document.getElementById('cw-state').value || null,
      passive: document.getElementById('cw-passive').value === 'true',
      breakdown: document.getElementById('cw-breakdown').value.trim() || null
    },
    rank: parseInt(document.getElementById('cw-rank').value) || null,
    occurrenceCount: parseInt(document.getElementById('cw-occurrence').value) || 0,
    tags,
    notes: document.getElementById('cw-notes').value.trim() || null
  };

  const btn = document.getElementById('submit-create-word');
  btn.disabled = true;
  btn.textContent = '⏳ Creating...';

  try {
    const result = await apiRequest(API.quranWords(), {
      method: 'POST',
      body: JSON.stringify(wordData)
    });

    const wordId = result.word?.id;

    // Upload audio if selected
    const audioFile = document.getElementById('cw-audio')?.files?.[0];
    if (audioFile && wordId) {
      try {
        const formData = new FormData();
        formData.append('audio', audioFile);
        await fetch(API.quranWordAudio(wordId), { method: 'POST', body: formData });
      } catch (audioError) {
        showToast('Word created but audio upload failed', 'warning');
      }
    }

    showToast(`Word "${arabicText}" created successfully`, 'success');
    closeCreateWordModal();
    totalQuranWordsCount = 0;
    loadWords();
  } catch (error) {
    showToast(`Failed to create word: ${error.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = '➕ Create Word';
  }
}

async function uploadWordAudio() {
  const wordId = document.getElementById('word-id').value;
  const audioFile = document.getElementById('word-audio-file')?.files?.[0];

  addToDebugLog('info', `Starting DIRECT audio upload for word: ${wordId}`);

  if (!wordId || wordId.trim() === '') {
    addToDebugLog('error', 'No word ID found - word modal may not be properly loaded');
    showToast('Error: No word ID found. Please close and reopen the word.', 'error');
    return;
  }

  if (!audioFile) {
    addToDebugLog('error', 'No audio file selected');
    showToast('Please select an audio file', 'error');
    return;
  }

  // Client-side validation
  const allowedTypes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg'];
  const allowedExtensions = ['.mp3', '.wav', '.ogg'];
  const fileName = audioFile.name.toLowerCase();
  
  addToDebugLog('info', 'Audio file details', {
    name: audioFile.name,
    type: audioFile.type,
    size: audioFile.size,
    sizeFormatted: `${(audioFile.size / 1024 / 1024).toFixed(2)} MB`,
    lastModified: audioFile.lastModified,
    webkitRelativePath: audioFile.webkitRelativePath || 'none'
  });
  
  // Additional validation for the File object
  if (audioFile.size === 0) {
    addToDebugLog('error', 'Selected file has zero size');
    showToast('Selected file appears to be empty', 'error');
    return;
  }
  
  if (!allowedTypes.includes(audioFile.type) && !allowedExtensions.some(ext => fileName.endsWith(ext))) {
    addToDebugLog('error', `Invalid file type: ${audioFile.type}`, { fileName });
    showToast('Please select a valid audio file (MP3, WAV, or OGG)', 'error');
    return;
  }

  if (audioFile.size > 20 * 1024 * 1024) { // 20MB limit
    addToDebugLog('error', `File too large: ${audioFile.size} bytes (max 20MB)`);
    showToast('File size must be less than 20MB', 'error');
    return;
  }

  const btn = document.getElementById('upload-audio-btn');
  btn.disabled = true;
  btn.textContent = '⏳ Uploading...';

  try {
    // First check if the word exists
    addToDebugLog('info', 'Checking if word exists before upload...');
    try {
      const wordCheck = await apiRequest(API.quranWord(wordId));
      if (!wordCheck.word) {
        throw new Error('Word not found');
      }
      addToDebugLog('success', 'Word exists, proceeding with direct upload', {
        wordId: wordId,
        arabicText: wordCheck.word.arabicText
      });
    } catch (checkError) {
      addToDebugLog('error', 'Word validation failed', {
        error: checkError.message,
        wordId: wordId
      });
      throw new Error(`Cannot upload audio: ${checkError.message}`);
    }

    // MULTIPART UPLOAD APPROACH - Using FormData (more reliable with Firebase Functions)
    addToDebugLog('info', 'Using multipart upload approach (FormData)', {
      endpoint: API.quranWordAudio(wordId),
      fileName: audioFile.name,
      contentType: audioFile.type
    });
    
    // Create FormData for multipart upload
    addToDebugLog('info', 'Creating FormData...');
    const formData = new FormData();
    formData.append('audio', audioFile, audioFile.name);
    
    addToDebugLog('success', 'FormData created', {
      fileName: audioFile.name,
      fileSize: audioFile.size,
      fileType: audioFile.type
    });
    
    const resp = await fetch(API.quranWordAudio(wordId), {
      method: 'POST',
      // Do NOT set Content-Type header - browser will set it with boundary for FormData
      body: formData
    });
    
    addToDebugLog('info', 'Multipart upload response received', {
      status: resp.status,
      ok: resp.ok,
      statusText: resp.statusText,
      contentType: resp.headers.get('content-type')
    });

    // Check if response is JSON before parsing
    const contentType = resp.headers.get('content-type');
    let data;
    if (contentType && contentType.includes('application/json')) {
      data = await resp.json();
    } else {
      // If not JSON, get text to see what we actually received
      const text = await resp.text();
      addToDebugLog('error', 'Server returned non-JSON response', {
        contentType,
        responseText: text.substring(0, 500) + (text.length > 500 ? '...' : '')
      });
      throw new Error(`Server returned ${contentType || 'non-JSON'} response: ${text.substring(0, 100)}...`);
    }
    
    addToDebugLog('info', 'Server response parsed', {
      response: data
    });

    if (!resp.ok) {
      throw new Error(data.error || `Upload failed with status ${resp.status}`);
    }

    const audioPlayer = document.getElementById('word-audio-player');
    audioPlayer.src = data.audioURL;
    audioPlayer.style.display = 'block';
    document.getElementById('word-audio-status').style.display = 'none';
    document.getElementById('delete-audio-btn').style.display = 'inline-block';

    addToDebugLog('success', 'Multipart audio upload completed successfully', { audioURL: data.audioURL });
    showToast(data.message || 'Audio uploaded successfully', 'success');
    
    // Clear the file input
    document.getElementById('word-audio-file').value = '';
  } catch (error) {
    addToDebugLog('error', 'Multipart audio upload failed', {
      error: error.message,
      stack: error.stack
    });
    console.error('Audio upload error:', error);
    showToast(`Audio upload failed: ${error.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = '⬆️ Upload Audio';
  }
}

async function deleteWordAudio() {
  const wordId = document.getElementById('word-id').value;
  if (!confirm('Remove audio pronunciation for this word?')) return;

  try {
    await apiRequest(API.quranWordAudio(wordId), { method: 'DELETE' });

    const audioPlayer = document.getElementById('word-audio-player');
    audioPlayer.style.display = 'none';
    audioPlayer.src = '';
    document.getElementById('word-audio-status').style.display = 'inline';
    document.getElementById('word-audio-status').textContent = 'No audio';
    document.getElementById('delete-audio-btn').style.display = 'none';

    showToast('Audio removed', 'success');
  } catch (error) {
    showToast(`Failed to remove audio: ${error.message}`, 'error');
  }
}

// ============================================
// Cover Image Upload
// ============================================

async function handleCoverImageUpload(event) {
  const file = event.target.files[0];
  if (!file) return;
  
  // Validate file type
  if (!file.type.startsWith('image/')) {
    showToast('Please select an image file', 'error');
    return;
  }
  
  // Validate file size (max 5MB)
  if (file.size > 5 * 1024 * 1024) {
    showToast('Image must be less than 5MB', 'error');
    return;
  }
  
  const statusEl = document.getElementById('story-cover-upload-status');
  const filenameEl = document.getElementById('story-cover-filename');
  const urlInput = document.getElementById('story-cover');
  
  statusEl.style.display = 'inline';
  statusEl.textContent = '⏳ Uploading...';
  filenameEl.textContent = file.name;
  
  try {
    // Create FormData for multipart upload
    const formData = new FormData();
    formData.append('image', file, file.name);
    
    const resp = await fetch(`${CONFIG.apiBaseUrl}/api/upload/image`, {
      method: 'POST',
      body: formData
    });
    
    if (!resp.ok) {
      const errorData = await resp.json().catch(() => ({}));
      throw new Error(errorData.error || `Upload failed: ${resp.status}`);
    }
    
    const data = await resp.json();
    
    if (data.success && data.imageURL) {
      urlInput.value = data.imageURL;
      statusEl.textContent = '✅ Uploaded!';
      statusEl.style.color = 'green';
      showToast('Image uploaded successfully', 'success');
      
      // Clear status after 3 seconds
      setTimeout(() => {
        statusEl.style.display = 'none';
        statusEl.style.color = '';
      }, 3000);
    } else {
      throw new Error('No image URL returned');
    }
  } catch (error) {
    console.error('Cover image upload error:', error);
    statusEl.textContent = '❌ Failed';
    statusEl.style.color = 'red';
    showToast(`Upload failed: ${error.message}`, 'error');
  }
}

// ============================================
// Delete Word Functions
// ============================================

function promptDeleteWord(wordId, arabicText) {
  state.wordToDelete = wordId;
  const modal = document.getElementById('delete-modal');
  modal.querySelector('h3').textContent = '⚠️ Delete Word';
  modal.querySelector('p').textContent = `Are you sure you want to delete the word "${arabicText}"? This action cannot be undone.`;
  modal.classList.remove('hidden');
  
  // Update the confirm button to call word delete
  document.getElementById('confirm-delete').onclick = confirmDeleteWord;
}

async function confirmDeleteWord() {
  if (!state.wordToDelete) return;
  
  try {
    await apiRequest(API.quranWord(state.wordToDelete), {
      method: 'DELETE'
    });
    
    showToast('Word deleted successfully', 'success');
    closeDeleteModal();
    totalQuranWordsCount = 0; // Reset count to trigger refetch
    loadWords(); // Reload the words list
  } catch (error) {
    showToast(`Failed to delete word: ${error.message}`, 'error');
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
window.createWord = createWord;
window.openCreateWordModal = openCreateWordModal;
window.closeCreateWordModal = closeCreateWordModal;
window.uploadWordAudio = uploadWordAudio;
window.deleteWordAudio = deleteWordAudio;
window.goToWordsPage = goToWordsPage;
window.promptDeleteWord = promptDeleteWord;
window.confirmDeleteWord = confirmDeleteWord;
window.toggleDebugConsole = toggleDebugConsole;
window.clearDebugLog = clearDebugLog;
window.exportDebugLog = exportDebugLog;
window.testApiConnection = testApiConnection;
window.testFileUpload = testFileUpload;

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


