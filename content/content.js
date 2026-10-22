/**
 * BanglaWrite AI - Content Script
 * Handles text detection, selection, in-place AI rewriting, and HUD feedback.
 * Zero external dependencies. Ultra-lightweight for optimal hardware performance.
 */

(() => {
  // Prevent duplicate script execution
  if (window.__BANGLAWRITE_INJECTED__) return;
  window.__BANGLAWRITE_INJECTED__ = true;

  const isMac = typeof navigator !== 'undefined' && /Mac/i.test(navigator.platform || navigator.userAgent || '');
  const DEDUP_THRESHOLD_MS = 600;
  let lastTriggerTimestamp = 0;
  let isRewriting = false;

  /* ==========================================================================
     1. SHADOW DOM HUD (Heads-Up Display) NOTIFICATION SYSTEM
     ========================================================================== */

  class BanglaWriteHUD {
    constructor() {
      this.host = null;
      this.shadow = null;
      this.toastEl = null;
      this.dismissTimer = null;
      this._init();
    }

    _init() {
      if (document.getElementById('banglawrite-hud-root')) {
        this.host = document.getElementById('banglawrite-hud-root');
        this.shadow = this.host.shadowRoot;
        this.toastEl = this.shadow?.querySelector('.bw-toast');
        return;
      }

      this.host = document.createElement('div');
      this.host.id = 'banglawrite-hud-root';
      this.shadow = this.host.attachShadow({ mode: 'open' });

      const style = document.createElement('style');
      style.textContent = `
        *, *::before, *::after {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
        }
        :host {
          all: initial;
        }
        .bw-container {
          position: fixed;
          bottom: 24px;
          right: 24px;
          pointer-events: none;
          z-index: 2147483647;
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 8px;
        }
        .bw-toast {
          pointer-events: auto;
          display: inline-flex;
          align-items: center;
          gap: 10px;
          padding: 9px 16px;
          border-radius: 9999px;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Hind Siliguri", "Kalpurush", sans-serif;
          font-size: 13px;
          font-weight: 500;
          line-height: 1.4;
          color: #f8fafc;
          background: rgba(15, 23, 42, 0.94);
          border: 1px solid rgba(255, 255, 255, 0.14);
          box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4), 0 8px 10px -6px rgba(0, 0, 0, 0.2);
          opacity: 0;
          transform: translateY(8px) scale(0.96);
          transition: opacity 0.2s ease, transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.2s ease;
          user-select: none;
          white-space: nowrap;
          contain: content;
        }
        .bw-toast.bw-visible {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
        .bw-state-loading { border-color: rgba(99, 102, 241, 0.4); }
        .bw-state-success { border-color: rgba(34, 197, 94, 0.4); }
        .bw-state-warning { border-color: rgba(245, 158, 11, 0.4); }
        .bw-state-error   { border-color: rgba(239, 68, 68, 0.4); }

        .bw-icon-wrap {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 16px;
          height: 16px;
          flex-shrink: 0;
        }
        .bw-spinner {
          width: 14px;
          height: 14px;
          border: 2px solid rgba(255, 255, 255, 0.2);
          border-top-color: #818cf8;
          border-radius: 50%;
          animation: bw-spin 0.7s linear infinite;
        }
        @keyframes bw-spin {
          to { transform: rotate(360deg); }
        }
        .bw-brand {
          font-weight: 700;
          color: #34d399;
          margin-right: 4px;
        }
        .bw-msg {
          color: #f1f5f9;
        }
        .bw-kbd {
          display: inline-block;
          padding: 1px 5px;
          font-size: 11px;
          font-weight: 600;
          color: #cbd5e1;
          background: rgba(255, 255, 255, 0.12);
          border: 1px solid rgba(255, 255, 255, 0.18);
          border-radius: 4px;
          margin-left: 4px;
        }
      `;

      const container = document.createElement('div');
      container.className = 'bw-container';

      this.toastEl = document.createElement('div');
      this.toastEl.className = 'bw-toast';

      container.appendChild(this.toastEl);
      this.shadow.appendChild(style);
      this.shadow.appendChild(container);

      const target = document.body || document.documentElement;
      if (target) {
        target.appendChild(this.host);
      } else {
        window.addEventListener('DOMContentLoaded', () => {
          (document.body || document.documentElement).appendChild(this.host);
        });
      }
    }

    showLoading(text = 'বাংলায় রূপান্তর হচ্ছে...') {
      this._clearTimer();
      this._render('loading', text, null, `<div class="bw-spinner"></div>`);
    }

    showSuccess(text = 'সফলভাবে পরিবর্তন করা হয়েছে!', showUndo = true) {
      const undoKey = showUndo ? (isMac ? '⌘Z' : 'Ctrl+Z') : null;
      this._render('success', text, undoKey, '✨');
      this._startDismissTimer(2800);
    }

    showWarning(text = 'কোনো টেক্সট পাওয়া যায়নি') {
      this._render('warning', text, null, '⚠️');
      this._startDismissTimer(3200);
    }

    showError(text = 'অনুরোধ ব্যর্থ হয়েছে') {
      this._render('error', text, null, '❌');
      this._startDismissTimer(4000);
    }

    hide() {
      this._clearTimer();
      if (this.toastEl) {
        this.toastEl.classList.remove('bw-visible');
      }
    }

    _render(type, message, shortcut, icon) {
      if (!this.toastEl) return;

      this.toastEl.className = `bw-toast bw-state-${type}`;

      const shortcutHtml = shortcut ? `<kbd class="bw-kbd">${shortcut}</kbd>` : '';

      this.toastEl.innerHTML = `
        <div class="bw-icon-wrap">${icon}</div>
        <div>
          <span class="bw-brand">BanglaWrite:</span>
          <span class="bw-msg">${this._escape(message)}</span>
          ${shortcutHtml}
        </div>
      `;

      requestAnimationFrame(() => {
        this.toastEl.classList.add('bw-visible');
      });
    }

    _startDismissTimer(ms) {
      this._clearTimer();
      this.dismissTimer = setTimeout(() => this.hide(), ms);
    }

    _clearTimer() {
      if (this.dismissTimer) {
        clearTimeout(this.dismissTimer);
        this.dismissTimer = null;
      }
    }

    _escape(str) {
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    }
  }

  const hud = new BanglaWriteHUD();

  /* ==========================================================================
     2. DEEP DOM FOCUS & TEXT CONTEXT EXTRACTION
     ========================================================================== */

  function getDeepActiveElement(root = document) {
    let active = root.activeElement;
    while (active) {
      if (active.shadowRoot && active.shadowRoot.activeElement) {
        active = active.shadowRoot.activeElement;
      } else if (active.tagName === 'IFRAME') {
        try {
          const doc = active.contentDocument || active.contentWindow?.document;
          if (doc && doc.activeElement) {
            active = doc.activeElement;
          } else {
            break;
          }
        } catch (e) {
          break; // Cross-origin iframe
        }
      } else {
        break;
      }
    }
    return active;
  }

  function getTargetContext() {
    const el = getDeepActiveElement();
    if (!el) return null;

    const win = el.ownerDocument?.defaultView || window;
    const tagName = el.tagName ? el.tagName.toUpperCase() : '';

    // Standard <textarea> or <input>
    if (tagName === 'TEXTAREA' || (tagName === 'INPUT' && /^(text|search|url|tel|email)$/i.test(el.type || 'text'))) {
      if (el.disabled || el.readOnly) return null;

      // Security guard: Never read passwords or sensitive credentials
      if (el.type === 'password' || el.type === 'hidden') return null;
      const autocomplete = (el.getAttribute('autocomplete') || '').toLowerCase();
      if (/password|cc-|cvv|current-password|new-password|credit-card/i.test(autocomplete)) return null;

      const fullText = el.value || '';
      let start = 0;
      let end = 0;
      try {
        start = el.selectionStart ?? 0;
        end = el.selectionEnd ?? 0;
      } catch (e) {
        start = end = fullText.length;
      }

      const hasSelection = start !== end;
      const selectedText = hasSelection ? fullText.substring(start, end) : '';

      return {
        type: 'standard',
        element: el,
        text: hasSelection ? selectedText : fullText,
        isSelection: hasSelection,
        start,
        end,
        fullText
      };
    }

    // Contenteditable (Lexical, Slate, Draft.js, Gmail, Messenger, Facebook)
    const editableContainer = el.isContentEditable ? el : el.closest?.('[contenteditable="true"], [contenteditable=""]');

    if (editableContainer) {
      const sel = win.getSelection();
      let hasSelection = false;
      let selectedText = '';
      let currentRange = null;

      if (sel && sel.rangeCount > 0 && !sel.isCollapsed) {
        const range = sel.getRangeAt(0);
        if (editableContainer.contains(range.commonAncestorContainer)) {
          currentRange = range.cloneRange();
          selectedText = sel.toString();
          hasSelection = selectedText.trim().length > 0;
        }
      }

      const fullText = (editableContainer.innerText || editableContainer.textContent || '').trim();

      return {
        type: 'contenteditable',
        element: editableContainer,
        text: hasSelection ? selectedText : fullText,
        isSelection: hasSelection,
        range: currentRange,
        selection: sel,
        fullText
      };
    }

    return null;
  }

  /* ==========================================================================
     3. HIGH-COMPATIBILITY TEXT REPLACEMENT ENGINE
     ========================================================================== */

  function replaceTargetText(targetCtx, replacementText) {
    if (!targetCtx || !targetCtx.element) return false;
    const el = targetCtx.element;
    el.focus();

    if (targetCtx.type === 'standard') {
      return replaceStandardInput(el, targetCtx, replacementText);
    } else {
      return replaceContentEditable(el, targetCtx, replacementText);
    }
  }

  function replaceStandardInput(el, targetCtx, replacementText) {
    const isSelection = targetCtx.isSelection;
    if (isSelection) {
      el.setSelectionRange(targetCtx.start, targetCtx.end);
    } else {
      el.select();
    }

    // 1. Try document.execCommand for native Undo stack support
    let execSuccess = false;
    try {
      execSuccess = document.execCommand('insertText', false, replacementText);
    } catch (e) {
      execSuccess = false;
    }

    if (execSuccess) return true;

    // 2. Fallback: Prototype value setter for React/Vue state tracking
    const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
    const prevValue = el.value || '';
    const start = isSelection ? targetCtx.start : 0;
    const end = isSelection ? targetCtx.end : prevValue.length;

    const newValue = prevValue.substring(0, start) + replacementText + prevValue.substring(end);

    if (descriptor && descriptor.set) {
      descriptor.set.call(el, newValue);
    } else {
      el.value = newValue;
    }

    // React _valueTracker sync
    if (el._valueTracker) {
      el._valueTracker.setValue(prevValue);
    }

    // Dispatch input & change events
    el.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertReplacementText' }));
    el.dispatchEvent(new Event('change', { bubbles: true, composed: true }));

    const newCursor = start + replacementText.length;
    try {
      el.setSelectionRange(newCursor, newCursor);
    } catch (e) {}

    return true;
  }

  function replaceContentEditable(el, targetCtx, replacementText) {
    const win = el.ownerDocument?.defaultView || window;
    const doc = el.ownerDocument || document;
    const sel = win.getSelection();

    if (targetCtx.isSelection && targetCtx.range) {
      sel.removeAllRanges();
      sel.addRange(targetCtx.range);
    } else if (!targetCtx.isSelection) {
      // Select all content of this contenteditable
      const range = doc.createRange();
      range.selectNodeContents(el);
      sel.removeAllRanges();
      sel.addRange(range);
    }

    // 1. execCommand insertText (Lexical, Slate, Draft.js, Quill)
    let execSuccess = false;
    try {
      execSuccess = doc.execCommand('insertText', false, replacementText);
    } catch (e) {
      execSuccess = false;
    }

    if (execSuccess) return true;

    // 2. Synthetic Paste fallback
    try {
      const dt = new DataTransfer();
      dt.setData('text/plain', replacementText);
      const pasteEvent = new ClipboardEvent('paste', {
        bubbles: true,
        cancelable: true,
        composed: true,
        clipboardData: dt
      });
      const handled = !el.dispatchEvent(pasteEvent);
      if (handled) return true;
    } catch (e) {}

    // 3. Direct DOM Range insertion
    try {
      if (sel && sel.rangeCount > 0) {
        const range = sel.getRangeAt(0);
        range.deleteContents();
        const textNode = doc.createTextNode(replacementText);
        range.insertNode(textNode);

        range.setStartAfter(textNode);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);

        el.dispatchEvent(new InputEvent('input', {
          bubbles: true,
          composed: true,
          inputType: 'insertReplacementText',
          data: replacementText
        }));
        return true;
      }
    } catch (e) {}

    return false;
  }

  /* ==========================================================================
     4. CORE REWRITE CONTROLLER
     ========================================================================== */

  async function triggerRewrite(options = {}) {
    const now = performance.now();
    if (now - lastTriggerTimestamp < DEDUP_THRESHOLD_MS || isRewriting) {
      return;
    }
    lastTriggerTimestamp = now;

    // Step 1: Detect focused text element and selection
    const targetCtx = getTargetContext();

    if (!targetCtx || !targetCtx.element) {
      hud.showWarning('টেক্সট বক্সে ক্লিক করুন (Click in a text box)');
      return;
    }

    const textToRewrite = (targetCtx.text || '').trim();

    if (!textToRewrite) {
      hud.showWarning('কোনো লেখা নেই (No text to rewrite)');
      return;
    }

    isRewriting = true;
    hud.showLoading(targetCtx.isSelection ? 'সিলেক্টেড টেক্সট রূপান্তর হচ্ছে...' : 'বাংলায় রূপান্তর হচ্ছে...');

    try {
      // Step 2: Request AI conversion from Background Service Worker
      const response = await new Promise((resolve) => {
        chrome.runtime.sendMessage(
          {
            type: 'REWRITE_REQUEST',
            text: textToRewrite,
            mode: options.mode // Optional custom mode from popup
          },
          (res) => {
            if (chrome.runtime.lastError) {
              resolve({ success: false, error: chrome.runtime.lastError.message });
            } else {
              resolve(res || { success: false, error: 'No response from background worker' });
            }
          }
        );
      });

      if (!response || !response.success) {
        const errMsg = response?.error || 'রূপান্তর ব্যর্থ হয়েছে';
        hud.showError(errMsg);
        return;
      }

      const rewrittenText = response.text;
      if (!rewrittenText) {
        hud.showError('খালি উত্তর এসেছে (Empty response)');
        return;
      }

      // Step 3: Replace text in DOM cleanly
      const replaced = replaceTargetText(targetCtx, rewrittenText);

      if (replaced) {
        hud.showSuccess('সফলভাবে রূপান্তর সম্পন্ন!', true);
      } else {
        hud.showError('টেক্সট প্রতিস্থাপন ব্যর্থ হয়েছে');
      }
    } catch (err) {
      hud.showError(err.message || 'অপ্রত্যাশিত সমস্যা');
    } finally {
      isRewriting = false;
    }
  }

  /* ==========================================================================
     5. KEYBOARD SHORTCUT & MESSAGE LISTENERS
     ========================================================================== */

  // In-Page Capturing Keydown Listener (Instant response & blocks Bookmarks Bar collision)
  window.addEventListener(
    'keydown',
    (e) => {
      const modifier = isMac ? e.metaKey : e.ctrlKey;
      const isShift = e.shiftKey;
      const isKeyB = e.code === 'KeyB';

      if (modifier && isShift && isKeyB) {
        // Prevent browser bookmarks toggle and web page overrides
        e.preventDefault();
        e.stopImmediatePropagation();

        triggerRewrite({ source: 'KEYDOWN_INSTANT' });
      }
    },
    { capture: true, passive: false }
  );

  // Background Service Worker / Popup Trigger Listener
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'TRIGGER_REWRITE') {
      triggerRewrite({
        mode: message.mode,
        forceSelectionOnly: message.selectionOnly,
        source: message.source || 'SW_COMMAND'
      });
      sendResponse({ received: true });
    }
    return false;
  });
})();
