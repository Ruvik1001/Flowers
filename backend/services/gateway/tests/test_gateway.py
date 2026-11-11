import httpx
import pytest
from fastapi.testclient import TestClient

from shared.auth.jwt import create_access_token, create_refresh_token
from shared.errors import AppError

from app.config import Settings
from app.main import SlidingWindowLimiter, create_app


SECRET = "test-secret"


def token(**claims) -> str:
    payload = {"permissions": ["*"], "is_admin": True}
    payload.update(claims)
    return create_access_token("user-1", secret=SECRET, claims=payload)


def test_health_and_proxy_forwards_headers_and_body():
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/products"
        assert request.url.params["active"] == "1"
        assert request.headers["Authorization"].startswith("Bearer ")
        assert request.headers["X-Request-Id"] == "request-1"
        return httpx.Response(201, json={"ok": True}, headers={"X-Upstream": "yes"})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cfg = Settings(jwt_secret=SECRET, service_urls={"catalog": "http://catalog"})
    with TestClient(create_app(cfg, client)) as api:
        assert api.get("/api/v1/health").json()["status"] == "ok"
        response = api.post(
            "/api/v1/catalog/products?active=1",
            headers={"Authorization": f"Bearer {token()}", "X-Request-Id": "request-1"},
            json={"name": "Rose"},
        )
    assert response.status_code == 201
    assert response.json() == {"ok": True}
    assert response.headers["X-Upstream"] == "yes"


@pytest.mark.parametrize(
    ("path", "authorization", "status"),
    [
        ("/api/v1/missing/x", f"Bearer {token()}", 404),
        ("/api/v1/catalog/x", "", 401),
        (
            "/api/v1/catalog/x",
            f"Bearer {create_refresh_token('u', secret=SECRET)}",
            401,
        ),
    ],
)
def test_proxy_rejects_invalid_requests(path, authorization, status):
    cfg = Settings(jwt_secret=SECRET, service_urls={"catalog": "http://catalog"})
    with TestClient(create_app(cfg, httpx.AsyncClient())) as api:
        response = api.get(path, headers={"Authorization": authorization})
    assert response.status_code == status


def test_upstream_failure_becomes_bad_gateway():
    async def handler(_: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("offline")

    cfg = Settings(jwt_secret=SECRET, service_urls={"catalog": "http://catalog"})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    with TestClient(create_app(cfg, client)) as api:
        response = api.get(
            "/api/v1/catalog/x", headers={"Authorization": f"Bearer {token()}"}
        )
    assert response.status_code == 502


def test_limiter_expires_windows_and_can_be_disabled():
    disabled = SlidingWindowLimiter(0)
    disabled.check("x", 0)
    limiter = SlidingWindowLimiter(1)
    limiter.check("x", 0)
    with pytest.raises(AppError):
        limiter.check("x", 1)
    limiter.check("x", 61)


def test_public_login_does_not_require_jwt():
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/auth/login"
        return httpx.Response(200, json={"access_token": "a", "refresh_token": "r"})

    cfg = Settings(jwt_secret=SECRET, service_urls={"identity": "http://identity"})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    with TestClient(create_app(cfg, client)) as api:
        response = api.post(
            "/api/v1/identity/auth/login",
            json={"email": "admin@flowers.local", "password": "admin12345"},
        )
    assert response.status_code == 200
    assert response.json()["access_token"] == "a"


def test_gateway_rbac_rejects_missing_permission():
    cfg = Settings(jwt_secret=SECRET, service_urls={"catalog": "http://catalog"})
    weak = token(permissions=["sales.read"], is_admin=False)
    with TestClient(create_app(cfg, httpx.AsyncClient())) as api:
        response = api.post(
            "/api/v1/catalog/products",
            headers={"Authorization": f"Bearer {weak}"},
            json={"name": "Rose"},
        )
    assert response.status_code == 403
    assert response.json()["code"] == "forbidden"
