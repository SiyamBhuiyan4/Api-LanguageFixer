#!/usr/bin/env python3
"""
BanglaWrite AI — Pure-Python 3 Companion CLI & Daemon for macOS
Zero-dependency desktop companion for converting Banglish & informal text
into clean, natural Bengali script across macOS applications.

Usage:
    python3 banglawrite.py                          # Interactive terminal prompt (REPL)
    python3 banglawrite.py "ami ajke ashbo na"      # One-shot command line translation
    python3 banglawrite.py -s / --selection         # Capture active macOS selection & paste
    python3 banglawrite.py -c / --clipboard         # Rewrite current macOS clipboard
    python3 banglawrite.py -d / --daemon            # Run local HTTP daemon on 127.0.0.1:8765
    python3 banglawrite.py --setup                  # Interactive API configuration wizard
"""

import os
import sys
import json
import time
import argparse
import subprocess
import urllib.request
import urllib.error
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread

CONFIG_DIR = os.path.expanduser("~/.banglawrite")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
DAEMON_PORT = 8765

TONE_MODES = {
    "natural": {
        "id": "natural",
        "name": "Natural Bangla",
        "instruction": "Convert the input into natural, fluent, and human-sounding everyday colloquial Bengali (প্রমিত চলিত বাংলা). Keep it authentic and effortless without being overly stiff."
    },
    "polite": {
        "id": "polite",
        "name": "Polite",
        "instruction": 'Make the text polite, respectful, and courteous (always using "আপনি" and respectful Bengali phrasing like "দয়া করে", "অনুরোধ করছি", or "আপু/ভাইয়া" where contextually fitting) without sounding groveling.'
    },
    "casual": {
        "id": "casual",
        "name": "Casual",
        "instruction": "Convert into relaxed, friendly, and informal conversational Bengali (using 'তুমি' or 'তুই' where appropriate), suitable for chatting with friends or close peers."
    },
    "professional": {
        "id": "professional",
        "name": "Professional",
        "instruction": "Rewrite with a polished, courteous, business-appropriate Bengali tone suitable for work, email, clients, or colleagues."
    },
    "formal": {
        "id": "formal",
        "name": "Formal",
        "instruction": "Use standard, official, dignified, and grammatically precise formal Bengali (প্রমিত সাধু/চলিত দাপ্তরিক ভাষা)."
    },
    "short": {
        "id": "short",
        "name": "Short",
        "instruction": "Make the message concise, direct, and crisp in Bengali while preserving 100% of the core actionable information, numbers, dates, and URLs."
    },
    "fix_grammar": {
        "id": "fix_grammar",
        "name": "Fix Grammar",
        "instruction": "Preserve the exact wording, style, vocabulary, and pronouns as much as possible; only fix spelling mistakes, phonetic typos, Bengali script conversion, and punctuation."
    }
}

SYSTEM_PROMPT_TEMPLATE = """You are "BanglaWrite AI", a specialized Bengali writing assistant and Banglish translator.

PRIMARY DIRECTIVES:
1. Convert Banglish (Bengali written in English/Latin letters, e.g. "ami ajke jete parbo na kalke gele ki hobe") or broken/informal Bengali into clean, grammatically correct Bengali script ("আমি আজকে যেতে পারব না। কালকে গেলে কি হবে?").
2. Strictly PRESERVE the user's intended meaning. Do NOT invent, assume, or add facts, claims, or information that the user did not express.
3. Preserve personal names, numbers/digits, URLs, usernames, email addresses, brand names, product titles, and common technical terms intact.
4. Ensure declarative sentences end with Bengali Dari (।), and interrogative sentences end with question marks (?).
5. Tone Mode: {MODE_INSTRUCTION}
6. Clean Output Rule: Return ONLY the final rewritten Bengali text. Do NOT wrap in quotes. Do NOT include markdown code fences (```). Do NOT include explanatory notes, introductions, or apologies."""

