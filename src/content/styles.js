/**
 * Styles for the SmartScribe Assistant
 * Provides styles for all UI components and states
 */
export const injectStyles = () => {
  const style = document.createElement("style");
  style.textContent = `
  /* Floating Button */
  .assistant-floating-button {
    position: fixed;
    bottom: 24px;
    right: 24px;
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: linear-gradient(135deg, #6e8efb, #a777e3);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    z-index: 9999;
    transition: all 0.3s ease;
    border: none;
    outline: none;
  }

  .assistant-floating-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
  }

  .assistant-floating-button.active {
    background: linear-gradient(135deg, #4CAF50, #2E7D32);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
  }

  /* Tooltip */
  .assistant-tooltip {
    position: absolute;
    width: 320px;
    max-width: 95vw;
    max-height: 70vh;
    border-radius: 12px;
    background: white;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    z-index: 10000;
    overflow: hidden;
    display: none;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    transition: opacity 0.2s ease, transform 0.2s ease;
    opacity: 0;
    transform: translateY(8px);
  }

  .assistant-tooltip.visible {
    display: flex;
    flex-direction: column;
    opacity: 1;
    transform: translateY(0);
  }

  .tooltip-header {
    padding: 12px 16px;
    background: linear-gradient(135deg, #6e8efb, #a777e3);
    color: white;
    font-weight: 600;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 16px;
  }

  .close-tooltip {
    background: none;
    border: none;
    color: white;
    font-size: 20px;
    cursor: pointer;
    padding: 0;
    line-height: 1;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: background-color 0.2s ease;
  }

  .close-tooltip:hover {
    background-color: rgba(255, 255, 255, 0.2);
  }

  .tooltip-content {
    padding: 16px;
    max-height: 350px;
    overflow-y: auto;
    flex-grow: 1;
    color: #333;
    font-size: 14px;
    line-height: 1.5;
  }

  .tooltip-content p {
    margin: 0 0 12px 0;
    line-height: 1.5;
    color: #333;
  }

  .tooltip-content em {
    font-style: italic;
    background-color: #f0f4ff;
    padding: 2px 4px;
    border-radius: 4px;
  }

  /* Action buttons - Dynamic grid based on number of context buttons */
  .action-buttons {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 8px;
    margin-top: 12px;
  }

  .tooltip-footer {
    padding: 12px 16px;
    border-top: 1px solid #eee;
    display: flex;
  }

  .action-buttons button, .summarize-btn {
    background: #f5f7ff;
    border: none;
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 13px;
    font-weight: 500;
    color: #5e7cea;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: center;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .action-buttons button:hover, .summarize-btn:hover {
    background: #e6ebff;
  }

  .summarize-btn {
    width: 100%;
    background: linear-gradient(135deg, #6e8efb, #a777e3);
    color: white;
  }

  .summarize-btn:hover {
    background: linear-gradient(135deg, #5e7cea, #9767d8);
  }

  /* Loading spinner */
  .loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid rgba(110, 142, 251, 0.2);
    border-radius: 50%;
    border-top-color: #6e8efb;
    animation: spin 1s ease-in-out infinite;
    margin: 0 auto 12px;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* Enhanced response styling for various content types */
  .response {
    line-height: 1.6;
  }

  .response h1, .response h2, .response h3 {
    margin-top: 16px;
    margin-bottom: 8px;
    color: #333;
    font-weight: 600;
  }

  .response h1 {
    font-size: 18px;
  }

  .response h2 {
    font-size: 16px;
  }

  .response h3 {
    font-size: 15px;
  }

  .response ul, .response ol {
    margin: 8px 0;
    padding-left: 20px;
  }

  .response li {
    margin-bottom: 4px;
  }

  .response .code-block {
    background-color: #f7f9fc;
    border-radius: 8px;
    padding: 12px;
    margin: 12px 0;
    overflow-x: auto;
    font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
    font-size: 13px;
    border-left: 3px solid #6e8efb;
  }

  .response code {
    font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
    background-color: #f5f7ff;
    padding: 2px 4px;
    border-radius: 4px;
    font-size: 13px;
  }

  /* Response action buttons */
  .response-actions {
    display: flex;
    gap: 8px;
    margin-top: 16px;
    justify-content: flex-end;
  }

  .response-actions button {
    background: #f5f7ff;
    border: none;
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 13px;
    font-weight: 500;
    color: #5e7cea;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .response-actions button:hover {
    background: #e6ebff;
  }

  .response-actions .copy-btn {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  /* Ask form styles */
  .ask-form {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .ask-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #dce1f9;
    border-radius: 8px;
    font-family: inherit;
    font-size: 14px;
    min-height: 80px;
    resize: vertical;
    transition: border-color 0.2s ease;
  }

  .ask-input:focus {
    outline: none;
    border-color: #6e8efb;
    box-shadow: 0 0 0 2px rgba(110, 142, 251, 0.1);
  }

  .ask-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }

  .ask-actions button {
    padding: 8px 14px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .cancel-ask {
    background-color: #f5f5f5;
    color: #666;
    border: none;
  }

  .cancel-ask:hover {
    background-color: #eaeaea;
  }

  .submit-ask {
    background: linear-gradient(135deg, #6e8efb, #a777e3);
    color: white;
    border: none;
  }

  .submit-ask:hover {
    background: linear-gradient(135deg, #5e7cea, #9767d8);
  }

  /* Context-specific button styling */
  .explain-code-btn, .debug-code-btn, .improve-code-btn {
    border-left: 3px solid #FF7043 !important;
  }

  .answer-btn, .solve-btn {
    border-left: 3px solid #4CAF50 !important;
  }

  .define-btn, .examples-btn {
    border-left: 3px solid #7E57C2 !important;
  }

  .summarize-text-btn, .key-points-btn {
    border-left: 3px solid #42A5F5 !important;
  }

  .translate-btn {
    border-left: 3px solid #26A69A !important;
  }

  /* Animation for tooltip appearances */
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
  }
  `;
  document.head.appendChild(style);
};