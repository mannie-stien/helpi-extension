# Helpi - AI Assistant Chrome Extension

**Version 0.2.0** - Enhanced with multi-provider support, conversation memory, and advanced features

An intelligent AI-powered assistant that provides context-aware help for any text on the web.

## ✨ Key Features

### 🎯 Context-Aware Actions
- **Smart Detection**: Automatically detects content type (code, math, questions, terms, etc.)
- **Dynamic Actions**: Shows relevant actions based on what you select
- **Multi-Language Support**: Translate foreign text instantly

### 🤖 Multi-Provider AI Support
- **Together.ai** (Mixtral, Llama 2)
- **OpenAI** (GPT-4, GPT-3.5)
- **Anthropic** (Claude 3 Opus, Sonnet, Haiku)
- **Google AI** (Gemini Pro)

### 💬 Conversation Memory
- **Follow-up Questions**: Continue conversations with context
- **Conversation History**: Access past interactions
- **Smart Context**: AI remembers previous exchanges

### ⚡ Performance Features
- **Response Caching**: Instant results for repeated queries
- **Retry Logic**: Automatic retry with exponential backoff
- **Error Recovery**: Graceful error handling with retry options
- **Request Timeout**: 30-second timeout with abort capability

### ⌨️ Keyboard Shortcuts
- `Ctrl+Shift+H` (Mac: `Cmd+Shift+H`) - Toggle assistant
- `Ctrl+Shift+E` (Mac: `Cmd+Shift+E`) - Quick explain
- `Ctrl+Shift+S` (Mac: `Cmd+Shift+S`) - Summarize page
- `Ctrl+Shift+T` - Translate selection
- `Ctrl+Shift+D` - Define term
- `Ctrl+Shift+Y` - Show history
- `Escape` - Close tooltip

### 📊 Advanced Features
- **History Management**: View, search, and clear conversation history
- **Side Panel UI**: Extended conversation interface with full chat experience
- **Visual Content Support**: Detect and analyze images, charts, diagrams, and SVGs
- **PDF Detection**: Identify PDF content (text extraction coming soon)
- **Page Summarization**: Intelligent full-page summaries
- **Code Analysis**: Explain, improve, and debug code
- **Math Solver**: Solve equations with step-by-step explanations
- **Enhanced Context Detection**: SQL, JSON/YAML/XML, regex, URLs, dates, emails

## 🚀 Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/helpi-extension.git
   cd helpi-extension
   ```

2. Open Chrome and navigate to `chrome://extensions`

3. Enable **Developer mode** (toggle in top-right corner)

4. Click **Load unpacked** and select the extension folder

5. The extension icon should appear in your toolbar

## ⚙️ Configuration

### Default Setup (Together.ai)
The extension comes pre-configured with a Together.ai API key. You can start using it immediately!

### Adding Additional Providers
1. Click the Helpi extension icon
2. Select your preferred AI provider
3. Enter your API key for that provider
4. The extension will automatically use your selected provider

