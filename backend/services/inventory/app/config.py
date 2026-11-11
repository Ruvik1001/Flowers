from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="INVENTORY_", extra="ignore")
    service_name: str = "inventory"


settings = Settings()