PROVIDER_DEFAULTS = {
    "offline": {
        "name": "Built-in Offline Engine (No Key Needed)",
        "endpoint": "local://offline",
        "model": "offline-phonetic-v1",
        "requires_api_key": False,
        "env_var": ""
    },
    "gemini": {
        "name": "Google Gemini",
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models",
        "model": "gemini-1.5-flash",
        "requires_api_key": True,
        "env_var": "GEMINI_API_KEY"
    },
    "groq": {
        "name": "Groq Cloud (Fast)",
        "endpoint": "https://api.groq.com/openai/v1/chat/completions",
        "model": "llama-3.3-70b-versatile",
        "requires_api_key": True,
        "env_var": "GROQ_API_KEY"
    },
    "openai": {
        "name": "OpenAI",
        "endpoint": "https://api.openai.com/v1/chat/completions",
        "model": "gpt-4o-mini",
        "requires_api_key": True,
        "env_var": "OPENAI_API_KEY"
    },
    "ollama": {
        "name": "Ollama (Local Offline)",
        "endpoint": "http://localhost:11434/v1/chat/completions",
        "model": "llama3.2",
        "requires_api_key": False,
        "env_var": ""
    },
    "custom": {
        "name": "Custom OpenAI-Compatible",
        "endpoint": "http://localhost:8080/v1/chat/completions",
        "model": "custom-model",
        "requires_api_key": False,
        "env_var": "CUSTOM_API_KEY"
    }
}

DEFAULT_CONFIG = {
    "provider": "gemini",
    "mode": "natural",
    "apiKey": "",
    "model": "gemini-1.5-flash",
    "endpoint": "https://generativelanguage.googleapis.com/v1beta/models",
    "temperature": 0.3,
    "soundEnabled": True,
    "providerConfigs": {
        p: {
            "apiKey": "",
            "endpoint": d["endpoint"],
            "model": d["model"]
        } for p, d in PROVIDER_DEFAULTS.items()
    }
}

def load_config() -> dict:
    if not os.path.exists(CONFIG_FILE):
        return DEFAULT_CONFIG.copy()
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            merged = DEFAULT_CONFIG.copy()
            merged.update(cfg)
            return merged
    except Exception:
        return DEFAULT_CONFIG.copy()

def save_config(cfg: dict) -> None:
    os.makedirs(CONFIG_DIR, exist_ok=True)
    temp_file = CONFIG_FILE + ".tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, CONFIG_FILE)
    try:
        os.chmod(CONFIG_FILE, 0o600)
    except OSError:
        pass

def resolve_settings(args=None) -> dict:
    cfg = load_config()
    provider = (getattr(args, "provider", None) or os.environ.get("BANGLAWRITE_PROVIDER") or cfg.get("provider", "gemini")).lower()
    mode = (getattr(args, "mode", None) or os.environ.get("BANGLAWRITE_MODE") or cfg.get("mode", "natural")).lower()

    if mode not in TONE_MODES:
        mode = "natural"
    if provider not in PROVIDER_DEFAULTS:
        provider = "gemini"

    prov_cfg = cfg.get("providerConfigs", {}).get(provider, {})
    default_meta = PROVIDER_DEFAULTS[provider]

    env_key_name = default_meta["env_var"]
    env_key = os.environ.get(env_key_name) if env_key_name else None
    generic_key = os.environ.get("BANGLAWRITE_API_KEY")

    api_key = (getattr(args, "api_key", None) or env_key or generic_key or prov_cfg.get("apiKey", "") or cfg.get("apiKey", "")).strip()
    model = (getattr(args, "model", None) or os.environ.get("BANGLAWRITE_MODEL") or prov_cfg.get("model", "") or default_meta["model"]).strip()
    endpoint = (getattr(args, "endpoint", None) or os.environ.get("BANGLAWRITE_ENDPOINT") or prov_cfg.get("endpoint", "") or default_meta["endpoint"]).strip()

    return {
        "provider": provider,
        "mode": mode,
        "apiKey": api_key,
        "model": model,
        "endpoint": endpoint,
        "requiresApiKey": default_meta["requires_api_key"]
    }

