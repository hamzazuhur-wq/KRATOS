#!/usr/bin/env python3
"""
KRATOS: One-Click Production Android APK Packager & Publisher.

Automates:
1. Auto-incrementing the build number in pubspec.yaml (+1, +2, +3...).
2. Building release APK with embedded production Supabase credentials and persistent keystore.
3. Uploading the resulting APK with a direct download link.
"""

import sys
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "app"
PUBSPEC = APP_DIR / "pubspec.yaml"
OUTPUT_APK = APP_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"

def increment_build_number():
    content = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", content)
    if not match:
        print("[WARN] Could not parse version in pubspec.yaml. Skipping increment.")
        return
    version_name = match.group(1)
    build_num = int(match.group(2)) + 1
    new_version_line = f"version: {version_name}+{build_num}"
    updated_content = re.sub(r"version:\s*[^\r\n]+", new_version_line, content)
    PUBSPEC.write_text(updated_content, encoding="utf-8")
    print(f"✅ Incremented version to: {version_name}+{build_num}")

def build_apk():
    print("[BUILD] Compiling release APK with production flags...")
    flutter_bin = Path(r"C:\Users\hamza\AppData\devtools\flutter\bin\flutter.bat")
    cmd = [
        str(flutter_bin) if flutter_bin.exists() else "flutter",
        "build",
        "apk",
        "--release",
        "--dart-define=APP_ENV=production",
    ]
    res = subprocess.run(cmd, cwd=APP_DIR)
    if res.returncode != 0:
        print("❌ Flutter build failed.")
        sys.exit(res.returncode)
    print("✅ Flutter build succeeded.")

def upload_apk():
    upload_script = ROOT / "tools" / "upload_apk.py"
    if upload_script.exists() and OUTPUT_APK.exists():
        subprocess.run([sys.executable, str(upload_script), str(OUTPUT_APK)], cwd=ROOT)

def main():
    print("==================================================")
    print("      KRATOS PRODUCTION APK PACKAGING PIPELINE    ")
    print("==================================================")
    increment_build_number()
    build_apk()
    upload_apk()

if __name__ == "__main__":
    main()
