import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.schemas.auth import (
    SendCodeRequest,
    SendCodeResponse,
    VerifyCodeRequest,
    TokenPair,
    RefreshRequest,
    ErrorResponse,
)
from app.services.telegram_gateway import telegram_gateway, TelegramGatewayError
from app.services.auth_service import auth_service
from app.security.jwt import get_current_user
from app.security.rate_limit import (
    ensure_rate_limit,
    consume_rate_limit,
    parse_rate_limit_spec,
    check_send_code_cooldown,
    set_send_code_cooldown,
    store_verification_session,
    get_verification_session,
    increment_verification_attempts,
    delete_verification_session,
)
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth/telegram", tags=["auth"])


@router.post(
    "/send-code",
    response_model=SendCodeResponse,
    responses={429: {"model": ErrorResponse}},
)
async def send_code(body: SendCodeRequest, request: Request):
    """Send verification code via Telegram Gateway."""
    client_ip = request.client.host if request.client else "unknown"
    phone = body.phone

    ip_limit, ip_window = parse_rate_limit_spec(
        settings.rate_limit_send_code_per_ip,
        default=(20, 3600),
    )
    phone_limit, phone_window = parse_rate_limit_spec(
        settings.rate_limit_send_code_per_phone,
        default=(3, 3600),
    )

    ip_key = f"rl:send_code:ip:{client_ip}"
    phone_key = f"rl:send_code:phone:{phone}"

    await check_send_code_cooldown(phone)
    await ensure_rate_limit(ip_key, ip_limit, ip_window)
    await ensure_rate_limit(phone_key, phone_limit, phone_window)

    try:
        result = await telegram_gateway.send_verification_code(
            phone_number=phone,
            code_length=6,
            ttl=settings.verification_code_ttl_seconds,
        )
    except TelegramGatewayError as e:
        logger.error(f"Gateway error for {phone}: {e}")
        if e.code == "BALANCE_NOT_ENOUGH":
            raise HTTPException(
                status_code=503,
                detail=(
                    "Сервис отправки кода временно недоступен "
                    "(закончился баланс Telegram Gateway)."
                ),
            )
        raise HTTPException(
            status_code=502,
            detail=f"Не удалось отправить код через Telegram ({e.code})",
        )
    except Exception as e:
        logger.exception(f"Unexpected error sending code to {phone}")
        raise HTTPException(status_code=500, detail="Внутренняя ошибка сервера")

    await consume_rate_limit(ip_key, ip_window)
    await consume_rate_limit(phone_key, phone_window)

    session_id = str(uuid.uuid4())
    await store_verification_session(session_id, phone, result.request_id)
    await set_send_code_cooldown(phone)

    logger.info(f"Verification code sent to {phone}, session={session_id}")

    return SendCodeResponse(
        session_id=session_id,
        phone=phone,
        cooldown_seconds=settings.verification_cooldown_seconds,
    )


@router.post(
    "/verify-code",
    response_model=TokenPair,
    responses={400: {"model": ErrorResponse}, 429: {"model": ErrorResponse}},
)
async def verify_code(
    body: VerifyCodeRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Verify code, create/find user by phone, return JWT tokens."""
    session = await get_verification_session(body.session_id)
    if not session:
        raise HTTPException(status_code=400, detail="Session expired or invalid")

    attempts = int(session.get("attempts", "0"))
    if attempts >= settings.rate_limit_verify_code_max_attempts:
        await delete_verification_session(body.session_id)
        raise HTTPException(status_code=429, detail="Too many attempts. Request a new code.")

    await increment_verification_attempts(body.session_id)

    try:
        result = await telegram_gateway.check_verification(
            request_id=session["request_id"],
            code=body.code,
        )
    except TelegramGatewayError as e:
        logger.error(f"Gateway verify error: {e}")
        raise HTTPException(status_code=502, detail="Verification check failed")

    if not result.verified:
        remaining = settings.rate_limit_verify_code_max_attempts - attempts - 1
        raise HTTPException(
            status_code=400,
            detail=f"Invalid code. {remaining} attempts remaining.",
        )

    phone = session["phone"]
    await delete_verification_session(body.session_id)

    user = await auth_service.get_or_create_user(db, phone)
    tokens = await auth_service.create_token_pair(db, user)

    logger.info(f"Phone {phone} verified, user {user.id} authenticated")

    return tokens


@router.post(
    "/bot-link",
    response_model=dict,
)
async def create_bot_link_token(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a token for linking Telegram profile via bot."""
    from app.security.rate_limit import store_bot_link_token
    token = str(uuid.uuid4())[:8]
    await store_bot_link_token(token, str(user.id))
    bot_username = "donskih_authorization_bot"
    return {
        "link_token": token,
        "bot_url": f"https://t.me/{bot_username}?start=link_{token}",
    }


@router.get(
    "/link-status",
    response_model=dict,
)
async def check_link_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Check if Telegram account has been linked via bot."""
    await db.refresh(user, ["telegram_account"])
    linked = user.telegram_account is not None
    result = {"linked": linked}
    if linked:
        tg = user.telegram_account
        result["telegram"] = {
            "telegram_user_id": tg.telegram_user_id,
            "first_name": tg.first_name,
            "last_name": tg.last_name,
            "username": tg.username,
            "photo_url": tg.photo_url,
        }
    return result


@router.post("/refresh", response_model=TokenPair)
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Rotate refresh token."""
    try:
        return await auth_service.refresh_tokens(db, body.refresh_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/logout", status_code=204)
async def logout(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke all refresh tokens for the current user."""
    await auth_service.revoke_all_tokens(db, user.id)
    logger.info(f"User {user.id} logged out")
