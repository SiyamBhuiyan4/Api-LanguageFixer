/**
 * BanglaWrite AI - Popup Controller
 * Connects UI actions to background/content scripts and manages settings.
 */

import { Storage, PROVIDER_DEFAULTS } from '../utils/storage.js';

document.addEventListener('DOMContentLoaded', async () => {
  const modeSelect = document.getElementById('modeSelect');
  const apiStatusBanner = document.getElementById('apiStatusBanner');
  const apiStatusText = document.getElementById('apiStatusText');
  const configureLink = document.getElementById('configureLink');
  const rewriteSelectionBtn = document.getElementById('rewriteSelectionBtn');
  const rewriteFullBtn = document.getElementById('rewriteFullBtn');
  const settingsIconBtn = document.getElementById('settingsIconBtn');
  const openOptionsLink = document.getElementById('openOptionsLink');
  const shortcutKbd = document.getElementById('shortcutKbd');
  const feedbackMsg = document.getElementById('feedbackMsg');

  // Detect platform for shortcut display
  const isMac = typeof navigator !== 'undefined' && /Mac/i.test(navigator.platform || navigator.userAgent || '');
  if (shortcutKbd) {
    shortcutKbd.textContent = isMac ? '⌘ + Shift + B' : 'Ctrl + Shift + B';
  }

  // Load settings & check API status
  await refreshUI();

  // Mode change handler
  modeSelect.addEventListener('change', async () => {
    const selectedMode = modeSelect.value;
    await Storage.saveSettings({ mode: selectedMode });
    showFeedback('টোন মোড সংরক্ষিত হয়েছে', 'success');
  });

  // Settings links
  const openSettings = () => {
    chrome.runtime.sendMessage({ type: 'OPEN_OPTIONS' }, () => {
      window.close();
    });
  };

  if (settingsIconBtn) settingsIconBtn.addEventListener('click', openSettings);
  if (openOptionsLink) openOptionsLink.addEventListener('click', (e) => { e.preventDefault(); openSettings(); });
  if (configureLink) configureLink.addEventListener('click', openSettings);

  // Rewrite Selected Text
  if (rewriteSelectionBtn) {
    rewriteSelectionBtn.addEventListener('click', () => {
      triggerContentRewrite(true);
    });
  }

  // Rewrite Entire Field
  if (rewriteFullBtn) {
    rewriteFullBtn.addEventListener('click', () => {
      triggerContentRewrite(false);
    });
  }

  async function refreshUI() {
    try {
      const settings = await Storage.getSettings();
      if (modeSelect && settings.mode) {
        modeSelect.value = settings.mode;
      }

      const isConfig = await Storage.isConfigured();
      const provider = settings.provider || 'gemini';
      const providerName = PROVIDER_DEFAULTS[provider]?.name || provider.toUpperCase();

      if (isConfig) {
        apiStatusBanner.className = 'status-banner status-ready';
        apiStatusText.textContent = `API Ready (${providerName})`;
        configureLink.style.display = 'none';
      } else {
        apiStatusBanner.className = 'status-banner status-warning';
        apiStatusText.textContent = 'API Not Configured';
        configureLink.style.display = 'inline-block';
      }
    } catch (e) {
      apiStatusBanner.className = 'status-banner status-warning';
      apiStatusText.textContent = 'Configuration required';
    }
  }

  async function triggerContentRewrite(selectionOnly) {
    const isConfig = await Storage.isConfigured();
    if (!isConfig) {
      showFeedback('অনুগ্রহ করে আগে সেটিংসে API কী প্রদান করুন', 'error');
      setTimeout(openSettings, 800);
      return;
    }

    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab?.id || !tab.url || tab.url.startsWith('chrome://')) {
        showFeedback('ব্রাউজারের এই পৃষ্ঠায় কাজ করবে না', 'error');
        return;
      }

      chrome.tabs.sendMessage(tab.id, {
        type: 'TRIGGER_REWRITE',
        mode: modeSelect.value,
        selectionOnly,
        source: 'POPUP_BUTTON'
      }, (res) => {
        if (chrome.runtime.lastError) {
          showFeedback('কোনো টেক্সট বক্সে ক্লিক করুন', 'error');
        } else {
          showFeedback('অনুরোধ পাঠানো হয়েছে!', 'success');
          setTimeout(() => window.close(), 400);
        }
      });
    } catch (e) {
      showFeedback('সমস্যা হয়েছে: ' + e.message, 'error');
    }
  }

  function showFeedback(msg, type = 'success') {
    if (!feedbackMsg) return;
    feedbackMsg.textContent = msg;
    feedbackMsg.className = `feedback-msg feedback-${type}`;
    feedbackMsg.style.display = 'block';
    setTimeout(() => {
      feedbackMsg.style.display = 'none';
    }, 2500);
  }
});
