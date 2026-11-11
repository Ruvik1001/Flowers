from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="CASHIER_", extra="ignore")
    service_name: str = "cashier"
    redis_url: str = Field(default="", validation_alias="REDIS_URL")
    database_url: str = Field(default="sqlite+pysqlite:///:memory:", validation_alias="DATABASE_URL")


settings = Settings()
