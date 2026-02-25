"""
Read-only access to the Telegram bot's MySQL database.
Only SELECT queries — never modify this database.
"""

import aiomysql
import logging
from datetime import datetime

from app.config import settings

logger = logging.getLogger(__name__)

_pool: aiomysql.Pool | None = None


async def get_pool() -> aiomysql.Pool:
    global _pool
    if _pool is None or _pool.closed:
        _pool = await aiomysql.create_pool(
            host=settings.bot_mysql_host,
            port=settings.bot_mysql_port,
            user=settings.bot_mysql_user,
            password=settings.bot_mysql_password,
            db=settings.bot_mysql_db,
            minsize=1,
            maxsize=5,
            autocommit=True,
            charset="utf8mb4",
            connect_timeout=10,
        )
    return _pool


async def get_bot_user_by_telegram_id(telegram_user_id: int) -> dict | None:
    """Find a user in the bot DB by their Telegram user_id."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT user_id, username, role, sub_type, auto, test, "
                "reg_date, end_date, sub_date, notification, sub_is_rus "
                "FROM users WHERE user_id = %s LIMIT 1",
                (str(telegram_user_id),),
            )
            return await cur.fetchone()


async def get_bot_user_by_username(username: str) -> dict | None:
    """Find a user in the bot DB by their Telegram username."""
    clean = username.lstrip("@")
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT user_id, username, role, sub_type, auto, test, "
                "reg_date, end_date, sub_date, notification, sub_is_rus "
                "FROM users WHERE username = %s LIMIT 1",
                (clean,),
            )
            return await cur.fetchone()


async def get_payment_history(telegram_user_id: int, limit: int = 10) -> list[dict]:
    """Get recent payments for a user."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT inv_id, cost, sub_type, pay_type, datetime, status "
                "FROM payments WHERE user_id = %s ORDER BY id DESC LIMIT %s",
                (str(telegram_user_id), limit),
            )
            return await cur.fetchall()


def parse_subscription(bot_user: dict) -> dict:
    """Parse bot DB user row into a clean subscription status."""
    sub_type = bot_user.get("sub_type")
    end_date_str = bot_user.get("end_date")
    sub_date_str = bot_user.get("sub_date")

    is_active = False
    end_date = None
    sub_date = None

    if sub_type == "infinity":
        is_active = True
    elif sub_type == "paid" and end_date_str:
        try:
            end_date = datetime.strptime(end_date_str.strip(), "%Y-%m-%d %H:%M")
            is_active = end_date > datetime.now()
        except (ValueError, AttributeError):
            pass

    if sub_date_str:
        try:
            sub_date = datetime.strptime(sub_date_str.strip(), "%Y-%m-%d %H:%M")
        except (ValueError, AttributeError):
            pass

    return {
        "is_active": is_active,
        "sub_type": sub_type,
        "end_date": end_date.isoformat() if end_date else None,
        "sub_date": sub_date.isoformat() if sub_date else None,
        "auto_renewal": bool(bot_user.get("auto")),
        "is_test": bool(bot_user.get("test")),
        "role": bot_user.get("role", "user"),
        "bot_username": bot_user.get("username"),
    }
