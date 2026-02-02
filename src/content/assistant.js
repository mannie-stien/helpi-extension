import { callTogetherAPI, callAPI } from "./callTogetherAPI.js";
import { detectContentType, detectVisualContent } from "./detectContext.js";
import { injectStyles } from "./styles.js";
import { KeyboardShortcutsManager } from "./keyboardShortcuts.js";
import { ConversationManager } from "./conversationManager.js";
import { handleVisualSelection, getVisualContentActions } from "./visualContentHandler.js";

export class Assistant {
  constructor() {
    this.initialized = false;
    this.assistantActive = false;
    this.tooltip = null;
    this.currentSelection = "";
    this.apiEndpoint = "https://api.together.xyz/inference";
    this.isProcessing = false;
    this.contextType = "";
    this.conversationManager = new ConversationManager();
    this.keyboardShortcuts = null;
    this.lastError = null;
    this.retryCount = 0;
    this.maxRetries = 2;
    this.visualContent = null;
  }

  showButton() {
    if (!this.initialized) {
      this.init();
      return;
    }
    
    this.assistantActive = true;
    document.body.style.cursor = "text";
  }

  hideButton() {
    this.assistantActive = false;
    this.hideTooltip();
    document.body.style.cursor = "default";
  }
  
  /**
   * Initialize the assistant on the page
   */
  async init() {
    if (this.initialized) return;

    try {
      injectStyles();
      this.createTooltip();
      this.setupSelectionListener();
      
      // Initialize keyboard shortcuts
      this.keyboardShortcuts = new KeyboardShortcutsManager(this);
      this.keyboardShortcuts.init();
      
      // Setup command listeners
      this.setupCommandListeners();
      
      this.initialized = true;

      // Load initial state
      const { showAssistant } = await chrome.storage.local.get(["showAssistant"]);
      if (showAssistant !== false) {
        this.showButton();
      }
    } catch (error) {
      console.error('Failed to initialize assistant:', error);
      this.lastError = error;
    }
  }

