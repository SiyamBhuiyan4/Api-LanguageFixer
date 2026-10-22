/**
 * BanglaWrite AI - Extension Verification & Test Suite
 * Pure Node.js verification script (zero external dependencies).
 * Run: node test/verify.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { buildPrompt, TONE_MODES } from '../api/ai.js';
import { Storage, PROVIDERS, PROVIDER_DEFAULTS, TONES } from '../utils/storage.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

let totalTests = 0;
let passedTests = 0;

function assert(condition, message) {
  totalTests++;
  if (!condition) {
    console.error(`❌ FAIL: ${message}`);
    process.exitCode = 1;
  } else {
    console.log(`✅ PASS: ${message}`);
    passedTests++;
  }
}

console.log('====================================================');
console.log('🚀 Running BanglaWrite AI Verification Suite');
console.log('====================================================\n');

// 1. Manifest V3 Schema & File Existence Checks
console.log('--- 1. Manifest & Files Verification ---');
const manifestPath = path.join(rootDir, 'manifest.json');
assert(fs.existsSync(manifestPath), 'manifest.json exists');

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
assert(manifest.manifest_version === 3, 'Manifest version is 3');
assert(manifest.name === 'BanglaWrite AI', 'Manifest name is BanglaWrite AI');
assert(manifest.commands && manifest.commands['rewrite-text'], 'Keyboard command "rewrite-text" is declared');
assert(manifest.commands['rewrite-text'].suggested_key?.mac === 'Command+Shift+B', 'Mac shortcut is Command+Shift+B');
assert(manifest.commands['rewrite-text'].suggested_key?.default === 'Ctrl+Shift+B', 'Default shortcut is Ctrl+Shift+B');
assert(manifest.action && manifest.action.default_popup === 'popup/popup.html', 'Action popup points to popup/popup.html');
assert(manifest.background && manifest.background.service_worker === 'background/service-worker.js', 'Service worker points to background/service-worker.js');
assert(manifest.content_scripts && manifest.content_scripts[0]?.js?.includes('content/content.js'), 'Content script registered');

// Check Icon Files
const iconSizes = [16, 32, 48, 128];
for (const size of iconSizes) {
  const iconFile = path.join(rootDir, 'icons', `icon${size}.png`);
  assert(fs.existsSync(iconFile), `Icon file icon${size}.png exists`);
}

// Check Core UI & Scripts
const requiredFiles = [
  'popup/popup.html',
  'popup/popup.css',
  'popup/popup.js',
  'options/options.html',
  'options/options.css',
  'options/options.js',
  'content/content.js',
  'content/content.css',
  'background/service-worker.js',
  'api/ai.js',
  'utils/text.js',
  'utils/storage.js'
];

for (const rel of requiredFiles) {
  const full = path.join(rootDir, rel);
  assert(fs.existsSync(full), `Core file ${rel} exists`);
}

// 2. Prompt Engineering & Tone Modes Verification
console.log('\n--- 2. Prompt Builder & Tone Modes Verification ---');
const toneKeys = ['natural', 'polite', 'casual', 'professional', 'formal', 'short', 'fix_grammar'];

for (const key of toneKeys) {
  assert(Boolean(TONE_MODES[key]), `Tone mode "${key}" is defined in TONE_MODES`);
  const testInput = 'ami ajke jete parbo na kalke gele ki hobe';
  const { systemPrompt, userPrompt } = buildPrompt(testInput, key);
  assert(userPrompt === testInput, `User prompt retains verbatim input for mode "${key}"`);
  assert(systemPrompt.includes('BanglaWrite AI'), `System prompt includes identity for mode "${key}"`);
  assert(systemPrompt.includes(TONE_MODES[key].instruction), `System prompt includes specific instruction for "${key}"`);
}

// 3. Storage Defaults & Provider Matrix Verification
console.log('\n--- 3. Storage & Configuration Verification ---');
const expectedProviders = ['gemini', 'openai', 'groq', 'ollama', 'anthropic', 'custom'];
for (const p of expectedProviders) {
  assert(Boolean(PROVIDER_DEFAULTS[p]), `Provider default exists for "${p}"`);
  if (p !== 'custom' && p !== 'ollama') {
    assert(PROVIDER_DEFAULTS[p].endpoint.length > 0, `Provider "${p}" has valid default endpoint`);
    assert(PROVIDER_DEFAULTS[p].model.length > 0, `Provider "${p}" has valid default model`);
    assert(PROVIDER_DEFAULTS[p].requiresApiKey === true, `Provider "${p}" flags requiresApiKey=true`);
  }
}

// Test Storage in-memory fallback
const defaults = Storage.getSettings ? true : false;
assert(defaults, 'Storage helper is initialized and exports getSettings');

// 4. Test Banglish Corpus Samples
console.log('\n--- 4. Banglish Test Corpus Validation ---');
const corpus = [
  { input: 'ami ajke jete parbo na kalke gele ki hobe', note: 'Standard query' },
  { input: 'apu ajke product ta pathaite parbo na kalke pathabo', note: 'E-commerce chat' },
  { input: 'kire kemon achos kobe ashbi bolli na to', note: 'Informal banter' },
  { input: 'sir presentation slide gula ready kore mail e pathiye dilam', note: 'Work report' },
  { input: 'amader offic e shobar meeting ase 3 tay shobai ke thakte bolben', note: 'Broken phonetics' }
];

for (const item of corpus) {
  const p = buildPrompt(item.input, 'natural');
  assert(p.userPrompt.length > 0, `Prompt generated cleanly for: "${item.note}"`);
}

console.log('\n====================================================');
console.log(`🎉 Results: ${passedTests}/${totalTests} tests passed successfully!`);
console.log('====================================================');
