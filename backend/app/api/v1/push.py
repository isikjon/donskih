import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import List

import httpx
from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel, Field
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.push import DeviceToken, PushNotification
from app.models.user import User
from app.security.jwt import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(tags=["push"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class RegisterDeviceRequest(BaseModel):
    token: str = Field(..., max_length=512)
    platform: str = Field("unknown", max_length=20)


class SendPushRequest(BaseModel):
    title: str = Field(..., max_length=256)
    body: str = Field(..., max_length=4096)


class PushNotificationOut(BaseModel):
    id: str
    title: str
    body: str
    sent_at: str
    recipients_count: int
    success_count: int
    failure_count: int


# ---------------------------------------------------------------------------
# Admin auth
# ---------------------------------------------------------------------------

async def require_admin(x_admin_key: str | None = Header(None, alias="X-Admin-Key")):
    if not settings.admin_secret_key or x_admin_key != settings.admin_secret_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin key",
        )


# ---------------------------------------------------------------------------
# Device registration (called from mobile app)
# ---------------------------------------------------------------------------

@router.post("/devices/register", status_code=200)
async def register_device(
    body: RegisterDeviceRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(DeviceToken).where(DeviceToken.token == body.token)
    )
    row = existing.scalar_one_or_none()

    if row:
        row.user_id = user.id
        row.platform = body.platform
        row.updated_at = datetime.now(timezone.utc)
    else:
        db.add(DeviceToken(
            user_id=user.id,
            token=body.token,
            platform=body.platform,
        ))

    await db.flush()
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Admin: send push to all devices
# ---------------------------------------------------------------------------

@router.post("/admin/push/send", status_code=200, dependencies=[Depends(require_admin)])
async def send_push(
    body: SendPushRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(DeviceToken.token))
    tokens: List[str] = [r[0] for r in result.all()]

    if not tokens:
        raise HTTPException(status_code=400, detail="No registered devices")

    success = 0
    failure = 0
    all_stale: List[str] = []

    batch_size = 500
    for i in range(0, len(tokens), batch_size):
        batch = tokens[i:i + batch_size]
        s, f, stale = await _send_fcm_batch(body.title, body.body, batch)
        success += s
        failure += f
        all_stale.extend(stale)

    if all_stale:
        await db.execute(delete(DeviceToken).where(DeviceToken.token.in_(all_stale)))
        logger.info(f"Removed {len(all_stale)} stale FCM tokens")

    notification = PushNotification(
        title=body.title,
        body=body.body,
        recipients_count=len(tokens),
        success_count=success,
        failure_count=failure,
    )
    db.add(notification)
    await db.flush()

    return {
        "status": "ok",
        "recipients": len(tokens),
        "success": success,
        "failure": failure,
    }


# ---------------------------------------------------------------------------
# Admin: push history
# ---------------------------------------------------------------------------

@router.get("/admin/push/history", dependencies=[Depends(require_admin)])
async def push_history(
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    total_q = await db.execute(select(func.count(PushNotification.id)))
    total = total_q.scalar() or 0

    result = await db.execute(
        select(PushNotification)
        .order_by(PushNotification.sent_at.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = result.scalars().all()

    items = [
        PushNotificationOut(
            id=str(r.id),
            title=r.title,
            body=r.body,
            sent_at=r.sent_at.isoformat(),
            recipients_count=r.recipients_count,
            success_count=r.success_count,
            failure_count=r.failure_count,
        ).model_dump()
        for r in rows
    ]

    return {"total": total, "items": items}


# ---------------------------------------------------------------------------
# Admin: device count
# ---------------------------------------------------------------------------

@router.get("/admin/push/devices-count", dependencies=[Depends(require_admin)])
async def devices_count(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(func.count(DeviceToken.id)))
    count = result.scalar() or 0
    return {"count": count}


# ---------------------------------------------------------------------------
# Admin: diagnostic — list all tokens with user info
# ---------------------------------------------------------------------------

@router.get("/admin/push/tokens", dependencies=[Depends(require_admin)])
async def list_tokens(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(DeviceToken, User.phone)
        .join(User, DeviceToken.user_id == User.id)
        .order_by(DeviceToken.updated_at.desc())
    )
    rows = result.all()
    return {
        "tokens": [
            {
                "token_prefix": dt.token[:12],
                "token_full": dt.token,
                "platform": dt.platform,
                "user_id": str(dt.user_id),
                "phone": phone,
                "created_at": dt.created_at.isoformat() if dt.created_at else None,
                "updated_at": dt.updated_at.isoformat() if dt.updated_at else None,
            }
            for dt, phone in rows
        ]
    }


# ---------------------------------------------------------------------------
# FCM HTTP v1 API
# ---------------------------------------------------------------------------

_cached_access_token: dict | None = None


async def _get_google_access_token() -> str:
    """Get OAuth2 access token from service account JSON for FCM HTTP v1 API."""
    global _cached_access_token

    if _cached_access_token:
        exp = _cached_access_token.get("expires_at", 0)
        if datetime.now(timezone.utc).timestamp() < exp - 60:
            return _cached_access_token["token"]

    sa_path = settings.firebase_service_account_path
    if not sa_path:
        raise HTTPException(500, "Firebase service account not configured")

    with open(sa_path) as f:
        sa_info = json.load(f)

    import time
    from jose import jwt as jose_jwt

    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": "https://www.googleapis.com/auth/firebase.messaging",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600,
    }

    signed_jwt = jose_jwt.encode(
        payload,
        sa_info["private_key"],
        algorithm="RS256",
    )

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": signed_jwt,
            },
        )
        resp.raise_for_status()
        data = resp.json()

    _cached_access_token = {
        "token": data["access_token"],
        "expires_at": datetime.now(timezone.utc).timestamp() + data.get("expires_in", 3600),
    }
    return data["access_token"]


async def _send_fcm_batch(
    title: str, body: str, tokens: List[str], *, push_type: str = "admin"
) -> tuple[int, int, List[str]]:
    """Send push notifications via FCM HTTP v1 API concurrently.

    push_type: "admin" | "chat" | "lesson"
    Returns (success_count, failure_count, stale_tokens).
    Stale tokens (404 from FCM) should be removed from DB by the caller.
    """
    try:
        access_token = await _get_google_access_token()
    except Exception as e:
        logger.error(f"Failed to get Google access token: {e}")
        return 0, len(tokens), []

    project_id = settings.firebase_project_id
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

    semaphore = asyncio.Semaphore(50)

    async def _send_one(client: httpx.AsyncClient, token: str) -> tuple[str | None, bool]:
        """Returns (stale_token | None, is_success)."""
        message = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "data": {"type": push_type},
                "apns": {
                    "headers": {
                        "apns-push-type": "alert",
                        "apns-priority": "10",
                    },
                    "payload": {
                        "aps": {
                            "alert": {"title": title, "body": body},
                            "sound": "default",
                            "badge": 1,
                            "mutable-content": 1,
                        }
                    }
                },
                "android": {
                    "priority": "high",
                    "notification": {
                        "sound": "default",
                        "channel_id": "donskih_push_channel",
                    }
                },
            }
        }
        async with semaphore:
            try:
                resp = await client.post(
                    url,
                    json=message,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if resp.status_code == 200:
                    resp_data = resp.json()
                    msg_name = resp_data.get("name", "unknown")
                    logger.info(f"FCM 200 OK token={token[:12]}... fcm_msg={msg_name}")
                    return None, True
                logger.warning(f"FCM {resp.status_code} for {token[:12]}...: {resp.text}")
                if resp.status_code in (404, 400):
                    return token, False
                return None, False
            except Exception as e:
                logger.error(f"FCM send error for token {token[:12]}...: {e}")
                return None, False

    async with httpx.AsyncClient(timeout=30) as client:
        results = await asyncio.gather(*[_send_one(client, t) for t in tokens])

    stale = [r[0] for r in results if r[0] is not None]
    success = sum(1 for r in results if r[1])
    failure = len(results) - success
    return success, failure, stale
