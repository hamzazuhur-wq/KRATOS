#!/usr/bin/env python3
"""
Uploads the generated APK to temporary file sharing services (Litterbox, Tmpfiles, File.io)
and outputs the direct download link.
"""

import sys
import json
import urllib.request
import urllib.parse
from pathlib import Path

def upload_to_litterbox(apk_path: Path) -> str | None:
    print("[UPLOAD] Trying litterbox.catbox.moe (72h temporary hosting)...")
    url = "https://litterbox.catbox.moe/resources/internals/api.php"
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    
    with open(apk_path, "rb") as f:
        file_bytes = f.read()

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="reqtype"\r\n\r\n'
        f"fileupload\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="time"\r\n\r\n'
        f"72h\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileToUpload"; filename="{apk_path.name}"\r\n'
        f"Content-Type: application/vnd.android.package-archive\r\n\r\n"
    ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    req = urllib.request.Request(url, data=body)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("User-Agent", "Mozilla/5.0")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            link = resp.read().decode("utf-8").strip()
            if link.startswith("http"):
                return link
    except Exception as e:
        print(f"Litterbox failed: {e}")
    return None

def upload_to_tmpfiles(apk_path: Path) -> str | None:
    print("[UPLOAD] Trying tmpfiles.org...")
    url = "https://tmpfiles.org/api/v1/upload"
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

    with open(apk_path, "rb") as f:
        file_bytes = f.read()

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{apk_path.name}"\r\n'
        f"Content-Type: application/vnd.android.package-archive\r\n\r\n"
    ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    req = urllib.request.Request(url, data=body)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("User-Agent", "Mozilla/5.0")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("status") == "success":
                # tmpfiles returns https://tmpfiles.org/12345/app.apk -> direct is https://tmpfiles.org/dl/12345/app.apk
                raw_url = data["data"]["url"]
                return raw_url.replace("tmpfiles.org/", "tmpfiles.org/dl/")
    except Exception as e:
        print(f"Tmpfiles failed: {e}")
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: upload_apk.py <path_to_apk>")
        sys.exit(1)

    apk_path = Path(sys.argv[1]).resolve()
    if not apk_path.exists():
        print(f"Error: {apk_path} does not exist.")
        sys.exit(1)

    size_mb = apk_path.stat().st_size / (1024 * 1024)
    print(f"Target APK: {apk_path.name} ({size_mb:.2f} MB)")

    link = upload_to_litterbox(apk_path)
    if not link:
        link = upload_to_tmpfiles(apk_path)

    if link:
        print(f"\n=======================================================")
        print(f"DOWNLOAD LINK: {link}")
        print(f"=======================================================")
    else:
        print("Failed to upload to temporary hosts.")
        sys.exit(1)

if __name__ == "__main__":
    main()