  setupCommandListeners() {
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
      if (message.type === 'COMMAND') {
        switch (message.command) {
          case 'toggle-assistant':
            this.toggleAssistant();
            break;
          case 'quick-explain':
            if (this.currentSelection) this.handleExplain();
            break;
          case 'summarize-page':
            this.summarizePage();
            break;
        }
        sendResponse({ success: true });
      }
      return true;
    });
  }

  /**
   * Create the tooltip for displaying responses
   */
  createTooltip() {
    this.tooltip = document.createElement("div");
    this.tooltip.className = "assistant-tooltip";
    this.tooltip.innerHTML = `
      <div class="tooltip-header">
        <span>HelpI</span>
        <div class="header-actions">
          <button class="history-btn" aria-label="History" title="View History">📜</button>
          <button class="close-tooltip" aria-label="Close">&times;</button>
        </div>
      </div>
      <div class="tooltip-content"></div>
      <div class="tooltip-footer">
        <button class="summarize-btn">Summarize Page</button>
        <button class="history-btn-footer">History</button>
      </div>
    `;

    this.tooltip
      .querySelector(".close-tooltip")
      .addEventListener("click", (e) => {
        e.stopPropagation();
        this.hideTooltip();
      });

    this.tooltip
      .querySelector(".summarize-btn")
      .addEventListener("click", (e) => {
        e.stopPropagation();
        this.summarizePage();
      });

    this.tooltip
      .querySelectorAll(".history-btn, .history-btn-footer")
      .forEach(btn => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          this.showHistory();
        });
      });

    document.body.appendChild(this.tooltip);
  }

  /**
   * Toggle the assistant on/off
   */
  toggleAssistant() {
    this.assistantActive = !this.assistantActive;

    if (this.assistantActive) {
      document.body.style.cursor = "text";
    } else {
      document.body.style.cursor = "default";
      this.hideTooltip();
    }
  }

  /**
   * Setup text selection listener
   */
  setupSelectionListener() {
    document.addEventListener("selectionchange", () => {
      if (!this.assistantActive || this.isProcessing) return;

      // Ignore selections inside our tooltip
      const activeElement = document.activeElement;
      if (activeElement.closest(".assistant-tooltip")) {
        return;
      }

      const selection = window.getSelection();
      if (selection && selection.toString().trim().length > 0) {
        this.currentSelection = selection.toString().trim();
        
        // Check for visual content
        this.visualContent = detectVisualContent(selection);
        
        // Start new conversation on new selection
        detectContentType(this.currentSelection, selection, (type) => {
          this.contextType = this.visualContent ? 'image' : type;
          this.conversationManager.startConversation(this.currentSelection, this.contextType);
          this.showTooltipNearSelection(selection);
        });
      } else {
        this.hideTooltip();
      }
    });
  }

  /**
   * Show tooltip near the selected text with context-aware buttons
   */
  showTooltipNearSelection(selection) {
    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    // Position tooltip below selection
    this.tooltip.style.top = `${window.scrollY + rect.bottom + 10}px`;
    this.tooltip.style.left = `${window.scrollX + rect.left}px`;
    this.tooltip.classList.add("visible");

    // Update tooltip content with context-aware action buttons
    const content = this.tooltip.querySelector(".tooltip-content");
    content.innerHTML = `
      <p>Selected: <em>"${this.currentSelection.substring(0, 50)}${
      this.currentSelection.length > 50 ? "..." : ""
    }"</em></p>
      <div class="action-buttons">
        ${this.getContextButtons()}
      </div>
    `;

    // Add event listeners to buttons
    this.addButtonEventListeners(content);
  }

  /**
   * Generate context-aware buttons based on detected content type
   */
  getContextButtons() {
    const hasConversation = this.conversationManager.hasActiveConversation() && 
                           this.conversationManager.getCurrentConversation()?.exchanges.length > 0;
    
    // Handle visual content
    if (this.visualContent) {
      const visualActions = getVisualContentActions(this.visualContent);
      visualActions.push({ class: 'open-sidepanel-btn', text: 'Open in Side Panel' });
      return visualActions.map(btn => 
        `<button class="${btn.class}">${btn.text}</button>`
      ).join('');
    }
    
    const buttonConfigs = {
    code: [
      { class: 'explain-code-btn', text: 'Explain Code' },
      { class: 'improve-code-btn', text: 'Improve Code' },
      { class: 'debug-code-btn', text: 'Debug Code' }
    ],
    question: [
      { class: 'answer-btn', text: 'Answer Question' },
      { class: 'explain-btn', text: 'Explain Concept' }
    ],
    math: [
      { class: 'solve-btn', text: 'Solve' },
      { class: 'explain-math-btn', text: 'Explain Steps' }
    ],
    term: [
      { class: 'define-btn', text: 'Define' },
      { class: 'explain-btn', text: 'Explain' },
      { class: 'examples-btn', text: 'Give Examples' }
    ],
    foreign: [
      { class: 'translate-btn', text: 'Translate' }
    ],
    paragraph: [
      { class: 'summarize-text-btn', text: 'Summarize' },
      { class: 'explain-btn', text: 'Explain' },
      { class: 'key-points-btn', text: 'Key Points' }
    ],
    default: [
      { class: 'explain-btn', text: 'Explain' },
      { class: 'define-btn', text: 'Define' },
      { class: 'translate-btn', text: 'Translate' }
    ]
  };

  // Get buttons for current context or default
  const buttons = buttonConfigs[this.contextType] || buttonConfigs.default;
  
  // Add Ask AI button to all contexts
  buttons.push({ class: 'ask-btn', text: 'Ask AI' });
  
  // Add Follow-up button if conversation exists
  if (this.conversationManager.hasActiveConversation() && 
      this.conversationManager.getCurrentConversation()?.exchanges.length > 0) {
    buttons.push({ class: 'followup-btn', text: 'Follow-up' });
  }
  
  // Add Side Panel button
  buttons.push({ class: 'open-sidepanel-btn', text: 'Side Panel' });

  // Generate HTML
  return buttons.map(btn => 
    `<button class="${btn.class}">${btn.text}</button>`
  ).join('');
}

  /**
   * Add event listeners to the context-aware buttons
   */

  /**
   * Adds event listeners to all context-aware buttons in the tooltip
   * @param {HTMLElement} content - The tooltip content element
   */
  addButtonEventListeners(content) {
    // Button handler mapping
    const buttonHandlers = {
      // Common buttons
      '.explain-btn': () => this.handleExplain(),
      '.define-btn': () => this.handleDefine(),
      '.translate-btn': () => this.handleTranslate(),
      '.ask-btn': () => this.handleAsk(),
      '.followup-btn': () => this.handleFollowUp(),
      '.open-sidepanel-btn': () => this.openSidePanel(),
      
      // Visual content handlers
      '.describe-visual-btn': () => this.handleDescribeVisual(),
      '.analyze-visual-btn': () => this.handleAnalyzeVisual(),
      '.extract-text-btn': () => this.handleExtractText(),
      '.explain-chart-btn': () => this.handleExplainChart(),
      
      // Context-specific buttons
      '.explain-code-btn': () => this.handleExplainCode(),
      '.improve-code-btn': () => this.handleImproveCode(),
      '.debug-code-btn': () => this.handleDebugCode(),
      '.answer-btn': () => this.handleAnswerQuestion(),
      '.solve-btn': () => this.handleSolveMath(),
      '.explain-math-btn': () => this.handleExplainMath(),
      '.examples-btn': () => this.handleGiveExamples(),
      '.summarize-text-btn': () => this.handleSummarizeText(),
      '.key-points-btn': () => this.handleKeyPoints()
    };

    // Add event listeners for each button type
    Object.entries(buttonHandlers).forEach(([selector, handler]) => {
      const button = content.querySelector(selector);
      if (button) {
        button.addEventListener('click', (e) => {
          e.stopPropagation();
          handler();
        });
      }
    });
  }

  /**
   * Hide the tooltip
   */
  hideTooltip() {
    this.tooltip.classList.remove("visible");
  }

  /**
   * Handle messages from background or popup
   */
  handleMessages(request, sender, sendResponse) {
    if (request.action === "explainSelectedText") {
      this.explainText(request.text);
      sendResponse({ status: "success" });
    }
    return true;
  }

  /**
   * Handle the 'Ask AI' button click
   */
  async handleAsk() {
    if (this.isProcessing) return;

    const content = this.tooltip.querySelector(".tooltip-content");
    content.innerHTML = `
    <div class="ask-form">
      <p>Ask a question about this selection:</p>
      <textarea class="ask-input" placeholder="Your question here..." rows="3"></textarea>
      <div class="ask-actions">
        <button class="cancel-ask">Cancel</button>
        <button class="submit-ask">Submit</button>
      </div>
    </div>
  `;

    const askInput = content.querySelector(".ask-input");
    askInput.focus();

    askInput.addEventListener("mousedown", (e) => {
      e.stopPropagation();
    });

    content.querySelector(".cancel-ask").addEventListener("click", (e) => {
      e.stopPropagation();
      this.showTooltipNearSelection(window.getSelection());
    });

    content
      .querySelector(".submit-ask")
      .addEventListener("click", async (e) => {
        e.stopPropagation();
        const question = askInput.value.trim();
        if (!question) return;

        const prompt = `Question: ${question}\n\nContext: "${this.currentSelection}"\n\nPlease answer the question based on the provided context.`;
        await this.processApiRequest(prompt, 'ask');
      });
  }

  async handleFollowUp() {
    if (this.isProcessing) return;

    const content = this.tooltip.querySelector(".tooltip-content");
    content.innerHTML = `
    <div class="ask-form">
      <p>Follow-up question:</p>
      <textarea class="ask-input" placeholder="Continue the conversation..." rows="3"></textarea>
      <div class="ask-actions">
        <button class="cancel-ask">Cancel</button>
        <button class="submit-ask">Submit</button>
      </div>
    </div>
  `;

    const askInput = content.querySelector(".ask-input");
    askInput.focus();

    askInput.addEventListener("mousedown", (e) => {
      e.stopPropagation();
    });

    content.querySelector(".cancel-ask").addEventListener("click", (e) => {
      e.stopPropagation();
      this.showTooltipNearSelection(window.getSelection());
    });

    content
      .querySelector(".submit-ask")
      .addEventListener("click", async (e) => {
        e.stopPropagation();
        const question = askInput.value.trim();
        if (!question) return;

        const contextualPrompt = this.conversationManager.buildContextualPrompt(question);
        await this.processApiRequest(contextualPrompt, 'followup');
      });
  }

  /**
   * Summarize the current page
   */
  async summarizePage() {
    if (this.isProcessing) return;

    const pageContent = this.getPageContent();
    const prompt = `Please provide a concise summary of the following content, focusing on the key points and main ideas:\n\n${pageContent}`;
    await this.processApiRequest(prompt);
  }

  /** Handle Explain button click */
  async handleExplain() {
    const prompt = `Please explain the following text in simple terms, providing context and any additional relevant information:\n\n"${this.currentSelection}"`;
    await this.processApiRequest(prompt);
  }

  /** Handle Define button click */
  async handleDefine() {
    const prompt = `Provide a clear definition of the following term, along with an example if appropriate:\n\n"${this.currentSelection}"`;
    await this.processApiRequest(prompt);
  }

  /** Handle Translate button click */
  async handleTranslate() {
    const prompt = `Translate the following text to English while preserving the original meaning and context:\n\n"${this.currentSelection}"`;
    await this.processApiRequest(prompt);
  }

  /** Handle Explain Code button click */
  async handleExplainCode() {
    const prompt = `Explain the following code in detail, describing what it does and how it works:\n\n\`\`\`\n${this.currentSelection}\n\`\`\``;
    await this.processApiRequest(prompt);
  }

  /** Handle Improve Code button click */
  async handleImproveCode() {
    const prompt = `Review the following code and suggest improvements for better readability, performance, and best practices:\n\n\`\`\`\n${this.currentSelection}\n\`\`\`\n\nPlease provide an improved version with explanations for the changes.`;
    await this.processApiRequest(prompt);
  }

  /** Handle Debug Code button click */
  async handleDebugCode() {
    const prompt = `Debug the following code. Identify any issues, bugs, or potential problems, and suggest fixes:\n\n\`\`\`\n${this.currentSelection}\n\`\`\``;
    await this.processApiRequest(prompt);
  }

  /** Handle Answer Question button click */
  async handleAnswerQuestion() {
    const prompt = `Please answer the following question comprehensively and accurately:\n\n"${this.currentSelection}"`;
    await this.processApiRequest(prompt);
  }

  /** Handle Solve Math button click */
  async handleSolveMath() {
    const prompt = `Solve the following mathematical expression or equation, showing the complete solution and final answer:\n\n${this.currentSelection}`;
    await this.processApiRequest(prompt);
  }

  /** Handle Explain Math button click */
  async handleExplainMath() {
    const prompt = `Explain the step-by-step process for solving this mathematical expression or equation:\n\n${this.currentSelection}\n\nPlease provide a detailed explanation of each step in the solution process.`;
    await this.processApiRequest(prompt);
  }

  /** Handle Give Examples button click */
  async handleGiveExamples() {
    const prompt = `Provide multiple examples and use cases for the term or concept:\n\n"${this.currentSelection}"\n\nPlease include diverse examples that illustrate the meaning and applications.`;
    await this.processApiRequest(prompt);
  }

  /** Handle Summarize Text button click */
  async handleSummarizeText() {
    const prompt = `Provide a concise summary of the following text, capturing the main points and key information:\n\n"${this.currentSelection}"`;
    await this.processApiRequest(prompt);
  }

  /** Handle Key Points button click */
  async handleKeyPoints() {
    const prompt = `Extract and list the key points from the following text:\n\n"${this.currentSelection}"\n\nPlease provide the most important ideas and information in a clear, organized format.`;
    await this.processApiRequest(prompt);
  }

  /**
   * Process API request with error handling and loading states
   */
  async processApiRequest(prompt, action = 'general') {
    if (this.isProcessing) return;

    this.isProcessing = true;
    this.showLoading();
    this.retryCount = 0;

    try {
      const response = await callAPI(prompt);
      
      // Add to conversation history
      this.conversationManager.addExchange(prompt, response, action);
      
      this.showResponse(response);
      this.lastError = null;
    } catch (error) {
      this.lastError = error;
      this.showError(error.message);
    } finally {
      this.isProcessing = false;
    }
  }

  async showHistory() {
    try {
      const response = await chrome.runtime.sendMessage({
        action: 'getConversationHistory',
        limit: 20
      });

      if (!response?.success) {
        this.showError('Failed to load history');
        return;
      }

      const content = this.tooltip.querySelector(".tooltip-content");
      const history = response.history || [];

      if (history.length === 0) {
        content.innerHTML = `
          <div class="history-view">
            <h3>Conversation History</h3>
            <p style="color: #666; text-align: center; padding: 20px;">No history yet</p>
            <button class="back-btn">Back</button>
          </div>
        `;
      } else {
        const historyHTML = history.map((conv, idx) => `
          <div class="history-item" data-index="${idx}">
            <div class="history-header">
              <strong>${new Date(conv.timestamp).toLocaleString()}</strong>
              <span class="history-provider">${conv.provider || 'together'}</span>
            </div>
            <div class="history-prompt">${conv.prompt.substring(0, 100)}${conv.prompt.length > 100 ? '...' : ''}</div>
          </div>
        `).join('');

        content.innerHTML = `
          <div class="history-view">
            <h3>Recent Conversations</h3>
            <div class="history-list">${historyHTML}</div>
            <div class="history-actions">
              <button class="clear-history-btn">Clear History</button>
              <button class="back-btn">Back</button>
            </div>
          </div>
        `;

        content.querySelectorAll('.history-item').forEach((item, idx) => {
          item.addEventListener('click', () => {
            const conv = history[idx];
            this.showHistoryDetail(conv);
          });
        });

        content.querySelector('.clear-history-btn')?.addEventListener('click', async () => {
          if (confirm('Clear all conversation history?')) {
            await chrome.runtime.sendMessage({ action: 'clearHistory' });
            this.showHistory();
          }
        });
      }

      content.querySelector('.back-btn')?.addEventListener('click', () => {
        if (this.currentSelection) {
          this.showTooltipNearSelection(window.getSelection());
        } else {
          this.hideTooltip();
        }
      });

      this.tooltip.classList.add('visible');
    } catch (error) {
      console.error('Failed to show history:', error);
      this.showError('Failed to load history');
    }
  }

  showHistoryDetail(conversation) {
    const content = this.tooltip.querySelector(".tooltip-content");
    content.innerHTML = `
      <div class="history-detail">
        <h3>Conversation Detail</h3>
        <div class="detail-meta">
          <div><strong>Date:</strong> ${new Date(conversation.timestamp).toLocaleString()}</div>
          <div><strong>Provider:</strong> ${conversation.provider || 'together'}</div>
          <div><strong>Page:</strong> ${conversation.pageTitle || 'Unknown'}</div>
        </div>
        <div class="detail-content">
          <h4>Prompt:</h4>
          <p>${conversation.prompt}</p>
          <h4>Response:</h4>
          <p>${conversation.response}</p>
        </div>
        <button class="back-to-history-btn">Back to History</button>
      </div>
    `;

    content.querySelector('.back-to-history-btn')?.addEventListener('click', () => {
      this.showHistory();
    });
  }

  /** Handle visual content actions */
  async handleDescribeVisual() {
    if (!this.visualContent) return;
    const prompt = await handleVisualSelection(this.visualContent, this);
    await this.processApiRequest(prompt, 'describe-visual');
  }

  async handleAnalyzeVisual() {
    if (!this.visualContent) return;
    const prompt = await handleVisualSelection(this.visualContent, this);
    const enhancedPrompt = `${prompt}\n\nPlease provide a detailed analysis of this visual content.`;
    await this.processApiRequest(enhancedPrompt, 'analyze-visual');
  }

  async handleExtractText() {
    if (!this.visualContent || this.visualContent.type !== 'image') return;
    this.showError('OCR text extraction is not yet implemented. This feature requires integration with an OCR service like Google Vision API or Tesseract.js.');
  }

  async handleExplainChart() {
    if (!this.visualContent) return;
    const prompt = await handleVisualSelection(this.visualContent, this);
    const enhancedPrompt = `${prompt}\n\nPlease explain what type of chart or diagram this is and what insights can be derived from it.`;
    await this.processApiRequest(enhancedPrompt, 'explain-chart');
  }

  /** Open side panel */
  async openSidePanel() {
    try {
      // Open side panel
      await chrome.sidePanel.open({ windowId: (await chrome.windows.getCurrent()).id });
      
      // Send context to side panel
      if (this.currentSelection) {
        await chrome.runtime.sendMessage({
          type: 'SELECTION_CONTEXT',
          text: this.currentSelection,
          contextType: this.contextType,
          visualContent: this.visualContent
        });
      }
    } catch (error) {
      console.error('Failed to open side panel:', error);
      this.showError('Failed to open side panel. Make sure you have the latest version of Chrome.');
    }
  }

  /**
   * Get readable page content
   */
  getPageContent() {
    // Try to get article content, fall back to body text
    const article =
      document.querySelector("article") ||
      document.querySelector(".article, .post, .content") ||
      document.body;

    // Clone to avoid modifying the original DOM
    const clone = article.cloneNode(true);

    // Remove unwanted elements
    clone
      .querySelectorAll("nav, footer, script, style, iframe, noscript")
      .forEach((el) => el.remove());

    return clone.textContent.trim().replace(/\s+/g, " ");
  }

  /**
   * Show loading state in tooltip
   */
  showLoading() {
    const content = this.tooltip.querySelector(".tooltip-content");
    content.innerHTML = `
      <div style="text-align: center; padding: 16px;">
        <div class="loading-spinner"></div>
        <p style="margin-top: 12px; color: #666;">Processing...</p>
      </div>
    `;
  }

  /**
   * Show error message in tooltip
   */
  showError(message) {
    const content = this.tooltip.querySelector(".tooltip-content");
    const canRetry = this.retryCount < this.maxRetries;
    
    content.innerHTML = `
      <div style="color: #d32f2f; background: #fde8e8; padding: 12px; border-radius: 8px;">
        <p><strong>Error:</strong> ${message}</p>
        ${canRetry ? '<button class="retry-btn" style="margin-top: 8px;">Retry</button>' : ''}
      </div>
    `;

    if (canRetry) {
      content.querySelector('.retry-btn')?.addEventListener('click', () => {
        this.retryCount++;
        if (this.lastError && this.conversationManager.hasActiveConversation()) {
          const lastExchange = this.conversationManager.getCurrentConversation()?.exchanges.slice(-1)[0];
          if (lastExchange) {
            this.processApiRequest(lastExchange.prompt, lastExchange.action);
          }
        }
      });
    }
  }

  /**
   * Show API response in tooltip
   */
  showResponse(response) {
    const content = this.tooltip.querySelector(".tooltip-content");

    // Parse markdown if response contains it
    let formattedResponse = response;

    // Handle code blocks
    formattedResponse = formattedResponse.replace(
      /```([\s\S]*?)```/g,
      (match, code) => {
        return `<pre class="code-block"><code>${code.trim()}</code></pre>`;
      }
    );

    // Handle lists
    formattedResponse = formattedResponse.replace(
      /^\s*[\*\-]\s+(.*?)$/gm,
      "<li>$1</li>"
    );
    formattedResponse = formattedResponse.replace(
      /(<li>.*?<\/li>)\s+(?=<li>)/gs,
      "$1"
    );
    formattedResponse = formattedResponse.replace(
      /(<li>.*?<\/li>)+/gs,
      "<ul>$&</ul>"
    );

    // Handle headers
    formattedResponse = formattedResponse.replace(
      /^###\s+(.*?)$/gm,
      "<h3>$1</h3>"
    );
    formattedResponse = formattedResponse.replace(
      /^##\s+(.*?)$/gm,
      "<h2>$1</h2>"
    );
    formattedResponse = formattedResponse.replace(
      /^#\s+(.*?)$/gm,
      "<h1>$1</h1>"
    );

    // Handle paragraphs
    formattedResponse = formattedResponse.replace(/\n\n/g, "</p><p>");

    content.innerHTML = `
      <div class="response">
        <p>${formattedResponse}</p>
        <div class="response-actions">
          <button class="copy-btn">Copy</button>
          <button class="new-action-btn">New Action</button>
        </div>
      </div>
    `;

    // Add event listeners for response actions
    content.querySelector(".copy-btn").addEventListener("click", () => {
      navigator.clipboard.writeText(response).then(() => {
        const copyBtn = content.querySelector(".copy-btn");
        copyBtn.textContent = "Copied!";
        setTimeout(() => {
          copyBtn.textContent = "Copy";
        }, 2000);
      });
    });

    content.querySelector(".new-action-btn").addEventListener("click", () => {
      this.showTooltipNearSelection(window.getSelection());
    });
  }

  destroy() {
    if (this.tooltip) {
      this.tooltip.remove();
    }
    if (this.keyboardShortcuts) {
      this.keyboardShortcuts.disable();
    }
    this.initialized = false;
    this.visualContent = null;
  }
}