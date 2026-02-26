"""Download a Telegram profile photo and persist it as a static file.

Returns a permanent CDN URL like:
  https://donskih-cdn.ru/static/avatars/{tg_user_id}.jpg
"""
import logging
from pathlib import Path

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_AVATARS_DIR = Path("/app/static/avatars")
_CDN_BASE = "https://donskih-cdn.ru"


async def fetch_and_store_avatar(tg_user_id: int) -> str | None:
    """Fetch avatar from Telegram Bot API, save locally, return static URL."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            # 1. Get file_id of most recent profile photo
            r = await client.get(
                f"https://api.telegram.org/bot{settings.telegram_bot_token}"
                f"/getUserProfilePhotos?user_id={tg_user_id}&limit=1"
            )
            data = r.json()
            if not data.get("ok") or not data["result"]["photos"]:
                return None

            file_id = data["result"]["photos"][0][-1]["file_id"]

            # 2. Resolve to a downloadable path
            r = await client.get(
                f"https://api.telegram.org/bot{settings.telegram_bot_token}"
                f"/getFile?file_id={file_id}"
            )
            file_data = r.json()
            if not file_data.get("ok"):
                return None

            file_path = file_data["result"]["file_path"]
            download_url = (
                f"https://api.telegram.org/file/bot{settings.telegram_bot_token}"
                f"/{file_path}"
            )

            # 3. Download the image bytes
            r = await client.get(download_url)
            if r.status_code != 200:
                return None

            # 4. Save to static/avatars/{tg_user_id}.jpg
            _AVATARS_DIR.mkdir(parents=True, exist_ok=True)
            dest = _AVATARS_DIR / f"{tg_user_id}.jpg"
            dest.write_bytes(r.content)

            return f"{_CDN_BASE}/static/avatars/{tg_user_id}.jpg"

    except Exception as e:
        logger.warning(f"fetch_and_store_avatar({tg_user_id}) failed: {e}")
        return None


async def download_and_store_avatar(tg_user_id: int, source_url: str) -> str | None:
    """Download avatar from an arbitrary URL (e.g. Telegram Login Widget),
    save locally, return static URL."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(source_url)
            if r.status_code != 200:
                return None

            _AVATARS_DIR.mkdir(parents=True, exist_ok=True)
            dest = _AVATARS_DIR / f"{tg_user_id}.jpg"
            dest.write_bytes(r.content)

            return f"{_CDN_BASE}/static/avatars/{tg_user_id}.jpg"

    except Exception as e:
        logger.warning(f"download_and_store_avatar({tg_user_id}) failed: {e}")
        return None
