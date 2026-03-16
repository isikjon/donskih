#!/usr/bin/env python3
"""
Upload Telegram export photos as sub-item thumbnails.
Usage:
    python scripts/upload_thumbnails.py --key YOUR_ADMIN_KEY
"""

import argparse
import json
import os
import ssl
import sys
import urllib.request
import urllib.error

API_BASE = "https://donskih-cdn.ru/api/v1"
PHOTOS_DIR = os.path.join(os.path.dirname(__file__), "..", "ChatExport_2026-03-10", "photos")

_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE


# ─────────────────────────────────────────────────────────────
# Photo → sub-item title mapping (title used since IDs can change after PUT)
# Format: (photo_filename, content_item_title, sub_item_title)
# ─────────────────────────────────────────────────────────────

ASSIGNMENTS = [
    # ── Урок 1: Макияж Clean Girl ─────────────────────────────
    ("photo_1@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Уход"),
    ("photo_2@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Нанесение тона и консилера"),
    ("photo_3@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Скульптурирование лица"),
    ("photo_4@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж бровей"),
    ("photo_5@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж глаз"),
    ("photo_6@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж губ"),
    ("photo_1@21-02-2026_14-51-34.jpg",
     "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Итог: вот такой макияж получился ♥️"),

    # ── Урок 2: Кисти ─────────────────────────────────────────
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке",
     "Кисти для тона и кремовых: скульптора, бронзера, румян, хайлайтера"),
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке",
     "Кисти для сухих продуктов: пудры, румян, хайлайтера, бронзера, скульптора"),
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке",
     "Кисти для теней и растушевки карандаша"),
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке",
     "Кисть для подчищений в макияже и графичных стрел"),
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке", "Спонж"),
    ("photo_7@21-02-2026_14-51-35.jpg",
     "Какие кисти должны быть в косметичке", "Точилки"),

    # ── Урок 4: Контуринг ─────────────────────────────────────
    ("photo_8@21-02-2026_14-51-35.jpg",
     "Создание контуринга", "Техника с кремовыми и сухими продуктами"),
    ("photo_9@21-02-2026_14-51-35.jpg",
     "Создание контуринга", "Контуринг: разбор по зонам"),
    ("photo_10@21-02-2026_14-51-35.jpg",
     "Создание контуринга", "Итог контуринга"),
]


# ─────────────────────────────────────────────────────────────
# API helpers
# ─────────────────────────────────────────────────────────────

def api_get(path: str, key: str):
    req = urllib.request.Request(
        f"{API_BASE}{path}", headers={"X-Admin-Key": key})
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=30) as r:
        return json.loads(r.read())


def api_put(path: str, body: dict, key: str):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        f"{API_BASE}{path}", data=data,
        headers={"Content-Type": "application/json", "X-Admin-Key": key},
        method="PUT",
    )
    try:
        with urllib.request.urlopen(req, context=_SSL_CTX, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"  PUT error {e.code}: {e.read().decode()}", file=sys.stderr)
        raise


def upload_image(photo_path: str, key: str) -> str:
    filename = os.path.basename(photo_path)
    with open(photo_path, "rb") as f:
        data = f.read()

    boundary = "----FormBoundary7MA4YWxkTrZu0gW"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: image/jpeg\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        f"{API_BASE}/admin/content/upload-image", data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "X-Admin-Key": key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, context=_SSL_CTX, timeout=60) as r:
            return json.loads(r.read())["url"]
    except urllib.error.HTTPError as e:
        print(f"  Upload error {e.code}: {e.read().decode()}", file=sys.stderr)
        raise


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", default=os.environ.get("ADMIN_KEY", ""))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.key:
        print("Error: --key required", file=sys.stderr)
        sys.exit(1)

    # Load all content items from both sections
    print("Loading content items...")
    all_items = api_get("/admin/content?section=base", args.key)
    all_items += api_get("/admin/content?section=main", args.key)

    # Index by title
    items_by_title = {item["title"]: item for item in all_items}

    # Upload all needed photos (with cache)
    uploaded_cache: dict[str, str] = {}
    photos_needed = list({a[0] for a in ASSIGNMENTS})

    print(f"\nUploading {len(photos_needed)} unique photos...")
    for photo_filename in photos_needed:
        photo_path = os.path.join(PHOTOS_DIR, photo_filename)
        if not os.path.exists(photo_path):
            print(f"  ⚠ Not found: {photo_path}")
            continue
        if args.dry_run:
            uploaded_cache[photo_filename] = f"https://example.com/{photo_filename}"
            print(f"  [DRY RUN] {photo_filename}")
            continue
        print(f"  ↑ {photo_filename}...")
        url = upload_image(photo_path, args.key)
        uploaded_cache[photo_filename] = url
        print(f"    → {url}")

    # Group assignments by content_item_title
    by_item: dict[str, dict[str, str]] = {}  # item_title → {sub_title: photo_url}
    for photo_filename, item_title, sub_title in ASSIGNMENTS:
        if photo_filename not in uploaded_cache:
            continue
        by_item.setdefault(item_title, {})[sub_title] = uploaded_cache[photo_filename]

    # Apply thumbnails per content item (one PUT per item)
    print("\nApplying thumbnails...")
    for item_title, thumb_map in by_item.items():
        item = items_by_title.get(item_title)
        if not item:
            print(f"  ⚠ Content item not found: {item_title}")
            continue

        sub_items_payload = []
        changed = 0
        for s in item["sub_items"]:
            thumb = thumb_map.get(s["title"])
            if thumb:
                changed += 1
            sub_items_payload.append({
                "title": s["title"],
                "description": s.get("description"),
                "url": s.get("url"),
                "thumbnail_url": thumb or s.get("thumbnail_url"),
                "duration": s.get("duration"),
                "sort_order": s["sort_order"],
            })

        print(f"  ✎ {item_title[:55]}  ({changed} thumbnails updated)")
        if args.dry_run:
            print("    [DRY RUN] would PUT")
            continue

        api_put(f"/admin/content/{item['id']}", {"sub_items": sub_items_payload}, args.key)
        print(f"  ✓ Saved")

    print("\nDone.")


if __name__ == "__main__":
    main()
