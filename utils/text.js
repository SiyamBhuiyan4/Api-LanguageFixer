/**
 * BanglaWrite AI - Text & DOM Utilities
 * Lightweight, vanilla DOM helpers for text extraction, selection, and framework-safe replacement.
 */

export const TextUtils = {
  /**
   * Get the currently active/focused element, traversing through open shadow roots if present.
   */
  getActiveElement(root = document) {
    let active = root.activeElement;
    while (active && active.shadowRoot && active.shadowRoot.activeElement) {
      active = active.shadowRoot.activeElement;
    }
    return active;
  },

  /**
   * Determine if an element is an editable target (input, textarea, or contenteditable).
   */
  isEditable(element) {
    if (!element) return false;
    const tagName = element.tagName ? element.tagName.toUpperCase() : '';
    if (tagName === 'TEXTAREA') return !element.disabled && !element.readOnly;
    if (tagName === 'INPUT') {
      const type = (element.getAttribute('type') || 'text').toLowerCase();
      // Never touch password, hidden, or credential inputs
      if (type === 'password' || type === 'hidden') return false;
      const autocomplete = (element.getAttribute('autocomplete') || '').toLowerCase();
      if (/password|cc-|cvv|current-password|new-password|credit-card/i.test(autocomplete)) return false;

      const validTypes = ['text', 'search', 'url', 'tel', 'email'];
      return validTypes.includes(type) && !element.disabled && !element.readOnly;
    }
    return element.isContentEditable || element.getAttribute('contenteditable') === 'true';
  },

  /**
   * Extract text and selection context from an editable element.
   * Returns: { text: string, isSelection: boolean, start: number, end: number, element: HTMLElement }
   */
  getTargetText(element) {
    if (!this.isEditable(element)) return null;

    const tagName = element.tagName ? element.tagName.toUpperCase() : '';

    if (tagName === 'INPUT' || tagName === 'TEXTAREA') {
      const start = element.selectionStart;
      const end = element.selectionEnd;
      const fullText = element.value || '';

      if (typeof start === 'number' && typeof end === 'number' && start !== end) {
        return {
          text: fullText.substring(start, end),
          isSelection: true,
          start,
          end,
          element
        };
      }

      return {
        text: fullText,
        isSelection: false,
        start: 0,
        end: fullText.length,
        element
      };
    }

    // Contenteditable elements
    const selection = window.getSelection();
    if (selection && selection.rangeCount > 0 && !selection.isCollapsed) {
      const selectedText = selection.toString();
      if (selectedText.trim().length > 0) {
        return {
          text: selectedText,
          isSelection: true,
          range: selection.getRangeAt(0).cloneRange(),
          element
        };
      }
    }

    // Fallback to full contenteditable text
    const fullText = element.innerText || element.textContent || '';
    return {
      text: fullText,
      isSelection: false,
      element
    };
  },

  /**
   * Replace text in the active element cleanly without triggering form submission.
   * Preserves Undo/Redo (Cmd+Z) where supported, and updates React/Vue/Lexical state.
   */
  replaceText(targetInfo, replacementText) {
    if (!targetInfo || !targetInfo.element) return false;
    const el = targetInfo.element;
    const tagName = el.tagName ? el.tagName.toUpperCase() : '';

    el.focus();

    if (tagName === 'INPUT' || tagName === 'TEXTAREA') {
      return this._replaceInputText(el, targetInfo, replacementText);
    } else {
      return this._replaceContentEditableText(el, targetInfo, replacementText);
    }
  },

  _replaceInputText(el, targetInfo, replacementText) {
    const isFull = !targetInfo.isSelection;
    if (isFull) {
      el.select();
    } else {
      el.setSelectionRange(targetInfo.start, targetInfo.end);
    }

    let success = false;

    // 1. Try document.execCommand first for Undo stack support
    try {
      success = document.execCommand('insertText', false, replacementText);
    } catch (e) {
      success = false;
    }

    // 2. Fallback to native property descriptor setter for React/Vue/Angular
    if (!success) {
      const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      const nativeSetter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;

      const currentVal = el.value || '';
      const start = targetInfo.isSelection ? targetInfo.start : 0;
      const end = targetInfo.isSelection ? targetInfo.end : currentVal.length;

      const newVal = currentVal.substring(0, start) + replacementText + currentVal.substring(end);

      if (nativeSetter) {
        nativeSetter.call(el, newVal);
      } else {
        el.value = newVal;
      }

      // Dispatch standard input and change events
      el.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
      el.dispatchEvent(new Event('change', { bubbles: true, cancelable: true }));

      // Position cursor at end of replacement
      const newCursorPos = start + replacementText.length;
      try {
        el.setSelectionRange(newCursorPos, newCursorPos);
      } catch (e) {
        // Ignore if element is not focusable
      }
      success = true;
    }

    return success;
  },

  _replaceContentEditableText(el, targetInfo, replacementText) {
    const selection = window.getSelection();
    if (!selection) return false;

    if (targetInfo.isSelection && targetInfo.range) {
      selection.removeAllRanges();
      selection.addRange(targetInfo.range);
    } else if (!targetInfo.isSelection) {
      // Select all content of this contenteditable element
      const range = document.createRange();
      range.selectNodeContents(el);
      selection.removeAllRanges();
      selection.addRange(range);
    }

    let success = false;

    // 1. execCommand insertText is best for Lexical / Draft.js / Quill
    try {
      success = document.execCommand('insertText', false, replacementText);
    } catch (e) {
      success = false;
    }

    // 2. Fallback: manual range replacement
    if (!success) {
      try {
        if (selection.rangeCount > 0) {
          const range = selection.getRangeAt(0);
          range.deleteContents();
          const textNode = document.createTextNode(replacementText);
          range.insertNode(textNode);

          // Place cursor after text node
          range.setStartAfter(textNode);
          range.setEndAfter(textNode);
          selection.removeAllRanges();
          selection.addRange(range);

          el.dispatchEvent(new InputEvent('input', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: replacementText
          }));
          success = true;
        }
      } catch (e) {
        success = false;
      }
    }

    return success;
  }
};
