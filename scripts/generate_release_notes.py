#!/usr/bin/env python3
"""
DiscordStorage Release Notes Generator
Generates RELEASE_<version>.md for GitHub Releases using Google Gemini API or Antigravity CLI (agy).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def get_current_version() -> str:
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if not pubspec.exists():
        raise FileNotFoundError(f"pubspec.yaml not found at {pubspec}")
    content = pubspec.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\+\s]+)", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not extract version from pubspec.yaml")
    return match.group(1).strip()


def get_git_context(version: str) -> tuple[str, str, str]:
    """
    Hedef sürümden önceki son tag'i ve iki sürüm arasındaki
    detaylı commit geçmişini ve dosya diff istatistiklerini döndürür.
    Returns: (last_tag, commit_log, diff_stat)
    """
    last_tag = ""
    target_tags = {f"v{version}", version}

    try:
        all_tags = subprocess.check_output(
            ["git", "tag", "--sort=-creatordate"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip().splitlines()

        for t in all_tags:
            t = t.strip()
            if t and t not in target_tags:
                last_tag = t
                break
    except Exception:
        pass

    if not last_tag:
        try:
            last_tag = subprocess.check_output(
                ["git", "describe", "--tags", "--abbrev=0", "HEAD^"],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL,
                text=True
            ).strip()
        except Exception:
            last_tag = ""

    if last_tag:
        rev_range = f"{last_tag}..HEAD"
        print(f"[*] Previous release tag detected: {last_tag}")
        print(f"[*] Revision range: {rev_range}")
    else:
        rev_range = "HEAD~15..HEAD"
        print("[*] No previous tag detected; inspecting recent commits (HEAD~15..HEAD)")

    # 1. Commit Log
    try:
        commit_log = subprocess.check_output(
            ["git", "log", rev_range, "--format=- %s%n  %b", "--no-merges"],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
    except Exception:
        try:
            commit_log = subprocess.check_output(
                ["git", "log", "-n", "15", "--format=- %s%n  %b", "--no-merges"],
                cwd=PROJECT_ROOT,
                stderr=subprocess.DEVNULL,
                text=True
            ).strip()
        except Exception:
            commit_log = ""

    # 2. Dosya Diff İstatistikleri
    try:
        diff_stat = subprocess.check_output(
            ["git", "diff", "--stat", rev_range],
            cwd=PROJECT_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
    except Exception:
        diff_stat = ""

    if not commit_log:
        commit_log = "- General improvements and routine maintenance."

    return last_tag, commit_log, diff_stat


def find_gemini_api_key(explicit_key: str = None) -> str:
    if explicit_key:
        return explicit_key.strip()
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"].strip()

    home_key = Path.home() / ".gemini" / "api.key"
    if home_key.exists():
        key = home_key.read_text(encoding="utf-8").strip()
        if key:
            return key

    return ""


def load_template() -> str:
    for path in [
        PROJECT_ROOT / ".github" / "RELEASE_TEMPLATE.md",
        PROJECT_ROOT / "RELEASE_TEMPLATE.md"
    ]:
        if path.exists():
            return path.read_text(encoding="utf-8")
    return ""


def generate_with_gemini(
    api_key: str,
    version: str,
    last_tag: str,
    commit_log: str,
    diff_stat: str,
    gh_template: str
) -> str:
    print(f"[*] Requesting release notes from Gemini API for v{version}...")

    prompt = f"""You are a principal release manager and technical copywriter for "DiscordStorage" (a free, unlimited cloud storage Windows desktop application powered by Flutter and Discord, featuring file chunking, local encryption, notification integration, and Windows desktop shell support).

Generate a comprehensive, accurate, and professional GitHub Release Notes document for version {version}.

============================================================
ACTUAL GIT CHANGES (since previous version: {last_tag or 'initial commit'}):
============================================================

COMMIT HISTORY:
{commit_log}

MODIFIED FILES & STATS:
{diff_stat}

============================================================
OFFICIAL REPOSITORY RELEASE TEMPLATE:
============================================================
{gh_template}

Strict Rules for GitHub Notes:
1. English Section First:
   - Header format: "## 📦 Version {version} – <Concise, Impactful Title Highlighting Key Additions>"
   - "### 🚀 Changes":
     - Group into bold topic categories (e.g., "**Feature or System Name:**").
     - Include detailed sub-bullets explaining the technical architecture, key classes/files, and user impact.
     - DO NOT invent generic filler (such as "minor UI glitches" or "routine maintenance") if specific features or workflows were added in the commits!
   - "### 🐛 Bug Fixes": Specific bug fixes with brief cause and resolution. If none, write "* None."
   - "### ⚠️ Breaking Changes (if any)": If none, write "* None."