### Getting API Keys
- **Together.ai**: [https://together.ai](https://together.ai)
- **OpenAI**: [https://platform.openai.com](https://platform.openai.com)
- **Anthropic**: [https://console.anthropic.com](https://console.anthropic.com)
- **Google AI**: [https://makersuite.google.com](https://makersuite.google.com)

## 📖 Usage

### Basic Usage
1. **Activate**: The assistant is active by default on all pages
2. **Select Text**: Highlight any text on a webpage
3. **Choose Action**: Click one of the context-aware action buttons
4. **View Response**: Read the AI's response in the tooltip

### Context-Aware Actions

Depending on what you select, you'll see different actions:

- **Code**: Explain Code, Improve Code, Debug Code
- **SQL**: Explain query, optimize, debug
- **JSON/YAML/XML**: Parse, validate, explain structure
- **Math**: Solve, Explain Steps
- **Questions**: Answer Question, Explain Concept
- **Terms**: Define, Explain, Give Examples
- **Foreign Text**: Translate
- **Paragraphs**: Summarize, Explain, Key Points
- **Images/Charts/Diagrams**: Describe, Analyze, Explain (OCR coming soon)
- **URLs**: Explain, validate
- **Dates/Emails**: Format, validate
- **Regex**: Explain pattern, test, debug
- **General**: Explain, Define, Translate

### Advanced Features

#### Follow-up Questions
1. After getting a response, click **Follow-up**
2. Ask additional questions with full conversation context
3. The AI remembers previous exchanges

#### Conversation History
1. Click the **History** button (📜) in the tooltip header
2. Browse past conversations
3. Click any conversation to view details
4. Clear history when needed

#### Page Summarization
1. Click **Summarize Page** in the tooltip footer
2. Get an intelligent summary of the entire page
3. Works best on article pages and documentation

#### Custom Questions
1. Select text and click **Ask AI**
2. Type your custom question
3. Get contextual answers based on the selection

#### Side Panel Interface
1. Click **Side Panel** button in the tooltip
2. Opens a dedicated chat interface
3. Extended conversations with full history
4. Better for longer interactions and complex queries
5. Persistent across page navigation

#### Visual Content Analysis
1. Select or click on images, charts, or diagrams
2. Get specialized actions: Describe, Analyze, Explain Chart
3. AI analyzes visual context and provides insights
4. Works with:
   - **Images** (IMG tags) - description and analysis
   - **Canvas** (charts, graphs) - chart type and data insights
   - **SVG** (diagrams, icons) - structure and meaning
   - **PDF** detection (extraction coming soon)

#### Enhanced Content Detection
Helpi now detects and provides specialized actions for:
- **SQL Queries**: Optimization and explanation
- **JSON/YAML/XML**: Structure validation and parsing
- **Regular Expressions**: Pattern explanation and testing
- **URLs**: Link validation and explanation
- **Dates**: Format detection and conversion
- **Email Addresses**: Validation

## 🔒 Security & Privacy

- **Local Storage**: API keys stored securely in Chrome's local storage
- **No Tracking**: No analytics or user tracking
- **Direct API Calls**: Requests go directly to AI providers
- **Cache Control**: Optional response caching (can be disabled)
- **History Management**: Full control over conversation history

## 🛠️ Technical Details

### Architecture
- **Manifest V3**: Modern Chrome extension architecture
- **Service Worker**: Background processing with keep-alive
- **Content Scripts**: Injected into all web pages
- **Modular Design**: Separate modules for API, detection, UI, etc.

### Key Components
- `background.js` - Service worker with API key management
- `assistant.js` - Main assistant class with UI logic
- `callTogetherAPI.js` - Multi-provider API client
- `apiProviders.js` - Provider configurations
- `detectContext.js` - Content type detection (13+ types)
- `conversationManager.js` - Conversation memory
- `keyboardShortcuts.js` - Keyboard shortcut handling
- `visualContentHandler.js` - Image/chart/diagram analysis
- `sidepanel/` - Side panel UI for extended conversations

### Error Handling
- Automatic retry with exponential backoff (3 attempts)
- Rate limiting detection and handling
- Timeout protection (30 seconds)
- User-friendly error messages
- Manual retry option on failures

### Performance Optimizations
- Response caching (1-hour TTL)
- Request deduplication
- Lazy loading of modules
- Efficient DOM manipulation
- Memory-conscious history management

## 🎨 Customization

### Preferences
Access preferences through the extension popup:
- **Default Provider**: Choose your preferred AI provider
- **Cache Responses**: Enable/disable response caching
- **Assistant Visibility**: Toggle the assistant on/off
- **Keyboard Shortcuts**: Customize shortcuts (via Chrome settings)

### Keyboard Shortcuts
Customize shortcuts in Chrome:
1. Go to `chrome://extensions/shortcuts`
2. Find "Helpi" in the list
3. Click the edit icon to change shortcuts

## 🐛 Troubleshooting

### Assistant Not Appearing
- Check if the toggle is enabled in the extension popup
- Refresh the page after enabling
- Check browser console for errors

### API Errors
- Verify your API key is correct
- Check your API provider account has credits
- Try switching to a different provider
- Use the retry button if available

### Slow Responses
- Check your internet connection
- Try a different AI provider
- Clear the response cache
- Some models are slower than others

### History Not Saving
- Check Chrome storage permissions
- Clear and restart if storage is full
- History has a 100-item limit by default

## 📝 Changelog

### Version 0.3.0 (Current)
- 🖼️ **Visual content support** (images, charts, diagrams, SVG)
- 🎨 **Side panel UI** for extended conversations
- 📄 **PDF detection** and content handling
- 🔍 **Enhanced context detection** (SQL, JSON, regex, URLs, dates, emails)
- 🎯 **13+ content types** with specialized actions
- ✨ Multi-provider AI support (OpenAI, Anthropic, Google)
- 💬 Conversation memory and follow-up questions
- 📊 Conversation history with search
- ⚡ Response caching and performance improvements
- ⌨️ Keyboard shortcuts
- 🔄 Retry logic with exponential backoff
- 🎯 Enhanced error handling
- 🛠️ Improved code architecture

### Version 0.2.0
- Multi-provider AI support
- Conversation memory
- History management
- Keyboard shortcuts

### Version 0.1.2
- Initial release with Together.ai support
- Context-aware action buttons
- Basic text operations
- Page summarization

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

MIT License - feel free to use and modify as needed.

## 🙏 Credits

- Built with Chrome Extension Manifest V3
- Powered by Together.ai, OpenAI, Anthropic, and Google AI
- Created by Mannie

## 🔮 Roadmap

### In Progress
- [x] Side panel UI for extended conversations ✅
- [x] Visual content detection (images, charts, diagrams) ✅
- [x] Enhanced context detection (SQL, JSON, regex, etc.) ✅
- [x] PDF detection ✅

### Planned Features
- [ ] OCR text extraction from images (Google Vision API / Tesseract.js)
- [ ] PDF text extraction and analysis
- [ ] Custom action templates with variables
- [ ] Export conversations to markdown/PDF
- [ ] Streaming responses for faster feedback
- [ ] Local model support (Ollama, LM Studio)
- [ ] Voice input and text-to-speech
- [ ] Team collaboration features
- [ ] Browser sync across devices
- [ ] Advanced analytics dashboard
- [ ] Browser extension for Firefox and Edge
- [ ] Mobile companion app