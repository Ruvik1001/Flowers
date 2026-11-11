from __future__ import annotations

from shared.auth import (
    AuthUser,
    TokenPair,
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from shared.errors import AppError
from shared.messaging import DomainEvent, EventNames, StreamBus

from app.config import settings
from app.domain.entities import User
from app.domain.rbac import assert_object_access
from app.infrastructure.store import store


class AuthService:
    def __init__(self, bus: StreamBus | None = None) -> None:
        self._bus = bus

    def ensure_bootstrap(self) -> User:
        return store.bootstrap_admin(settings.bootstrap_admin_email, settings.bootstrap_admin_password)

    def login(self, email: str, password: str) -> TokenPair:
        user = store.get_by_email(email)
        if not user.is_active or not verify_password(password, user.password_hash):
            raise AppError("invalid_credentials", "Invalid email or password", status_code=401)
        return self._tokens_for(user)

    def refresh(self, refresh_token: str) -> TokenPair:
        payload = decode_token(refresh_token, secret=settings.jwt_secret, expected_type="refresh")
        user = store.get_user(payload["sub"])
        return self._tokens_for(user)

    def _tokens_for(self, user: User) -> TokenPair:
        perms = store.permissions_for(user)
        claims = {
            "email": user.email,
            "roles": [store.roles[r].name for r in user.role_ids if r in store.roles],
            "permissions": perms,
            "is_admin": user.is_admin,
        }
        return TokenPair(
            access_token=create_access_token(
                user.id,
                secret=settings.jwt_secret,
                expires_minutes=settings.access_token_minutes,
                claims=claims,
            ),
            refresh_token=create_refresh_token(
                user.id,
                secret=settings.jwt_secret,
                expires_days=settings.refresh_token_days,
            ),
        )

    def create_user(
        self,
        actor: AuthUser,
        *,
        email: str,
        password: str,
        role_ids: list[str],
        object_scopes: dict[str, list[str]] | None = None,
    ) -> User:
        if not actor.is_admin and "identity.users.write" not in actor.permissions:
            raise AppError("forbidden", "Admin or identity.users.write required", status_code=403)
        from shared.persistence.runtime import unit_of_work

        with unit_of_work():
            user = store.create_user(
                email=email,
                password=password,
                role_ids=role_ids,
                object_scopes=object_scopes,
            )
            if self._bus:
                import os

                self._bus.publish(
                    os.getenv("EVENT_STREAM", "domain-events"),
                    DomainEvent(
                        name=EventNames.USER_ROLE_CHANGED,
                        payload={"user_id": user.id, "role_ids": role_ids},
                        idempotency_key=f"user-created:{user.id}",
                    ),
                )
        return user

    def me(self, user_id: str) -> dict:
        user = store.get_user(user_id)
        return {
            "id": user.id,
            "email": user.email,
            "is_admin": user.is_admin,
            "roles": [store.roles[r].name for r in user.role_ids if r in store.roles],
            "permissions": store.permissions_for(user),
            "object_scopes": user.object_scopes,
        }

    def check_object(self, user_id: str, resource_type: str, resource_id: str) -> dict:
        user = store.get_user(user_id)
        assert_object_access(user, resource_type, resource_id)
        return {"allowed": True}
