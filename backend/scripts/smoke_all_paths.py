from __future__ import annotations

import json
import sys
import time
import uuid
from datetime import date, timedelta

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
RUN_ID = uuid.uuid4().hex[:8]


def pretty(title: str, response: httpx.Response, *, allow: set[int] | None = None) -> dict:
    print(f"\n== {title} [{response.status_code}] ==")
    try:
        data = response.json()
    except Exception:
        print(response.text)
        if allow and response.status_code in allow:
            return {}
        response.raise_for_status()
        return {}
    print(json.dumps(data, ensure_ascii=False, indent=2)[:1000])
    if allow and response.status_code in allow:
        return data if isinstance(data, dict) else {}
    response.raise_for_status()
    return data if isinstance(data, dict) else {}


def main() -> None:
    client = httpx.Client(base_url=BASE, timeout=30.0)
    for _ in range(60):
        try:
            if client.get("/api/v1/health").status_code == 200:
                break
        except Exception:
            pass
        time.sleep(2)
    else:
        raise SystemExit("gateway health timeout")

    pretty("health", client.get("/api/v1/health"))
    tokens = pretty(
        "login",
        client.post(
            "/api/v1/identity/auth/login",
            json={"email": "admin@flowers.local", "password": "admin12345"},
        ),
    )
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    pretty("me", client.get("/api/v1/identity/auth/me", headers=headers))
    roles = pretty("roles", client.get("/api/v1/identity/roles", headers=headers))
    cashier_role = next(r for r in roles["items"] if r["name"] == "cashier")
    pretty(
        "create_user",
        client.post(
            "/api/v1/identity/users",
            headers=headers,
            json={
                "email": f"cashier.smoke.{RUN_ID}@flowers.local",
                "password": "password1",
                "role_ids": [cashier_role["id"]],
                "object_scopes": {"cash_shift": ["*"]},
            },
        ),
    )
    product = pretty(
        "create_product",
        client.post(
            "/api/v1/catalog/products",
            headers=headers,
            json={"name": f"Rose Smoke {RUN_ID}", "kind": "flower", "sell_price": "150.00"},
        ),
    )
    product_id = product["id"]
    supplier = pretty(
        "create_supplier",
        client.post(
            "/api/v1/procurement/suppliers",
            headers=headers,
            json={"name": "Garden LLC"},
        ),
    )
    supply = pretty(
        "create_supply",
        client.post(
            "/api/v1/procurement/supplies",
            headers=headers,
            json={
                "supplier_id": supplier["id"],
                "lines": [{"product_id": product_id, "quantity": "20", "unit_cost": "50.00"}],
            },
        ),
    )
    pretty(
        "accept_supply",
        client.post(
            f"/api/v1/procurement/supplies/{supply['id']}/accept",
            headers=headers,
            json={"product_id": product_id, "quantity": "10"},
        ),
    )
    pretty(
        "receive_lot",
        client.post(
            "/api/v1/inventory/lots",
            headers=headers,
            json={
                "product_id": product_id,
                "quantity": "10",
                "unit_cost": "50.00",
                "expires_on": (date.today() + timedelta(days=7)).isoformat(),
            },
        ),
    )
    shift = pretty(
        "open_shift",
        client.post(
            "/api/v1/cashier/shifts",
            headers=headers,
            json={"cashier_id": "smoke-cashier", "opening_cash": "0"},
        ),
    )
    sale = pretty(
        "create_sale",
        client.post(
            "/api/v1/sales/sales",
            headers=headers,
            json={
                "lines": [{"product_id": product_id, "quantity": "2", "unit_price": "150.00"}],
                "payments": [{"method": "cash", "amount": "300.00"}],
            },
        ),
    )
    client.post(
        f"/api/v1/cashier/shifts/{shift['id']}/cash",
        headers=headers,
        json={"amount": "300.00"},
    )
    pretty(
        "close_shift",
        client.post(
            f"/api/v1/cashier/shifts/{shift['id']}/close",
            headers=headers,
            json={"actual_cash": "295.00"},
        ),
    )
    photo = pretty(
        "upload_photo",
        client.post(
            "/api/v1/files/files",
            headers=headers,
            files={"file": ("wilt.jpg", b"\xff\xd8\xff" + b"0" * 128, "image/jpeg")},
        ),
    )
    pretty(
        "write_off",
        client.post(
            "/api/v1/inventory/write-offs",
            headers=headers,
            json={
                "product_id": product_id,
                "quantity": "1",
                "reason": "wilted",
                "photo_ids": [photo["id"]],
            },
        ),
    )
    pretty(
        "refund",
        client.post(
            f"/api/v1/sales/sales/{sale['id']}/refunds",
            headers=headers,
            json={"amount": "150.00", "kind": "money_only"},
        ),
    )
    # drain analytics/audit
    client.post("/api/v1/analytics/internal/drain", headers=headers)
    client.post("/api/v1/audit/internal/drain", headers=headers)
    pretty(
        "analytics_revenue",
        client.get("/api/v1/analytics/reports/revenue-by-day", headers=headers),
    )
    pretty("audit_list", client.get("/api/v1/audit/audit", headers=headers))
    print("\nSMOKE OK")


if __name__ == "__main__":
    main()
