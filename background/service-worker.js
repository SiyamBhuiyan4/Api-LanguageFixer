/**
 * BanglaWrite AI - Background Service Worker (Manifest V3)
 * Lightweight, event-driven, handles API calls, commands, and options.
 */

import { Storage } from '../utils/storage.js';
import { AIClient } from '../api/ai.js';

// Top-level command listener for keyboard shortcuts
chrome.commands.onCommand.addListener(async (command) => {
  if (command === 'rewrite-text') {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id && tab.url && !tab.url.startsWith('chrome://')) {
        await chrome.tabs.sendMessage(tab.id, {
          type: 'TRIGGER_REWRITE',
          source: 'CHROME_COMMAND'
        });
      }
    } catch (e) {
      // Content script may not be loaded yet or active tab is a restricted browser internal page
    }
  }
});

// Top-level message listener (Always returns true for async response)
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (!request || !request.type) {
    sendResponse({ success: false, error: 'Invalid request' });
    return false;
  }

  handleMessage(request, sender)
    .then((result) => sendResponse({ success: true, ...result }))
    .catch((err) => {
      sendResponse({ success: false, error: err.message || 'An unknown error occurred.' });
    });

  return true; // Crucial for asynchronous sendResponse in MV3
});

async function handleMessage(request, sender) {
  switch (request.type) {
    case 'REWRITE_REQUEST': {
      const settings = await Storage.getSettings();
      const mode = request.mode || settings.mode || 'natural';
      const text = request.text;

      const result = await AIClient.sendToAI(text, mode, settings);
      return { text: result.text };
    }

    case 'GET_SETTINGS': {
      const settings = await Storage.getSettings();
      const configured = await Storage.isConfigured();
      return { settings, configured };
    }

    case 'SAVE_SETTINGS': {
      const updated = await Storage.saveSettings(request.settings || {});
      const configured = await Storage.isConfigured();
      return { settings: updated, configured };
    }

    case 'CHECK_CONFIG': {
      const configured = await Storage.isConfigured();
      const settings = await Storage.getSettings();
      return { configured, provider: settings.provider, model: settings.model };
    }

    case 'OPEN_OPTIONS': {
      chrome.runtime.openOptionsPage();
      return { opened: true };
    }

    case 'TEST_CONNECTION': {
      const settings = request.settings || (await Storage.getSettings());
      const testText = 'kemon acho bondhu';
      const result = await AIClient.sendToAI(testText, 'natural', settings);
      return { success: true, text: result.text };
    }

    default:
      throw new Error(`Unknown message type: ${request.type}`);
  }
}
