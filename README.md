# BanglaWrite AI (বাংলা রাইটিং অ্যাসিস্ট্যান্ট)

> **বাংলিশ ও অপ্রমিত বাংলাকে এক ক্লিকে স্বাভাবিক, সুন্দর ও ব্যাকরণসম্মত প্রমিত বাংলায় রূপান্তর করার জন্য একটি অত্যন্ত হালকা (Ultra-lightweight) Chrome Extension।**

![Version](https://img.shields.io/badge/version-1.0.0-emerald)
![Manifest](https://img.shields.io/badge/manifest-v3-blue)
![Dependencies](https://img.shields.io/badge/dependencies-0-success)
![Hardware](https://img.shields.io/badge/hardware-optimized%20for%20MacBook%20Air-purple)

---

## 🌟 মূল বৈশিষ্ট্যসমূহ (Key Features)

1. **যেকোনো ওয়েবসাইটে কাজ করে**: Facebook, Messenger, Gmail, LinkedIn, Discord Web, YouTube, কিংবা যেকোনো সাধারণ ফর্মের ইনপুট বা `contenteditable` টেক্সটবক্সে কাজ করে।
2. **কিবোর্ড শর্টকাট**: <kbd>Command</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> (Mac) অথবা <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> (Windows/Linux)।
3. **নির্বাচিত অথবা সম্পূর্ণ লেখা রূপান্তর**:
   - কোনো অংশ সিলেক্ট করা থাকলে **শুধুমাত্র নির্বাচিত অংশ** রূপান্তর হবে।
   - কোনো অংশ সিলেক্ট না থাকলে **সম্পূর্ণ টেক্সটবক্সের লেখা** রূপান্তর হবে।
4. **কোনো স্বয়ংক্রিয় সেন্ড/পোস্ট নেই**: এক্সটেনশন কখনোই স্বয়ংক্রিয়ভাবে ফর্ম সাবমিট বা সেন্ড বাটনে ক্লিক করবে না। আপনি নিজে দেখে সন্তুষ্ট হয়ে ম্যানুয়ালি সেন্ড করবেন।
5. **৭টি ভিন্ন টোন মোড (Tone Modes)**:
   - **Natural Bangla**: স্বাভাবিক, স্বতঃস্ফূর্ত ও সাবলীল প্রমিত বাংলা।
   - **Polite**: বিনম্র, মার্জিত ও শ্রদ্ধাশীল ভাষা।
   - **Casual**: বন্ধুমহলের আড্ডা ও হালকা কথ্য রূপ।
   - **Professional**: অফিস, ক্লায়েন্ট ও কর্মক্ষেত্রোপযোগী পরিশীলিত ভাষা।
   - **Formal**: প্রাতিষ্ঠানিক, দাপ্তরিক ও প্রমিত রূপ।
   - **Short**: মূল ভাব ঠিক রেখে সরাসরি ও সংক্ষিপ্ত রূপ।
   - **Fix Grammar**: শব্দ ও ভাব অপরিবর্তিত রেখে কেবল বানান, যতিচিহ্ন ও ব্যাকরণ সংশোধন।
6. **মাল্টি-প্রভাইডার সুবিধা**:
   - Google Gemini (বিনামূল্যে ব্যবহারের সুযোগ ও অত্যন্ত সমৃদ্ধ বাংলা সাপোর্ট)
   - Groq (সুপার-ফাস্ট LPU ইনফারেন্স)
   - OpenAI (GPT-4o Mini / GPT-4o)
   - Anthropic Claude (Claude 3.5 Haiku)
   - Ollama (আপনার কম্পিউটারে সম্পূর্ণ লোকাল ও অফলাইন)
7. **ম্যাকবুক এয়ার ২০১৭ (Intel) অপ্টিমাইজড**: শূন্য ডিপেন্ডেন্সি, কোনো ফ্রেমওয়ার্ক নেই, কোনো মেমরি লিক নেই।

---

## 🚀 কীভাবে Chrome-এ ইনস্টল করবেন (Load Unpacked)

১. গুগল ক্রোম (Google Chrome) ব্রাউজার খুলুন।  
২. এড্রেস বারে যান: `chrome://extensions/`  
৩. ওপরের ডান কোণায় থাকা **Developer mode** টগলটি চালু (ON) করুন।  
৪. ওপরের বাঁ দিকে থাকা **Load unpacked** বাটনে ক্লিক করুন।  
৫. ফাইল সিলেক্টর থেকে এই ডিরেক্টরিটি নির্বাচন করুন:  
   `/Users/mdyeakubsarker/Documents/Agent-bangla`  
৬. ব্যস! আপনার এক্সটেনশন তালিকায় **BanglaWrite AI** যুক্ত হয়ে যাবে।

---

## ⚙️ কীভাবে API কনফিগার করবেন (API Settings)

১. ক্রোমের এক্সটেনশন আইকন থেকে **BanglaWrite AI**-এর ওপর ক্লিক করুন অথবা এক্সটেনশন সেটিংসে যান।  
২. **API Provider** হিসেবে আপনার পছন্দ নির্বাচন করুন (যেমন: **Google Gemini**)।  
৩. আপনার API কী (API Key) প্রবেশ করান:
   - **Google Gemini**: [Google AI Studio](https://aistudio.google.com/app/apikey) থেকে সম্পূর্ণ বিনামূল্যে আপনার API Key সংগ্রহ করুন।
   - **Groq**: [Groq Console](https://console.groq.com/keys) থেকে ফ্রি ও দ্রুততম API Key সংগ্রহ করতে পারেন।
   - **Ollama**: লোকাল ব্যবহারের জন্য কোনো কী-এর প্রয়োজন নেই (ডিফল্ট: `http://localhost:11434/v1/chat/completions`)।
৪. **Test Connection** বাটনে ক্লিক করে সংযোগ নিশ্চিত করুন।  
৫. **Save Settings** বাটনে ক্লিক করে সেটিংস সেভ করুন।

---

## ⌨️ কীভাবে ব্যবহার করবেন (Usage Guide)

1. যেকোনো ওয়েবসাইট (যেমন: Facebook, Gmail, Messenger) খুলুন।
2. যেকোনো টেক্সটবক্সে ক্লিক করে বাংলিশ বা খসড়া বাংলায় লিখুন:
   ```text
   ami ajke jete parbo na kalke gele ki hobe
   ```
3. কিবোর্ডে চাপুন:
   - **Mac**: <kbd>Command</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>
   - **Windows / Linux**: <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>
4. স্ক্রিনের নিচে সুন্দর নোটিফিকেশন আসবে এবং মুহূর্তের মধ্যে লেখাটি প্রতিস্থাপিত হয়ে যাবে:
   ```text
   আমি আজকে যেতে পারব না। কালকে গেলে কি হবে?
   ```
5. পছন্দ না হলে তাৎক্ষণিক <kbd>Cmd</kbd> + <kbd>Z</kbd> বা <kbd>Ctrl</kbd> + <kbd>Z</kbd> চেপে পূর্বাবস্থায় ফিরে যেতে পারবেন।

---

## 📂 প্রোজেক্ট আর্কিটেকচার (Project Architecture)

```
Agent-bangla/
├── manifest.json              # Chrome Manifest V3 কনফিগারেশন
├── icons/                     # ক্রোম এক্সটেনশন আইকনসমূহ (16, 32, 48, 128)
│   ├── icon16.png
│   ├── icon32.png
│   ├── icon48.png
│   ├── icon128.png
│   └── icon.svg
├── popup/                     # এক্সটেনশন পপআপ ইন্টারফেস
│   ├── popup.html
│   ├── popup.css
│   └── popup.js
├── options/                   # সেটিংস ও API কনফিগারেশন পেজ
│   ├── options.html
│   ├── options.css
│   └── options.js
├── content/                   # ওয়েবপেজে ইনজেক্ট হওয়া স্ক্রিপ্ট ও Shadow DOM HUD
│   ├── content.js
│   └── content.css
├── background/                # ব্যাকগ্রাউন্ড সার্ভিস ওয়ার্কার (MV3)
│   └── service-worker.js
├── api/                       # মাল্টি-প্রভাইডার AI মডিউল
│   └── ai.js
├── utils/                     # টেক্সট, DOM ও স্টোরেজ হেল্পার
│   ├── text.js
│   └── storage.js
├── test/                      # টেস্ট ও ভেরিফিকেশন স্যুট
│   └── verify.js
└── README.md
```

---

## 🔒 নিরাপত্তা ও গোপনীয়তা (Security & Privacy)

- **কোনো ব্রাউজিং হিস্ট্রি ট্র্যাক করা হয় না**: ব্যবহারকারীর কোনো ব্রাউজিং ডেটা সংগ্রহ করা হয় না।
- **API কী সুরক্ষিত**: আপনার API কী শুধুমাত্র আপনার ব্রাউজারের `chrome.storage`-এ এনক্রিপ্টেড/লোকালি সংরক্ষিত থাকে। এটি কোনো তৃতীয় পক্ষের সার্ভারে পাঠানো হয় না।
- **শুধুমাত্র ব্যবহারকারীর ইচ্ছায় ডেটা সেন্ড**: ব্যবহারকারী নিজে শর্টকাট চাপলে কেবল সেই নির্দিষ্ট টেক্সটটি নির্বাচিত AI প্রভাইডারে পাঠানো হয়।
- **ন্যূনতম পারমিশন**: অপ্রয়োজনীয় কোনো পারমিশন চাওয়া হয়নি (`storage`, `activeTab`)।

---

## 🧪 টেস্ট চালানো (Run Verification)

প্রোজেক্টের সমস্ত ভ্যালিডেশন টেস্ট চালাতে রান করুন:
```bash
node test/verify.js
```
