/**
 * BanglaWrite AI - Modular LLM API Client
 * Ultra-lightweight vanilla JS API client supporting:
 * - Google Gemini API
 * - OpenAI & OpenAI-compatible (Groq, Together AI, Ollama, DeepSeek)
 * - Anthropic Claude API
 */

export const TONE_MODES = {
  natural: {
    id: 'natural',
    name: 'Natural Bangla',
    instruction: 'Convert the input into natural, fluent, and human-sounding everyday Bengali. Keep it authentic and effortless without being overly stiff.'
  },
  polite: {
    id: 'polite',
    name: 'Polite',
    instruction: 'Make the text polite, respectful, and courteous (using respectful Bengali phrasing like "দয়া করে", "অনুরোধ", or "আপু/ভাইয়া" where contextually fitting) without sounding groveling.'
  },
  casual: {
    id: 'casual',
    name: 'Casual',
    instruction: 'Convert into relaxed, friendly, and informal conversational Bengali (উপযুক্ত ক্ষেত্রে তুমি/তুই নির্ভর), suitable for chatting with friends or close peers.'
  },
  professional: {
    id: 'professional',
    name: 'Professional',
    instruction: 'Rewrite with a polished, courteous, business-appropriate Bengali tone suitable for work, email, clients, or colleagues.'
  },
  formal: {
    id: 'formal',
    name: 'Formal',
    instruction: 'Use standard, official, and grammatically precise formal Bengali (প্রমিত সাধু/চলিত দাপ্তরিক ভাষা).'
  },
  short: {
    id: 'short',
    name: 'Short',
    instruction: 'Make the message concise, direct, and crisp in Bengali while preserving the complete core meaning.'
  },
  fix_grammar: {
    id: 'fix_grammar',
    name: 'Fix Grammar',
    instruction: 'Preserve the exact wording, style, and vocabulary as much as possible, only fixing spelling, grammatical errors, Bengali script conversion, and punctuation.'
  }
};

const SYSTEM_PROMPT_TEMPLATE = `You are "BanglaWrite AI", a specialized Bengali writing assistant and Banglish translator.

PRIMARY DIRECTIVES:
1. Convert Banglish (Bengali written in English/Latin letters, e.g. "ami ajke jete parbo na kalke gele ki hobe") or broken/informal Bengali into clean, grammatically correct Bengali script ("আমি আজকে যেতে পারব না। কালকে গেলে কি হবে?").
2. Strictly PRESERVE the user's intended meaning. Do NOT invent, assume, or add facts, claims, or information that the user did not express.
3. Preserve personal names, numbers/digits, URLs, usernames, email addresses, brand names, product titles, and common technical terms intact.
4. Tone Mode: {MODE_INSTRUCTION}
5. Clean Output Rule: Return ONLY the final rewritten Bengali text. Do NOT wrap in quotes. Do NOT include markdown code fences (\`\`\`). Do NOT include explanatory notes, introductions, or apologies.`;

export function buildPrompt(text, modeKey = 'natural') {
  const mode = TONE_MODES[modeKey] || TONE_MODES.natural;
  const systemPrompt = SYSTEM_PROMPT_TEMPLATE.replace('{MODE_INSTRUCTION}', mode.instruction);
  return {
    systemPrompt,
    userPrompt: text
  };
}