def get_clipboard() -> str:
    try:
        proc = subprocess.run(["pbpaste"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        return proc.stdout.decode("utf-8")
    except Exception:
        return ""

def set_clipboard(text: str) -> bool:
    try:
        proc = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
        proc.communicate(input=text.encode("utf-8"))
        return proc.returncode == 0
    except Exception:
        return False

def capture_selection() -> str:
    old_clipboard = get_clipboard()
    sentinel = f"__BW_CAPTURE_{time.time()}__"
    set_clipboard(sentinel)
    time.sleep(0.04)

    # Simulate Cmd+C
    script = 'tell application "System Events" to keystroke "c" using {command down}'
    subprocess.run(["osascript", "-e", script], capture_output=True)
    time.sleep(0.12)

    new_clipboard = get_clipboard()
    if new_clipboard == sentinel or not new_clipboard.strip():
        set_clipboard(old_clipboard)
        return ""

    return new_clipboard

def paste_text(text: str) -> bool:
    if not set_clipboard(text):
        return False
    time.sleep(0.04)
    script = 'tell application "System Events" to keystroke "v" using {command down}'
    res = subprocess.run(["osascript", "-e", script], capture_output=True)
    return res.returncode == 0

def clean_output(text: str) -> str:
    clean = text.strip()
    if clean.startswith("```") and clean.endswith("```"):
        lines = clean.splitlines()
        if len(lines) >= 2:
            clean = "\n".join(lines[1:-1]).strip()
    if (clean.startswith('"') and clean.endswith('"')) or (clean.startswith('“') and clean.endswith('”')):
        clean = clean[1:-1].strip()
    return clean

def call_gemini(user_text: str, system_prompt: str, settings: dict) -> str:
    endpoint = settings["endpoint"].rstrip("/")
    model = settings["model"]
    api_key = settings["apiKey"]
    url = f"{endpoint}/{model}:generateContent"

    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": [{"text": user_text}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 2048}
    }
    body_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body_bytes,
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=25) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        candidates = res.get("candidates", [])
        if not candidates:
            raise RuntimeError("Gemini returned empty candidate list.")
        parts = candidates[0].get("content", {}).get("parts", [])
        if not parts or not parts[0].get("text"):
            raise RuntimeError("Gemini returned no text content.")
        return parts[0]["text"]

def call_openai_compatible(user_text: str, system_prompt: str, settings: dict) -> str:
    url = settings["endpoint"]
    model = settings["model"]
    api_key = settings["apiKey"]

    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text}
        ],
        "temperature": 0.3
    }
    body_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body_bytes, headers=headers, method="POST")

    with urllib.request.urlopen(req, timeout=25) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        choices = res.get("choices", [])
        if not choices:
            raise RuntimeError(f"{settings['provider'].upper()} returned empty choices.")
        content = choices[0].get("message", {}).get("content", "")
        if not content:
            raise RuntimeError(f"{settings['provider'].upper()} returned empty content.")
        return content

OFFLINE_DICT = {
    "ami": "আমি", "amar": "আমার", "amake": "আমাকে", "amader": "আমাদের",
    "tumi": "তুমি", "tomar": "তোমার", "tomake": "তোমাকে", "apni": "আপনি",
    "apnar": "আপনার", "apnake": "আপনাকে", "tui": "তুই", "tor": "তোর",
    "se": "সে", "tar": "তার", "take": "তাকে", "tara": "তারা",
    "ajke": "আজকে", "kalke": "কালকে", "gotokal": "গতকাল", "agamikal": "আগামীকাল",
    "jete": "যেতে", "parbo": "পারব", "parbona": "পারব না", "hobe": "হবে", "hobena": "হবে না",
    "gele": "গেলে", "gechi": "গেছি", "gelam": "গেলাম",
    "korbo": "করব", "korte": "করতে", "kore": "করে", "jani": "জানি", "janina": "জানি না",
    "jabo": "যাব", "ashbo": "আসব", "ashte": "আসতে", "bolbo": "বলব", "bolte": "বলতে",
    "dekha": "দেখা", "pathabo": "পাঠাব", "pathaite": "পাঠাতে", "product": "প্রোডাক্ট",
    "ta": "তা", "to": "তো", "na": "না", "ki": "কি", "keno": "কেন", "kivabe": "কিভাবে",
    "kothay": "কোথায়", "kintu": "কিন্তু", "ar": "আর", "vai": "ভাই", "apu": "আপু",
    "office": "অফিস", "kaj": "কাজ", "bhalo": "ভালো", "dhonnobad": "ধন্যবাদ",
    "shob": "সব", "kichu": "কিছু", "ektu": "একটু", "onek": "অনেক", "khub": "খুব"
}

