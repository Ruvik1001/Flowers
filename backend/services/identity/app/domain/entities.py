from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(slots=True)
class Permission:
    code: str
    description: str = ""


@dataclass(slots=True)
class Role:
    id: str
    name: str
    permissions: list[str] = field(default_factory=list)


@dataclass(slots=True)
class User:
    id: str
    email: str
    password_hash: str
    is_admin: bool = False
    is_active: bool = True
    role_ids: list[str] = field(default_factory=list)
    object_scopes: dict[str, list[str]] = field(default_factory=dict)
