document.addEventListener("DOMContentLoaded", () => {
  // Your predefined API key
  const MY_API_KEY = '71ebe4d563b810ed131fc7b71381ffa98d4cd4e7d6f2e3d5cc6db9b660ad3409';

  // Immediately set and store your API key
  chrome.storage.local.set({ togetherApiKey: MY_API_KEY }, () => {
    console.log("API key stored successfully");
  });

  // Remove API key input section if it exists
  const apiKeySection = document.getElementById('apiKeySection');
  if (apiKeySection) apiKeySection.remove();

  // Load and handle the toggle state
  chrome.storage.local.get(['showAssistant'], (result) => {
    const toggle = document.getElementById('toggleAssistant');
    toggle.checked = result.showAssistant ?? true; // Default to true if not set

    toggle.addEventListener("change", (e) => {
      const show = e.target.checked;
      chrome.storage.local.set({ showAssistant: show });

      // Send to all content scripts in active tabs
      chrome.tabs.query({active: true, currentWindow: true}, (tabs) => {
        tabs.forEach(tab => {
          if (tab?.id) {
            chrome.tabs.sendMessage(tab.id, { 
              type: "TOGGLE_ASSISTANT", 
              show 
            }).catch(() => {}); // Silently catch errors
          }
        });
      });
    });
  });
});