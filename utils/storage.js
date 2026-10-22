/**
 * BanglaWrite AI - Storage Management
 * Dual-tier storage (chrome.storage.sync with fallback to chrome.storage.local)
 * and in-memory fallback for test runners.
 */

export const PROVIDERS = {
  GEMINI: 'gemini',
  OPENAI: 'openai',
  GROQ: 'groq',
  OLLAMA: 'ollama',
  ANTHROPIC: 'anthropic',
  CUSTOM: 'custom'
};

export const PROVIDER_DEFAULTS = {
  [PROVIDERS.GEMINI]: {
    name: 'Google Gemini',
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/models',
    model: 'gemini-1.5-flash',
    requiresApiKey: true,
    helpUrl: 'https://aistudio.google.com/app/apikey'
  },
  [PROVIDERS.OPENAI]: {
    name: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    model: 'gpt-4o-mini',
    requiresApiKey: true,
    helpUrl: 'https://platform.openai.com/api-keys'
  },
  [PROVIDERS.GROQ]: {
    name: 'Groq (Ultra-Fast)',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    model: 'llama-3.3-70b-versatile',
    requiresApiKey: true,
    helpUrl: 'https://console.groq.com/keys'
  },
  [PROVIDERS.OLLAMA]: {
    name: 'Ollama (Local Offline)',
    endpoint: 'http://localhost:11434/v1/chat/completions',
    model: 'llama3.2',
    requiresApiKey: false,
    helpUrl: 'https://ollama.com'
  },
  [PROVIDERS.ANTHROPIC]: {
    name: 'Anthropic Claude',
    endpoint: 'https://api.anthropic.com/v1/messages',
    model: 'claude-3-5-haiku-20241022',
    requiresApiKey: true,
    helpUrl: 'https://console.anthropic.com'
  },
  [PROVIDERS.CUSTOM]: {
    name: 'Custom / OpenAI-Compatible',
    endpoint: '',
    model: '',
    requiresApiKey: false,
    helpUrl: ''
  }
};

export const TONES = [
  { id: 'natural', name: 'Natural Bangla' },
  { id: 'polite', name: 'Polite' },
  { id: 'casual', name: 'Casual' },
  { id: 'professional', name: 'Professional' },
  { id: 'formal', name: 'Formal' },
  { id: 'short', name: 'Short' },
  { id: 'fix_grammar', name: 'Fix Grammar' }
];

export function getDefaultSettings() {
  const isMac = typeof navigator !== 'undefined' && /Mac/i.test(navigator.userAgent || navigator.platform || '');
  return {
    provider: PROVIDERS.GEMINI,
    endpoint: PROVIDER_DEFAULTS[PROVIDERS.GEMINI].endpoint,
    apiKey: '',
    model: PROVIDER_DEFAULTS[PROVIDERS.GEMINI].model,
    mode: 'natural',
    shortcut: isMac ? 'Command+Shift+B' : 'Ctrl+Shift+B',
    providerConfigs: {
      [PROVIDERS.GEMINI]: {
        apiKey: '',
        endpoint: PROVIDER_DEFAULTS[PROVIDERS.GEMINI].endpoint,
        model: PROVIDER_DEFAULTS[PROVIDERS.GEMINI].model
      },
      [PROVIDERS.OPENAI]: {
        apiKey: '',
        endpoint: PROVIDER_DEFAULTS[PROVIDERS.OPENAI].endpoint,
        model: PROVIDER_DEFAULTS[PROVIDERS.OPENAI].model
      },
      [PROVIDERS.GROQ]: {
        apiKey: '',
        endpoint: PROVIDER_DEFAULTS[PROVIDERS.GROQ].endpoint,
        model: PROVIDER_DEFAULTS[PROVIDERS.GROQ].model
      },
      [PROVIDERS.OLLAMA]: {
        apiKey: '',
        endpoint: PROVIDER_DEFAULTS[PROVIDERS.OLLAMA].endpoint,
        model: PROVIDER_DEFAULTS[PROVIDERS.OLLAMA].model
      },
      [PROVIDERS.ANTHROPIC]: {
        apiKey: '',
        endpoint: PROVIDER_DEFAULTS[PROVIDERS.ANTHROPIC].endpoint,
        model: PROVIDER_DEFAULTS[PROVIDERS.ANTHROPIC].model
      },
      [PROVIDERS.CUSTOM]: {
        apiKey: '',
        endpoint: '',
        model: ''
      }
    }
  };
}

