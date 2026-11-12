from __future__ import annotations

"""Gateway-edge permission matrix. Internal S2S calls bypass the gateway."""

from shared.errors import AppError


def _has_any(claims: dict, required: list[str]) -> bool:
    if claims.get("is_admin"):
        return True
    perms = set(claims.get("permissions") or [])
    if "*" in perms:
        return True
    return any(p in perms for p in required)


# (service, METHOD, path_prefix) → any-of permissions. Longer prefixes match first.
_RULES: list[tuple[str, str, str, list[str]]] = [
    ("identity", "POST", "users", ["identity.users.write"]),
    ("identity", "GET", "users", ["identity.users.write"]),
    ("identity", "POST", "roles", ["identity.roles.write"]),
    ("identity", "GET", "roles", []),  # any authenticated (assignment UX)
    ("identity", "GET", "auth/me", []),  # any authenticated
    ("identity", "GET", "authz/", []),
    ("catalog", "GET", "", ["catalog.read"]),
    ("catalog", "POST", "", ["catalog.write"]),
    ("catalog", "PATCH", "", ["catalog.write"]),
    ("procurement", "GET", "", ["procurement.read", "catalog.read"]),
    ("procurement", "POST", "", ["procurement.write", "catalog.write"]),
    ("inventory", "GET", "", ["inventory.read"]),
    ("inventory", "POST", "write-offs", ["inventory.write_off"]),
    ("inventory", "POST", "", ["inventory.write", "inventory.write_off"]),
    ("assembly", "GET", "", ["assembly.read", "assembly.write"]),
    ("assembly", "POST", "", ["assembly.write"]),
    ("sales", "GET", "", ["sales.read"]),
    ("sales", "POST", "", ["sales.write"]),
    ("cashier", "GET", "", ["cashier.read"]),
    ("cashier", "POST", "", ["cashier.write"]),
    ("files", "GET", "", ["files.read", "inventory.write_off", "sales.write"]),
    ("files", "POST", "", ["files.write", "inventory.write_off", "sales.write"]),
    ("analytics", "GET", "", ["analytics.read"]),
    ("analytics", "POST", "internal/", ["analytics.read"]),
    ("audit", "GET", "", ["audit.read", "analytics.read"]),
    ("audit", "POST", "internal/", ["audit.read"]),
]


def required_permissions(service: str, method: str, path: str) -> list[str] | None:
    """Return required perms, empty list = any auth, None = no rule (deny writes, allow reads)."""
    method_u = method.upper()
    path = path.lstrip("/")
    if path in {"health", "ready"} or path.endswith("/health") or path.endswith("/ready"):
        return []
    matches: list[tuple[int, list[str]]] = []
    for svc, meth, prefix, perms in _RULES:
        if svc != service or meth != method_u:
            continue
        if path == prefix or path.startswith(prefix):
            matches.append((len(prefix), perms))
    if not matches:
        # Default: authenticated read OK; mutating needs explicit rule → deny
        if method_u in {"GET", "HEAD", "OPTIONS"}:
            return []
        return ["__denied__"]
    matches.sort(key=lambda x: x[0], reverse=True)
    return matches[0][1]


def enforce_gateway_rbac(service: str, method: str, path: str, claims: dict) -> None:
    needed = required_permissions(service, method, path) or []
    if needed == ["__denied__"]:
        raise AppError("forbidden", "No permission rule for this route", status_code=403)
    if not needed:
        return
    if not _has_any(claims, needed):
        raise AppError(
            "forbidden",
            "Missing required permissions",
            status_code=403,
            details={"required_any_of": needed},
        )
