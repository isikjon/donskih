import logging
import re
import subprocess
from datetime import datetime
from pathlib import Path
from uuid import UUID
import uuid

from fastapi import APIRouter, Depends, HTTPException, Header, UploadFile, File, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.database import get_db
from app.models.content import ContentItem, ContentSubItem
from app.schemas.content import (
    ContentItemCreate,
    ContentItemOut,
    ContentItemUpdate,
    content_item_to_out,
)
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/content", tags=["admin-content"])


async def require_admin(x_admin_key: str | None = Header(None, alias="X-Admin-Key")):
    if not settings.admin_secret_key or x_admin_key != settings.admin_secret_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin key",
        )


def _slugify(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_-]+", "-", value).strip("-").lower()
    return value or "video"


def _make_upload_folder(upload_root: Path, stem: str) -> Path:
    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    slug = _slugify(stem)
    folder = upload_root / f"{timestamp}-{slug}-{uuid.uuid4().hex[:8]}"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


async def _write_upload_file(file: UploadFile, target: Path, max_bytes: int) -> int:
    written = 0
    try:
        with target.open("wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                written += len(chunk)
                if written > max_bytes:
                    out.close()
                    target.unlink(missing_ok=True)
                    raise HTTPException(status_code=413, detail="File is too large")
                out.write(chunk)
    finally:
        await file.close()
    return written


@router.post("/upload-video", response_model=dict)
async def upload_video_file(
    file: UploadFile = File(...),
    _: None = Depends(require_admin),
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="Missing filename")

    suffix = Path(file.filename).suffix.lower()
    allowed = {".mp4", ".mov", ".m4v", ".mkv", ".webm", ".m3u8"}
    if suffix not in allowed:
        raise HTTPException(status_code=400, detail="Unsupported file format")

    upload_root = Path(settings.hls_upload_dir)
    folder = _make_upload_folder(upload_root, Path(file.filename).stem)

    target = folder / f"source{suffix}"
    max_bytes = settings.upload_max_size_mb * 1024 * 1024
    written = await _write_upload_file(file, target, max_bytes)

    playlist = folder / "index.m3u8"
    if suffix == ".m3u8":
        playlist = target
    else:
        segment_pattern = folder / "segment_%03d.ts"
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(target),
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "23",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-ac",
            "2",
            "-ar",
            "48000",
            "-f",
            "hls",
            "-hls_time",
            "6",
            "-hls_playlist_type",
            "vod",
            "-hls_segment_filename",
            str(segment_pattern),
            str(playlist),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0 or not playlist.exists():
            logger.error("ffmpeg failed: %s", proc.stderr)
            raise HTTPException(status_code=500, detail="Video conversion failed")
        target.unlink(missing_ok=True)

    thumbnail = folder / "thumb.jpg"
    thumb_cmd = [
        "ffmpeg",
        "-y",
        "-ss",
        "00:00:03",
        "-i",
        str(playlist),
        "-frames:v",
        "1",
        "-q:v",
        "2",
        str(thumbnail),
    ]
    thumb_proc = subprocess.run(thumb_cmd, capture_output=True, text=True)
    if thumb_proc.returncode != 0:
        logger.warning("thumbnail generation failed: %s", thumb_proc.stderr)

    rel = playlist.relative_to(upload_root).as_posix()
    thumb_rel = thumbnail.relative_to(upload_root).as_posix() if thumbnail.exists() else None
    base = settings.hls_public_base_url.rstrip("/")
    return {
        "url": f"{base}/{rel}",
        "filename": playlist.name,
        "thumbnail_url": f"{base}/{thumb_rel}" if thumb_rel else None,
        "size_bytes": written,
    }


@router.post("/upload-checklist", response_model=dict)
async def upload_checklist_file(
    file: UploadFile = File(...),
    _: None = Depends(require_admin),
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="Missing filename")

    suffix = Path(file.filename).suffix.lower()
    if suffix != ".pdf":
        raise HTTPException(status_code=400, detail="Unsupported file format")

    upload_root = Path(settings.hls_upload_dir)
    folder = _make_upload_folder(upload_root / "checklists", Path(file.filename).stem)

    target = folder / "file.pdf"
    max_bytes = settings.upload_max_size_mb * 1024 * 1024
    written = await _write_upload_file(file, target, max_bytes)

    thumbnail = folder / "thumb.jpg"
    thumb_cmd = [
        "ffmpeg",
        "-y",
        "-ss",
        "00:00:01",
        "-i",
        str(target),
        "-frames:v",
        "1",
        "-q:v",
        "2",
        str(thumbnail),
    ]
    thumb_proc = subprocess.run(thumb_cmd, capture_output=True, text=True)
    if thumb_proc.returncode != 0:
        logger.warning("checklist thumbnail generation failed: %s", thumb_proc.stderr)

    rel = target.relative_to(upload_root).as_posix()
    thumb_rel = thumbnail.relative_to(upload_root).as_posix() if thumbnail.exists() else None
    base = settings.hls_public_base_url.rstrip("/")
    return {
        "url": f"{base}/{rel}",
        "filename": file.filename,
        "thumbnail_url": f"{base}/{thumb_rel}" if thumb_rel else None,
        "size_bytes": written,
    }


@router.get("", response_model=list[ContentItemOut])
async def admin_list_content(
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
):
    result = await db.execute(
        select(ContentItem)
        .options(selectinload(ContentItem.sub_items))
        .order_by(ContentItem.display_date.desc(), ContentItem.sort_order.asc())
    )
    items = result.scalars().all()
    return [content_item_to_out(i) for i in items]


@router.post("", response_model=ContentItemOut, status_code=status.HTTP_201_CREATED)
async def admin_create_content(
    body: ContentItemCreate,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
):
    item = ContentItem(
        type=body.type,
        display_date=body.display_date,
        title=body.title,
        subtitle=body.subtitle,
        sort_order=body.sort_order,
        url=body.url,
    )
    db.add(item)
    await db.flush()
    for i, sub in enumerate(body.sub_items):
        sub_item = ContentSubItem(
            content_item_id=item.id,
            title=sub.title,
            duration=sub.duration,
            sort_order=sub.sort_order if sub.sort_order else i,
        )
        db.add(sub_item)
    await db.commit()
    await db.refresh(item)
    await db.refresh(item, ["sub_items"])
    return content_item_to_out(item)


@router.get("/{item_id}", response_model=ContentItemOut)
async def admin_get_content(
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
):
    result = await db.execute(
        select(ContentItem)
        .options(selectinload(ContentItem.sub_items))
        .where(ContentItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Content not found")
    return content_item_to_out(item)


@router.put("/{item_id}", response_model=ContentItemOut)
async def admin_update_content(
    item_id: UUID,
    body: ContentItemUpdate,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
):
    result = await db.execute(
        select(ContentItem)
        .options(selectinload(ContentItem.sub_items))
        .where(ContentItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Content not found")
    if body.display_date is not None:
        item.display_date = body.display_date
    if body.title is not None:
        item.title = body.title
    if body.subtitle is not None:
        item.subtitle = body.subtitle
    if body.sort_order is not None:
        item.sort_order = body.sort_order
    if body.url is not None:
        item.url = body.url
    if body.sub_items is not None:
        for sub in item.sub_items:
            await db.delete(sub)
        for i, sub_in in enumerate(body.sub_items):
            sub_item = ContentSubItem(
                content_item_id=item.id,
                title=sub_in.title,
                duration=sub_in.duration,
                sort_order=sub_in.sort_order if sub_in.sort_order else i,
            )
            db.add(sub_item)
    await db.commit()
    await db.refresh(item)
    await db.refresh(item, ["sub_items"])
    return content_item_to_out(item)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_content(
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_admin),
):
    result = await db.execute(select(ContentItem).where(ContentItem.id == item_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Content not found")
    await db.delete(item)
    await db.commit()