def offline_convert(text: str) -> str:
    words = text.split()
    converted = [OFFLINE_DICT.get(w.lower(), w) for w in words]
    res = " ".join(converted)
    if not res.endswith("।") and not res.endswith("?") and not res.endswith("!"):
        res += "?" if "?" in text or "ki" in text.lower() else "।"
    return res

def rewrite_text(text: str, settings: dict) -> str:
    stripped = text.strip()
    if not stripped:
        raise ValueError("Input text is empty.")

    provider = settings["provider"]
    api_key = settings["apiKey"]
    if provider == "offline" or (settings["requiresApiKey"] and not api_key):
        return offline_convert(stripped)

    mode_info = TONE_MODES.get(settings["mode"], TONE_MODES["natural"])
    system_prompt = SYSTEM_PROMPT_TEMPLATE.replace("{MODE_INSTRUCTION}", mode_info["instruction"])

    if provider == "gemini":
        result = call_gemini(stripped, system_prompt, settings)
    else:
        result = call_openai_compatible(stripped, system_prompt, settings)
    return clean_output(result)

def handle_selection_transform(settings: dict) -> None:
    captured = capture_selection()
    if not captured:
        print("[!] No text selected. Highlight text and try again.", file=sys.stderr)
        return

    try:
        bengali = rewrite_text(captured, settings)
        paste_text(bengali)
        print(f"✨ Transformed: {bengali}")
    except Exception as e:
        print(f"[Error] {e}", file=sys.stderr)

def handle_clipboard_transform(settings: dict) -> None:
    clip = get_clipboard()
    if not clip.strip():
        print("[!] Clipboard is empty.", file=sys.stderr)
        return
    try:
        bengali = rewrite_text(clip, settings)
        set_clipboard(bengali)
        print(f"✨ Transformed & copied to clipboard:\n{bengali}")
    except Exception as e:
        print(f"[Error] {e}", file=sys.stderr)

def run_repl(settings: dict) -> None:
    print("=" * 64)
    print("  🇧🇩 BanglaWrite AI — Interactive Bengali Assistant")
    print(f"  Provider: {settings['provider'].upper()} ({settings['model']}) | Mode: {settings['mode']}")
    print("=" * 64 + "\n")

    while True:
        try:
            line = input(f"BanglaWrite [{settings['mode']}] > ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nবিদায়!")
            break

        if not line or line in ("exit", "quit", ":q"):
            break

        try:
            bengali = rewrite_text(line, settings)
            set_clipboard(bengali)
            print(f"\n✨ {bengali}")
            print("   [Copied to clipboard]\n")
        except Exception as e:
            print(f"\n[!] Error: {e}\n", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="BanglaWrite AI — Pure Python 3 Companion")
    parser.add_argument("text", nargs="?", default=None, help="Text to rewrite")
    parser.add_argument("-s", "--selection", action="store_true", help="Transform highlighted selection")
    parser.add_argument("-c", "--clipboard", action="store_true", help="Transform clipboard")
    parser.add_argument("-p", "--provider", choices=list(PROVIDER_DEFAULTS.keys()))
    parser.add_argument("-m", "--mode", choices=list(TONE_MODES.keys()))
    parser.add_argument("--api-key", help="API key override")

    args = parser.parse_args()
    settings = resolve_settings(args)

    if args.selection:
        handle_selection_transform(settings)
        return

    if args.clipboard:
        handle_clipboard_transform(settings)
        return

    if args.text is not None:
        try:
            bengali = rewrite_text(args.text, settings)
            set_clipboard(bengali)
            print(bengali)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        return

    if not sys.stdin.isatty():
        piped = sys.stdin.read().strip()
        if piped:
            try:
                bengali = rewrite_text(piped, settings)
                print(bengali)
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
        return

    run_repl(settings)

if __name__ == "__main__":
    main()