let syncDisabled = false;
const memoryMock = {};

async function storageGet(keys) {
  if (typeof chrome === 'undefined' || !chrome.storage) {
    if (typeof keys === 'string') return { [keys]: memoryMock[keys] };
    if (Array.isArray(keys)) {
      const res = {};
      keys.forEach(k => { res[k] = memoryMock[k]; });
      return res;
    }
    return { ...memoryMock };
  }

  if (!syncDisabled && chrome.storage.sync) {
    try {
      return await chrome.storage.sync.get(keys);
    } catch (e) {
      syncDisabled = true;
    }
  }
  return await chrome.storage.local.get(keys);
}

async function storageSet(items) {
  if (typeof chrome === 'undefined' || !chrome.storage) {
    Object.assign(memoryMock, items);
    return;
  }

  if (!syncDisabled && chrome.storage.sync) {
    try {
      await chrome.storage.sync.set(items);
    } catch (e) {
      syncDisabled = true;
    }
  }
  await chrome.storage.local.set(items);
}

export const Storage = {
  async getSettings() {
    const defaults = getDefaultSettings();
    try {
      const stored = await storageGet(Object.keys(defaults));
      const merged = {
        ...defaults,
        ...stored,
        providerConfigs: {
          ...defaults.providerConfigs,
          ...(stored.providerConfigs || {})
        }
      };

      // Keep active provider settings synchronized
      const activeProvider = merged.provider || PROVIDERS.GEMINI;
      if (merged.providerConfigs[activeProvider]) {
        if (!merged.apiKey && merged.providerConfigs[activeProvider].apiKey) {
          merged.apiKey = merged.providerConfigs[activeProvider].apiKey;
        }
        if (!merged.endpoint && merged.providerConfigs[activeProvider].endpoint) {
          merged.endpoint = merged.providerConfigs[activeProvider].endpoint;
        }
        if (!merged.model && merged.providerConfigs[activeProvider].model) {
          merged.model = merged.providerConfigs[activeProvider].model;
        }
      }

      return merged;
    } catch (e) {
      return defaults;
    }
  },

  async saveSettings(updates = {}) {
    const current = await this.getSettings();
    const nextProvider = updates.provider || current.provider;

    const providerConfigs = {
      ...current.providerConfigs,
      ...(updates.providerConfigs || {})
    };

    if (updates.provider && updates.provider !== current.provider) {
      // Switching provider: hydrate from saved provider config or provider defaults
      const targetConfig = providerConfigs[nextProvider] || {};
      const def = PROVIDER_DEFAULTS[nextProvider] || {};
      updates.endpoint = updates.endpoint ?? (targetConfig.endpoint || def.endpoint || '');
      updates.model = updates.model ?? (targetConfig.model || def.model || '');
      updates.apiKey = updates.apiKey ?? (targetConfig.apiKey || '');
    } else {
      // Saving fields for current provider: update map
      providerConfigs[nextProvider] = {
        apiKey: updates.apiKey !== undefined ? updates.apiKey.trim() : current.apiKey,
        endpoint: updates.endpoint !== undefined ? updates.endpoint.trim() : current.endpoint,
        model: updates.model !== undefined ? updates.model.trim() : current.model
      };
    }

    const merged = {
      ...current,
      ...updates,
      provider: nextProvider,
      providerConfigs
    };

    if (merged.apiKey) merged.apiKey = merged.apiKey.trim();
    if (merged.endpoint) merged.endpoint = merged.endpoint.trim();
    if (merged.model) merged.model = merged.model.trim();

    await storageSet(merged);
    return merged;
  },

  async isConfigured() {
    const settings = await this.getSettings();
    const provider = settings.provider || PROVIDERS.GEMINI;
    const reqKey = PROVIDER_DEFAULTS[provider]?.requiresApiKey;

    if (reqKey && (!settings.apiKey || !settings.apiKey.trim())) {
      return false;
    }
    return Boolean(settings.endpoint && settings.model);
  }
};
