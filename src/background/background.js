// background.js - Chrome Extension Service Worker (Manifest V3)

// Constants
const STORAGE_KEYS = {
  API_KEYS: 'apiKeys',
  CONVERSATION_HISTORY: 'conversationHistory',
  RESPONSE_CACHE: 'responseCache',
  USER_PREFERENCES: 'userPreferences',
  CUSTOM_ACTIONS: 'customActions'
};

const DEFAULT_PREFERENCES = {
  defaultProvider: 'together',
  theme: 'light',
  autoTranslate: false,
  cacheResponses: true,
  maxHistoryItems: 100,
  keyboardShortcuts: true
};

// Error logging utility
const logError = (context, error) => {
  console.error(`[Helpi Error - ${context}]:`, error);
  return {
    success: false,
    error: error.message || 'Unknown error occurred',
    context
  };
};

// API Key Management for Multiple Providers
const handleApiKeyRequest = async (request, sender, sendResponse) => {
  try {
    if (request.action === "getApiKey") {
      const provider = request.provider || 'together';
      const result = await chrome.storage.local.get([STORAGE_KEYS.API_KEYS]);
      const apiKeys = result[STORAGE_KEYS.API_KEYS] || {};
      
      sendResponse({ 
        success: true,
        apiKey: apiKeys[provider] || null,
        provider 
      });
      return true;
    }
    
    if (request.action === "setApiKey") {
      const { provider, apiKey } = request;
      if (!provider || !apiKey) {
        sendResponse({ success: false, error: 'Provider and API key required' });
        return true;
      }
      
      const result = await chrome.storage.local.get([STORAGE_KEYS.API_KEYS]);
      const apiKeys = result[STORAGE_KEYS.API_KEYS] || {};
      apiKeys[provider] = apiKey;
      
      await chrome.storage.local.set({ [STORAGE_KEYS.API_KEYS]: apiKeys });
      sendResponse({ success: true, provider });
      return true;
    }
    
    if (request.action === "removeApiKey") {
      const { provider } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.API_KEYS]);
      const apiKeys = result[STORAGE_KEYS.API_KEYS] || {};
      delete apiKeys[provider];
      
      await chrome.storage.local.set({ [STORAGE_KEYS.API_KEYS]: apiKeys });
      sendResponse({ success: true, provider });
      return true;
    }
    
    sendResponse({ success: false, error: 'Unknown action' });
    return true;
  } catch (error) {
    sendResponse(logError('handleApiKeyRequest', error));
    return true;
  }
};

