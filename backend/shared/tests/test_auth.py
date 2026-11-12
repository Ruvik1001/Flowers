import pytest

from shared.auth import (
    AuthUser,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    require_permissions,
    verify_password,
)
from shared.errors import AppError


def test_password_hash_and_verify() -> None:
    hashed = hash_password("secret123")
    assert verify_password("secret123", hashed)
    assert not verify_password("wrong", hashed)


def test_jwt_roundtrip() -> None:
    secret = "test-secret"
    access = create_access_token("user-1", secret=secret, claims={"roles": ["admin"]})
    payload = decode_token(access, secret=secret, expected_type="access")
    assert payload["sub"] == "user-1"
    assert payload["roles"] == ["admin"]
    refresh = create_refresh_token("user-1", secret=secret)
    assert decode_token(refresh, secret=secret, expected_type="refresh")["sub"] == "user-1"


def test_require_permissions() -> None:
    user = AuthUser(id="1", email="a@b.c", permissions=["sales.read"])
    require_permissions(user, "sales.read")
    with pytest.raises(AppError) as exc:
        require_permissions(user, "sales.write")
    assert exc.value.status_code == 403


def test_admin_bypasses_permissions() -> None:
    admin = AuthUser(id="1", email="a@b.c", is_admin=True)
    require_permissions(admin, "anything")
