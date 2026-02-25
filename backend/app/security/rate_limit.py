import redis.asyncio as redis
from fastapi import HTTPException, Request, status

from app.config import settings
import re

_redis: redis.Redis | None = None


async def get_redis() -> redis.Redis:
    global _redis
    if _redis is None:
        _redis = redis.from_url(settings.redis_url, decode_responses=True)
    return _redis


def parse_rate_limit_spec(spec: str, default: tuple[int, int]) -> tuple[int, int]:
    """
    Parse limits like:
    - 3/hour
    - 10/min
    - 30/sec
    - 20/day
    """
    if not spec:
        return default
    m = re.match(r"^\s*(\d+)\s*/\s*(?:(\d+)\s*)?([a-zA-Z]+)\s*$", spec.strip())
    if not m:
        return default
    count = int(m.group(1))
    window_multiplier = int(m.group(2)) if m.group(2) else 1
    unit = m.group(3).lower()
    multipliers = {
        "s": 1,
        "sec": 1,
        "second": 1,
        "seconds": 1,
        "m": 60,
        "min": 60,
        "minute": 60,
        "minutes": 60,
        "h": 3600,
        "hr": 3600,
        "hour": 3600,
        "hours": 3600,
        "d": 86400,
        "day": 86400,
        "days": 86400,
    }
    mult = multipliers.get(unit)
    if mult is None or count <= 0 or window_multiplier <= 0:
        return default
    return count, mult * window_multiplier


async def ensure_rate_limit(key: str, max_requests: int, window_seconds: int) -> None:
    """Raises 429 if rate limit exceeded. Does not increment counters."""
    r = await get_redis()
    current = await r.get(key)
    if current and int(current) >= max_requests:
        ttl = await r.ttl(key)
        wait_seconds = ttl if ttl and ttl > 0 else window_seconds
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Слишком много попыток. Повторите через {wait_seconds} секунд.",
        )


async def consume_rate_limit(key: str, window_seconds: int) -> None:
    """Increment counter after successful action."""
    r = await get_redis()
    current = await r.incr(key)
    if current == 1:
        await r.expire(key, window_seconds)


async def check_rate_limit(key: str, max_requests: int, window_seconds: int) -> None:
    """
    Backward-compatible helper: checks + consumes.
    Prefer ensure_rate_limit + consume_rate_limit for precise control.
    """
    await ensure_rate_limit(key, max_requests, window_seconds)
    await consume_rate_limit(key, window_seconds)


async def check_send_code_cooldown(phone: str) -> None:
    """Ensures cooldown between code sends."""
    r = await get_redis()
    cooldown_key = f"cooldown:send_code:{phone}"
    if await r.exists(cooldown_key):
        ttl = await r.ttl(cooldown_key)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Подождите {ttl} секунд перед повторной отправкой кода.",
        )


async def set_send_code_cooldown(phone: str) -> None:
    r = await get_redis()
    cooldown_key = f"cooldown:send_code:{phone}"
    await r.setex(cooldown_key, settings.verification_cooldown_seconds, "1")


async def store_verification_session(
    session_id: str, phone: str, request_id: str
) -> None:
    """Store verification session in Redis with TTL."""
    r = await get_redis()
    key = f"verification:{session_id}"
    await r.hset(key, mapping={
        "phone": phone,
        "request_id": request_id,
        "attempts": "0",
    })
    await r.expire(key, settings.verification_code_ttl_seconds)


async def get_verification_session(session_id: str) -> dict | None:
    r = await get_redis()
    key = f"verification:{session_id}"
    data = await r.hgetall(key)
    return data if data else None


async def increment_verification_attempts(session_id: str) -> int:
    r = await get_redis()
    key = f"verification:{session_id}"
    return await r.hincrby(key, "attempts", 1)


async def delete_verification_session(session_id: str) -> None:
    r = await get_redis()
    await r.delete(f"verification:{session_id}")


async def store_verified_phone_token(token: str, phone: str) -> None:
    """Temporary token proving phone is verified, used for linking Telegram."""
    r = await get_redis()
    await r.setex(f"verified_phone:{token}", 600, phone)


async def get_verified_phone(token: str) -> str | None:
    r = await get_redis()
    return await r.get(f"verified_phone:{token}")


async def delete_verified_phone_token(token: str) -> None:
    r = await get_redis()
    await r.delete(f"verified_phone:{token}")


async def store_bot_link_token(token: str, user_id: str) -> None:
    """Temporary token for linking Telegram via bot. TTL 10 minutes."""
    r = await get_redis()
    await r.setex(f"bot_link:{token}", 600, user_id)


async def get_bot_link_user_id(token: str) -> str | None:
    r = await get_redis()
    return await r.get(f"bot_link:{token}")


async def delete_bot_link_token(token: str) -> None:
    r = await get_redis()
    await r.delete(f"bot_link:{token}")
