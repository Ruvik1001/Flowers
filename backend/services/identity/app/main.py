from __future__ import annotations

from fastapi import Depends, FastAPI, Header
from pydantic import BaseModel, Field

from shared.auth import AuthUser, decode_token
from shared.errors import AppError
from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.persistence.outbox_bus import build_outbox_bus, outbox_lifespan

from app.application.auth_service import AuthService
from app.config import settings
from app.infrastructure.store import store

# Request path publishes into the transactional outbox; the lifespan worker relays to Redis.
bus = build_outbox_bus(settings.service_name, settings.redis_url or None, database_url=settings.database_url)
auth_service = AuthService(bus=bus)


class LoginRequest(BaseModel):
    email: str
    password: str


class CreateUserRequest(BaseModel):
    email: str
    password: str = Field(min_length=8)
    role_ids: list[str]
    object_scopes: dict[str, list[str]] = Field(default_factory=dict)


class CreateRoleRequest(BaseModel):
    name: str
    permissions: list[str]


class RefreshRequest(BaseModel):
    refresh_token: str


def create_app() -> FastAPI:
    app = FastAPI(title="Flowers Identity", lifespan=outbox_lifespan(bus))
    install_exception_handlers(app)
    install_readiness(app, settings.service_name, check_db=True, check_redis=True)
    install_request_context_middleware(app, settings.service_name)
    auth_service.ensure_bootstrap()

    def current_user(authorization: str | None = Header(default=None)) -> AuthUser:
        if not authorization or not authorization.lower().startswith("bearer "):
            raise AppError("missing_token", "Bearer access token required", status_code=401)
        token = authorization.split(" ", 1)[1]
        payload = decode_token(token, secret=settings.jwt_secret, expected_type="access")
        return AuthUser(
            id=payload["sub"],
            email=payload.get("email", ""),
            roles=list(payload.get("roles") or []),
            permissions=list(payload.get("permissions") or []),
            is_admin=bool(payload.get("is_admin")),
        )

    @app.get("/health")
    @app.get("/api/v1/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": settings.service_name}

    @app.post("/api/v1/auth/login")
    def login(body: LoginRequest) -> dict:
        tokens = auth_service.login(body.email, body.password)
        return {
            "access_token": tokens.access_token,
            "refresh_token": tokens.refresh_token,
            "token_type": tokens.token_type,
        }

    @app.post("/api/v1/auth/refresh")
    def refresh(body: RefreshRequest) -> dict:
        tokens = auth_service.refresh(body.refresh_token)
        return {
            "access_token": tokens.access_token,
            "refresh_token": tokens.refresh_token,
            "token_type": tokens.token_type,
        }

    @app.get("/api/v1/auth/me")
    def me(user: AuthUser = Depends(current_user)) -> dict:
        return auth_service.me(user.id)

    @app.post("/api/v1/users")
    def create_user(body: CreateUserRequest, user: AuthUser = Depends(current_user)) -> dict:
        created = auth_service.create_user(
            user,
            email=body.email,
            password=body.password,
            role_ids=body.role_ids,
            object_scopes=body.object_scopes,
        )
        return {"id": created.id, "email": created.email, "role_ids": created.role_ids}

    @app.get("/api/v1/roles")
    def list_roles(user: AuthUser = Depends(current_user)) -> dict:
        if not user.is_admin and "identity.roles.read" not in user.permissions:
            # admins and any authenticated staff can list seeded roles for assignment UX
            pass
        return {
            "items": [
                {"id": r.id, "name": r.name, "permissions": r.permissions}
                for r in store.roles.values()
            ]
        }

    @app.post("/api/v1/roles")
    def create_role(body: CreateRoleRequest, user: AuthUser = Depends(current_user)) -> dict:
        if not user.is_admin:
            raise AppError("forbidden", "Admin required", status_code=403)
        role = store.create_role(body.name, body.permissions)
        return {"id": role.id, "name": role.name, "permissions": role.permissions}

    @app.get("/api/v1/authz/object/{resource_type}/{resource_id}")
    def check_object(
        resource_type: str,
        resource_id: str,
        user: AuthUser = Depends(current_user),
    ) -> dict:
        # evaluate against stored user scopes
        return auth_service.check_object(user.id, resource_type, resource_id)

    return app


app = create_app()
