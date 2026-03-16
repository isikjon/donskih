#!/usr/bin/env python3
"""
Upload videos from Telegram export to API and assign to sub-items.
Usage:
    ADMIN_KEY=123 python scripts/upload_videos.py

Videos folder: записи уроков с видосами/video_files
"""

import json
import os
import ssl
import sys
import urllib.request
import urllib.error

API_BASE = "https://donskih-cdn.ru/api/v1"
# Папка на рабочем столе — можно переопределить через VIDEOS_DIR
VIDEOS_DIR = os.environ.get(
    "VIDEOS_DIR",
    os.path.expanduser("~/Desktop/записи уроков с видосами/video_files"),
)

_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE

# (video_filename, content_item_title, sub_item_title, duration)
# Duration format "M:SS" from HTML
ASSIGNMENTS = [
    # ── Урок 1 ─────────────────────────────────────────────────
    ("Уход.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Уход", "12:26"),
    ("Тон и консилер.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Нанесение тона и консилера", "17:14"),
    ("Контуринг.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Скульптурирование лица", "12:51"),
    ("Брови.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж бровей", "09:45"),
    ("Глаза_compressed.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж глаз", "19:13"),
    ("Губы.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Макияж губ", "12:39"),
    ("VID_20250915153500775.mp4", "Макияж: Clean Girl с акцентом на сияющую здоровую кожу", "Итог: вот такой макияж получился ♥️", "00:15"),
    # ── Урок 2 ─────────────────────────────────────────────────
    ("IMG_4216.MP4", "Какие кисти должны быть в косметичке", "Кисти для тона и кремовых: скульптора, бронзера, румян, хайлайтера", "03:15"),
    ("IMG_4217.MP4", "Какие кисти должны быть в косметичке", "Кисти для сухих продуктов: пудры, румян, хайлайтера, бронзера, скульптора", "02:44"),
    ("IMG_4218.MP4", "Какие кисти должны быть в косметичке", "Кисти для теней и растушевки карандаша", "02:53"),
    ("IMG_4219.MP4", "Какие кисти должны быть в косметичке", "Кисть для подчищений в макияже и графичных стрел", "01:06"),
    ("IMG_4221.MP4", "Какие кисти должны быть в косметичке", "Спонж", "00:45"),
    ("IMG_4220.MP4", "Какие кисти должны быть в косметичке", "Точилки", "00:35"),
    # ── Урок 3 ─────────────────────────────────────────────────
    ("IMG_4222.MP4", "Как ухаживать за кистями", "Урок: как ухаживать за кистями", "03:43"),
    # ── Урок 4 ─────────────────────────────────────────────────
    ("IMG_5737.MP4", "Создание контуринга", "Техника с кремовыми и сухими продуктами", "13:19"),
    ("IMG_5738.MP4", "Создание контуринга", "Контуринг: разбор по зонам", "08:58"),
    ("IMG_5739.MP4", "Создание контуринга", "Итог контуринга", "00:31"),
    # ── Урок 5 ─────────────────────────────────────────────────
    ("IMG_8606.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Наталья — кожа склонна к жирности ✨", "01:32"),
    ("IMG_8607.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Наталья — нанесение тона (часть 2)", "03:56"),
    ("IMG_8608.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Наталья — нанесение тона (часть 3)", "03:47"),
    ("IMG_8609.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Наталья — нанесение тона (часть 4)", "01:07"),
    ("IMG_8610.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Наталья — финальный результат", "01:00"),
    ("IMG_8591.MP4", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Ирина — кожа склонна к сухости ✨", "01:32"),
    ("IMG_8596.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Ирина — нанесение тона (часть 2)", "02:23"),
    ("IMG_8597.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Ирина — нанесение тона (часть 3)", "01:21"),
    ("IMG_8594.MOV", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Ирина — нанесение тона (часть 4)", "02:59"),
    ("IMG_8620.MP4", "Особенности подготовки кожи и нанесения тона на разных типах кожи", "Ирина — финальный результат", "00:31"),
]


def api_get(path: str, key: str):
    req = urllib.request.Request(f"{API_BASE}{path}", headers={"X-Admin-Key": key})
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=60) as r:
        return json.loads(r.read())


def api_put(path: str, body: dict, key: str):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        f"{API_BASE}{path}", data=data,
        headers={"Content-Type": "application/json", "X-Admin-Key": key},
        method="PUT",
    )
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=300) as r:
        return json.loads(r.read())


