from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    app_name: str = "donskih-api"
    app_env: str = "production"
    debug: bool = False
    secret_key: str

    # Database
    postgres_user: str
    postgres_password: str
    postgres_db: str
    postgres_host: str = "postgres"
    postgres_port: int = 5432

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def database_url_sync(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    # Redis
    redis_url: str = "redis://redis:6379/0"

    # JWT
    jwt_secret_key: str
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 30

    # Telegram Gateway
    telegram_gateway_token: str = ""
    telegram_gateway_url: str = "https://gatewayapi.telegram.org"

    # Telegram Bot
    telegram_bot_token: str = ""

    # Bot MySQL (read-only, external)
    bot_mysql_host: str = "77.221.157.84"
    bot_mysql_port: int = 3306
    bot_mysql_user: str = "donskih_api"
    bot_mysql_password: str = "DnskApi_R3ad0nly!"
    bot_mysql_db: str = "donckix_bot_db"

    # Admin (content CRUD)
    admin_secret_key: str = ""
    hls_upload_dir: str = "/var/www/hls/uploads"
    hls_public_base_url: str = "https://donskih-cdn.ru/hls/uploads"
    upload_max_size_mb: int = 1024

    # Rate Limiting
    rate_limit_send_code_per_ip: str = "30/10min"
    rate_limit_send_code_per_phone: str = "5/10min"
    rate_limit_verify_code_max_attempts: int = 5
    verification_code_ttl_seconds: int = 300
    verification_cooldown_seconds: int = 30

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
