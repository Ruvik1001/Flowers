from fastapi.testclient import TestClient

from app.infrastructure.store import store
from app.main import create_app


def _client() -> TestClient:
    return TestClient(create_app())


def test_health_and_login_me_flow() -> None:
    client = _client()
    assert client.get("/api/v1/health").json()["status"] == "ok"
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@flowers.local", "password": "admin12345"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["is_admin"] is True


def test_create_user_and_role_and_object_scope() -> None:
    client = _client()
    admin = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@flowers.local", "password": "admin12345"},
    ).json()
    headers = {"Authorization": f"Bearer {admin['access_token']}"}
    roles = client.get("/api/v1/roles", headers=headers).json()["items"]
    cashier = next(r for r in roles if r["name"] == "cashier")
    created_role = client.post(
        "/api/v1/roles",
        headers=headers,
        json={"name": "custom-shift", "permissions": ["cashier.read"]},
    )
    assert created_role.status_code == 200
    user = client.post(
        "/api/v1/users",
        headers=headers,
        json={
            "email": "cashier1@flowers.local",
            "password": "password1",
            "role_ids": [cashier["id"]],
            "object_scopes": {"cash_shift": ["shift-1"]},
        },
    )
    assert user.status_code == 200
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "cashier1@flowers.local", "password": "password1"},
    )
    assert login.status_code == 200
    cash_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    ok = client.get("/api/v1/authz/object/cash_shift/shift-1", headers=cash_headers)
    assert ok.status_code == 200
    denied = client.get("/api/v1/authz/object/cash_shift/shift-2", headers=cash_headers)
    assert denied.status_code == 403


def test_refresh_and_invalid_login() -> None:
    client = _client()
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@flowers.local", "password": "admin12345"},
    ).json()
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": login["refresh_token"]})
    assert refreshed.status_code == 200
    bad = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@flowers.local", "password": "wrong-password"},
    )
    assert bad.status_code == 401


def test_rbac_merge_and_duplicate_email() -> None:
    from app.domain.rbac import merge_permissions

    assert merge_permissions([["a"], ["a", "b"]]) == ["a", "b"]
    client = _client()
    admin = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@flowers.local", "password": "admin12345"},
    ).json()
    headers = {"Authorization": f"Bearer {admin['access_token']}"}
    role_id = next(iter(store.roles))
    first = client.post(
        "/api/v1/users",
        headers=headers,
        json={"email": "dup@flowers.local", "password": "password1", "role_ids": [role_id]},
    )
    assert first.status_code == 200
    second = client.post(
        "/api/v1/users",
        headers=headers,
        json={"email": "dup@flowers.local", "password": "password1", "role_ids": [role_id]},
    )
    assert second.status_code == 409
