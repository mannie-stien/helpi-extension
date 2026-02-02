// Enhanced Popup with Multi-Provider Support
const PROVIDERS = {
  together: { name: 'Together.ai', placeholder: 'sk-...' },
  openai: { name: 'OpenAI', placeholder: 'sk-...' },
  anthropic: { name: 'Anthropic', placeholder: 'sk-ant-...' },
  google: { name: 'Google AI', placeholder: 'AIza...' }
};

let currentProvider = 'together';
let apiKeys = {};
let preferences = {};

document.addEventListener("DOMContentLoaded", async () => {
  // Initialize with legacy API key if exists
  const legacyKey = '7863bf715b5f025784c5f3d2c7614292ac511e30318455d61a7ad015eb895eae';
  
  try {
    // Migrate legacy key
    const legacyResult = await chrome.storage.local.get(['togetherApiKey']);
    if (legacyResult.togetherApiKey) {
      await chrome.runtime.sendMessage({
        action: 'setApiKey',
        provider: 'together',
        apiKey: legacyResult.togetherApiKey
      });
    } else {
      // Set default key if no legacy key exists
      await chrome.runtime.sendMessage({
        action: 'setApiKey',
        provider: 'together',
        apiKey: legacyKey
      });
    }
  } catch (error) {
    console.error('Migration error:', error);
  }

  await loadSettings();
  setupEventListeners();
});

async function loadSettings() {
  try {
    // Load API keys
    const keysResponse = await chrome.runtime.sendMessage({ action: 'getApiKey', provider: 'together' });
    if (keysResponse?.success) {
      apiKeys.together = keysResponse.apiKey;
    }

    // Load preferences
    const prefsResponse = await chrome.runtime.sendMessage({ action: 'getPreferences' });
    if (prefsResponse?.success) {
      preferences = prefsResponse.preferences;
      updateUIFromPreferences();
    }

    // Load assistant toggle state
    const result = await chrome.storage.local.get(['showAssistant']);
    const toggle = document.getElementById('toggleAssistant');
    if (toggle) {
      toggle.checked = result.showAssistant ?? true;
    }
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
}

function updateUIFromPreferences() {
  // Update provider selection if UI exists
  const providerSelect = document.getElementById('providerSelect');
  if (providerSelect) {
    providerSelect.value = preferences.defaultProvider || 'together';
  }

  // Update cache toggle if exists
  const cacheToggle = document.getElementById('cacheToggle');
  if (cacheToggle) {
    cacheToggle.checked = preferences.cacheResponses !== false;
  }
}

function setupEventListeners() {
  // Assistant toggle
  const toggle = document.getElementById('toggleAssistant');
  if (toggle) {
    toggle.addEventListener('change', async (e) => {
      const show = e.target.checked;
      await chrome.storage.local.set({ showAssistant: show });

      // Send to all tabs
      chrome.tabs.query({}, (tabs) => {
        tabs.forEach(tab => {
          if (tab?.id) {
            chrome.tabs.sendMessage(tab.id, { 
              type: 'TOGGLE_ASSISTANT', 
              show 
            }).catch(() => {});
          }
        });
      });
    });
  }

  // Provider selection
  const providerSelect = document.getElementById('providerSelect');
  if (providerSelect) {
    providerSelect.addEventListener('change', async (e) => {
      currentProvider = e.target.value;
      await updatePreference('defaultProvider', currentProvider);
    });
  }

  // Cache toggle
  const cacheToggle = document.getElementById('cacheToggle');
  if (cacheToggle) {
    cacheToggle.addEventListener('change', async (e) => {
      await updatePreference('cacheResponses', e.target.checked);
    });
  }

  // View history button
  const historyBtn = document.getElementById('viewHistoryBtn');
  if (historyBtn) {
    historyBtn.addEventListener('click', viewHistory);
  }

  // Clear cache button
  const clearCacheBtn = document.getElementById('clearCacheBtn');
  if (clearCacheBtn) {
    clearCacheBtn.addEventListener('click', clearCache);
  }

  // Clear history button
  const clearHistoryBtn = document.getElementById('clearHistoryBtn');
  if (clearHistoryBtn) {
    clearHistoryBtn.addEventListener('click', clearHistory);
  }
}

async function updatePreference(key, value) {
  try {
    preferences[key] = value;
    await chrome.runtime.sendMessage({
      action: 'updatePreferences',
      preferences: { [key]: value }
    });
  } catch (error) {
    console.error('Failed to update preference:', error);
  }
}

async function viewHistory() {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getConversationHistory',
      limit: 50
    });

    if (response?.success) {
      const history = response.history || [];
      alert(`You have ${history.length} conversations in history.\n\nUse the History button in the assistant tooltip to view details.`);
    }
  } catch (error) {
    console.error('Failed to view history:', error);
    alert('Failed to load history');
  }
}

async function clearCache() {
  if (!confirm('Clear all cached responses?')) return;
  
  try {
    await chrome.runtime.sendMessage({ action: 'clearCache' });
    alert('Cache cleared successfully');
  } catch (error) {
    console.error('Failed to clear cache:', error);
    alert('Failed to clear cache');
  }
}

async function clearHistory() {
  if (!confirm('Clear all conversation history? This cannot be undone.')) return;
  
  try {
    await chrome.runtime.sendMessage({ action: 'clearHistory' });
    alert('History cleared successfully');
  } catch (error) {
    console.error('Failed to clear history:', error);
    alert('Failed to clear history');
  }
}