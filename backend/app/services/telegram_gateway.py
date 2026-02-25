"""
Telegram Gateway API integration.

Docs: https://core.telegram.org/gateway/api

Flow:
1. sendVerificationMessage → sends code via Telegram
2. checkVerificationStatus(request_id, code) → checks if user-entered code matches
"""

import httpx
from dataclasses import dataclass

from app.config import settings


@dataclass
class SendResult:
    request_id: str
    phone_code_hash: str | None = None


@dataclass
class VerifyResult:
    verified: bool
    status: str  # "code_valid" | "code_invalid" | "code_max_attempts_exceeded" | "expired"


class TelegramGatewayService:
    def __init__(self):
        self.base_url = settings.telegram_gateway_url
        self.token = settings.telegram_gateway_token

    @property
    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    async def send_verification_code(
        self, phone_number: str, code_length: int = 6, ttl: int = 300
    ) -> SendResult:
        """
        Send a verification code via Telegram Gateway.
        Telegram generates the code and delivers it to the user.

        Проверено по docs: https://core.telegram.org/gateway/api#sendverificationmessage
        """
        async with httpx.AsyncClient(timeout=30) as client:
            try:
                resp = await client.post(
                    f"{self.base_url}/sendVerificationMessage",
                    headers=self._headers,
                    json={
                        "phone_number": phone_number,
                        "code_length": code_length,
                        "ttl": ttl,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
            except httpx.HTTPError as e:
                raise TelegramGatewayError(code="HTTP_ERROR", message=str(e))

            if not data.get("ok"):
                error = data.get("error", "UNKNOWN_ERROR")
                raise TelegramGatewayError(
                    code=error,
                    message=f"Gateway error: {error}",
                )

            result = data["result"]
            return SendResult(
                request_id=result["request_id"],
                phone_code_hash=result.get("phone_code_hash"),
            )

    async def check_verification(
        self, request_id: str, code: str
    ) -> VerifyResult:
        """
        Check if the code entered by user matches.

        Проверено по docs: https://core.telegram.org/gateway/api#checkverificationstatus
        """
        async with httpx.AsyncClient(timeout=30) as client:
            try:
                resp = await client.post(
                    f"{self.base_url}/checkVerificationStatus",
                    headers=self._headers,
                    json={
                        "request_id": request_id,
                        "code": code,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
            except httpx.HTTPError as e:
                raise TelegramGatewayError(code="HTTP_ERROR", message=str(e))

            if not data.get("ok"):
                error = data.get("error", "UNKNOWN_ERROR")
                raise TelegramGatewayError(
                    code=error,
                    message=f"Gateway error: {error}",
                )

            result = data["result"]
            verification_status = result.get("verification_status", {})
            status_value = verification_status.get("status", "unknown")

            return VerifyResult(
                verified=(status_value == "code_valid"),
                status=status_value,
            )


class TelegramGatewayError(Exception):
    def __init__(self, code: str, message: str | None = None):
        self.code = code
        super().__init__(message or code)


telegram_gateway = TelegramGatewayService()
