let assistantInstance = null;

async function loadAssistant() {
  try {
    const { Assistant } = await import(chrome.runtime.getURL('src/content/assistant.js'));
    assistantInstance = new Assistant();
    
    // Load initial state
    const { showAssistant } = await chrome.storage.local.get(['showAssistant']);
    if (showAssistant !== false) { // Default to true if not set
      await assistantInstance.init();
    }
  } catch (error) {
    // console.error('Failed to load assistant:', error);
  }
}

// Handle messages safely
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'TOGGLE_ASSISTANT') {
    if (!assistantInstance) {
      loadAssistant().then(() => {
        if (message.show) assistantInstance?.showButton?.();
      });
      return;
    }
    
    if (message.show) {
      assistantInstance.showButton();
      if (!assistantInstance.initialized) {
        assistantInstance.init();
      }
    } else {
      assistantInstance.hideButton();
    }
  }
  return true; // Keep message channel open for async responses
});

// Initialize
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', loadAssistant);
} else {
  loadAssistant();
}

