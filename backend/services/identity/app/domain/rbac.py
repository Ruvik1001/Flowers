from __future__ import annotations

from shared.errors import AppError

from app.domain.entities import User


def assert_object_access(user: User, resource_type: str, resource_id: str) -> None:
    if user.is_admin:
        return
    allowed = user.object_scopes.get(resource_type, [])
    if "*" in allowed or resource_id in allowed:
        return
    raise AppError(
        "object_forbidden",
        f"No access to {resource_type}:{resource_id}",
        status_code=403,
        details={"resource_type": resource_type, "resource_id": resource_id},
    )


def merge_permissions(role_permissions: list[list[str]]) -> list[str]:
    merged: set[str] = set()
    for perms in role_permissions:
        merged.update(perms)
    return sorted(merged)
