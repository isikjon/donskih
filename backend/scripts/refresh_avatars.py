"""One-time script: re-download all Telegram avatars and update photo_url in DB.

Run inside the container:
  docker compose exec api python scripts/refresh_avatars.py
"""
import asyncio
import sys
import os

sys.path.insert(0, "/app")

from sqlalchemy import select
from app.database import async_session as AsyncSessionLocal
from app.models.user import TelegramAccount
from app.services.avatar_store import fetch_and_store_avatar


async def main():
    os.makedirs("/app/static/avatars", exist_ok=True)
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(TelegramAccount).where(TelegramAccount.telegram_user_id.isnot(None))
        )
        accounts = result.scalars().all()
        print(f"Found {len(accounts)} accounts with telegram_user_id")

        updated = 0
        for acc in accounts:
            url = await fetch_and_store_avatar(acc.telegram_user_id)
            if url:
                acc.photo_url = url
                updated += 1
                print(f"  ✓ {acc.telegram_user_id} → {url}")
            else:
                print(f"  ✗ {acc.telegram_user_id} — no photo or error")

        await db.commit()
        print(f"\nDone. Updated {updated}/{len(accounts)} avatars.")


if __name__ == "__main__":
    asyncio.run(main())
