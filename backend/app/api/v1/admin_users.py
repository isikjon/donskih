import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.admin_content import require_admin
from app.api.v1.chat import manager as ws_manager
from app.database import get_db
from app.models.chat import ChatMessage
from app.models.user import TelegramAccount, User
from app.services.bot_db import (
    get_bot_user_by_telegram_id,
    get_bot_user_by_username,
    get_payment_history,
    parse_subscription,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin-users"])


# ---------------------------------------------------------------------------
# Serializers
# ---------------------------------------------------------------------------

def _serialize_user_brief(user: User) -> dict:
    tg = user.telegram_account
    name_parts = []
    if tg:
        if tg.first_name:
            name_parts.append(tg.first_name)
        if tg.last_name:
            name_parts.append(tg.last_name)

    return {
        "id": str(user.id),
        "phone": user.phone,
        "is_active": user.is_active,
        "created_at": user.created_at.isoformat(),
        "updated_at": user.updated_at.isoformat(),
        "telegram": {
            "display_name": " ".join(name_parts) if name_parts else None,
            "username": tg.username if tg else None,
            "photo_url": tg.photo_url if tg else None,
            "telegram_user_id": tg.telegram_user_id if tg else None,
            "linked_at": tg.linked_at.isoformat() if tg else None,
        } if tg else None,
    }


def _serialize_chat_message(msg: ChatMessage) -> dict:
    tg = msg.user.telegram_account if msg.user else None
    name_parts = []
    if tg:
        if tg.first_name:
            name_parts.append(tg.first_name)
        if tg.last_name:
            name_parts.append(tg.last_name)

    return {
        "id": str(msg.id),
        "user_id": str(msg.user_id),
        "sender_name": " ".join(name_parts) if name_parts else (tg.username if tg else "Участник"),
        "sender_photo_url": tg.photo_url if tg else None,
        "text": msg.text if not msg.is_deleted else None,
        "image_url": msg.image_url if not msg.is_deleted else None,
        "is_edited": msg.is_edited,
        "is_deleted": msg.is_deleted,
        "created_at": msg.created_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# Users — list
# ---------------------------------------------------------------------------

@router.get("/users")
async def admin_list_users(
    limit: int = 50,
    offset: int = 0,
    search: str = "",
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> dict:
    base_query = (
        select(User)
        .outerjoin(User.telegram_account)
        .order_by(desc(User.created_at))
    )

    if search.strip():
        term = f"%{search.strip()}%"
        base_query = base_query.where(
            or_(
                User.phone.ilike(term),
                TelegramAccount.username.ilike(term),
                TelegramAccount.first_name.ilike(term),
                TelegramAccount.last_name.ilike(term),
            )
        )

    count_result = await db.execute(select(func.count()).select_from(base_query.subquery()))
    total = count_result.scalar() or 0

    result = await db.execute(base_query.limit(min(limit, 200)).offset(offset))
    users = result.scalars().unique().all()

    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": [_serialize_user_brief(u) for u in users],
    }


# ---------------------------------------------------------------------------
# Users — detail (with subscription from MySQL)
# ---------------------------------------------------------------------------

@router.get("/users/{user_id}")
async def admin_get_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> dict:
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="User not found")

    result = await db.execute(
        select(User)
        .options(selectinload(User.refresh_tokens))
        .where(User.id == uid)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    brief = _serialize_user_brief(user)

    # Last activity: most recent non-revoked token
    active_tokens = [t for t in (user.refresh_tokens or []) if not t.is_revoked]
    last_active_at = None
    if active_tokens:
        last_token = max(active_tokens, key=lambda t: t.created_at)
        last_active_at = last_token.created_at.isoformat()

    # Subscription from bot MySQL
    subscription = None
    payments: list[dict] = []
    tg = user.telegram_account
    if tg:
        try:
            bot_user = await get_bot_user_by_telegram_id(tg.telegram_user_id)
            if not bot_user and tg.username:
                bot_user = await get_bot_user_by_username(tg.username)
            if bot_user:
                subscription = parse_subscription(bot_user)
                raw_payments = await get_payment_history(int(bot_user["user_id"]), limit=10)
                payments = [
                    {
                        "inv_id": p["inv_id"],
                        "cost": str(p["cost"]),
                        "sub_type": p["sub_type"],
                        "pay_type": p["pay_type"],
                        "datetime": str(p["datetime"]),
                        "status": p["status"],
                    }
                    for p in raw_payments
                ]
        except Exception as e:
            logger.warning(f"Could not fetch subscription for user {user_id}: {e}")

    # Recent chat messages by this user
    msgs_result = await db.execute(
        select(ChatMessage)
        .options(selectinload(ChatMessage.user))
        .where(ChatMessage.user_id == uid)
        .order_by(desc(ChatMessage.created_at))
        .limit(20)
    )
    recent_messages = [
        _serialize_chat_message(m) for m in reversed(msgs_result.scalars().all())
    ]

    return {
        **brief,
        "last_active_at": last_active_at,
        "subscription": subscription,
        "payments": payments,
        "recent_messages": recent_messages,
    }


# ---------------------------------------------------------------------------
# Users — block / unblock
# ---------------------------------------------------------------------------

@router.post("/users/{user_id}/block", status_code=status.HTTP_200_OK)
async def admin_block_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> dict:
    user = await _get_user_or_404(user_id, db)
    user.is_active = False
    await db.flush()
    logger.info(f"Admin blocked user {user_id}")
    return {"id": user_id, "is_active": False}


@router.post("/users/{user_id}/unblock", status_code=status.HTTP_200_OK)
async def admin_unblock_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> dict:
    user = await _get_user_or_404(user_id, db)
    user.is_active = True
    await db.flush()
    logger.info(f"Admin unblocked user {user_id}")
    return {"id": user_id, "is_active": True}


async def _get_user_or_404(user_id: str, db: AsyncSession) -> User:
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="User not found")
    result = await db.execute(select(User).where(User.id == uid))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ---------------------------------------------------------------------------
# Chat moderation — list all messages
# ---------------------------------------------------------------------------

@router.get("/chat/messages")
async def admin_list_chat_messages(
    limit: int = 50,
    before_id: str | None = None,
    user_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> list[dict]:
    query = (
        select(ChatMessage)
        .options(selectinload(ChatMessage.user))
        .order_by(desc(ChatMessage.created_at))
        .limit(min(limit, 200))
    )

    if before_id:
        try:
            before_uuid = uuid.UUID(before_id)
            before_result = await db.execute(
                select(ChatMessage).where(ChatMessage.id == before_uuid)
            )
            before_msg = before_result.scalar_one_or_none()
            if before_msg:
                query = query.where(ChatMessage.created_at < before_msg.created_at)
        except ValueError:
            pass

    if user_id:
        try:
            uid = uuid.UUID(user_id)
            query = query.where(ChatMessage.user_id == uid)
        except ValueError:
            pass

    result = await db.execute(query)
    messages = list(reversed(result.scalars().all()))
    return [_serialize_chat_message(m) for m in messages]


# ---------------------------------------------------------------------------
# Chat moderation — admin force delete
# ---------------------------------------------------------------------------

@router.delete("/chat/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_chat_message(
    message_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
) -> None:
    try:
        msg_uuid = uuid.UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Message not found")

    result = await db.execute(
        select(ChatMessage).where(ChatMessage.id == msg_uuid)
    )
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    msg.is_deleted = True
    await db.flush()

    # Broadcast deletion to all connected chat clients
    await ws_manager.broadcast({"type": "delete_message", "message_id": message_id})
    logger.info(f"Admin deleted chat message {message_id}")