2. Separator line: "---"
3. Turkish Section Second:
   - Header format: "## 📦 Sürüm {version} – <Türkçe Açıklayıcı Başlık>"
   - "### 🚀 Değişiklikler": Match the English section bullet-for-bullet in rich, fluent, natural Turkish.
   - "### 🐛 Hata Düzeltmeleri": Açıklayıcı hata düzeltmeleri listesi. Yoksa "* Yok."
   - "### ⚠️ Kırıcı Değişiklikler (varsa)": Yoksa "* Yok."

============================================================
RESPONSE FORMAT:
============================================================
Respond ONLY with a valid JSON object with exactly one key:
{{
  "github_notes": "<markdown content for RELEASE_{version}.md>"
}}
"""

    models = [
        "models/gemini-3.5-flash-lite",
        "models/gemini-flash-latest",
        "models/gemini-flash-lite-latest",
        "models/gemini-2.5-flash",
        "models/gemini-3.5-flash"
    ]
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json"
        }
    }

    last_error = None
    for model in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/{model}:generateContent?key={api_key}"
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                resp_json = json.loads(resp.read().decode("utf-8"))
                text_content = resp_json["candidates"][0]["content"]["parts"][0]["text"]
                data = json.loads(text_content)
                return data["github_notes"].strip()
        except Exception as e:
            last_error = e
            print(f"[!] Model {model} request failed: {e}. Trying fallback if available...")

    raise RuntimeError(f"Gemini API request failed on all models: {last_error}")


def generate_with_agy(version: str) -> str:
    print(f"[*] Calling Antigravity CLI (agy) to generate release notes for v{version}...")
    agy_prompt = (
        f"DiscordStorage projesinin v{version} surumu icin surum notlarini olustur. "
        "1. Git commit loglarini ve son degisiklikleri incele. "
        f"2. .github/RELEASE_TEMPLATE.md sablonuna birebir uyarak 'RELEASE_{version}.md' dosyasini olustur. "
        "Dosyayi dogrudan proje kok dizininde olustur."
    )

    cmd = ["agy", "-p", agy_prompt, "--add-dir", str(PROJECT_ROOT), "--dangerously-skip-permissions"]
    res = subprocess.run(cmd, cwd=PROJECT_ROOT)
    if res.returncode != 0:
        raise RuntimeError(f"agy CLI exited with code {res.returncode}")

    gh_file = PROJECT_ROOT / f"RELEASE_{version}.md"
    if not gh_file.exists():
        raise FileNotFoundError("agy completed but RELEASE_{version}.md was not created.")

    return gh_file.read_text(encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="DiscordStorage Release Notes Generator")
    parser.add_argument("--version", "-v", help="Release version (default: from pubspec.yaml)")
    parser.add_argument("--engine", "-e", choices=["gemini", "agy", "auto"], default="auto",
                        help="Generator engine: gemini, agy, or auto (default: auto)")
    parser.add_argument("--api-key", "-k", help="Gemini API Key (optional)")
    args = parser.parse_args()

    version = args.version or get_current_version()
    print(f"=== DiscordStorage Release Notes Generator (v{version}) ===")

    last_tag, commit_log, diff_stat = get_git_context(version)
    print(f"[*] Commits to summarize:\n{commit_log}\n")
    if diff_stat:
        print(f"[*] Diff stat summary:\n{diff_stat}\n")

    api_key = find_gemini_api_key(args.api_key)
    engine = args.engine

    if engine == "auto":
        engine = "gemini" if api_key else "agy"

    print(f"[*] Using engine: {engine.upper()}")

    gh_notes = ""

    if engine == "gemini":
        if not api_key:
            print("[!] Error: Gemini engine selected but no GEMINI_API_KEY found.")
            print("    Provide it via --api-key or set the GEMINI_API_KEY environment variable.")
            sys.exit(1)
        gh_template = load_template()
        gh_notes = generate_with_gemini(
            api_key=api_key,
            version=version,
            last_tag=last_tag,
            commit_log=commit_log,
            diff_stat=diff_stat,
            gh_template=gh_template
        )
    elif engine == "agy":
        gh_notes = generate_with_agy(version)
    else:
        print(f"[!] Unknown engine: {engine}")
        sys.exit(1)

    gh_file = PROJECT_ROOT / f"RELEASE_{version}.md"
    gh_file.write_text(gh_notes, encoding="utf-8")

    print(f"\n[+] Successfully saved GitHub release notes: {gh_file.name}")

    print("\n=== Next Steps ===")
    print(f"1. Review {gh_file.name}")
    print("2. Commit and push:")
    print(f"   git add {gh_file.name}")
    print(f"   git commit -m \"docs: add release notes for v{version}\"")
    print(f"   git push origin main")
    print(f"   git tag v{version}")
    print(f"   git push origin v{version}")


if __name__ == "__main__":
    main()