// Conversation History Management
const handleConversationHistory = async (request, sender, sendResponse) => {
  try {
    if (request.action === "saveConversation") {
      const { conversation } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.CONVERSATION_HISTORY]);
      const history = result[STORAGE_KEYS.CONVERSATION_HISTORY] || [];
      
      const prefs = await chrome.storage.local.get([STORAGE_KEYS.USER_PREFERENCES]);
      const maxItems = prefs[STORAGE_KEYS.USER_PREFERENCES]?.maxHistoryItems || 100;
      
      history.unshift({
        ...conversation,
        timestamp: Date.now(),
        id: `conv_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
      });
      
      // Keep only max items
      const trimmedHistory = history.slice(0, maxItems);
      await chrome.storage.local.set({ [STORAGE_KEYS.CONVERSATION_HISTORY]: trimmedHistory });
      
      sendResponse({ success: true, historyLength: trimmedHistory.length });
      return true;
    }
    
    if (request.action === "getConversationHistory") {
      const { limit = 50, offset = 0 } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.CONVERSATION_HISTORY]);
      const history = result[STORAGE_KEYS.CONVERSATION_HISTORY] || [];
      
      sendResponse({ 
        success: true, 
        history: history.slice(offset, offset + limit),
        total: history.length
      });
      return true;
    }
    
    if (request.action === "clearHistory") {
      await chrome.storage.local.set({ [STORAGE_KEYS.CONVERSATION_HISTORY]: [] });
      sendResponse({ success: true });
      return true;
    }
    
    sendResponse({ success: false, error: 'Unknown action' });
    return true;
  } catch (error) {
    sendResponse(logError('handleConversationHistory', error));
    return true;
  }
};

// Response Cache Management
const handleCacheRequest = async (request, sender, sendResponse) => {
  try {
    if (request.action === "getCachedResponse") {
      const { cacheKey } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.RESPONSE_CACHE]);
      const cache = result[STORAGE_KEYS.RESPONSE_CACHE] || {};
      
      const cached = cache[cacheKey];
      if (cached && Date.now() - cached.timestamp < 3600000) { // 1 hour TTL
        sendResponse({ success: true, response: cached.response, cached: true });
      } else {
        sendResponse({ success: true, cached: false });
      }
      return true;
    }
    
    if (request.action === "setCachedResponse") {
      const { cacheKey, response } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.RESPONSE_CACHE]);
      const cache = result[STORAGE_KEYS.RESPONSE_CACHE] || {};
      
      cache[cacheKey] = {
        response,
        timestamp: Date.now()
      };
      
      // Limit cache size
      const cacheKeys = Object.keys(cache);
      if (cacheKeys.length > 100) {
        const sortedKeys = cacheKeys.sort((a, b) => cache[a].timestamp - cache[b].timestamp);
        sortedKeys.slice(0, 50).forEach(key => delete cache[key]);
      }
      
      await chrome.storage.local.set({ [STORAGE_KEYS.RESPONSE_CACHE]: cache });
      sendResponse({ success: true });
      return true;
    }
    
    if (request.action === "clearCache") {
      await chrome.storage.local.set({ [STORAGE_KEYS.RESPONSE_CACHE]: {} });
      sendResponse({ success: true });
      return true;
    }
    
    sendResponse({ success: false, error: 'Unknown action' });
    return true;
  } catch (error) {
    sendResponse(logError('handleCacheRequest', error));
    return true;
  }
};

// User Preferences Management
const handlePreferencesRequest = async (request, sender, sendResponse) => {
  try {
    if (request.action === "getPreferences") {
      const result = await chrome.storage.local.get([STORAGE_KEYS.USER_PREFERENCES]);
      const preferences = result[STORAGE_KEYS.USER_PREFERENCES] || DEFAULT_PREFERENCES;
      sendResponse({ success: true, preferences });
      return true;
    }
    
    if (request.action === "updatePreferences") {
      const { preferences } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.USER_PREFERENCES]);
      const currentPrefs = result[STORAGE_KEYS.USER_PREFERENCES] || DEFAULT_PREFERENCES;
      
      const updatedPrefs = { ...currentPrefs, ...preferences };
      await chrome.storage.local.set({ [STORAGE_KEYS.USER_PREFERENCES]: updatedPrefs });
      
      sendResponse({ success: true, preferences: updatedPrefs });
      return true;
    }
    
    sendResponse({ success: false, error: 'Unknown action' });
    return true;
  } catch (error) {
    sendResponse(logError('handlePreferencesRequest', error));
    return true;
  }
};

// Custom Actions Management
const handleCustomActionsRequest = async (request, sender, sendResponse) => {
  try {
    if (request.action === "getCustomActions") {
      const result = await chrome.storage.local.get([STORAGE_KEYS.CUSTOM_ACTIONS]);
      const actions = result[STORAGE_KEYS.CUSTOM_ACTIONS] || [];
      sendResponse({ success: true, actions });
      return true;
    }
    
    if (request.action === "saveCustomAction") {
      const { action } = request;
      if (!action.name || !action.prompt) {
        sendResponse({ success: false, error: 'Action name and prompt required' });
        return true;
      }
      
      const result = await chrome.storage.local.get([STORAGE_KEYS.CUSTOM_ACTIONS]);
      const actions = result[STORAGE_KEYS.CUSTOM_ACTIONS] || [];
      
      const actionWithId = {
        ...action,
        id: action.id || `action_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        createdAt: action.createdAt || Date.now()
      };
      
      const existingIndex = actions.findIndex(a => a.id === actionWithId.id);
      if (existingIndex >= 0) {
        actions[existingIndex] = actionWithId;
      } else {
        actions.push(actionWithId);
      }
      
      await chrome.storage.local.set({ [STORAGE_KEYS.CUSTOM_ACTIONS]: actions });
      sendResponse({ success: true, action: actionWithId });
      return true;
    }
    
    if (request.action === "deleteCustomAction") {
      const { actionId } = request;
      const result = await chrome.storage.local.get([STORAGE_KEYS.CUSTOM_ACTIONS]);
      const actions = result[STORAGE_KEYS.CUSTOM_ACTIONS] || [];
      
      const filteredActions = actions.filter(a => a.id !== actionId);
      await chrome.storage.local.set({ [STORAGE_KEYS.CUSTOM_ACTIONS]: filteredActions });
      
      sendResponse({ success: true });
      return true;
    }
    
    sendResponse({ success: false, error: 'Unknown action' });
    return true;
  } catch (error) {
    sendResponse(logError('handleCustomActionsRequest', error));
    return true;
  }
};

