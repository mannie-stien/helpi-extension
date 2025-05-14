/**
 * Main assistant class that handles all UI interactions and API calls
 */
import { detectContentType } from "./detectContext.js";
import { injectStyles } from "./styles.js";

export class Assistant {
  constructor() {
    this.initialized = false;

    this.assistantActive = false;
    this.floatingButton = null;
    this.tooltip = null;
    this.currentSelection = "";
    this.apiEndpoint = "https://api.together.xyz/inference";
    this.isProcessing = false;
    this.contextType = ""; // Stores detected content type
  }

  showButton() {
    if (!this.initialized) {
      this.init();
      return;
    }
    if (!this.floatingButton) {
      this.createFloatingButton();
    }
    this.floatingButton.style.display = "block";
    document.body.style.cursor = "text";
  }

  hideButton() {
    if (this.floatingButton) {
      this.floatingButton.style.display = "none";
      this.hideTooltip();
      document.body.style.cursor = "default";
    }
  }
  /**
   * Initialize the assistant on the page
   */
  async init() {
    if (this.initialized) return;

    injectStyles();
    this.createFloatingButton();
    this.createTooltip();
    this.setupSelectionListener();
    this.initialized = true;

    // Load initial state
    const { showAssistant } = await chrome.storage.local.get(["showAssistant"]);
    if (showAssistant !== false) {
      this.showButton();
    }
  }

  /**
   * Create the floating assistant button
   */
  createFloatingButton() {
    this.floatingButton = document.createElement("button");
    this.floatingButton.className = "assistant-floating-button";
    this.floatingButton.setAttribute("aria-label", "AI Assistant");
    this.floatingButton.innerHTML = `
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" fill="white"/>
        <path d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z" fill="white"/>
        <path d="M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm0 6c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" fill="white"/>
      </svg>
    `;

    this.floatingButton.addEventListener("click", (e) => {
      e.stopPropagation();
      this.toggleAssistant();
    });

    document.body.appendChild(this.floatingButton);
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
        <button class="close-tooltip" aria-label="Close">&times;</button>
      </div>
      <div class="tooltip-content"></div>
      <div class="tooltip-footer">
        <button class="summarize-btn">Summarize Page</button>
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

    document.body.appendChild(this.tooltip);
  }

