from pydantic import BaseModel, Field
import re


class SendCodeRequest(BaseModel):
    phone: str = Field(..., pattern=r"^\+\d{10,15}$", examples=["+79991234567"])


class SendCodeResponse(BaseModel):
    session_id: str
    phone: str
    cooldown_seconds: int
    message: str = "Код отправлен через Telegram"


class VerifyCodeRequest(BaseModel):
    session_id: str
    code: str = Field(..., min_length=4, max_length=8)


class VerifyCodeResponse(BaseModel):
    verified: bool
    verification_token: str
    message: str = "Номер подтверждён. Привяжите Telegram-аккаунт."


class TelegramLoginData(BaseModel):
    """Data from Telegram Login Widget callback."""
    id: int
    first_name: str | None = None
    last_name: str | None = None
    username: str | None = None
    photo_url: str | None = None
    auth_date: int
    hash: str


class TelegramLoginRequest(BaseModel):
    verification_token: str
    telegram_data: TelegramLoginData


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshRequest(BaseModel):
    refresh_token: str


class ErrorResponse(BaseModel):
    error: str
    detail: str | None = None
    code: str | None = None
