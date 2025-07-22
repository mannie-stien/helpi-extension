document.addEventListener("DOMContentLoaded", () => {
  // Your predefined API key
  const MY_API_KEY = '7863bf715b5f025784c5f3d2c7614292ac511e30318455d61a7ad015eb895eae';
  

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