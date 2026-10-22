# 🇧🇩 BanglaWrite AI — বাংলা রাইটিং অ্যাসিস্ট্যান্ট

> **Instant, Natural, and Context-Aware Bengali Writing Assistant for Chrome**  
> Convert Banglish and informal Bengali into natural, grammatically correct Bangla in real time across any webpage.

---

```
  ____                    _         __        __ _ _            _     ___ 
 | __ )  __ _ _ __   __ _| | __ _   \ \      / / __(_) |_ ___   / \   |_ _|
 |  _ \ / _` | '_ \ / _` | |/ _` |   \ \ /\ / / '__| | __/ _ \ / _ \   | | 
 | |_) | (_| | | | | (_| | | (_| |    \ V  V /| |  | | ||  __// ___ \  | | 
 |____/ \__,_|_| |_|\__, |_|\__,_|     \_/\_/ |_|  |_|\__\___/_/   \_\_|___|
                    |___/                                                  
                ✨ বাংলা ও বাংলিশ লেখার নির্ভরযোগ্য এআই সহকারী ✨
```

---

## 📑 Table of Contents
1. [Overview & Architecture](#-overview--architecture)
2. [Feature Highlights & Tone Modes](#-feature-highlights--tone-modes)
3. [Installation Guide (Chrome Load Unpacked)](#-installation-guide-chrome-load-unpacked)
4. [How to Obtain API Keys](#-how-to-obtain-api-keys)
   - [Google Gemini API (Free Tier Recommended)](#1-google-gemini-api-free-tier-recommended)
   - [Groq API (Ultra-Fast & Free Tier)](#2-groq-api-ultra-fast--free-tier)
   - [OpenAI API](#3-openai-api)
   - [Ollama (100% Free, Offline & Private)](#4-ollama-100-free-offline--private)
5. [Configuring API Settings](#-configuring-api-settings)
6. [Keyboard Shortcut Usage (Command/Ctrl + Shift + B)](#-keyboard-shortcut-usage-commandctrl--shift--b)
7. [Privacy & Security Commitment](#-privacy--security-commitment)
8. [Comprehensive Troubleshooting Guide](#-comprehensive-troubleshooting-guide)
9. [Project Structure & File Map](#-project-structure--file-map)

---

## 🌟 Overview & Architecture

**BanglaWrite AI** is a privacy-first, ultra-lightweight Chrome Extension (Manifest V3) designed for millions of Bengali speakers worldwide. Whether you are typing phonetic Banglish (*e.g., "ami ajke office jabo na"*) or writing informal Bengali that needs grammatical refinement, BanglaWrite AI intelligently rewrites your text into authentic, fluent Bengali script (*"আমি আজকে অফিসে যাব না।"*) directly inside your browser input fields.

### 📐 System Architecture Diagram

```
+-----------------------------------------------------------------------------------+
|                                  USER BROWSER                                     |
|                                                                                   |
|  +--------------------+         Keyboard Shortcut        +---------------------+  |
|  |   Active Webpage   |  ─── [Cmd/Ctrl + Shift + B] ───> |  Content Script     |  |
|  |  (Gmail, Docs,     |                                  |  (content.js)       |  |
|  |   Facebook, etc.)  |  <── Replaces Text in DOM ────── |  - DOM Extraction   |  |
|  +--------------------+                                  |  - Shadow DOM HUD   |  |
|                                                                     │             |
|                                                     chrome.runtime  │ IPC         |
|                                                     .sendMessage()  ▼             |
|  +--------------------+                                  +---------------------+  |
|  |  Extension Popup   | ─── Selects Tone Mode ─────────> |  Service Worker     |  |
|  |  & Options Page    | <── Status & Settings Sync ───── |  (service-worker.js)|  |
|  +--------------------+                                  |  - State Manager    |  |
|            │                                             |  - Prompt Builder   |  |
|            │ Saves Configuration                         |  - Error Handler    |  |
|            ▼                                             +---------------------+  |
|  +--------------------+                                             │             |
|  | chrome.storage.    | <── Reads API Keys & Presets ───────────────┤             |
|  | local (Sandboxed)  |                                             │ Direct HTTPS|
+---------------------------------------------------------------------┼-------------+
                                                                      │ (No Proxy)
                                                                      ▼
                     +─────────────────────────────────────────────────────────────+
                     |                     AI LLM ENGINES                          |
                     |  - Google Gemini (gemini-1.5-flash / gemini-2.0-flash)      |
                     |  - Groq Cloud (llama-3.3-70b-versatile, 300+ tok/s)         |
                     |  - OpenAI (gpt-4o-mini / gpt-4o)                            |
                     |  - Anthropic (claude-3-5-haiku / sonnet)                    |
                     |  - Ollama (Localhost:11434 - 100% Offline & Private)        |
                     +─────────────────────────────────────────────────────────────+
```

---

## 🎯 Feature Highlights & Tone Modes

### Key Features
* 🔤 **Banglish to Bengali Script Conversion**: Seamlessly converts phonetic Latin-script typing into flawless Bengali Unicode characters without requiring complex phonetic layout switchers.
* 🧠 **Zero Hallucination & Meaning Preservation**: Strictly retains the author's original intent, emotional tone, and factual statements. No added claims, no assumptions.
* 🛡️ **Entity & Code Integrity**: Automatically preserves proper names, numbers/dates, URLs (`https://...`), email addresses, currency amounts, coupon codes, and programming syntax.
* ✍️ **Bengali Punctuation Rules**: Correctly employs the Bengali Dari (`।` - U+0964) instead of English periods (`.`) for declarative statements, with standard spacing for commas, colons, and question marks.
* 🌐 **Universal DOM Compatibility**: Works on standard HTML `<input type="text">`, `<textarea>`, as well as rich `contenteditable` wrappers (Gmail, Slack, WhatsApp Web, Twitter/X, LinkedIn, Notion, and Google Docs).
* ⚡ **Instant In-Place Replacement**: Replaces highlighted text or whole fields directly without opening external tabs or copy-pasting.
* ↩️ **Full Undo Support**: Press standard `Cmd + Z` / `Ctrl + Z` or click "Undo" on the HUD notification to restore your original draft instantly.
* 🔒 **Zero Telemetry**: No tracking, no user logs, zero analytics scripts, and no middleman servers.

---

### The 7 Tone Modes

BanglaWrite AI features **7 specialized tone modes** engineered to handle any personal, casual, or professional writing scenario:

```
+───────────────────────────────────────────────────────────────────────────────────+
|                           BANGLAWRITE AI TONE SPECTRUM                            |
|                                                                                   |
|  [Casual] ◄─── [Natural] ───► [Polite] ───► [Professional] ───► [Formal]         |
|  (Friends)     (Everyday)     (Gentle)      (Workplace)         (Institutional)   |
|                                                                                   |
|  Specialized Modes:                                                               |
|  - [Short]: Maximum brevity & zero fluff.                                         |
|  - [Fix Grammar]: Strict error correction with zero alteration to personal voice. |
+───────────────────────────────────────────────────────────────────────────────────+
```

| # | Tone Mode | বাংলা নাম | Purpose & Stylistic Behavior | Example Input ➔ Output |
|---|---|---|---|---|
| **1** | **Natural Bangla** *(Default)* | স্বাভাবিক ও প্রমিত চলিত বাংলা | Idiomatic, fluent modern colloquial Bengali (প্রমিত চলিত ভাষা). Ideal for daily conversations, comments, and posts. | `ami ajke office ashte parbo na matha betha korche`<br>➔ **আমি আজকে অফিসে আসতে পারব না, কারণ মাথা ব্যথা করছে।** |
| **2** | **Polite** | নম্র ও বিনয়ী বাংলা | Infuses gentle warmth, courtesy, and respectful honorifics (`আপনি`/`আপনার`, `দয়া করে`, `একটু দেখবেন কি`). De-escalates blunt or impatient messages. | `ei file ta pathao taratari amar lagbe`<br>➔ **অনুগ্রহ করে ফাইলটি একটু দ্রুত পাঠালে খুব উপকৃত হতাম।** |
| **3** | **Casual** | অনানুষ্ঠানিক ও বন্ধুত্বপূর্ণ | Easygoing, relaxed conversational tone for close friends and peers. Uses friendly pronouns (`তুমি`/`তুই`) and colloquial markers (`রে`, `তো`, `চলো`). | `ami ajke rate ashte parbo na onno kono din dekha kori`<br>➔ **আজ রাতে আসতে পারছি না রে, চলো অন্য কোনো দিন দেখা করি।** |
| **4** | **Professional** | পেশাদার ও কর্মক্ষেত্রোপযোগী | Polished, structured, and constructive tone for business emails, client communications, and team updates. Uses clean business vocabulary. | `sir client meeting er time change korse kal 3 tay boshbo`<br>➔ **ক্লায়েন্ট মিটিংয়ের সময়সূচি পরিবর্তনের অনুরোধ করেছেন। আমরা কি আগামীকাল দুপুর ৩টায় বসতে পারি?** |
| **5** | **Formal** | দাপ্তরিক ও প্রাতিষ্ঠানিক বাংলা | Dignified, high-register Bengali for official applications, corporate notices, contracts, and administrative correspondence (`মহোদয়`, `সদয় অবগতির জন্য`). | `amar chuti lagbe 2 din er jonno application disi`<br>➔ **আমার জরুরি ব্যক্তিগত প্রয়োজনে আগামী দুই দিনের ছুটির জন্য বিনীত আবেদন পেশ করছি।** |
| **6** | **Short** | সংক্ষিপ্ত ও স্পষ্ট বাংলা | Condenses statements down to their bare essential action, time, and fact while maintaining grammatical integrity. Zero conversational padding. | `ami ekhon ektu busy achi tai apnar sathe ekhon kotha bolte parbo na pore phone dicchi`<br>➔ **এখন ব্যস্ত আছি, একটু পর ফোন করছি।** |
| **7** | **Fix Grammar** | ব্যাকরণ ও বানান সংশোধন | **Strict Minimal Intervention**: Corrects spelling (বানান), conjuncts (যুক্তাক্ষর), punctuation, and Banglish transliteration **without** changing wording, style, or pronoun register. | `tara kaj ta sesh korsile kintu taka pai ni.`<br>➔ **তারা কাজটা শেষ করেছিল কিন্তু টাকা পায়নি।** |

---

## 🚀 Installation Guide (Chrome Load Unpacked)

Install BanglaWrite AI into Google Chrome or any Chromium-based browser (Brave, Microsoft Edge, Opera, Vivaldi, Arc) in less than 60 seconds:

```
[ Download / Clone ] ──> [ chrome://extensions ] ──> [ Enable Developer Mode ] ──> [ Load Unpacked ] ──> ✨ Ready!
```

### Step-by-Step Instructions:

1. **Open the Extensions Page**:
   In your Chrome address bar, type the following and press `Enter`:
   ```text
   chrome://extensions
   ```

2. **Enable Developer Mode**:
   Locate the **"Developer mode"** toggle switch in the top-right corner of the Extensions page and turn it **ON**.

3. **Click "Load Unpacked"**:
   Click the **"Load unpacked"** button located on the top-left toolbar.

4. **Select the Extension Folder**:
   In the file picker dialog, navigate to and select:
   ```text
   /Users/mdyeakubsarker/Documents/Agent-bangla
   ```

5. **Verify & Pin the Extension**:
   * The **BanglaWrite AI** extension card will appear with its emerald **"ব"** icon and version `1.0.0`.
   * Click the **Extensions puzzle icon** (🧩) on your browser toolbar and click the **Pin icon** (📌) next to BanglaWrite AI.

---

## 🔑 How to Obtain API Keys

BanglaWrite AI communicates directly with your preferred LLM provider. Follow the step-by-step guides below to obtain your key:

### 1. Google Gemini API (Free Tier Recommended)
*Recommended for most users — completely free tier with high speed and natural Bengali understanding.*

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Sign in with your standard Google account.
3. Click the blue **"Create API key"** button.
4. Choose **"Create API key in new project"** (or link an existing Google Cloud project).
5. Copy the generated key string (starts with `AIzaSy...`).
6. *Cost*: **Free** under Google's generous rate limits (15 requests/minute, 1,500 requests/day).

---

### 2. Groq API (Ultra-Fast & Free Tier)
*Incredible speed (300+ tokens/second) powered by LPU inference with `llama-3.3-70b-versatile`.*

1. Go to the [Groq Console](https://console.groq.com/).
2. Sign up or log in with GitHub or Google.
3. In the left navigation menu, click **"API Keys"**.
4. Click **"Create API Key"**, enter a name (e.g. `BanglaWrite`), and click **Submit**.
5. Copy your key immediately (starts with `gsk_...`).
6. *Cost*: **Free tier** with fast response times.

---

### 3. OpenAI API
*Standard enterprise reliability with `gpt-4o-mini` or `gpt-4o`.*

1. Navigate to the [OpenAI Platform](https://platform.openai.com/).
2. Log in and access the [API Keys Dashboard](https://platform.openai.com/api-keys).
3. Click **"Create new secret key"**.
4. Label the key `BanglaWrite-AI` and click **Create secret key**.
5. Copy the key string (starts with `sk-proj-...`).

---

### 4. Ollama (100% Free, Offline & Private)
*Run completely locally on your machine without an internet connection or external API key.*

1. Download and install Ollama from [ollama.com/download](https://ollama.com/download).
2. Open your terminal and pull a model:
   ```bash
   ollama run llama3.2
   ```
3. **Configure CORS for Chrome Extensions**:
   * **macOS / Linux**:
     ```bash
     OLLAMA_ORIGINS="*" ollama serve
     ```
   * **Windows**:
     ```cmd
     set OLLAMA_ORIGINS=*
     ollama serve
     ```
4. In BanglaWrite AI Settings, select **Ollama (Local)**.
   * Endpoint: `http://localhost:11434/v1/chat/completions`
   * Model: `llama3.2`

---

## ⚙️ Configuring API Settings

1. Click the BanglaWrite AI toolbar icon and click **"⚙️ API Settings"**.
2. Select your AI Provider (Google Gemini, Groq, OpenAI, Anthropic, or Ollama).
3. Paste your API key into the API Key input box.
4. Select your preferred default writing tone.
5. Click **"Test Connection"** (`সংযোগ পরীক্ষা`) to verify the key.
6. Click **"Save Settings"** (`সেটিংস সংরক্ষণ করুন`).

---

## ⌨️ Keyboard Shortcut Usage (`Command/Ctrl + Shift + B`)

```
       macOS:   [ ⌘ Command ]  +  [ ⇧ Shift ]  +  [ B ]
Windows/Linux:   [ Ctrl      ]  +  [ ⇧ Shift ]  +  [ B ]
```

1. **Selected Text Replacement (Precision Mode)**:
   Highlight a specific word or sentence, then press <kbd>Cmd/Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>. Only the selected portion will be rewritten.
2. **Entire Field Replacement (Zero-Selection Mode)**:
   Keep your caret anywhere inside an input field or textarea and press <kbd>Cmd/Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>. The entire field will be rewritten.
3. **No Auto-Submit**: The extension will never automatically send, post, or submit the form.
4. **Undo Support**: Press <kbd>Cmd</kbd> + <kbd>Z</kbd> (or <kbd>Ctrl</kbd> + <kbd>Z</kbd>) to revert anytime.

---

## 🔒 Privacy & Security Commitment

- **Password Protection**: Password fields (`type="password"`) and credential autocomplete fields are strictly ignored.
- **Credential Isolation**: API keys remain strictly within `chrome.storage` and background service workers; web pages cannot access raw keys.
- **Zero Telemetry**: No analytics, tracking pixels, or external dependencies.
- **Direct Communication**: All requests go directly to your configured provider or localhost (Ollama).

---

## 📂 Project Structure & File Map

```text
Agent-bangla/
├── manifest.json              # Chrome Manifest V3 specification
├── icons/                     # Icons (16, 32, 48, 128) + icon.svg
│   ├── icon16.png
│   ├── icon32.png
│   ├── icon48.png
│   └── icon128.png
├── popup/                     # Extension popup interface
│   ├── popup.html
│   ├── popup.css
│   └── popup.js
├── options/                   # Settings & API configuration page
│   ├── options.html
│   ├── options.css
│   └── options.js
├── content/                   # In-page script & Shadow DOM HUD
│   ├── content.js
│   └── content.css
├── background/                # Background service worker (MV3)
│   └── service-worker.js
├── api/                       # Multi-provider client (Gemini, Groq, OpenAI, Ollama, Anthropic)
│   └── ai.js
├── utils/                     # Safe text replacement & storage sync
│   ├── text.js
│   └── storage.js
├── test/                      # Verification suite (77 automated tests)
│   └── verify.js
└── README.md
```

---

## 📄 License

* **Author**: Md Yeakub Sarker
* **License**: MIT Open-Source License
