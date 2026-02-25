"""
Telegram Login Widget verification.

Docs: https://core.telegram.org/widgets/login#checking-authorization

The hash is HMAC-SHA256 of the data-check-string with SHA256(bot_token) as key.
"""

import hashlib
import hmac
import time

from app.config import settings
from app.schemas.auth import TelegramLoginData


class TelegramLoginService:
    MAX_AUTH_AGE_SECONDS = 86400  # data must be < 24h old

    def verify_login_data(self, data: TelegramLoginData) -> bool:
        """
        Verify that the Telegram Login Widget data is authentic.

        Проверено по docs: https://core.telegram.org/widgets/login#checking-authorization
        """
        check_dict = data.model_dump(exclude={"hash"})
        check_dict = {k: v for k, v in check_dict.items() if v is not None}

        data_check_string = "\n".join(
            f"{k}={v}" for k, v in sorted(check_dict.items())
        )

        secret_key = hashlib.sha256(
            settings.telegram_bot_token.encode()
        ).digest()

        computed_hash = hmac.new(
            secret_key,
            data_check_string.encode(),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(computed_hash, data.hash):
            return False

        if time.time() - data.auth_date > self.MAX_AUTH_AGE_SECONDS:
            return False

        return True


telegram_login = TelegramLoginService()
