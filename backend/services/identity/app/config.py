from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    service_name: str = "identity"
    database_url: str = "sqlite+pysqlite:///:memory:"
    jwt_secret: str = "change-me"
    access_token_minutes: int = 30
    refresh_token_days: int = 14
    bootstrap_admin_email: str = "admin@flowers.local"
    bootstrap_admin_password: str = "admin12345"
    otlp_endpoint: str | None = None


settings = Settings()