export const AIClient = {
  /**
   * Main unified entry point.
   * @param {string} text - User's input text (Banglish or informal Bengali)
   * @param {string} mode - Tone mode key ('natural', 'polite', etc.)
   * @param {object} config - User settings from chrome.storage
   * @returns {Promise<{ text: string }>}
   */
  async sendToAI(text, mode = 'natural', config = {}) {
    if (!text || !text.trim()) {
      throw new Error('Text is empty. Please select or enter text to rewrite.');
    }

    const provider = (config.provider || 'gemini').toLowerCase();
    const apiKey = (config.apiKey || '').trim();
    const endpoint = (config.endpoint || '').trim();
    const model = (config.model || '').trim();

    // Local Ollama does not require an API key
    if (!apiKey && provider !== 'ollama') {
      throw new Error(`API key is missing for ${provider.toUpperCase()}. Please configure it in extension Settings.`);
    }

    const { systemPrompt, userPrompt } = buildPrompt(text, mode);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
      controller.abort(new Error('Request timed out after 25 seconds.'));
    }, 25000);

    try {
      let rewrittenText = '';

      switch (provider) {
        case 'gemini':
          rewrittenText = await this._callGemini(userPrompt, systemPrompt, apiKey, endpoint, model, controller.signal);
          break;
        case 'openai':
        case 'groq':
        case 'ollama':
        case 'custom':
          rewrittenText = await this._callOpenAICompatible(userPrompt, systemPrompt, apiKey, endpoint, model, provider, controller.signal);
          break;
        case 'anthropic':
          rewrittenText = await this._callAnthropic(userPrompt, systemPrompt, apiKey, endpoint, model, controller.signal);
          break;
        default:
          throw new Error(`Unsupported API provider: ${provider}`);
      }

      // Clean any accidental markdown code wrappers or quotation marks
      let cleanResult = rewrittenText.trim();
      if (cleanResult.startsWith('```') && cleanResult.endsWith('```')) {
        cleanResult = cleanResult.replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
      }
      if ((cleanResult.startsWith('"') && cleanResult.endsWith('"')) || (cleanResult.startsWith('“') && cleanResult.endsWith('”'))) {
        cleanResult = cleanResult.slice(1, -1).trim();
      }

      return { text: cleanResult };
    } finally {
      clearTimeout(timeoutId);
    }
  },

  async _callGemini(userPrompt, systemPrompt, apiKey, endpoint, model, signal) {
    const selectedModel = model || 'gemini-1.5-flash';
    const baseUrl = endpoint || 'https://generativelanguage.googleapis.com/v1beta/models';
    const url = `${baseUrl.replace(/\/$/, '')}/${selectedModel}:generateContent`;

    const payload = {
      system_instruction: {
        parts: [{ text: systemPrompt }]
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: userPrompt }]
        }
      ],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 2048
      }
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey
      },
      body: JSON.stringify(payload),
      signal
    });

    if (!res.ok) {
      await this._handleHttpError(res, 'Google Gemini');
    }

    const data = await res.json();
    const candidate = data.candidates?.[0];
    const text = candidate?.content?.parts?.[0]?.text;

    if (!text) {
      throw new Error('Gemini returned an empty response. Please check your model or prompt.');
    }
    return text;
  },

  async _callOpenAICompatible(userPrompt, systemPrompt, apiKey, endpoint, model, provider, signal) {
    let url = endpoint;
    let defaultModel = 'gpt-4o-mini';

    if (provider === 'groq') {
      url = url || 'https://api.groq.com/openai/v1/chat/completions';
      defaultModel = 'llama-3.3-70b-versatile';
    } else if (provider === 'ollama') {
      url = url || 'http://localhost:11434/v1/chat/completions';
      defaultModel = 'llama3.2';
    } else {
      url = url || 'https://api.openai.com/v1/chat/completions';
    }

    const headers = { 'Content-Type': 'application/json' };
    if (apiKey) {
      headers['Authorization'] = `Bearer ${apiKey}`;
    }

    const payload = {
      model: model || defaultModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3
    };

    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal
    });

    if (!res.ok) {
      await this._handleHttpError(res, provider.toUpperCase());
    }

    const data = await res.json();
    const text = data.choices?.[0]?.message?.content;
    if (!text) {
      throw new Error(`${provider.toUpperCase()} returned an empty response.`);
    }
    return text;
  },

  async _callAnthropic(userPrompt, systemPrompt, apiKey, endpoint, model, signal) {
    const url = endpoint || 'https://api.anthropic.com/v1/messages';
    const selectedModel = model || 'claude-3-5-haiku-20241022';

    const headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    };

    const payload = {
      model: selectedModel,
      system: systemPrompt,
      messages: [
        { role: 'user', content: userPrompt }
      ],
      max_tokens: 2048,
      temperature: 0.3
    };

    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal
    });

    if (!res.ok) {
      await this._handleHttpError(res, 'Anthropic');
    }

    const data = await res.json();
    const textBlock = data.content?.find(c => c.type === 'text');
    if (!textBlock || !textBlock.text) {
      throw new Error('Anthropic returned an empty response.');
    }
    return textBlock.text;
  },

  async _handleHttpError(res, providerName) {
    let detail = '';
    try {
      const errJson = await res.json();
      detail = errJson.error?.message || errJson.message || JSON.stringify(errJson);
    } catch (e) {
      detail = await res.text().catch(() => '');
    }

    if (res.status === 401 || res.status === 403) {
      throw new Error(`${providerName} authentication failed. Check your API key. (${res.status})`);
    } else if (res.status === 429) {
      throw new Error(`${providerName} rate limit reached or quota exceeded. Please wait a moment. (${res.status})`);
    } else if (res.status === 404) {
      throw new Error(`${providerName} endpoint or model not found. Check endpoint & model name. (${res.status})`);
    } else if (res.status >= 500) {
      throw new Error(`${providerName} server error. Please try again later. (${res.status})`);
    }

    throw new Error(`${providerName} Error (${res.status}): ${detail || res.statusText}`);
  }
};
