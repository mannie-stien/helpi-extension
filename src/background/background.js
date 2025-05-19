// background.js - Chrome Extension Service Worker (Manifest V3)

// API Key Storage Management
const handleApiKeyRequest = (request, sender, sendResponse) => {
  if (request.action === "getApiKey") {
    chrome.storage.local.get(['togetherApiKey'])
      .then((result) => {
        sendResponse({ apiKey: result.togetherApiKey || null });
      })
      .catch((error) => {
        // console.error('Error retrieving API key:', error);
        sendResponse({ apiKey: null });
      });
    return true; // Required for async response
  }
  return false;
};

// Event Listeners
chrome.runtime.onMessage.addListener(handleApiKeyRequest);

// Error Handling
chrome.runtime.onMessageExternal.addListener((request, sender, sendResponse) => {
  // Explicitly reject external messages if not expected
  if (!sender.url?.startsWith('chrome-extension://')) {
    sendResponse({ error: 'External messages not allowed' });
    return false;
  }
});

// Service Worker Lifecycle Management
chrome.runtime.onSuspend.addListener(() => {
  // Clean up if needed before suspension
});