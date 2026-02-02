/**
 * Keyboard Shortcuts Manager for Helpi
 */

export class KeyboardShortcutsManager {
  constructor(assistant) {
    this.assistant = assistant;
    this.enabled = true;
    this.shortcuts = new Map();
    this.setupDefaultShortcuts();
  }

  setupDefaultShortcuts() {
    // Toggle assistant
    this.registerShortcut('ctrl+shift+h', () => {
      this.assistant.toggleAssistant();
    }, 'Toggle assistant on/off');

    // Quick explain
    this.registerShortcut('ctrl+shift+e', () => {
      if (this.assistant.currentSelection) {
        this.assistant.handleExplain();
      }
    }, 'Explain selected text');

    // Quick translate
    this.registerShortcut('ctrl+shift+t', () => {
      if (this.assistant.currentSelection) {
        this.assistant.handleTranslate();
      }
    }, 'Translate selected text');

    // Quick define
    this.registerShortcut('ctrl+shift+d', () => {
      if (this.assistant.currentSelection) {
        this.assistant.handleDefine();
      }
    }, 'Define selected term');

    // Summarize page
    this.registerShortcut('ctrl+shift+s', () => {
      this.assistant.summarizePage();
    }, 'Summarize current page');

    // Show history
    this.registerShortcut('ctrl+shift+y', () => {
      this.assistant.showHistory();
    }, 'Show conversation history');

    // Close tooltip
    this.registerShortcut('escape', () => {
      this.assistant.hideTooltip();
    }, 'Close tooltip');
  }

  registerShortcut(keys, callback, description) {
    this.shortcuts.set(keys, { callback, description });
  }

  unregisterShortcut(keys) {
    this.shortcuts.delete(keys);
  }

  handleKeyPress(event) {
    if (!this.enabled) return;

    const keys = [];
    if (event.ctrlKey || event.metaKey) keys.push('ctrl');
    if (event.shiftKey) keys.push('shift');
    if (event.altKey) keys.push('alt');
    keys.push(event.key.toLowerCase());

    const shortcut = keys.join('+');
    const handler = this.shortcuts.get(shortcut);

    if (handler) {
      event.preventDefault();
      event.stopPropagation();
      handler.callback();
    }
  }

  enable() {
    this.enabled = true;
  }

  disable() {
    this.enabled = false;
  }

  getShortcuts() {
    return Array.from(this.shortcuts.entries()).map(([keys, { description }]) => ({
      keys,
      description
    }));
  }

  init() {
    document.addEventListener('keydown', (e) => this.handleKeyPress(e), true);
  }
}
