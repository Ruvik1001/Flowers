from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="CASHIER_", extra="ignore")
    service_name: str = "cashier"


settings = Settings()
