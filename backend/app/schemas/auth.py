import hashlib

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


class AuthorizationCodeStatuses:
    SUCCESS = 200
    AUTHORIZED = 205
    OTHER_ERROR = 100
    MAIL_NOT_FOUND_IN_DB = 101
    SEND_MAIL_ERROR = 102
    SESSION_NOT_FOUND = 103
    CODE_EXPIRED = 104
    INVALID_CODE = 105
    INVALID_METHOD = 106
    mesgs = {
        OTHER_ERROR: "Внутрення ошибка сервера авторизации.",
        MAIL_NOT_FOUND_IN_DB: "Почта не найдена в базе данных!",
        SEND_MAIL_ERROR: "Ошибка при отправке кода на почту!",
        SESSION_NOT_FOUND: "Запрос не найден на сервере авторизации! Попробуйте начать сначала!",
        CODE_EXPIRED: "Код истёк. Запросите новый!",
        INVALID_CODE: "Неверный код!",
        INVALID_METHOD: "Неверный запрос к серверу авторизации! Если вы видите это сообщение, пожалуйста сообщите о нём в поддержку!",
    }


class SendCodeEmailRequest(BaseModel):
    email: str


class SendCodeEmailResponse(BaseModel):
    session_id: str
    email: str
    cooldown_seconds: int
    message: str = "Код отправлен на вашу электронную почту."


class VerifyCodeEmailRequest(BaseModel):
    session_id: str
    code: str


class VerifyCodeEmailResponse(BaseModel):
    verified: bool
    verification_token: str
    message: str = "Добро пожаловать!"


class AuthorizationServerGenCodeRequest:
    def __init__(self, email: str):
        self.email = email

    def generate_params(self):
        return {"method": "generate_code", "mail": self.email}


class AuthorizationServerGenCodeResponse:
    def __init__(self, params: dict):
        self.session_uuid = params["session_uuid"]
        self.operation_code = params["op_code"]


class AuthorizationServerVerifyCodeRequest:
    def __init__(self, session_uuid: str, code: str):
        self.session_uuid = session_uuid
        self.code = hashlib.md5(code.encode()).hexdigest()

    def generate_params(self):
        return {
            "method": "verify_code",
            "session_uuid": self.session_uuid,
            "code": self.code,
        }


class AuthorizationServerVerifyCodeResponse:
    def __init__(self, params: dict):
        self.session_uuid = params["session_uuid"]
        self.operation_code = params["op_code"]
        if "user_id" in params:
            self.user_id = params["user_id"]
            self.email = params["email"]