// Main Message Router
const handleMessage = (request, sender, sendResponse) => {
  const { action } = request;
  
  if (!action) {
    sendResponse({ success: false, error: 'No action specified' });
    return false;
  }
  
  // Route to appropriate handler
  if (action.startsWith('getApiKey') || action.startsWith('setApiKey') || action.startsWith('removeApiKey')) {
    return handleApiKeyRequest(request, sender, sendResponse);
  }
  
  if (action.includes('Conversation') || action.includes('History')) {
    return handleConversationHistory(request, sender, sendResponse);
  }
  
  if (action.includes('Cache')) {
    return handleCacheRequest(request, sender, sendResponse);
  }
  
  if (action.includes('Preferences')) {
    return handlePreferencesRequest(request, sender, sendResponse);
  }
  
  if (action.includes('CustomAction')) {
    return handleCustomActionsRequest(request, sender, sendResponse);
  }
  
  // Legacy support
  if (action === 'getApiKey') {
    return handleApiKeyRequest(request, sender, sendResponse);
  }
  
  sendResponse({ success: false, error: 'Unknown action type' });
  return false;
};

// Event Listeners
chrome.runtime.onMessage.addListener(handleMessage);

// Error Handling for External Messages
chrome.runtime.onMessageExternal.addListener((request, sender, sendResponse) => {
  if (!sender.url?.startsWith('chrome-extension://')) {
    sendResponse({ success: false, error: 'External messages not allowed' });
    return false;
  }
});

// Initialize default preferences on install
chrome.runtime.onInstalled.addListener(async (details) => {
  try {
    if (details.reason === 'install') {
      await chrome.storage.local.set({
        [STORAGE_KEYS.USER_PREFERENCES]: DEFAULT_PREFERENCES,
        [STORAGE_KEYS.CONVERSATION_HISTORY]: [],
        [STORAGE_KEYS.RESPONSE_CACHE]: {},
        [STORAGE_KEYS.CUSTOM_ACTIONS]: []
      });
      console.log('Helpi installed successfully');
    } else if (details.reason === 'update') {
      console.log('Helpi updated successfully');
    }
  } catch (error) {
    console.error('Installation error:', error);
  }
});

// Service Worker Lifecycle Management
chrome.runtime.onSuspend.addListener(() => {
  console.log('Service worker suspending...');
});

// Keep service worker alive for critical operations
let keepAliveInterval;
const startKeepAlive = () => {
  if (keepAliveInterval) return;
  keepAliveInterval = setInterval(() => {
    chrome.runtime.getPlatformInfo(() => {
      // Just to keep alive
    });
  }, 20000); // Every 20 seconds
};

startKeepAlive();

// Keyboard Command Handlers
chrome.commands.onCommand.addListener((command) => {
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs[0]?.id) {
      chrome.tabs.sendMessage(tabs[0].id, {
        type: 'COMMAND',
        command: command
      }).catch(err => console.error('Command error:', err));
    }
  });
});