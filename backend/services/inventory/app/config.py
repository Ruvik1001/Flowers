from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="INVENTORY_", extra="ignore")
    service_name: str = "inventory"
    redis_url: str = Field(default="", validation_alias="REDIS_URL")
    database_url: str | None = Field(default=None, validation_alias="DATABASE_URL")


settings = Settings()
