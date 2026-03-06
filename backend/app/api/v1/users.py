import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.database import get_db
from app.schemas.user import UserOut, UserPublicOut
from app.security.jwt import get_current_user

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)):
    """Return the current authenticated user's profile."""
    return user


def _to_public_user(user: User) -> UserPublicOut:
    tg = user.telegram_account
    name = "Пользователь"
    username = None
    avatar_url = None

    if tg is not None:
        first = (tg.first_name or "").strip()
        last = (tg.last_name or "").strip()
        combined = f"{first} {last}".strip()
        if combined:
            name = combined
        elif tg.username:
            name = f"@{tg.username}"
        username = tg.username
        avatar_url = tg.photo_url

    return UserPublicOut(
        id=user.id,
        name=name,
        username=username,
        avatar_url=avatar_url,
        bio=None,
        joined_at=user.created_at,
        is_online=None,
        last_seen_at=None,
    )


@router.get("/users/{user_id}", response_model=UserPublicOut)
async def get_user_profile(
    user_id: str,
    _: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return public profile of a user by id."""
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user id")

    result = await db.execute(select(User).where(User.id == uid))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _to_public_user(user)
