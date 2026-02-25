import hashlib
import hmac
import time
import pytest
from unittest.mock import AsyncMock, patch

from app.services.telegram_login import TelegramLoginService
from app.schemas.auth import TelegramLoginData


class TestTelegramLoginVerification:
    def setup_method(self):
        self.service = TelegramLoginService()

    @patch("app.services.telegram_login.settings")
    def test_valid_hash(self, mock_settings):
        mock_settings.telegram_bot_token = "test_bot_token"

        data_dict = {
            "id": 12345,
            "first_name": "Test",
            "auth_date": int(time.time()),
        }

        secret = hashlib.sha256(b"test_bot_token").digest()
        check_string = "\n".join(
            f"{k}={v}" for k, v in sorted(data_dict.items())
        )
        valid_hash = hmac.new(
            secret, check_string.encode(), hashlib.sha256
        ).hexdigest()

        login_data = TelegramLoginData(
            **data_dict,
            hash=valid_hash,
        )

        assert self.service.verify_login_data(login_data) is True

    @patch("app.services.telegram_login.settings")
    def test_invalid_hash(self, mock_settings):
        mock_settings.telegram_bot_token = "test_bot_token"

        login_data = TelegramLoginData(
            id=12345,
            first_name="Test",
            auth_date=int(time.time()),
            hash="invalid_hash_value",
        )

        assert self.service.verify_login_data(login_data) is False

    @patch("app.services.telegram_login.settings")
    def test_expired_auth_date(self, mock_settings):
        mock_settings.telegram_bot_token = "test_bot_token"

        old_time = int(time.time()) - 100000
        data_dict = {"id": 12345, "first_name": "Test", "auth_date": old_time}

        secret = hashlib.sha256(b"test_bot_token").digest()
        check_string = "\n".join(
            f"{k}={v}" for k, v in sorted(data_dict.items())
        )
        valid_hash = hmac.new(
            secret, check_string.encode(), hashlib.sha256
        ).hexdigest()

        login_data = TelegramLoginData(**data_dict, hash=valid_hash)
        assert self.service.verify_login_data(login_data) is False


@pytest.mark.asyncio
async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_send_code_validation(client):
    resp = await client.post(
        "/api/v1/auth/telegram/send-code",
        json={"phone": "invalid"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_verify_code_invalid_session(client):
    resp = await client.post(
        "/api/v1/auth/telegram/verify-code",
        json={"session_id": "nonexistent", "code": "123456"},
    )
    assert resp.status_code == 400
