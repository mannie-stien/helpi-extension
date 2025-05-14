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

// Context Menu Setup
const setupContextMenu = () => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "explainText",
      title: "Explain with AI Assistant",
      contexts: ["selection"],
      documentUrlPatterns: ["http://*/*", "https://*/*"] // Restrict to web pages only
    });
  });
};

// Context Menu Click Handler
const handleContextMenuClick = (info, tab) => {
  if (info.menuItemId === "explainText" && info.selectionText && tab.id) {
    chrome.tabs.sendMessage(tab.id, {
      action: "explainSelectedText",
      text: info.selectionText.trim()
    }).catch(error => {
      // console.error('Failed to send message:', error);
    });
  }
};

// Event Listeners
chrome.runtime.onMessage.addListener(handleApiKeyRequest);
chrome.runtime.onInstalled.addListener(setupContextMenu);
chrome.contextMenus.onClicked.addListener(handleContextMenuClick);

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