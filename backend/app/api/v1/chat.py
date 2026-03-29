import asyncio
import logging
import os
import subprocess
import uuid
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.config import settings
from app.database import async_session, get_db
from app.models.chat import ChatMessage
from app.models.push import DeviceToken
from app.models.user import TelegramAccount, User
from app.schemas.chat import (
    ChatMessageOut,
    EditMessageRequest,
    SendMessageRequest,
)
from app.security.jwt import decode_access_token, get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])

CHAT_UPLOAD_DIR = "/app/static/chat"
CHAT_PUBLIC_BASE = "https://donskih-cdn.ru/static/chat"
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v", ".mkv", ".webm"}
MAX_VIDEO_SIZE_BYTES = 200 * 1024 * 1024  # 200 MB


# ---------------------------------------------------------------------------
# WebSocket connection manager
# ---------------------------------------------------------------------------

class _ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: str) -> None:
        await websocket.accept()
        self._connections[user_id] = websocket
        logger.info(f"Chat WS connected: user={user_id}, total={len(self._connections)}")

    def disconnect(self, user_id: str) -> None:
        self._connections.pop(user_id, None)
        logger.info(f"Chat WS disconnected: user={user_id}, total={len(self._connections)}")

    async def broadcast(self, data: dict) -> None:
        dead: list[str] = []
        for uid, ws in list(self._connections.items()):
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(uid)
        for uid in dead:
            self.disconnect(uid)

    @property
    def online_count(self) -> int:
        return len(self._connections)


manager = _ConnectionManager()


# ---------------------------------------------------------------------------
# Push notifications for offline users
# ---------------------------------------------------------------------------

