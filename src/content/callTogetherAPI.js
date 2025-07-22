/**
 * Calls the Together.ai API with the given prompt (automatically gets API key from storage)
 * @param {string} prompt - The prompt to send to the API
 * @param {object} [options] - Optional configuration
 * @returns {Promise<string>} - The generated text response
 * @throws {Error} - If the API request fails or API key is missing
 */
export async function callTogetherAPI(prompt, options = {}) {
  if (!prompt?.trim()) {
    throw new Error("Prompt cannot be empty");
  }

  // Get API key from Chrome storage
  const { togetherApiKey: apiKey } = await new Promise((resolve) => {
    chrome.storage.local.get(['togetherApiKey'], resolve);
  });

  if (!apiKey) {
    throw new Error("API key not found in storage");
  }
  console.log("Using API key:", apiKey);

  // Default configuration
  const config = {
    endpoint: "https://api.together.xyz/inference",
    model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
    params: {
      temperature: 0.7,
      top_p: 0.7, 
      top_k: 50,
      repetition_penalty: 1,
      stop: ["</s>"],
      ...options.params
    },
    ...options
  };

  try {
    const response = await fetch(config.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: config.model,
        prompt,
        ...config.params
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.error?.message ||
        `API request failed with status ${response.status}`
      );
    }

    const data = await response.json();
    
    return (
      data.output?.choices?.[0]?.text ||
      data.choices?.[0]?.text || 
      data.output ||
      "Sorry, I couldn't process the API response."
    );
  } catch (error) {
    console.error("API call failed:", error);
    throw error;
  }
}

// Usage example:
// const response = await callTogetherAPI("Explain quantum computing");