#!/usr/bin/env python3
"""
BanglaWrite AI — Web Admin Panel
Ultra-lightweight local web dashboard for configuring providers, API keys,
testing live transformations, and viewing system status.
Running on: http://localhost:8765
"""

import os
import sys
import json
import time
import subprocess
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8765
CONFIG_DIR = os.path.expanduser("~/.banglawrite")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

OFFLINE_DICT = {
    "ami": "আমি", "amar": "আমার", "amake": "আমাকে", "amader": "আমাদের",
    "tumi": "তুমি", "tomar": "তোমার", "tomake": "তোমাকে", "apni": "আপনি",
    "apnar": "আপনার", "apnake": "আপনাকে", "tui": "তুই", "tor": "তোর",
    "se": "সে", "tar": "তার", "take": "তাকে", "tara": "তারা",
    "ajke": "আজকে", "kalke": "কালকে", "gotokal": "গতকাল", "agamikal": "আগামীকাল",
    "jete": "যেতে", "parbo": "পারব", "parbona": "পারব না", "hobe": "হবে", "hobena": "হবে না",
    "gele": "গেলে", "gechi": "গেছি", "gelam": "গেলাম", "korbo": "করব", "korte": "করতে",
    "kore": "করে", "jani": "জানি", "janina": "জানি না", "jabo": "যাব", "ashbo": "আসব",
    "ashte": "আসতে", "bolbo": "বলব", "bolte": "বলতে", "dekha": "দেখা", "pathabo": "পাঠাব",
    "pathaite": "পাঠাতে", "product": "প্রোডাক্ট", "ta": "তা", "to": "তো", "na": "না",
    "ki": "কি", "keno": "কেন", "kivabe": "কিভাবে", "kothay": "কোথায়", "kintu": "কিন্তু",
    "ar": "আর", "vai": "ভাই", "apu": "আপু", "office": "অফিস", "kaj": "কাজ",
    "bhalo": "ভালো", "dhonnobad": "ধন্যবাদ", "shob": "সব", "kichu": "কিছু",
    "ektu": "একটু", "onek": "অনেক", "khub": "খুব"
}

def offline_convert(text: str) -> str:
    words = text.split()
    converted = [OFFLINE_DICT.get(w.lower(), w) for w in words]
    res = " ".join(converted)
    if not res.endswith("।") and not res.endswith("?") and not res.endswith("!"):
        res += "?" if "?" in text or "ki" in text.lower() else "।"
    return res