async def _push_chat_message(sender_name: str, text: str | None, sender_user_id: str) -> None:
    """Send FCM push to all users who are NOT currently connected via WebSocket.

    Opens its own DB session so it's safe to run as a background task
    after the request's session has been closed.
    """
    from app.api.v1.push import _send_fcm_batch

    online_user_ids = set(manager._connections.keys())

    try:
        async with async_session() as db:
            result = await db.execute(select(DeviceToken.token, DeviceToken.user_id))
            rows = result.all()
    except Exception as e:
        logger.error(f"_push_chat_message: DB error: {e}")
        return

    offline_tokens = [
        row.token for row in rows
        if str(row.user_id) not in online_user_ids and str(row.user_id) != sender_user_id
    ]

    if not offline_tokens:
        return

    title = f"Новое сообщение от {sender_name}"
    body = text or "📎 Медиафайл"

    try:
        await _send_fcm_batch(title, body, offline_tokens)
    except Exception as e:
        logger.error(f"_push_chat_message: FCM error: {e}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _serialize(msg: ChatMessage) -> dict:
    tg = None
    if msg.user and msg.user.telegram_account:
        tg = msg.user.telegram_account

    sender_name = "Участник"
    if tg:
        parts = [tg.first_name or "", tg.last_name or ""]
        sender_name = " ".join(p for p in parts if p).strip() or tg.username or "Участник"

    return {
        "id": str(msg.id),
        "user_id": str(msg.user_id),
        "sender_name": sender_name,
        "sender_photo_url": tg.photo_url if tg else None,
        "text": msg.text if not msg.is_deleted else None,
        "image_url": msg.image_url if not msg.is_deleted else None,
        "video_url": msg.video_url if not msg.is_deleted else None,
        "video_thumbnail_url": msg.video_thumbnail_url if not msg.is_deleted else None,
        "group_id": msg.group_id,
        "reply_to_message_id": str(msg.reply_to_message_id) if msg.reply_to_message_id else None,
        "is_edited": msg.is_edited,
        "is_deleted": msg.is_deleted,
        "created_at": msg.created_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------

@router.websocket("/ws")
async def chat_websocket(websocket: WebSocket, token: str) -> None:
    try:
        payload = decode_access_token(token)
        user_id: str = payload["sub"]
    except HTTPException:
        await websocket.close(code=4001)
        return

    async with async_session() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user or not user.is_active:
            await websocket.close(code=4001)
            return

    await manager.connect(websocket, user_id)
    try:
        while True:
            # Keep connection alive — client can send pings
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id)


# ---------------------------------------------------------------------------
# REST: load message history
# ---------------------------------------------------------------------------

@router.get("/messages", response_model=list[ChatMessageOut])
async def get_messages(
    limit: int = 50,
    before_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    query = (
        select(ChatMessage)
        .options(
            selectinload(ChatMessage.user).joinedload(User.telegram_account)
        )
        .order_by(desc(ChatMessage.created_at))
        .limit(min(limit, 100))
    )
    if before_id:
        try:
            before_uuid = uuid.UUID(before_id)
            before_msg_result = await db.execute(
                select(ChatMessage).where(ChatMessage.id == before_uuid)
            )
            before_msg = before_msg_result.scalar_one_or_none()
            if before_msg:
                query = query.where(ChatMessage.created_at < before_msg.created_at)
        except (ValueError, AttributeError):
            pass

    result = await db.execute(query)
    messages = list(reversed(result.scalars().all()))
    return [_serialize(m) for m in messages]


# ---------------------------------------------------------------------------
# REST: send message
# ---------------------------------------------------------------------------

@router.post("/messages", response_model=ChatMessageOut, status_code=status.HTTP_201_CREATED)
async def send_message(
    req: SendMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    if not req.text and not req.image_url and not req.video_url:
        raise HTTPException(status_code=400, detail="Either text, image_url or video_url is required")

    reply_to_uuid = None
    if req.reply_to_message_id:
        try:
            reply_to_uuid = uuid.UUID(req.reply_to_message_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid reply_to_message_id")

    msg = ChatMessage(
        user_id=current_user.id,
        text=req.text.strip() if req.text else None,
        image_url=req.image_url,
        video_url=req.video_url,
        video_thumbnail_url=req.video_thumbnail_url,
        group_id=req.group_id,
        reply_to_message_id=reply_to_uuid,
    )
    db.add(msg)
    await db.flush()

    # Reload with user relation for serialization
    await db.refresh(msg)
    result = await db.execute(
        select(ChatMessage)
        .options(
            selectinload(ChatMessage.user).joinedload(User.telegram_account)
        )
        .where(ChatMessage.id == msg.id)
    )
    msg = result.scalar_one()

    serialized = _serialize(msg)
    await manager.broadcast({"type": "new_message", "message": serialized})

    # Push notification to offline users (non-blocking, uses own DB session)
    sender_name = serialized.get("sender_name", "Участник")
    asyncio.create_task(
        _push_chat_message(sender_name, msg.text, str(current_user.id))
    )

    return serialized


# ---------------------------------------------------------------------------
# REST: edit message
# ---------------------------------------------------------------------------

@router.put("/messages/{message_id}", response_model=ChatMessageOut)
async def edit_message(
    message_id: str,
    req: EditMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    try:
        msg_uuid = uuid.UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Message not found")

    result = await db.execute(
        select(ChatMessage)
        .options(
            selectinload(ChatMessage.user).joinedload(User.telegram_account)
        )
        .where(ChatMessage.id == msg_uuid)
    )
    msg = result.scalar_one_or_none()

    if not msg or msg.is_deleted:
        raise HTTPException(status_code=404, detail="Message not found")
    if str(msg.user_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Cannot edit another user's message")
    if not msg.text:
        raise HTTPException(status_code=400, detail="Cannot edit image-only messages")

    msg.text = req.text.strip()
    msg.is_edited = True
    await db.flush()

    serialized = _serialize(msg)
    await manager.broadcast({"type": "edit_message", "message": serialized})
    return serialized


# ---------------------------------------------------------------------------
# REST: delete message
# ---------------------------------------------------------------------------

@router.delete("/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_message(
    message_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    try:
        msg_uuid = uuid.UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Message not found")

    result = await db.execute(
        select(ChatMessage).where(ChatMessage.id == msg_uuid)
    )
    msg = result.scalar_one_or_none()

    if not msg or msg.is_deleted:
        raise HTTPException(status_code=404, detail="Message not found")
    if str(msg.user_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Cannot delete another user's message")

    msg.is_deleted = True
    await db.flush()

    await manager.broadcast({"type": "delete_message", "message_id": message_id})


# ---------------------------------------------------------------------------
# REST: upload image
# ---------------------------------------------------------------------------

@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> dict:
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")

    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported format. Allowed: {ALLOWED_IMAGE_EXTENSIONS}")

    content = await file.read()
    if len(content) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="Image too large (max 10 MB)")

    os.makedirs(CHAT_UPLOAD_DIR, exist_ok=True)
    filename = f"{uuid.uuid4()}{ext}"
    save_path = os.path.join(CHAT_UPLOAD_DIR, filename)

    with open(save_path, "wb") as f:
        f.write(content)

    return {"image_url": f"{CHAT_PUBLIC_BASE}/{filename}"}


# ---------------------------------------------------------------------------
# REST: upload video
# ---------------------------------------------------------------------------

def _compress_video(source: Path, output: Path, thumb: Path) -> float | None:
    """Run ffmpeg to compress video and extract thumbnail. Returns duration in seconds."""
    cmd = [
        "ffmpeg", "-y", "-i", str(source),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "28",
        "-c:a", "aac", "-b:a", "96k", "-ac", "2", "-ar", "44100",
        "-movflags", "+faststart",
        str(output),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0 or not output.exists():
        logger.error("ffmpeg video compress failed: %s", proc.stderr)
        return None

    thumb_cmd = [
        "ffmpeg", "-y", "-ss", "00:00:01", "-i", str(output),
        "-frames:v", "1", "-q:v", "3", str(thumb),
    ]
    subprocess.run(thumb_cmd, capture_output=True, text=True)

    dur_cmd = [
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(output),
    ]
    dur_proc = subprocess.run(dur_cmd, capture_output=True, text=True)
    try:
        return float(dur_proc.stdout.strip())
    except (ValueError, AttributeError):
        return None


@router.post("/upload-video")
async def upload_video(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> dict:
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")

    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_VIDEO_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported format. Allowed: {ALLOWED_VIDEO_EXTENSIONS}",
        )

    folder_name = str(uuid.uuid4())
    video_dir = Path(CHAT_UPLOAD_DIR) / "videos" / folder_name
    os.makedirs(video_dir, exist_ok=True)

    source_path = video_dir / f"source{ext}"
    written = 0
    try:
        with open(source_path, "wb") as f:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                written += len(chunk)
                if written > MAX_VIDEO_SIZE_BYTES:
                    f.close()
                    source_path.unlink(missing_ok=True)
                    raise HTTPException(
                        status_code=413,
                        detail=f"Video too large (max {MAX_VIDEO_SIZE_BYTES // (1024*1024)} MB)",
                    )
                f.write(chunk)
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Video upload write error: %s", e)
        raise HTTPException(status_code=500, detail="Upload failed")

    output_path = video_dir / "output.mp4"
    thumb_path = video_dir / "thumb.jpg"

    duration = await asyncio.to_thread(
        _compress_video, source_path, output_path, thumb_path
    )

    if not output_path.exists():
        raise HTTPException(status_code=500, detail="Video conversion failed")

    source_path.unlink(missing_ok=True)

    video_url = f"{CHAT_PUBLIC_BASE}/videos/{folder_name}/output.mp4"
    thumb_url = (
        f"{CHAT_PUBLIC_BASE}/videos/{folder_name}/thumb.jpg"
        if thumb_path.exists()
        else None
    )
    return {
        "video_url": video_url,
        "thumbnail_url": thumb_url,
        "duration_sec": round(duration, 1) if duration else None,
    }


# ---------------------------------------------------------------------------
# REST: online count
# ---------------------------------------------------------------------------

@router.get("/online")
async def get_online_count(current_user: User = Depends(get_current_user)) -> dict:
    return {"online": manager.online_count}
