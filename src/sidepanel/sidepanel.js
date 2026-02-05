/**
 * Side Panel JavaScript for Helpi
 * Handles extended conversations and visual interface
 */

let currentContext = null;
let conversationHistory = [];
let isProcessing = false;

// DOM Elements
const conversationArea = document.getElementById('conversationArea');
const messageInput = document.getElementById('messageInput');
const sendBtn = document.getElementById('sendBtn');
const providerSelect = document.getElementById('providerSelect');
const contextInfo = document.getElementById('contextInfo');
const contextText = document.getElementById('contextText');
const clearContextBtn = document.getElementById('clearContextBtn');
const newConversationBtn = document.getElementById('newConversationBtn');
const settingsBtn = document.getElementById('settingsBtn');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    loadPreferences();
    listenForPageContext();
});

function setupEventListeners() {
    messageInput.addEventListener('input', () => {
        sendBtn.disabled = !messageInput.value.trim() && !currentContext;
    });

    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            handleSendMessage();
        }
    });

    sendBtn.addEventListener('click', handleSendMessage);
    clearContextBtn.addEventListener('click', clearContext);
    newConversationBtn.addEventListener('click', startNewConversation);
    settingsBtn.addEventListener('click', openSettings);

    // Quick actions
    document.querySelectorAll('.quick-action-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const action = e.target.dataset.action;
            handleQuickAction(action);
        });
    });

    providerSelect.addEventListener('change', async (e) => {
        await chrome.runtime.sendMessage({
            action: 'updatePreferences',
            preferences: { defaultProvider: e.target.value }
        });
    });
}

async function loadPreferences() {
    try {
        const response = await chrome.runtime.sendMessage({ action: 'getPreferences' });
        if (response?.success) {
            providerSelect.value = response.preferences.defaultProvider || 'together';
        }
    } catch (error) {
        console.error('Failed to load preferences:', error);
    }
}

function listenForPageContext() {
    // Listen for messages from content script
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.type === 'SELECTION_CONTEXT') {
            setContext(message.text, message.contextType);
            sendResponse({ success: true });
        }
        return true;
    });
}

function setContext(text, type) {
    currentContext = { text, type };
    contextText.textContent = text.substring(0, 100) + (text.length > 100 ? '...' : '');
    contextInfo.style.display = 'flex';
    messageInput.focus();
    sendBtn.disabled = false;
}

function clearContext() {
    currentContext = null;
    contextInfo.style.display = 'none';
}

function startNewConversation() {
    if (conversationHistory.length > 0 && 
        confirm('Start a new conversation? Current conversation will be saved to history.')) {
        conversationHistory = [];
        conversationArea.innerHTML = `
            <div class="welcome-message">
                <h2>New Conversation</h2>
                <p>What would you like to know?</p>
            </div>
        `;
        clearContext();
        messageInput.value = '';
    }
}

function openSettings() {
    chrome.runtime.openOptionsPage();
}

async function handleQuickAction(action) {
    switch (action) {
        case 'summarize':
            await summarizePage();
            break;
        case 'history':
            await showHistory();
            break;
    }
}

async function summarizePage() {
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        
        addMessage('user', 'Summarize this page');
        showLoading();
        
        // Request page content from content script
        const response = await chrome.tabs.sendMessage(tab.id, { 
            type: 'GET_PAGE_CONTENT' 
        });
        
        if (response?.content) {
            const prompt = `Please provide a concise summary of the following content:\n\n${response.content}`;
            await sendToAI(prompt);
        } else {
            hideLoading();
            addMessage('ai', 'Unable to access page content. Please try selecting text manually.');
        }
    } catch (error) {
        hideLoading();
        addMessage('ai', `Error: ${error.message}`);
    }
}

async function showHistory() {
    try {
        const response = await chrome.runtime.sendMessage({
            action: 'getConversationHistory',
            limit: 50
        });

        if (response?.success && response.history.length > 0) {
            conversationArea.innerHTML = '<div class="history-view"><h3>Recent Conversations</h3></div>';
            
            response.history.forEach(conv => {
                const historyItem = document.createElement('div');
                historyItem.className = 'history-item';
                historyItem.innerHTML = `
                    <div class="history-header">
                        <strong>${new Date(conv.timestamp).toLocaleString()}</strong>
                        <span>${conv.provider || 'together'}</span>
                    </div>
                    <div class="history-prompt">${conv.prompt.substring(0, 150)}...</div>
                `;
                historyItem.addEventListener('click', () => loadConversation(conv));
                conversationArea.querySelector('.history-view').appendChild(historyItem);
            });
        } else {
            addMessage('ai', 'No conversation history found.');
        }
    } catch (error) {
        addMessage('ai', `Error loading history: ${error.message}`);
    }
}

