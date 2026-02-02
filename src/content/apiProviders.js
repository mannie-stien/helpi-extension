/**
 * Multi-Provider API Support for Helpi
 * Supports Together.ai, OpenAI, Anthropic, and more
 */

export const API_PROVIDERS = {
  TOGETHER: 'together',
  OPENAI: 'openai',
  ANTHROPIC: 'anthropic',
  GOOGLE: 'google'
};

export const PROVIDER_CONFIGS = {
  [API_PROVIDERS.TOGETHER]: {
    name: 'Together.ai',
    endpoint: 'https://api.together.xyz/inference',
    models: [
      { id: 'mistralai/Mixtral-8x7B-Instruct-v0.1', name: 'Mixtral 8x7B' },
      { id: 'meta-llama/Llama-2-70b-chat-hf', name: 'Llama 2 70B' },
      { id: 'NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO', name: 'Nous Hermes 2' }
    ],
    defaultModel: 'mistralai/Mixtral-8x7B-Instruct-v0.1',
    formatRequest: (prompt, model, params) => ({
      model,
      prompt,
      temperature: params.temperature || 0.7,
      top_p: params.top_p || 0.7,
      top_k: params.top_k || 50,
      repetition_penalty: params.repetition_penalty || 1,
      stop: params.stop || ['</s>'],
      max_tokens: params.max_tokens || 2048
    }),
    formatHeaders: (apiKey) => ({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    }),
    extractResponse: (data) => {
      return data.output?.choices?.[0]?.text ||
             data.choices?.[0]?.text ||
             data.output ||
             null;
    }
  },
  
  [API_PROVIDERS.OPENAI]: {
    name: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    models: [
      { id: 'gpt-4-turbo-preview', name: 'GPT-4 Turbo' },
      { id: 'gpt-4', name: 'GPT-4' },
      { id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo' }
    ],
    defaultModel: 'gpt-3.5-turbo',
    formatRequest: (prompt, model, params) => ({
      model,
      messages: [{ role: 'user', content: prompt }],
      temperature: params.temperature || 0.7,
      max_tokens: params.max_tokens || 2048,
      top_p: params.top_p || 1,
      frequency_penalty: params.frequency_penalty || 0,
      presence_penalty: params.presence_penalty || 0
    }),
    formatHeaders: (apiKey) => ({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    }),
    extractResponse: (data) => {
      return data.choices?.[0]?.message?.content || null;
    }
  },
  
  [API_PROVIDERS.ANTHROPIC]: {
    name: 'Anthropic',
    endpoint: 'https://api.anthropic.com/v1/messages',
    models: [
      { id: 'claude-3-opus-20240229', name: 'Claude 3 Opus' },
      { id: 'claude-3-sonnet-20240229', name: 'Claude 3 Sonnet' },
      { id: 'claude-3-haiku-20240307', name: 'Claude 3 Haiku' }
    ],
    defaultModel: 'claude-3-sonnet-20240229',
    formatRequest: (prompt, model, params) => ({
      model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: params.max_tokens || 2048,
      temperature: params.temperature || 0.7
    }),
    formatHeaders: (apiKey) => ({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    }),
    extractResponse: (data) => {
      return data.content?.[0]?.text || null;
    }
  },
  
  [API_PROVIDERS.GOOGLE]: {
    name: 'Google AI',
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/models',
    models: [
      { id: 'gemini-pro', name: 'Gemini Pro' },
      { id: 'gemini-pro-vision', name: 'Gemini Pro Vision' }
    ],
    defaultModel: 'gemini-pro',
    formatRequest: (prompt, model, params) => ({
      contents: [{
        parts: [{ text: prompt }]
      }],
      generationConfig: {
        temperature: params.temperature || 0.7,
        maxOutputTokens: params.max_tokens || 2048,
        topP: params.top_p || 0.95,
        topK: params.top_k || 40
      }
    }),
    formatHeaders: (apiKey) => ({
      'Content-Type': 'application/json'
    }),
    formatEndpoint: (endpoint, model, apiKey) => {
      return `${endpoint}/${model}:generateContent?key=${apiKey}`;
    },
    extractResponse: (data) => {
      return data.candidates?.[0]?.content?.parts?.[0]?.text || null;
    }
  }
};

/**
 * Get provider configuration
 */
export function getProviderConfig(provider) {
  const config = PROVIDER_CONFIGS[provider];
  if (!config) {
    throw new Error(`Unknown provider: ${provider}`);
  }
  return config;
}

/**
 * Get all available providers
 */
export function getAvailableProviders() {
  return Object.keys(PROVIDER_CONFIGS).map(key => ({
    id: key,
    name: PROVIDER_CONFIGS[key].name,
    models: PROVIDER_CONFIGS[key].models
  }));
}

/**
 * Validate provider and model
 */
export function validateProviderModel(provider, model) {
  const config = getProviderConfig(provider);
  if (model && !config.models.find(m => m.id === model)) {
    return {
      valid: false,
      error: `Model ${model} not available for provider ${provider}`
    };
  }
  return { valid: true };
}
