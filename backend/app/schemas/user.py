from pydantic import BaseModel
from datetime import datetime
import uuid


class TelegramAccountOut(BaseModel):
    telegram_user_id: int
    first_name: str | None
    last_name: str | None
    username: str | None
    photo_url: str | None

    model_config = {"from_attributes": True}


class UserOut(BaseModel):
    id: uuid.UUID
    phone: str
    is_active: bool
    created_at: datetime
    telegram_account: TelegramAccountOut | None = None

    model_config = {"from_attributes": True}


class UserPublicOut(BaseModel):
    id: uuid.UUID
    name: str
    username: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    joined_at: datetime
    is_online: bool | None = None
    last_seen_at: datetime | None = None

