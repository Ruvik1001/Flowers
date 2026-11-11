import pytest

from shared.errors import AppError

from app.rbac import enforce_gateway_rbac, required_permissions


def test_health_and_ready_are_open() -> None:
    assert required_permissions("catalog", "GET", "health") == []
    assert required_permissions("sales", "GET", "ready") == []
    assert required_permissions("inventory", "GET", "api/ready") == []


def test_defaults_for_unknown_routes() -> None:
    assert required_permissions("unknown", "GET", "x") == []
    assert required_permissions("unknown", "HEAD", "x") == []
    assert required_permissions("unknown", "POST", "x") == ["__denied__"]


def test_enforce_allows_wildcard_admin_and_exact() -> None:
    enforce_gateway_rbac("catalog", "POST", "products", {"permissions": ["*"]})
    enforce_gateway_rbac("catalog", "POST", "products", {"is_admin": True, "permissions": []})
    enforce_gateway_rbac("catalog", "POST", "products", {"permissions": ["catalog.write"]})
    enforce_gateway_rbac("identity", "GET", "roles", {"permissions": []})


def test_enforce_rejects_missing_and_denied() -> None:
    with pytest.raises(AppError) as exc:
        enforce_gateway_rbac("catalog", "POST", "products", {"permissions": ["sales.read"]})
    assert exc.value.status_code == 403
    with pytest.raises(AppError) as denied:
        enforce_gateway_rbac("unknown", "DELETE", "x", {"permissions": ["*"]})
    assert denied.value.status_code == 403


def test_inventory_write_off_prefers_specific_rule() -> None:
    assert required_permissions("inventory", "POST", "write-offs") == ["inventory.write_off"]
    assert "inventory.write" in required_permissions("inventory", "POST", "lots")
