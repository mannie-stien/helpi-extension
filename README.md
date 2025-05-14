# Intelligent Web Assistant Chrome Extension

An AI-powered assistant that provides:
- Page summarization
- Text explanation
- Word definitions
- Translation

## Features

- Floating button for easy access
- Context-aware responses
- Clean, minimal UI
- Secure API key storage

## Installation

1. Clone this repository
2. Open Chrome and go to `chrome://extensions`
3. Enable "Developer mode"
4. Click "Load unpacked" and select the extension folder

## Configuration

1. Click the extension icon
2. Enter your Together.ai API key
3. Click "Save Settings"

## Usage

1. Click the floating button to activate the assistant
2. Select text to see available actions
3. Choose to explain, define, or translate
4. Click "Summarize Page" for full page summaries

## API Key Security

The API key is stored securely using Chrome's `chrome.storage.local` API. It's never sent anywhere except to Together.ai's official API endpoint.

## Dependencies

- Together.ai API (mistralai/Mixtral-8x7B-Instruct-v0.1 model)
- Chrome Extension Manifest V3