function loadConversation(conv) {
    conversationArea.innerHTML = '';
    addMessage('user', conv.prompt);
    addMessage('ai', conv.response);
}

async function handleSendMessage() {
    if (isProcessing) return;
    
    const message = messageInput.value.trim();
    if (!message && !currentContext) return;

    isProcessing = true;
    sendBtn.disabled = true;

    try {
        let prompt = message;
        
        if (currentContext) {
            prompt = `Context: "${currentContext.text}"\n\nQuestion: ${message || 'Please explain this.'}`;
        }

        addMessage('user', message || 'Explain the selected text');
        messageInput.value = '';
        clearContext();

        showLoading();
        await sendToAI(prompt);
    } catch (error) {
        hideLoading();
        addMessage('ai', `Error: ${error.message}`);
    } finally {
        isProcessing = false;
        sendBtn.disabled = false;
    }
}

async function sendToAI(prompt) {
    try {
        // Import API function
        const { callAPI } = await import(chrome.runtime.getURL('src/content/callTogetherAPI.js'));
        
        const provider = providerSelect.value;
        const response = await callAPI(prompt, { provider });
        
        hideLoading();
        addMessage('ai', response);
        
        conversationHistory.push({
            prompt,
            response,
            timestamp: Date.now()
        });
    } catch (error) {
        hideLoading();
        throw error;
    }
}

function addMessage(sender, content) {
    // Remove welcome message if present
    const welcomeMsg = conversationArea.querySelector('.welcome-message');
    if (welcomeMsg) {
        welcomeMsg.remove();
    }

    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}-message`;
    
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    
    messageDiv.innerHTML = `
        <div class="message-header">
            <div class="message-avatar">${sender === 'user' ? 'U' : 'AI'}</div>
            <span class="message-sender">${sender === 'user' ? 'You' : 'Helpi'}</span>
            <span class="message-time">${time}</span>
        </div>
        <div class="message-content">${formatMessage(content)}</div>
        ${sender === 'ai' ? `
            <div class="message-actions">
                <button class="message-action-btn copy-btn">Copy</button>
                <button class="message-action-btn regenerate-btn">Regenerate</button>
            </div>
        ` : ''}
    `;

    conversationArea.appendChild(messageDiv);
    conversationArea.scrollTop = conversationArea.scrollHeight;

    // Add event listeners for AI message actions
    if (sender === 'ai') {
        const copyBtn = messageDiv.querySelector('.copy-btn');
        const regenerateBtn = messageDiv.querySelector('.regenerate-btn');
        
        copyBtn.addEventListener('click', () => {
            navigator.clipboard.writeText(content);
            copyBtn.textContent = 'Copied!';
            setTimeout(() => copyBtn.textContent = 'Copy', 2000);
        });
        
        regenerateBtn.addEventListener('click', () => {
            // Implement regenerate logic
            console.log('Regenerate clicked');
        });
    }
}

function formatMessage(text) {
    // Basic markdown formatting
    let formatted = text;
    
    // Code blocks
    formatted = formatted.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
    
    // Inline code
    formatted = formatted.replace(/`([^`]+)`/g, '<code>$1</code>');
    
    // Bold
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    
    // Line breaks
    formatted = formatted.replace(/\n/g, '<br>');
    
    return formatted;
}

function showLoading() {
    const loadingDiv = document.createElement('div');
    loadingDiv.className = 'message ai-message loading-message';
    loadingDiv.id = 'loadingMessage';
    loadingDiv.innerHTML = `
        <div class="message-header">
            <div class="message-avatar">AI</div>
            <span class="message-sender">Helpi</span>
        </div>
        <div class="loading-message">
            <span>Thinking</span>
            <div class="loading-dots">
                <span></span>
                <span></span>
                <span></span>
            </div>
        </div>
    `;
    conversationArea.appendChild(loadingDiv);
    conversationArea.scrollTop = conversationArea.scrollHeight;
}

function hideLoading() {
    const loadingMsg = document.getElementById('loadingMessage');
    if (loadingMsg) {
        loadingMsg.remove();
    }
}
