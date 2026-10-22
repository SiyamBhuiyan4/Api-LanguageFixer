/**
 * BanglaWrite AI - Options Page Controller
 * Manages configuration, provider presets, credential persistence, and live connection testing.
 */

import { Storage, PROVIDERS, PROVIDER_DEFAULTS } from '../utils/storage.js';
import { AIClient } from '../api/ai.js';

document.addEventListener('DOMContentLoaded', async () => {
  // Elements
  const form = document.getElementById('settingsForm');
  const providerSelect = document.getElementById('providerSelect');
  const apiKeyRow = document.getElementById('apiKeyRow');
  const apiKeyInput = document.getElementById('apiKeyInput');
  const apiKeyLabel = document.getElementById('apiKeyLabel');
  const apiKeyHelpLink = document.getElementById('apiKeyHelpLink');
  const toggleKeyVisibility = document.getElementById('toggleKeyVisibility');
  const modelInput = document.getElementById('modelInput');
  const endpointInput = document.getElementById('endpointInput');
  const defaultModeSelect = document.getElementById('defaultModeSelect');
  const testBtn = document.getElementById('testBtn');
  const saveBtn = document.getElementById('saveBtn');
  const testResultBox = document.getElementById('testResultBox');
  const testResultTitle = document.getElementById('testResultTitle');
  const testResultIcon = document.getElementById('testResultIcon');
  const testResultContent = document.getElementById('testResultContent');
  const headerStatusText = document.getElementById('headerStatusText');
  const headerBadge = document.querySelector('.header-badge');
  const macShortcutKbd = document.getElementById('macShortcutKbd');

  // OS Detection
  const isMac = typeof navigator !== 'undefined' && /Mac/i.test(navigator.platform || navigator.userAgent || '');
  if (macShortcutKbd) {
    macShortcutKbd.textContent = isMac ? 'Command + Shift + B' : 'Ctrl + Shift + B';
  }

  // Load existing settings
  let currentSettings = await Storage.getSettings();
  populateForm(currentSettings);
  updateStatusBadge();

  // Provider change listener
  providerSelect.addEventListener('change', async () => {
    const newProvider = providerSelect.value;
    const def = PROVIDER_DEFAULTS[newProvider] || {};

    // Retrieve any previously saved configuration for this provider
    const savedConfig = currentSettings.providerConfigs?.[newProvider] || {};

    modelInput.value = savedConfig.model || def.model || '';
    endpointInput.value = savedConfig.endpoint || def.endpoint || '';
    apiKeyInput.value = savedConfig.apiKey || '';

    updateProviderUI(newProvider);
  });

  // Toggle API Key Visibility
  toggleKeyVisibility.addEventListener('click', () => {
    if (apiKeyInput.type === 'password') {
      apiKeyInput.type = 'text';
      toggleKeyVisibility.textContent = '🙈';
    } else {
      apiKeyInput.type = 'password';
      toggleKeyVisibility.textContent = '👁️';
    }
  });

  // Form submission (Save)
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    await saveCurrentSettings();
  });

  // Test connection
  testBtn.addEventListener('click', async () => {
    await runConnectionTest();
  });

  function populateForm(settings) {
    providerSelect.value = settings.provider || PROVIDERS.GEMINI;
    modelInput.value = settings.model || '';
    endpointInput.value = settings.endpoint || '';
    apiKeyInput.value = settings.apiKey || '';
    defaultModeSelect.value = settings.mode || 'natural';

    updateProviderUI(providerSelect.value);
  }

  function updateProviderUI(provider) {
    const def = PROVIDER_DEFAULTS[provider] || {};

    if (def.helpUrl) {
      apiKeyHelpLink.href = def.helpUrl;
      apiKeyHelpLink.style.display = 'inline';
      apiKeyHelpLink.textContent = `${def.name} API কী সংগ্রহ করুন ↗`;
    } else {
      apiKeyHelpLink.style.display = 'none';
    }

    if (provider === 'ollama') {
      apiKeyRow.style.opacity = '0.6';
      apiKeyInput.placeholder = 'Ollama-র জন্য সাধারণত কোনো কী দরকার নেই';
    } else {
      apiKeyRow.style.opacity = '1';
      apiKeyInput.placeholder = 'আপনার API কী এখানে পেস্ট করুন';
    }
  }

  async function updateStatusBadge() {
    const isConfig = await Storage.isConfigured();
    if (isConfig) {
      headerBadge.className = 'header-badge badge-ready';
      headerStatusText.textContent = 'সংযুক্ত ও সক্রিয় (Ready)';
    } else {
      headerBadge.className = 'header-badge';
      headerStatusText.textContent = 'কনফিগারেশন বাকি (Not configured)';
    }
  }

  async function saveCurrentSettings() {
    saveBtn.disabled = true;
    saveBtn.textContent = 'সংরক্ষণ হচ্ছে...';

    const provider = providerSelect.value;
    const apiKey = apiKeyInput.value.trim();
    const endpoint = endpointInput.value.trim();
    const model = modelInput.value.trim();
    const mode = defaultModeSelect.value;

    try {
      currentSettings = await Storage.saveSettings({
        provider,
        apiKey,
        endpoint,
        model,
        mode
      });

      await updateStatusBadge();

      showTestResult('success', 'সাফল্য!', 'সেটিংস সফলভাবে সংরক্ষিত হয়েছে। আপনি এখন যেকোনো ওয়েবসাইটে শর্টকাট দিয়ে ব্যবহার করতে পারেন।');
    } catch (err) {
      showTestResult('error', 'ত্রুটি', 'সেটিংস সংরক্ষণ করতে ব্যর্থ হয়েছে: ' + err.message);
    } finally {
      saveBtn.disabled = false;
      saveBtn.textContent = '💾 সেটিংস সংরক্ষণ করুন (Save Settings)';
    }
  }

  async function runConnectionTest() {
    testBtn.disabled = true;
    testBtn.textContent = 'পরীক্ষা চলছে...';

    const provider = providerSelect.value;
    const apiKey = apiKeyInput.value.trim();
    const endpoint = endpointInput.value.trim();
    const model = modelInput.value.trim();

    if (!apiKey && provider !== 'ollama') {
      showTestResult('error', 'API কী অনুপস্থিত', 'অনুগ্রহ করে প্রথমে আপনার API কী প্রবেশ করান।');
      testBtn.disabled = false;
      testBtn.textContent = '🧪 টেস্ট কানেকশন (Test Connection)';
      return;
    }

    showTestResult('testing', 'সংযোগ পরীক্ষা হচ্ছে...', `মডেল "${model}" এর কাছে একটি পরীক্ষামূলক অনুরোধ পাঠানো হচ্ছে...`);

    const testConfig = {
      provider,
      apiKey,
      endpoint,
      model
    };

    const testInput = 'kire kemon achos kobe ashbi';

    try {
      const result = await AIClient.sendToAI(testInput, 'natural', testConfig);

      showTestResult(
        'success',
        'কানেকশন সফল!',
        `ইনপুট: "${testInput}"\nআউটপুট: "${result.text}"\n\nঅভিনন্দন! আপনার API সংযোগ নিখুঁতভাবে কাজ করছে।`
      );
    } catch (err) {
      showTestResult(
        'error',
        'কানেকশন ব্যর্থ হয়েছে',
        `সমস্যা: ${err.message}\n\nপরামর্শ: এন্ডপয়েন্ট ইউআরএল, মডেলের নাম এবং API কী সঠিক আছে কিনা পুনরায় যাচাই করুন।`
      );
    } finally {
      testBtn.disabled = false;
      testBtn.textContent = '🧪 টেস্ট কানেকশন (Test Connection)';
    }
  }

  function showTestResult(type, title, message) {
    testResultBox.className = `test-result-box ${type}`;
    testResultTitle.textContent = title;
    testResultContent.textContent = message;

    if (type === 'success') testResultIcon.textContent = '✅';
    else if (type === 'error') testResultIcon.textContent = '❌';
    else testResultIcon.textContent = '⏳';

    testResultBox.style.display = 'block';
  }
});
