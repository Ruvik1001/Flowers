from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    service_name: str = "procurement"
    inventory_url: str = Field(default="http://inventory:8000", validation_alias="INVENTORY_URL")
    redis_url: str = Field(default="", validation_alias="REDIS_URL")
    database_url: str = Field(default="sqlite+pysqlite:///:memory:", validation_alias="DATABASE_URL")


settings = Settings()
