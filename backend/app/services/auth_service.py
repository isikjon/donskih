import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user import User, TelegramAccount, RefreshToken
from app.schemas.auth import TelegramLoginData, TokenPair
from app.security.jwt import (
    create_access_token,
    create_refresh_token_value,
    hash_token,
)


class AuthService:
    async def get_or_create_user(self, db: AsyncSession, phone: str) -> User:
        result = await db.execute(select(User).where(User.phone == phone))
        user = result.scalar_one_or_none()
        if user:
            return user

        user = User(phone=phone)
        db.add(user)
        await db.flush()
        return user

    async def link_telegram_account(
        self,
        db: AsyncSession,
        user: User,
        tg_data: TelegramLoginData,
    ) -> TelegramAccount:
        result = await db.execute(
            select(TelegramAccount).where(
                TelegramAccount.telegram_user_id == tg_data.id
            )
        )
        existing = result.scalar_one_or_none()

        if existing and existing.user_id != user.id:
            raise ValueError("Telegram account already linked to another user")

        if existing and existing.user_id == user.id:
            existing.first_name = tg_data.first_name
            existing.last_name = tg_data.last_name
            existing.username = tg_data.username
            existing.photo_url = tg_data.photo_url
            existing.auth_date = tg_data.auth_date
            return existing

        tg_account = TelegramAccount(
            user_id=user.id,
            telegram_user_id=tg_data.id,
            first_name=tg_data.first_name,
            last_name=tg_data.last_name,
            username=tg_data.username,
            photo_url=tg_data.photo_url,
            auth_date=tg_data.auth_date,
        )
        db.add(tg_account)
        await db.flush()
        return tg_account

    async def create_token_pair(self, db: AsyncSession, user: User) -> TokenPair:
        access_token, expires_in = create_access_token(str(user.id))

        raw_refresh, token_hash = create_refresh_token_value()
        expires_at = datetime.now(timezone.utc) + timedelta(
            days=settings.jwt_refresh_token_expire_days
        )
        rt = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        db.add(rt)
        await db.flush()

        return TokenPair(
            access_token=access_token,
            refresh_token=raw_refresh,
            expires_in=expires_in,
        )

    async def refresh_tokens(
        self, db: AsyncSession, raw_refresh: str
    ) -> TokenPair:
        token_h = hash_token(raw_refresh)
        result = await db.execute(
            select(RefreshToken).where(
                RefreshToken.token_hash == token_h,
                RefreshToken.is_revoked == False,
            )
        )
        rt = result.scalar_one_or_none()

        if not rt:
            raise ValueError("Invalid refresh token")

        if rt.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
            rt.is_revoked = True
            raise ValueError("Refresh token expired")

        # Rotation: revoke old, issue new
        rt.is_revoked = True

        result = await db.execute(select(User).where(User.id == rt.user_id))
        user = result.scalar_one_or_none()
        if not user or not user.is_active:
            raise ValueError("User not found or inactive")

        return await self.create_token_pair(db, user)

    async def revoke_all_tokens(self, db: AsyncSession, user_id: uuid.UUID) -> None:
        result = await db.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == user_id,
                RefreshToken.is_revoked == False,
            )
        )
        tokens = result.scalars().all()
        for t in tokens:
            t.is_revoked = True


auth_service = AuthService()
