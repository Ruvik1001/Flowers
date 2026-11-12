from __future__ import annotations

from dataclasses import dataclass, field

from shared.errors import AppError


@dataclass(slots=True)
class AuthUser:
    id: str
    email: str
    roles: list[str] = field(default_factory=list)
    permissions: list[str] = field(default_factory=list)
    is_admin: bool = False

    def has_permission(self, permission: str) -> bool:
        if self.is_admin or "*" in self.permissions:
            return True
        return permission in self.permissions


def require_permissions(user: AuthUser, *permissions: str) -> None:
    missing = [p for p in permissions if not user.has_permission(p)]
    if missing:
        raise AppError(
            "forbidden",
            "Missing required permissions",
            status_code=403,
            details={"missing": missing},
        )
