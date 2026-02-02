/**
 * Enhanced Multi-Provider API Client for Helpi
 * Supports multiple AI providers with retry logic, caching, and error handling
 */

import { getProviderConfig, API_PROVIDERS } from './apiProviders.js';

const MAX_RETRIES = 3;
const RETRY_DELAY = 1000; // ms
const REQUEST_TIMEOUT = 30000; // 30 seconds

/**
 * Sleep utility for retry delays
 */
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Generate cache key from prompt and options
 */
function generateCacheKey(prompt, provider, model) {
  const normalized = prompt.trim().toLowerCase().substring(0, 100);
  return `cache_${provider}_${model}_${btoa(normalized).substring(0, 50)}`;
}

/**
 * Get API key for provider from storage
 */
async function getApiKey(provider) {
  try {
    // Try new multi-provider storage first
    const response = await chrome.runtime.sendMessage({
      action: 'getApiKey',
      provider
    });
    
    if (response?.success && response.apiKey) {
      return response.apiKey;
    }
    
    // Fallback to legacy storage for Together.ai
    if (provider === API_PROVIDERS.TOGETHER) {
      const result = await chrome.storage.local.get(['togetherApiKey']);
      if (result.togetherApiKey) {
        return result.togetherApiKey;
      }
    }
    
    return null;
  } catch (error) {
    console.error('Error getting API key:', error);
    return null;
  }
}

/**
 * Get user preferences
 */
async function getPreferences() {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getPreferences'
    });
    return response?.success ? response.preferences : {};
  } catch (error) {
    console.error('Error getting preferences:', error);
    return {};
  }
}

/**
 * Check cache for response
 */
async function getCachedResponse(cacheKey) {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getCachedResponse',
      cacheKey
    });
    return response?.cached ? response.response : null;
  } catch (error) {
    console.error('Error getting cached response:', error);
    return null;
  }
}

/**
 * Save response to cache
 */
async function setCachedResponse(cacheKey, response) {
  try {
    await chrome.runtime.sendMessage({
      action: 'setCachedResponse',
      cacheKey,
      response
    });
  } catch (error) {
    console.error('Error caching response:', error);
  }
}

/**
 * Make API request with timeout
 */
async function fetchWithTimeout(url, options, timeout = REQUEST_TIMEOUT) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('Request timeout - please try again');
    }
    throw error;
  }
}

/**
 * Make API request with retry logic
 */
async function makeRequestWithRetry(url, options, retries = MAX_RETRIES) {
  let lastError;
  
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetchWithTimeout(url, options);
      
      // Handle rate limiting
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get('Retry-After') || '5');
        if (attempt < retries) {
          await sleep(retryAfter * 1000);
          continue;
        }
      }
      
      // Handle server errors with retry
      if (response.status >= 500 && attempt < retries) {
        await sleep(RETRY_DELAY * Math.pow(2, attempt));
        continue;
      }
      
      return response;
    } catch (error) {
      lastError = error;
      if (attempt < retries) {
        await sleep(RETRY_DELAY * Math.pow(2, attempt));
        continue;
      }
    }
  }
  
  throw lastError || new Error('Request failed after retries');
}

/**
 * Main API call function with multi-provider support
 * @param {string} prompt - The prompt to send to the API
 * @param {object} options - Configuration options
 * @returns {Promise<string>} - The generated text response
 */
export async function callAPI(prompt, options = {}) {
  if (!prompt?.trim()) {
    throw new Error('Prompt cannot be empty');
  }
  
  try {
    // Get preferences
    const preferences = await getPreferences();
    const provider = options.provider || preferences.defaultProvider || API_PROVIDERS.TOGETHER;
    const config = getProviderConfig(provider);
    
    // Get model
    const model = options.model || config.defaultModel;
    
    // Check cache if enabled
    if (preferences.cacheResponses !== false && !options.skipCache) {
      const cacheKey = generateCacheKey(prompt, provider, model);
      const cached = await getCachedResponse(cacheKey);
      if (cached) {
        return cached;
      }
    }
    
    // Get API key
    const apiKey = await getApiKey(provider);
    if (!apiKey) {
      throw new Error(`API key not found for ${config.name}. Please configure it in settings.`);
    }
    
    // Format request
    const requestBody = config.formatRequest(prompt, model, options.params || {});
    const headers = config.formatHeaders(apiKey);
    
    // Determine endpoint
    let endpoint = config.endpoint;
    if (config.formatEndpoint) {
      endpoint = config.formatEndpoint(config.endpoint, model, apiKey);
    }
    
    // Make request with retry
    const response = await makeRequestWithRetry(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(requestBody)
    });
    
    // Handle errors
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = 
        errorData.error?.message ||
        errorData.error ||
        errorData.message ||
        `API request failed with status ${response.status}`;
      throw new Error(errorMessage);
    }
    
    // Parse response
    const data = await response.json();
    const text = config.extractResponse(data);
    
    if (!text) {
      throw new Error('No response text received from API');
    }
    
    // Cache response if enabled
    if (preferences.cacheResponses !== false && !options.skipCache) {
      const cacheKey = generateCacheKey(prompt, provider, model);
      await setCachedResponse(cacheKey, text);
    }
    
    // Save to conversation history
    if (!options.skipHistory) {
      await chrome.runtime.sendMessage({
        action: 'saveConversation',
        conversation: {
          prompt,
          response: text,
          provider,
          model,
          url: window.location.href,
          pageTitle: document.title
        }
      }).catch(err => console.error('Failed to save conversation:', err));
    }
    
    return text;
  } catch (error) {
    console.error('API call failed:', error);
    
    // Provide user-friendly error messages
    if (error.message.includes('API key')) {
      throw error;
    } else if (error.message.includes('timeout')) {
      throw new Error('Request timed out. Please try again.');
    } else if (error.message.includes('network')) {
      throw new Error('Network error. Please check your connection.');
    } else {
      throw new Error(`Failed to get response: ${error.message}`);
    }
  }
}

/**
 * Legacy function for backward compatibility
 */
export async function callTogetherAPI(prompt, options = {}) {
  return callAPI(prompt, {
    ...options,
    provider: API_PROVIDERS.TOGETHER
  });
}

/**
 * Get available providers and their status
 */
export async function getAvailableProviders() {
  const providers = [];
  
  for (const [key, config] of Object.entries({
    [API_PROVIDERS.TOGETHER]: getProviderConfig(API_PROVIDERS.TOGETHER),
    [API_PROVIDERS.OPENAI]: getProviderConfig(API_PROVIDERS.OPENAI),
    [API_PROVIDERS.ANTHROPIC]: getProviderConfig(API_PROVIDERS.ANTHROPIC),
    [API_PROVIDERS.GOOGLE]: getProviderConfig(API_PROVIDERS.GOOGLE)
  })) {
    const apiKey = await getApiKey(key);
    providers.push({
      id: key,
      name: config.name,
      models: config.models,
      configured: !!apiKey
    });
  }
  
  return providers;
}