import logging

from fastapi import APIRouter, Request, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.user import User, TelegramAccount

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/bot", tags=["bot"])


@router.post("/webhook")
async def telegram_bot_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Handle Telegram Bot updates — auto-link by phone number match."""
    try:
        update = await request.json()
    except Exception:
        return {"ok": True}

    message = update.get("message")
    if not message:
        return {"ok": True}

    chat_id = message.get("chat", {}).get("id")
    text = message.get("text", "")
    contact = message.get("contact")

    if text == "/start":
        await _send_contact_request(chat_id)
        return {"ok": True}

    if contact:
        await _handle_contact(db, message, contact)
        return {"ok": True}

    await _send_message(chat_id, "Нажмите /start чтобы привязать аккаунт.")
    return {"ok": True}


async def _handle_contact(
    db: AsyncSession,
    message: dict,
    contact: dict,
):
    """Match phone from shared contact to a user and link Telegram profile."""
    chat_id = message["chat"]["id"]
    from_user = message.get("from", {})

    phone = contact.get("phone_number", "")
    if not phone.startswith("+"):
        phone = f"+{phone}"

    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()

    if not user:
        await _send_message(
            chat_id,
            "Аккаунт с этим номером не найден.\n"
            "Сначала зарегистрируйтесь в приложении.",
        )
        return

    tg_user_id = from_user.get("id")
    first_name = from_user.get("first_name")
    last_name = from_user.get("last_name")
    username = from_user.get("username")

    photo_url = None
    try:
        photo_url = await _get_profile_photo_url(tg_user_id)
    except Exception as e:
        logger.warning(f"Could not get profile photo: {e}")

    result = await db.execute(
        select(TelegramAccount).where(TelegramAccount.user_id == user.id)
    )
    existing = result.scalar_one_or_none()

    if existing:
        existing.telegram_user_id = tg_user_id
        existing.first_name = first_name
        existing.last_name = last_name
        existing.username = username
        if photo_url:
            existing.photo_url = photo_url
    else:
        tg_account = TelegramAccount(
            user_id=user.id,
            telegram_user_id=tg_user_id,
            first_name=first_name,
            last_name=last_name,
            username=username,
            photo_url=photo_url,
        )
        db.add(tg_account)

    logger.info(
        f"Linked Telegram {tg_user_id} (@{username}) "
        f"to user {user.id} (phone {phone})"
    )

    await _send_message(
        chat_id,
        "Аккаунт успешно привязан! ✅\nВернитесь в приложение.",
    )


async def _send_contact_request(chat_id: int) -> None:
    """Send a message with a keyboard button to share contact."""
    import httpx

    keyboard = {
        "keyboard": [
            [{"text": "📱 Поделиться контактом", "request_contact": True}]
        ],
        "resize_keyboard": True,
        "one_time_keyboard": True,
    }

    async with httpx.AsyncClient() as client:
        await client.post(
            f"https://api.telegram.org/bot{settings.telegram_bot_token}/sendMessage",
            json={
                "chat_id": chat_id,
                "text": "Чтобы привязать Telegram-профиль, "
                        "поделитесь своим контактом 👇",
                "reply_markup": keyboard,
            },
        )


async def _get_profile_photo_url(tg_user_id: int) -> str | None:
    """Fetch user's Telegram profile photo via Bot API."""
    import httpx

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://api.telegram.org/bot{settings.telegram_bot_token}"
            f"/getUserProfilePhotos?user_id={tg_user_id}&limit=1"
        )
        data = resp.json()
        if not data.get("ok") or not data["result"]["photos"]:
            return None

        file_id = data["result"]["photos"][0][-1]["file_id"]

        resp = await client.get(
            f"https://api.telegram.org/bot{settings.telegram_bot_token}"
            f"/getFile?file_id={file_id}"
        )
        file_data = resp.json()
        if not file_data.get("ok"):
            return None

        file_path = file_data["result"]["file_path"]
        return (
            f"https://api.telegram.org/file/bot{settings.telegram_bot_token}"
            f"/{file_path}"
        )


async def _send_message(chat_id: int, text: str) -> None:
    import httpx

    async with httpx.AsyncClient() as client:
        await client.post(
            f"https://api.telegram.org/bot{settings.telegram_bot_token}/sendMessage",
            json={
                "chat_id": chat_id,
                "text": text,
                "reply_markup": {"remove_keyboard": True},
            },
        )
