#!/usr/bin/env python3
"""Upload PDF checklists and assign to content items."""
import json
import os
import ssl
import urllib.request
import urllib.error

API_BASE = "https://donskih-cdn.ru/api/v1"
FILES_DIR = os.path.expanduser("~/Desktop/записи уроков с видосами/files")

_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE

# (pdf_filename, content_item_title)
ASSIGNMENTS = [
    ("чек-лист по кистям.pdf", "Чек-лист по кистям"),
    ("Чек-лист Косметичка новичка.pdf", "Чек-лист: Косметичка новичка"),
    ("Чек лист Тональные крема.pdf", "Чек-лист: Тональные крема"),
]


def upload_pdf(path: str, key: str) -> str:
    filename = os.path.basename(path)
    with open(path, "rb") as f:
        data = f.read()
    boundary = "----FormBoundary"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: application/pdf\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        f"{API_BASE}/admin/content/upload-checklist",
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "X-Admin-Key": key,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=120) as r:
        return json.loads(r.read())["url"]


def main():
    key = os.environ.get("ADMIN_KEY", "")
    if not key:
        print("Set ADMIN_KEY")
        return 1

    req = urllib.request.Request(
        f"{API_BASE}/admin/content?section=base",
        headers={"X-Admin-Key": key},
    )
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=30) as r:
        items = json.loads(r.read())
    items_by_title = {i["title"]: i for i in items}

    for pdf_file, item_title in ASSIGNMENTS:
        path = os.path.join(FILES_DIR, pdf_file)
        if not os.path.isfile(path):
            print(f"⚠ Не найден: {path}")
            continue
        item = items_by_title.get(item_title)
        if not item:
            print(f"⚠ Контент не найден: {item_title}")
            continue
        if item.get("url"):
            print(f"⟳ {item_title}: уже есть PDF")
            continue
        print(f"↑ {pdf_file} → {item_title}...", end=" ", flush=True)
        try:
            url = upload_pdf(path, key)
            print(f"✓ {url[:50]}...")
        except Exception as e:
            print(f"✗ {e}")
            continue
        # PUT update
        data = json.dumps({"url": url}).encode()
        req = urllib.request.Request(
            f"{API_BASE}/admin/content/{item['id']}",
            data=data,
            headers={"Content-Type": "application/json", "X-Admin-Key": key},
            method="PUT",
        )
        urllib.request.urlopen(req, context=_SSL_CTX)
        print(f"  ✓ Привязано")
    print("Готово.")
    return 0


if __name__ == "__main__":
    exit(main())
