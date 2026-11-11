from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SALES_", extra="ignore")
    service_name: str = "sales"
    inventory_url: str = "http://inventory:8000"


settings = Settings()
