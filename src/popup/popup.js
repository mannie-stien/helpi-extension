document.addEventListener("DOMContentLoaded", () => {
  // Load saved states
  chrome.storage.local.get(['showAssistant', 'togetherApiKey'], (result) => {
    document.getElementById('toggleAssistant').checked = result.showAssistant ?? true;
    if (result.togetherApiKey) {
      document.getElementById("apiKey").value = result.togetherApiKey;
    }
  });

  // Save API key
  document.getElementById("saveBtn").addEventListener("click", () => {
    const apiKey = document.getElementById("apiKey").value.trim();
    if (!apiKey) {
      alert("Please enter your Together.ai API key");
      return;
    }
    chrome.storage.local.set({ togetherApiKey: apiKey });
  });

  // Handle toggle
  document.getElementById("toggleAssistant").addEventListener("change", (e) => {
    const show = e.target.checked;
    chrome.storage.local.set({ showAssistant: show });

    // Only send to active tab initially
    chrome.tabs.query({active: true, currentWindow: true}, (tabs) => {
      if (tabs[0]?.id) {
        chrome.tabs.sendMessage(tabs[0].id, { 
          type: "TOGGLE_ASSISTANT", 
          show 
        }).catch(() => {}); // Silently catch errors
      }
    });
  });
});