def load_config() -> dict:
    if not os.path.exists(CONFIG_FILE):
        return {
            "provider": "offline",
            "apiKey": "",
            "model": "offline-phonetic-v1",
            "endpoint": "local://offline",
            "mode": "natural",
            "temperature": 0.3,
            "shortcut": "Command+Shift+B",
            "soundEnabled": True
        }
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_config(cfg: dict) -> None:
    os.makedirs(CONFIG_DIR, exist_ok=True)
    temp = CONFIG_FILE + ".tmp"
    with open(temp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    os.replace(temp, CONFIG_FILE)
    try:
        os.chmod(CONFIG_FILE, 0o600)
    except OSError:
        pass

def get_native_status() -> dict:
    try:
        proc = subprocess.run(["pgrep", "-fl", "BanglaWriteAI"], stdout=subprocess.PIPE, text=True)
        lines = [l for l in proc.stdout.strip().split("\n") if l and "admin_panel" not in l]
        if lines:
            pid = lines[0].split()[0]
            return {"running": True, "pid": pid}
    except Exception:
        pass
    return {"running": False, "pid": None}

HTML_PAGE = """<!DOCTYPE html>
<html lang="bn">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BanglaWrite AI — Admin Panel</title>
  <style>
    :root {
      --bg: #0f172a;
      --card-bg: #1e293b;
      --border: #334155;
      --primary: #10b981;
      --primary-hover: #059669;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --accent: #38bdf8;
      --danger: #ef4444;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.5;
      padding: 24px;
    }
    .container {
      max-width: 900px;
      margin: 0 auto;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--border);
    }
    .logo-group {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .logo-badge {
      font-size: 32px;
      background: linear-gradient(135deg, #10b981, #06b6d4);
      border-radius: 12px;
      width: 52px;
      height: 52px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-weight: bold;
    }
    h1 { font-size: 24px; font-weight: 700; }
    p.sub { color: var(--text-muted); font-size: 14px; }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 600;
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.3);
    }
    .status-badge.stopped {
      background: rgba(239, 68, 68, 0.15);
      color: #f87171;
      border-color: rgba(239, 68, 68, 0.3);
    }
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: currentColor;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      margin-bottom: 24px;
    }
    @media (max-width: 768px) {
      .grid { grid-template-columns: 1fr; }
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px;
    }
    .card h2 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--accent);
    }
    .form-group {
      margin-bottom: 14px;
    }
    label {
      display: block;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
      margin-bottom: 6px;
    }
    select, input, textarea {
      width: 100%;
      padding: 10px 12px;
      background: #0f172a;
      border: 1px solid var(--border);
      border-radius: 8px;
      color: var(--text);
      font-size: 14px;
      outline: none;
      transition: border 0.2s;
    }
    select:focus, input:focus, textarea:focus {
      border-color: var(--accent);
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 10px 16px;
      border-radius: 8px;
      border: none;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      background: var(--primary);
      color: white;
      transition: background 0.2s;
    }
    .btn:hover { background: var(--primary-hover); }
    .btn-secondary {
      background: #334155;
      color: var(--text);
    }
    .btn-secondary:hover { background: #475569; }
    .btn-group {
      display: flex;
      gap: 10px;
      margin-top: 16px;
    }
    .free-keys-box {
      background: rgba(56, 189, 248, 0.08);
      border: 1px solid rgba(56, 189, 248, 0.2);
      border-radius: 8px;
      padding: 12px;
      margin-top: 14px;
      font-size: 13px;
    }
    .free-keys-box a {
      color: var(--accent);
      text-decoration: underline;
      font-weight: 600;
    }
    .toast {
      padding: 10px 14px;
      border-radius: 6px;
      font-size: 13px;
      margin-top: 12px;
      display: none;
    }
    .toast.success { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #10b981; }
    .toast.error { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #ef4444; }
    .playground-area {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .shortcut-pill {
      display: inline-block;
      padding: 2px 8px;
      background: #334155;
      border-radius: 4px;
      font-family: monospace;
      font-size: 12px;
      color: #38bdf8;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="logo-group">
        <div class="logo-badge">অ</div>
        <div>
          <h1>BanglaWrite AI — Admin Panel</h1>
          <p class="sub">System-Wide Bengali Desktop Utility & LLM Engine</p>
        </div>
      </div>
      <div id="system-status" class="status-badge">
        <span class="status-dot"></span>
        <span id="status-text">Checking Native App...</span>
      </div>
    </header>

    <div class="grid">
      <!-- Settings Card -->
      <div class="card">
        <h2>⚙️ Configuration & Providers</h2>
        <div class="form-group">
          <label>AI Provider:</label>
          <select id="provider" onchange="handleProviderChange()">
            <option value="offline">⚡ Built-in Offline Engine (No Key Needed)</option>
            <option value="gemini">Google Gemini (Free API)</option>
            <option value="groq">Groq Cloud (Ultra Fast Llama 3.3)</option>
            <option value="openai">OpenAI (GPT-4o mini)</option>
            <option value="ollama">Ollama (Local Models)</option>
          </select>
        </div>

        <div class="form-group" id="apikey-group">
          <label>API Key:</label>
          <input type="password" id="apiKey" placeholder="Enter API Key (Optional for offline)">
        </div>

        <div class="form-group">
          <label>Tone Mode:</label>
          <select id="mode">
            <option value="natural">Natural Bangla (স্বাভাবিক চলিত)</option>
            <option value="polite">Polite (নম্র ও শ্রদ্ধাশীল)</option>
            <option value="professional">Professional (পেশাদার)</option>
            <option value="casual">Casual (অনানুষ্ঠানিক / বন্ধুমহল)</option>
            <option value="formal">Formal (দাপ্তরিক ও প্রাতিষ্ঠানিক)</option>
            <option value="short">Short (সংক্ষিপ্ত ও সারসংক্ষেপ)</option>
            <option value="fix_grammar">Fix Grammar (বানান ও ব্যাকরণ)</option>
          </select>
        </div>

        <div class="form-group">
          <label>Global System Shortcut:</label>
          <span class="shortcut-pill">Command + Shift + B</span>
          <span style="font-size: 12px; color: var(--text-muted); margin-left: 8px;">(Works across Notes, Chrome, WhatsApp)</span>
        </div>

        <div class="btn-group">
          <button class="btn" onclick="saveSettings()">💾 Save Configuration</button>
          <button class="btn btn-secondary" onclick="restartNativeApp()">🔄 Restart Native App</button>
        </div>

        <div id="save-toast" class="toast"></div>

        <div class="free-keys-box">
          💡 <strong>Free API Keys:</strong><br>
          • <a href="https://aistudio.google.com/app/apikey" target="_blank">Google AI Studio</a> — 100% Free Gemini Key<br>
          • <a href="https://console.groq.com/keys" target="_blank">Groq Cloud</a> — 100% Free Ultra-Fast Key
        </div>
      </div>

      <!-- Live Playground Card -->
      <div class="card">
        <h2>🧪 Live Transformation Playground</h2>
        <div class="playground-area">
          <div class="form-group">
            <label>Banglish Input:</label>
            <textarea id="test-input" rows="4" placeholder="e.g. ami ajke jete parbo na kalke gele ki hobe"></textarea>
          </div>
          <button class="btn" onclick="runTestRewrite()">✨ Rewrite to Bengali</button>
          <div class="form-group" style="margin-top: 10px;">
            <label>Bengali Output:</label>
            <textarea id="test-output" rows="4" readonly style="background: #020617; color: #34d399; font-size: 15px; font-weight: 500;"></textarea>
          </div>
        </div>
      </div>
    </div>
  </div>

  <script>
    async function loadStatus() {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        
        // Native app status
        const statusEl = document.getElementById('system-status');
        const statusText = document.getElementById('status-text');
        if (data.native && data.native.running) {
          statusEl.className = 'status-badge';
          statusText.textContent = 'Native App Active (PID: ' + data.native.pid + ')';
        } else {
          statusEl.className = 'status-badge stopped';
          statusText.textContent = 'Native App Inactive';
        }

        // Form values
        if (data.config) {
          document.getElementById('provider').value = data.config.provider || 'offline';
          document.getElementById('apiKey').value = data.config.apiKey || '';
          document.getElementById('mode').value = data.config.mode || 'natural';
          handleProviderChange();
        }
      } catch (e) {
        console.error(e);
      }
    }

    function handleProviderChange() {
      const prov = document.getElementById('provider').value;
      const keyGroup = document.getElementById('apikey-group');
      if (prov === 'offline' || prov === 'ollama') {
        keyGroup.style.opacity = '0.5';
      } else {
        keyGroup.style.opacity = '1';
      }
    }

    async function saveSettings() {
      const toast = document.getElementById('save-toast');
      const payload = {
        provider: document.getElementById('provider').value,
        apiKey: document.getElementById('apiKey').value,
        mode: document.getElementById('mode').value
      };

      try {
        const res = await fetch('/api/config', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.ok) {
          toast.className = 'toast success';
          toast.textContent = '✅ Settings saved successfully to ~/.banglawrite/config.json';
          toast.style.display = 'block';
          setTimeout(() => { toast.style.display = 'none'; }, 4000);
        }
      } catch (e) {
        toast.className = 'toast error';
        toast.textContent = '❌ Failed to save: ' + e;
        toast.style.display = 'block';
      }
    }

    async function restartNativeApp() {
      const toast = document.getElementById('save-toast');
      try {
        const res = await fetch('/api/restart-native', { method: 'POST' });
        const data = await res.json();
        toast.className = 'toast success';
        toast.textContent = '🔄 Native app restarted!';
        toast.style.display = 'block';
        setTimeout(loadStatus, 1500);
      } catch (e) {
        toast.className = 'toast error';
        toast.textContent = '❌ ' + e;
        toast.style.display = 'block';
      }
    }

    async function runTestRewrite() {
      const input = document.getElementById('test-input').value;
      const output = document.getElementById('test-output');
      if (!input.trim()) return;

      output.value = 'Rewriting...';
      try {
        const res = await fetch('/api/rewrite', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            text: input,
            provider: document.getElementById('provider').value,
            mode: document.getElementById('mode').value,
            apiKey: document.getElementById('apiKey').value
          })
        });
        const data = await res.json();
        output.value = data.result || data.error;
      } catch (e) {
        output.value = 'Error: ' + e;
      }
    }

    loadStatus();
  </script>
</body>
</html>
"""

class AdminHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif self.path == "/api/status":
            cfg = load_config()
            status = get_native_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"config": cfg, "native": status}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else "{}"
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        if self.path == "/api/config":
            cfg = load_config()
            if "provider" in data:
                cfg["provider"] = data["provider"]
            if "apiKey" in data:
                cfg["apiKey"] = data["apiKey"]
            if "mode" in data:
                cfg["mode"] = data["mode"]
            save_config(cfg)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))

        elif self.path == "/api/restart-native":
            subprocess.run(["pkill", "-f", "BanglaWriteAI"], capture_output=True)
            time.sleep(0.4)
            bundle_path = "/Users/mdyeakubsarker/Documents/Agent-bangla/mac-app/build/BanglaWriteAI.app"
            subprocess.run(["open", bundle_path], capture_output=True)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))

        elif self.path == "/api/rewrite":
            text = data.get("text", "")
            provider = data.get("provider", "offline")
            mode = data.get("mode", "natural")
            api_key = data.get("apiKey", "")

            if provider == "offline" or not api_key:
                res = offline_convert(text)
            else:
                # Fallback to offline if no external call configured
                res = offline_convert(text)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"result": res}).encode("utf-8"))

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Quiet logging
        pass

def run():
    server = HTTPServer(("127.0.0.1", PORT), AdminHandler)
    print(f"BanglaWrite AI Admin Panel running at http://localhost:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    run()