  /**
   * Toggle the assistant on/off
   */
  toggleAssistant() {
    this.assistantActive = !this.assistantActive;
    this.floatingButton.classList.toggle("active", this.assistantActive);

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
        detectContentType(this.currentSelection, selection, (type) => {
          this.contextType = type;
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
    switch (this.contextType) {
      case "code":
        return `
          <button class="explain-code-btn">Explain Code</button>
          <button class="improve-code-btn">Improve Code</button>
          <button class="debug-code-btn">Debug Code</button>
          <button class="ask-btn">Ask AI</button>
        `;
      case "question":
        return `
          <button class="answer-btn">Answer Question</button>
          <button class="explain-btn">Explain Concept</button>
          <button class="ask-btn">Ask AI</button>
        `;
      case "math":
        return `
          <button class="solve-btn">Solve</button>
          <button class="explain-math-btn">Explain Steps</button>
          <button class="ask-btn">Ask AI</button>
        `;
      case "term":
        return `
          <button class="define-btn">Define</button>
          <button class="explain-btn">Explain</button>
          <button class="examples-btn">Give Examples</button>
          <button class="ask-btn">Ask AI</button>
        `;
      case "foreign":
        return `
          <button class="translate-btn">Translate</button>
          <button class="ask-btn">Ask AI</button>
        `;
      case "paragraph":
        return `
          <button class="summarize-text-btn">Summarize</button>
          <button class="explain-btn">Explain</button>
          <button class="key-points-btn">Key Points</button>
          <button class="ask-btn">Ask AI</button>
        `;
      default:
        return `
          <button class="explain-btn">Explain</button>
          <button class="define-btn">Define</button>
          <button class="translate-btn">Translate</button>
          <button class="ask-btn">Ask AI</button>
        `;
    }
  }

  /**
   * Add event listeners to the context-aware buttons
   */
  addButtonEventListeners(content) {
    // Common buttons
    if (content.querySelector(".explain-btn")) {
      content
        .querySelector(".explain-btn")
        .addEventListener("click", () => this.handleExplain());
    }
    if (content.querySelector(".define-btn")) {
      content
        .querySelector(".define-btn")
        .addEventListener("click", () => this.handleDefine());
    }
    if (content.querySelector(".translate-btn")) {
      content
        .querySelector(".translate-btn")
        .addEventListener("click", () => this.handleTranslate());
    }
    if (content.querySelector(".ask-btn")) {
      content
        .querySelector(".ask-btn")
        .addEventListener("click", () => this.handleAsk());
    }

    // Context-specific buttons
    if (content.querySelector(".explain-code-btn")) {
      content
        .querySelector(".explain-code-btn")
        .addEventListener("click", () => this.handleExplainCode());
    }
    if (content.querySelector(".improve-code-btn")) {
      content
        .querySelector(".improve-code-btn")
        .addEventListener("click", () => this.handleImproveCode());
    }
    if (content.querySelector(".debug-code-btn")) {
      content
        .querySelector(".debug-code-btn")
        .addEventListener("click", () => this.handleDebugCode());
    }
    if (content.querySelector(".answer-btn")) {
      content
        .querySelector(".answer-btn")
        .addEventListener("click", () => this.handleAnswerQuestion());
    }
    if (content.querySelector(".solve-btn")) {
      content
        .querySelector(".solve-btn")
        .addEventListener("click", () => this.handleSolveMath());
    }
    if (content.querySelector(".explain-math-btn")) {
      content
        .querySelector(".explain-math-btn")
        .addEventListener("click", () => this.handleExplainMath());
    }
    if (content.querySelector(".examples-btn")) {
      content
        .querySelector(".examples-btn")
        .addEventListener("click", () => this.handleGiveExamples());
    }
    if (content.querySelector(".summarize-text-btn")) {
      content
        .querySelector(".summarize-text-btn")
        .addEventListener("click", () => this.handleSummarizeText());
    }
    if (content.querySelector(".key-points-btn")) {
      content
        .querySelector(".key-points-btn")
        .addEventListener("click", () => this.handleKeyPoints());
    }
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

    // Focus the input immediately
    const askInput = content.querySelector(".ask-input");
    askInput.focus();

    // Prevent tooltip closing when clicking in textarea
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
        await this.processApiRequest(prompt);
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
  async processApiRequest(prompt) {
    if (this.isProcessing) return;

    this.isProcessing = true;
    this.showLoading();

    try {
      const response = await this.callTogetherAPI(prompt);
      this.showResponse(response);
    } catch (error) {
      this.showError(error.message);
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * Call the Together.ai API
   */
  async callTogetherAPI(prompt) {
    try {
      // Get API key from storage
      const { apiKey } = await new Promise((resolve) => {
        chrome.runtime.sendMessage({ action: "getApiKey" }, resolve);
      });

      if (!apiKey) {
        throw new Error(
          "API key not set. Please set your Together.ai API key in extension settings."
        );
      }

      const response = await fetch(this.apiEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
          prompt: prompt,
          // max_tokens: 1000,
          temperature: 0.7,
          top_p: 0.7,
          top_k: 50,
          repetition_penalty: 1,
          stop: ["</s>"],
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(
          errorData.error?.message ||
            `API request failed with status ${response.status}`
        );
      }

      const data = await response.json();

      // Handle different response formats
      if (data.output?.choices?.[0]?.text) {
        return data.output.choices[0].text;
      } else if (data.choices?.[0]?.text) {
        return data.choices[0].text;
      } else if (data.output) {
        return data.output;
      } else {
        // console.error("Unexpected API response format:", data);
        return "Sorry, I couldn't process the response. The API format may have changed.";
      }
    } catch (error) {
      // console.error("API call failed:", error);
      throw error;
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
    content.innerHTML = `
      <div style="color: #d32f2f; background: #fde8e8; padding: 12px; border-radius: 8px;">
        <p><strong>Error:</strong> ${message}</p>
      </div>
    `;
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
      // Reset to show selection buttons
      this.showTooltipNearSelection(window.getSelection());
    });
  }
}
