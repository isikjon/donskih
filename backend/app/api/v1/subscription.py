import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.security.jwt import get_current_user
from app.services.bot_db import (
    get_bot_user_by_telegram_id,
    get_bot_user_by_username,
    get_payment_history,
    parse_subscription,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
async def get_subscription_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get subscription status from the bot database.
    Looks up by telegram_user_id first, then by username.
    """
    await db.refresh(user, ["telegram_account"])

    bot_user = None

    if user.telegram_account:
        tg = user.telegram_account
        bot_user = await get_bot_user_by_telegram_id(tg.telegram_user_id)

        if not bot_user and tg.username:
            bot_user = await get_bot_user_by_username(tg.username)

    if not bot_user:
        return {
            "found": False,
            "telegram_linked": user.telegram_account is not None,
            "subscription": {
                "is_active": False,
                "sub_type": None,
                "end_date": None,
                "sub_date": None,
                "auto_renewal": False,
                "is_test": False,
                "role": "user",
                "bot_username": None,
            },
            "payments": [],
        }

    subscription = parse_subscription(bot_user)

    tg_id = int(bot_user["user_id"])
    payments = await get_payment_history(tg_id, limit=5)
    payment_list = [
        {
            "inv_id": p["inv_id"],
            "cost": p["cost"],
            "sub_type": p["sub_type"],
            "pay_type": p["pay_type"],
            "datetime": p["datetime"],
            "status": p["status"],
        }
        for p in payments
    ]

    return {
        "found": True,
        "telegram_linked": True,
        "subscription": subscription,
        "payments": payment_list,
    }
