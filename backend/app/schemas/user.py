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
