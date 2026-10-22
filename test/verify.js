/**
 * BanglaWrite AI - Lightweight Test Runner & Verification Suite
 * 
 * Verifies:
 * 1. manifest.json syntax and strict Manifest V3 schema compliance & file integrity
 * 2. All JavaScript files for syntax errors using `node --check`
 * 3. Multi-provider API formatting simulation (Gemini, OpenAI, Groq, Anthropic, Ollama)
 * 4. In-place text replacement simulation on mock DOM elements (input, textarea, contenteditable)
 * 
 * Zero external dependencies (pure Node.js built-ins).
 * Usage: node test/verify.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';
import { buildPrompt, TONE_MODES, AIClient } from '../api/ai.js';
import { Storage, PROVIDERS, PROVIDER_DEFAULTS, TONES } from '../utils/storage.js';
import { TextUtils } from '../utils/text.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

// ANSI Terminal Colors
const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  gray: '\x1b[90m'
};

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;
const failureDetails = [];
const startTime = Date.now();

function suite(title) {
  console.log(`\n${colors.bold}${colors.cyan}▶ ${title}${colors.reset}`);
}

function assert(condition, message, detail = null) {
  totalTests++;
  if (condition) {
    console.log(`  ${colors.green}✔ PASS:${colors.reset} ${message}`);
    passedTests++;
  } else {
    console.error(`  ${colors.red}✖ FAIL:${colors.reset} ${message}`);
    failedTests++;
    failureDetails.push({ message, detail });
    process.exitCode = 1;
  }
}

async function runVerification() {
  console.log(`${colors.bold}====================================================${colors.reset}`);
  console.log(`${colors.bold}🚀 BanglaWrite AI — Test Runner & Verification Suite${colors.reset}`);
  console.log(`${colors.bold}====================================================${colors.reset}`);

  /* ==========================================================================
     SUITE 1: MANIFEST V3 SCHEMA & ASSET COMPLIANCE
     ========================================================================== */
  suite('1. Manifest V3 Schema & Asset Compliance');

  const manifestPath = path.join(rootDir, 'manifest.json');
  assert(fs.existsSync(manifestPath), 'manifest.json exists on disk');

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    assert(true, 'manifest.json is valid parseable JSON');
  } catch (err) {
    assert(false, 'manifest.json syntax error', err.message);
    return;
  }

  // Core MV3 metadata
  assert(manifest.manifest_version === 3, 'manifest_version is strictly 3');
  assert(typeof manifest.name === 'string' && manifest.name.length > 0, 'Extension name is defined');
  assert(/^\d+(\.\d+){0,3}$/.test(manifest.version), `Extension version format is valid (${manifest.version})`);
  assert(typeof manifest.description === 'string' && manifest.description.length > 0, 'Description is defined');

  // Strict MV3 Forbidden Keys Check (Least Privilege & deprecations)
  assert(manifest.browser_action === undefined, 'Deprecated "browser_action" is not present (MV3 compliance)');
  assert(manifest.page_action === undefined, 'Deprecated "page_action" is not present (MV3 compliance)');
  assert(manifest.background?.scripts === undefined, 'Legacy "background.scripts" is not present');
  assert(manifest.background?.page === undefined, 'Legacy "background.page" is not present');

  // Service Worker Verification
  assert(manifest.background && typeof manifest.background.service_worker === 'string', 'background.service_worker is declared');
  assert(manifest.background?.type === 'module', 'background.type is "module" for ES module imports');
  const swPath = path.join(rootDir, manifest.background?.service_worker || '');
  assert(fs.existsSync(swPath), `Service worker file exists (${manifest.background?.service_worker})`);

  // Action Popup & Icons
  assert(manifest.action && typeof manifest.action.default_popup === 'string', 'action.default_popup is declared');
  const popupHtmlPath = path.join(rootDir, manifest.action?.default_popup || '');
  assert(fs.existsSync(popupHtmlPath), `Popup HTML file exists (${manifest.action?.default_popup})`);

  // Icon Resolution Integrity Check
  const expectedSizes = ['16', '32', '48', '128'];
  for (const size of expectedSizes) {
    const iconRelPath = manifest.icons?.[size];
    assert(Boolean(iconRelPath), `Icon size ${size} is declared in manifest.icons`);
    if (iconRelPath) {
      assert(fs.existsSync(path.join(rootDir, iconRelPath)), `Icon file exists for size ${size} (${iconRelPath})`);
    }
  }

  // Content Scripts Verification
  assert(Array.isArray(manifest.content_scripts) && manifest.content_scripts.length > 0, 'content_scripts array is declared');
  if (manifest.content_scripts?.[0]) {
    const cs = manifest.content_scripts[0];
    assert(Array.isArray(cs.matches) && cs.matches.includes('<all_urls>'), 'content_scripts matches <all_urls>');
    assert(Array.isArray(cs.js) && cs.js.length > 0, 'content_scripts declares JS entry points');
    for (const jsFile of (cs.js || [])) {
      assert(fs.existsSync(path.join(rootDir, jsFile)), `Content script JS exists (${jsFile})`);
    }
    for (const cssFile of (cs.css || [])) {
      assert(fs.existsSync(path.join(rootDir, cssFile)), `Content script CSS exists (${cssFile})`);
    }
  }

  // Permissions & Scoping Verification
  assert(Array.isArray(manifest.permissions), 'permissions array is declared');
  assert(manifest.permissions.includes('storage'), 'Storage permission is granted');
  assert(manifest.permissions.includes('activeTab'), 'activeTab permission is granted');

  // Keyboard Shortcuts Verification
  assert(Boolean(manifest.commands?.['rewrite-text']), 'Command "rewrite-text" is declared in manifest.commands');
  assert(manifest.commands?.['rewrite-text']?.suggested_key?.mac === 'Command+Shift+B', 'Mac shortcut is Command+Shift+B');
  assert(manifest.commands?.['rewrite-text']?.suggested_key?.default === 'Ctrl+Shift+B', 'Default shortcut is Ctrl+Shift+B');

  /* ==========================================================================
     SUITE 2: JAVASCRIPT SYNTAX VALIDATION (node --check)
     ========================================================================== */
  suite('2. JavaScript Syntax Validation (node --check)');

  function getJsFilesRecursively(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
      if (file.startsWith('.') || file === 'node_modules') continue;
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        getJsFilesRecursively(fullPath, fileList);
      } else if (file.endsWith('.js') || file.endsWith('.mjs')) {
        fileList.push(fullPath);
      }
    }
    return fileList;
  }

  const jsFiles = getJsFilesRecursively(rootDir);
  assert(jsFiles.length > 0, `Discovered ${jsFiles.length} JavaScript files across the project`);

  for (const filePath of jsFiles) {
    const relPath = path.relative(rootDir, filePath);
    try {
      execFileSync(process.execPath, ['--check', filePath], { stdio: 'pipe' });
      assert(true, `Syntax valid: ${relPath}`);
    } catch (err) {
      assert(false, `Syntax error in ${relPath}`, err.stderr ? err.stderr.toString() : err.message);
    }
  }

  /* ==========================================================================
     SUITE 3: MULTI-PROVIDER LLM API FORMATTING & SIMULATION
     ========================================================================== */
  suite('3. Multi-Provider LLM API Formatting & Simulation');

  // 3.1 Prompt Builder & Tone Modes Matrix
  const toneKeys = ['natural', 'polite', 'casual', 'professional', 'formal', 'short', 'fix_grammar'];
  for (const mode of toneKeys) {
    assert(Boolean(TONE_MODES[mode]), `Tone mode "${mode}" is defined`);
    const sampleInput = 'ami ajke jete parbo na';
    const { systemPrompt, userPrompt } = buildPrompt(sampleInput, mode);
    assert(userPrompt === sampleInput, `userPrompt verbatim preserves text for tone "${mode}"`);
    assert(systemPrompt.includes('BanglaWrite AI'), `systemPrompt retains identity for tone "${mode}"`);
    assert(systemPrompt.includes(TONE_MODES[mode].instruction), `systemPrompt embeds tone instruction for "${mode}"`);
  }

  // Intercept global fetch for deterministic API simulation
  const originalFetch = globalThis.fetch;
  let interceptedRequest = null;

  try {
    // 3.2 Google Gemini Simulation
    globalThis.fetch = async (url, opts) => {
      interceptedRequest = { url, opts, body: JSON.parse(opts.body) };
      return {
        ok: true,
        json: async () => ({
          candidates: [{ content: { parts: [{ text: 'আমি আজকে যেতে পারব না।' }] } }]
        })
      };
    };

    const geminiResult = await AIClient.sendToAI('ami ajke jete parbo na', 'natural', {
      provider: 'gemini',
      apiKey: 'test-gemini-key',
      model: 'gemini-1.5-flash'
    });

    assert(geminiResult.text === 'আমি আজকে যেতে পারব না।', 'Gemini successfully returned parsed Bengali text');
    assert(interceptedRequest.url.includes('/gemini-1.5-flash:generateContent'), 'Gemini target model URL formatted correctly');
    assert(interceptedRequest.opts.headers['x-goog-api-key'] === 'test-gemini-key', 'Gemini API key passed via secure x-goog-api-key header');
    assert(interceptedRequest.body.contents?.[0]?.parts?.[0]?.text === 'ami ajke jete parbo na', 'Gemini user text payload matches input');
    assert(interceptedRequest.body.generationConfig?.temperature === 0.3, 'Gemini temperature configured to 0.3');

    // 3.3 OpenAI Simulation
    globalThis.fetch = async (url, opts) => {
      interceptedRequest = { url, opts, body: JSON.parse(opts.body) };
      return {
        ok: true,
        json: async () => ({
          choices: [{ message: { content: 'আমি আজকে যেতে পারব না।' } }]
        })
      };
    };

    const openaiResult = await AIClient.sendToAI('ami ajke jete parbo na', 'polite', {
      provider: 'openai',
      apiKey: 'sk-test-openai',
      model: 'gpt-4o-mini'
    });

    assert(openaiResult.text === 'আমি আজকে যেতে পারব না।', 'OpenAI successfully returned parsed Bengali text');
    assert(interceptedRequest.url === 'https://api.openai.com/v1/chat/completions', 'OpenAI endpoint resolved correctly');
    assert(interceptedRequest.opts.headers.Authorization === 'Bearer sk-test-openai', 'OpenAI Authorization Bearer header formatted correctly');
    assert(interceptedRequest.body.model === 'gpt-4o-mini', 'OpenAI model payload is gpt-4o-mini');
    assert(interceptedRequest.body.messages?.[0]?.role === 'system', 'OpenAI messages array includes system prompt');
    assert(interceptedRequest.body.messages?.[1]?.role === 'user', 'OpenAI messages array includes user prompt');

    // 3.4 Groq (Ultra-Fast) Simulation
    const groqResult = await AIClient.sendToAI('ami ajke jete parbo na', 'casual', {
      provider: 'groq',
      apiKey: 'gsk-test-groq',
      model: 'llama-3.3-70b-versatile'
    });

    assert(groqResult.text === 'আমি আজকে যেতে পারব না।', 'Groq successfully returned parsed Bengali text');
    assert(interceptedRequest.url === 'https://api.groq.com/openai/v1/chat/completions', 'Groq endpoint resolved correctly');
    assert(interceptedRequest.body.model === 'llama-3.3-70b-versatile', 'Groq model configured properly');

    // 3.5 Ollama (Local Offline - Zero Key Requirement)
    const ollamaResult = await AIClient.sendToAI('ami ajke jete parbo na', 'formal', {
      provider: 'ollama',
      apiKey: '',
      model: 'llama3.2',
      endpoint: 'http://localhost:11434/v1/chat/completions'
    });

    assert(ollamaResult.text === 'আমি আজকে যেতে পারব না।', 'Ollama returned parsed Bengali text');
    assert(interceptedRequest.url === 'http://localhost:11434/v1/chat/completions', 'Ollama local endpoint resolved correctly');
    assert(interceptedRequest.opts.headers.Authorization === undefined, 'Ollama does not attach empty Authorization header');

    // 3.6 Anthropic Claude Simulation
    globalThis.fetch = async (url, opts) => {
      interceptedRequest = { url, opts, body: JSON.parse(opts.body) };
      return {
        ok: true,
        json: async () => ({
          content: [{ type: 'text', text: 'আমি আজকে যেতে পারব না।' }]
        })
      };
    };

    const anthropicResult = await AIClient.sendToAI('ami ajke jete parbo na', 'short', {
      provider: 'anthropic',
      apiKey: 'sk-ant-test',
      model: 'claude-3-5-haiku-20241022'
    });

    assert(anthropicResult.text === 'আমি আজকে যেতে পারব না।', 'Anthropic returned parsed Bengali text');
    assert(interceptedRequest.url === 'https://api.anthropic.com/v1/messages', 'Anthropic endpoint resolved correctly');
    assert(interceptedRequest.opts.headers['x-api-key'] === 'sk-ant-test', 'Anthropic x-api-key header set correctly');
    assert(interceptedRequest.opts.headers['anthropic-version'] === '2023-06-01', 'Anthropic anthropic-version header set correctly');
    assert(typeof interceptedRequest.body.system === 'string', 'Anthropic uses top-level system parameter');
    assert(interceptedRequest.body.max_tokens === 2048, 'Anthropic max_tokens configured properly');

    // 3.7 Output Sanitization
    globalThis.fetch = async () => ({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: '```bangla\nআমি ভালো আছি\n```' }] } }]
      })
    });
    const sanitizedCodeBlock = await AIClient.sendToAI('ami bhalo achi', 'natural', { provider: 'gemini', apiKey: 'k' });
    assert(sanitizedCodeBlock.text === 'আমি ভালো আছি', 'Markdown code fences (```bangla) are cleanly stripped');

    globalThis.fetch = async () => ({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: '“আমি ভালো আছি”' }] } }]
      })
    });
    const sanitizedQuotes = await AIClient.sendToAI('ami bhalo achi', 'natural', { provider: 'gemini', apiKey: 'k' });
    assert(sanitizedQuotes.text === 'আমি ভালো আছি', 'Accidental Bengali quotation marks (“...”) are cleanly stripped');

  } finally {
    globalThis.fetch = originalFetch;
  }

  /* ==========================================================================
     SUITE 4: DOM TEXT REPLACEMENT SIMULATION (Mock DOM Environment)
     ========================================================================== */
  suite('4. In-Place DOM Replacement Simulation');

  class MockElement {
    constructor() {
      this.events = [];
    }
    addEventListener(type, fn) {}
    dispatchEvent(ev) {
      this.events.push(ev);
      return true;
    }
  }

  class MockInput extends MockElement {
    constructor(val = '', type = 'text') {
      super();
      this.tagName = 'INPUT';
      this.type = type;
      this.value = val;
      this.disabled = false;
      this.readOnly = false;
      this.selectionStart = 0;
      this.selectionEnd = val.length;
    }
    getAttribute(name) {
      if (name === 'type') return this.type;
      return null;
    }
    focus() {}
    select() {
      this.selectionStart = 0;
      this.selectionEnd = this.value.length;
    }
    setSelectionRange(start, end) {
      this.selectionStart = start;
      this.selectionEnd = end;
    }
  }

  class MockTextArea extends MockElement {
    constructor(val = '') {
      super();
      this.tagName = 'TEXTAREA';
      this.value = val;
      this.disabled = false;
      this.readOnly = false;
      this.selectionStart = 0;
      this.selectionEnd = val.length;
    }
    getAttribute() { return null; }
    focus() {}
    select() {
      this.selectionStart = 0;
      this.selectionEnd = this.value.length;
    }
    setSelectionRange(start, end) {
      this.selectionStart = start;
      this.selectionEnd = end;
    }
  }

  class MockNode {
    constructor(text = '') {
      this.nodeValue = text;
      this.textContent = text;
    }
  }

  class MockRange {
    constructor() {
      this.targetEl = null;
    }
    selectNodeContents(el) {
      this.targetEl = el;
    }
    cloneRange() {
      const r = new MockRange();
      r.targetEl = this.targetEl;
      return r;
    }
    deleteContents() {
      if (this.targetEl) {
        this.targetEl.childNodes = [];
        this.targetEl.innerText = '';
      }
    }
    insertNode(node) {
      if (this.targetEl) {
        this.targetEl.childNodes.push(node);
        this.targetEl.innerText = (this.targetEl.innerText || '') + node.nodeValue;
      }
    }
    setStartAfter() {}
    setEndAfter() {}
  }

  class MockSelection {
    constructor(selectedText = '') {
      this.ranges = [];
      this.selectedText = selectedText;
    }
    get rangeCount() { return this.ranges.length; }
    get isCollapsed() { return this.ranges.length === 0; }
    getRangeAt(i) { return this.ranges[i]; }
    removeAllRanges() { this.ranges = []; }
    addRange(r) { this.ranges.push(r); }
    toString() { return this.selectedText; }
  }

  class MockContentEditable extends MockElement {
    constructor(initialText = '') {
      super();
      this.tagName = 'DIV';
      this.isContentEditable = true;
      this.innerText = initialText;
      this.childNodes = [new MockNode(initialText)];
    }
    getAttribute(name) {
      return name === 'contenteditable' ? 'true' : null;
    }
    focus() {}
  }

  // Bind Mock Globals
  global.HTMLInputElement = MockInput;
  global.HTMLTextAreaElement = MockTextArea;
  global.Event = class {
    constructor(type, init) {
      this.type = type;
      this.bubbles = init?.bubbles ?? false;
      this.cancelable = init?.cancelable ?? false;
    }
  };
  global.InputEvent = class extends global.Event {
    constructor(type, init) {
      super(type, init);
      this.inputType = init?.inputType;
      this.data = init?.data;
    }
  };
  global.document = {
    execCommand: () => false, // Simulate fallback path for maximum verification
    createRange: () => new MockRange(),
    createTextNode: (t) => new MockNode(t),
    activeElement: null
  };
  global.window = {
    getSelection: () => new MockSelection()
  };

  // 4.1 isEditable() Matrix Validation
  assert(TextUtils.isEditable(new MockInput('hello', 'text')) === true, 'Input text is editable');
  assert(TextUtils.isEditable(new MockInput('hello', 'search')) === true, 'Input search is editable');
  assert(TextUtils.isEditable(new MockInput('hello', 'email')) === true, 'Input email is editable');
  assert(TextUtils.isEditable(new MockInput('hello', 'password')) === false, 'Input password is secure and NOT editable');
  assert(TextUtils.isEditable(new MockInput('hello', 'button')) === false, 'Input button is not editable');
  assert(TextUtils.isEditable(new MockInput('hello', 'submit')) === false, 'Input submit is not editable');
  const disabledInput = new MockInput('hello', 'text');
  disabledInput.disabled = true;
  assert(TextUtils.isEditable(disabledInput) === false, 'Disabled input is not editable');
  const roTextarea = new MockTextArea('hello');
  roTextarea.readOnly = true;
  assert(TextUtils.isEditable(roTextarea) === false, 'ReadOnly textarea is not editable');
  assert(TextUtils.isEditable(new MockTextArea('hello')) === true, 'Textarea is editable');
  assert(TextUtils.isEditable(new MockContentEditable('hello')) === true, 'Contenteditable element is editable');
  assert(TextUtils.isEditable({ tagName: 'DIV', getAttribute: () => null }) === false, 'Plain DIV is not editable');

  // 4.2 Active Element & Open Shadow Root Traversal
  const shadowLeaf = new MockInput('nested');
  const shadowHost = {
    tagName: 'CUSTOM-WEB-COMPONENT',
    shadowRoot: { activeElement: shadowLeaf }
  };
  global.document.activeElement = shadowHost;
  const resolvedActive = TextUtils.getActiveElement(global.document);
  assert(resolvedActive === shadowLeaf, 'Shadow DOM traversal extracts innermost activeElement');

  // 4.3 <input type="text"> Full Text Replacement
  const inputFull = new MockInput('ami ajke office jabo na');
  const inputFullTarget = TextUtils.getTargetText(inputFull);
  assert(inputFullTarget.text === 'ami ajke office jabo na', 'getTargetText extracts complete input value');
  const inputFullReplaced = TextUtils.replaceText(inputFullTarget, 'আমি আজকে অফিসে যাব না');
  assert(inputFullReplaced === true, 'replaceText succeeds for input');
  assert(inputFull.value === 'আমি আজকে অফিসে যাব না', 'input.value cleanly updated to Bengali text');
  assert(inputFull.events.some(e => e.type === 'input' && e.bubbles === true), 'Dispatches bubbling "input" event');
  assert(inputFull.events.some(e => e.type === 'change' && e.bubbles === true), 'Dispatches bubbling "change" event');
  assert(inputFull.selectionStart === 'আমি আজকে অফিসে যাব না'.length, 'Cursor positioned at end of replacement');

  // 4.4 <input type="text"> Partial Selection Replacement
  const inputPartial = new MockInput('Hello ami bhalo achi world');
  inputPartial.selectionStart = 6;
  inputPartial.selectionEnd = 20; // 'ami bhalo achi'
  const inputPartialTarget = TextUtils.getTargetText(inputPartial);
  assert(inputPartialTarget.text === 'ami bhalo achi', 'getTargetText extracts only selected range');
  assert(inputPartialTarget.isSelection === true, 'getTargetText flags isSelection=true');
  TextUtils.replaceText(inputPartialTarget, 'আমি ভালো আছি');
  assert(inputPartial.value === 'Hello আমি ভালো আছি world', 'Selected slice replaced while preserving surrounding text');
  assert(inputPartial.selectionStart === 6 + 'আমি ভালো আছি'.length, 'Cursor set immediately following inserted text');

  // 4.5 <textarea> Multi-line Replacement
  const multiLineTa = new MockTextArea('Line 1: shob thik ache\nLine 2: kalke dekha hobe');
  multiLineTa.selectionStart = 8;
  multiLineTa.selectionEnd = 22; // 'shob thik ache'
  const taTarget = TextUtils.getTargetText(multiLineTa);
  assert(taTarget.text === 'shob thik ache', 'Textarea extracts partial slice accurately');
  TextUtils.replaceText(taTarget, 'সব ঠিক আছে');
  assert(multiLineTa.value === 'Line 1: সব ঠিক আছে\nLine 2: kalke dekha hobe', 'Multi-line textarea preserves linebreaks and context');

  // 4.6 <div contenteditable="true"> Full Replacement
  const ceFull = new MockContentEditable('ami bhalo achi');
  const ceFullTarget = TextUtils.getTargetText(ceFull);
  assert(ceFullTarget.text === 'ami bhalo achi', 'Contenteditable extracts full innerText when no range selected');
  const ceFullSuccess = TextUtils.replaceText(ceFullTarget, 'আমি ভালো আছি');
  assert(ceFullSuccess === true, 'Contenteditable replacement succeeds');
  assert(ceFull.innerText === 'আমি ভালো আছি', 'Contenteditable innerText updated');
  assert(ceFull.events.some(e => e.type === 'input' && e.inputType === 'insertText'), 'Contenteditable dispatches InputEvent with inputType=insertText');

  // 4.7 <div contenteditable="true"> Selection Range Replacement
  const ceRangeEl = new MockContentEditable('original');
  const mockSel = new MockSelection('custom selection');
  const mockRng = new MockRange();
  mockRng.selectNodeContents(ceRangeEl);
  mockSel.addRange(mockRng);
  global.window.getSelection = () => mockSel;

  const ceRangeTarget = TextUtils.getTargetText(ceRangeEl);
  assert(ceRangeTarget.isSelection === true, 'Contenteditable detects active window Selection');
  assert(ceRangeTarget.text === 'custom selection', 'Contenteditable extracts text from Selection.toString()');
  TextUtils.replaceText(ceRangeTarget, 'নতুন বাংলা টেক্সট');
  assert(ceRangeEl.innerText === 'নতুন বাংলা টেক্সট', 'Contenteditable replaces via Range node manipulation');

  /* ==========================================================================
     SUMMARY REPORT
     ========================================================================== */
  const durationMs = Date.now() - startTime;
  console.log(`\n${colors.bold}====================================================${colors.reset}`);
  if (failedTests === 0) {
    console.log(`${colors.green}${colors.bold}🎉 ALL CHECKS PASSED: ${passedTests}/${totalTests} tests successful (${durationMs}ms)${colors.reset}`);
  } else {
    console.error(`${colors.red}${colors.bold}❌ TEST FAILURES DETECTED: ${failedTests} failed, ${passedTests} passed of ${totalTests} total (${durationMs}ms)${colors.reset}`);
    failureDetails.forEach(f => console.error(`   - ${f.message}: ${f.detail || 'Assertion failed'}`));
  }
  console.log(`${colors.bold}====================================================${colors.reset}`);
}

runVerification().catch((err) => {
  console.error(`\n${colors.red}${colors.bold}Fatal Verification Error:${colors.reset}`, err);
  process.exit(1);
});