def upload_video(video_path: str, key: str) -> str:
    filename = os.path.basename(video_path)
    size_mb = os.path.getsize(video_path) / (1024 * 1024)
    print(f"    ↑ Загрузка {filename} ({size_mb:.0f} MB)...", end=" ", flush=True)

    with open(video_path, "rb") as f:
        data = f.read()

    boundary = "----VideoFormBoundary"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: video/mp4\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        f"{API_BASE}/admin/content/upload-video",
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "X-Admin-Key": key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, context=_SSL_CTX, timeout=3600) as r:
            result = json.loads(r.read())
            url = result["url"]
            print(f"✓ → {url[:60]}...")
            return url
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"\n    ✗ HTTP {e.code}: {body[:200]}")
        raise


def main():
    key = os.environ.get("ADMIN_KEY", "")
    if not key:
        print("Error: set ADMIN_KEY env var", file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(VIDEOS_DIR):
        print(f"Error: folder not found: {VIDEOS_DIR}", file=sys.stderr)
        sys.exit(1)

    print("Loading content items...")
    all_items = api_get("/admin/content?section=base", key)
    items_by_title = {item["title"]: item for item in all_items}

    # Group by content item
    by_item: dict[str, list[tuple[str, str, str]]] = {}
    for video_file, item_title, sub_title, duration in ASSIGNMENTS:
        by_item.setdefault(item_title, []).append((video_file, sub_title, duration))

    total = len(ASSIGNMENTS)
    done = 0

    for item_title, assignments in by_item.items():
        item = items_by_title.get(item_title)
        if not item:
            print(f"⚠ Content item not found: {item_title}")
            continue

        print(f"\n{'='*60}")
        print(f"{item_title}")
        print("=" * 60)

        # Build sub_items payload with updates
        sub_map = {(st["title"]): st for st in item["sub_items"]}

        for video_file, sub_title, duration in assignments:
            video_path = os.path.join(VIDEOS_DIR, video_file)
            if not os.path.isfile(video_path):
                print(f"  ⚠ File not found: {video_file}")
                continue

            if sub_title not in sub_map:
                print(f"  ⚠ Sub-item not found: {sub_title}")
                continue

            # Skip if already has URL
            existing = sub_map[sub_title]
            if existing.get("url"):
                print(f"  ⟳ {sub_title}: уже есть видео, пропуск")
                done += 1
                continue

            try:
                url = upload_video(video_path, key)
            except Exception as e:
                print(f"  ✗ Failed: {e}")
                continue

            # Update sub_map for this item
            sub_map[sub_title] = {
                **existing,
                "url": url,
                "duration": duration,
            }
            done += 1
            print(f"    ✓ Привязано к «{sub_title}»")

        # PUT updated sub_items
        sub_items_payload = []
        for s in item["sub_items"]:
            updated = sub_map.get(s["title"], s)
            sub_items_payload.append({
                "title": updated["title"],
                "description": updated.get("description"),
                "url": updated.get("url"),
                "thumbnail_url": updated.get("thumbnail_url"),
                "duration": updated.get("duration", s.get("duration")),
                "sort_order": updated["sort_order"],
            })

        print(f"  → Сохранение {item_title[:50]}...")
        api_put(f"/admin/content/{item['id']}", {"sub_items": sub_items_payload}, key)
        print(f"  ✓ Сохранено")

    print(f"\nГотово. Обработано: {done}/{total} видео.")


if __name__ == "__main__":
    main()
