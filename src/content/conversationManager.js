/**
 * Conversation Manager for Helpi
 * Manages conversation context and follow-up questions
 */

export class ConversationManager {
  constructor() {
    this.currentConversation = null;
    this.conversationContext = [];
    this.maxContextLength = 5; // Keep last 5 exchanges
  }

  /**
   * Start a new conversation
   */
  startConversation(selection, contextType) {
    this.currentConversation = {
      id: `conv_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      selection,
      contextType,
      exchanges: [],
      startTime: Date.now()
    };
    this.conversationContext = [];
  }

  /**
   * Add exchange to current conversation
   */
  addExchange(prompt, response, action) {
    if (!this.currentConversation) {
      this.startConversation('', 'general');
    }

    const exchange = {
      prompt,
      response,
      action,
      timestamp: Date.now()
    };

    this.currentConversation.exchanges.push(exchange);
    this.conversationContext.push(exchange);

    // Keep only recent context
    if (this.conversationContext.length > this.maxContextLength) {
      this.conversationContext.shift();
    }
  }

  /**
   * Get conversation context for follow-up questions
   */
  getContext() {
    if (this.conversationContext.length === 0) {
      return '';
    }

    return this.conversationContext
      .map(ex => `User: ${ex.prompt}\nAssistant: ${ex.response}`)
      .join('\n\n');
  }

  /**
   * Build prompt with context for follow-up questions
   */
  buildContextualPrompt(newPrompt) {
    const context = this.getContext();
    if (!context) {
      return newPrompt;
    }

    return `Previous conversation:\n${context}\n\nNew question: ${newPrompt}`;
  }

  /**
   * Check if this is a follow-up question
   */
  isFollowUp(prompt) {
    const followUpIndicators = [
      'what about',
      'how about',
      'tell me more',
      'explain that',
      'what does that mean',
      'can you elaborate',
      'more details',
      'continue',
      'go on',
      'and then',
      'also'
    ];

    const lowerPrompt = prompt.toLowerCase();
    return followUpIndicators.some(indicator => lowerPrompt.includes(indicator));
  }

  /**
   * End current conversation
   */
  endConversation() {
    const conv = this.currentConversation;
    this.currentConversation = null;
    this.conversationContext = [];
    return conv;
  }

  /**
   * Get current conversation
   */
  getCurrentConversation() {
    return this.currentConversation;
  }

  /**
   * Check if conversation is active
   */
  hasActiveConversation() {
    return this.currentConversation !== null;
  }
}
