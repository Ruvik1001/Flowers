from __future__ import annotations

"""Create durable entities, restart app containers, assert data still present."""

import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
RUN_ID = uuid.uuid4().hex[:8]
BACKEND = Path(__file__).resolve().parents[1]
COMPOSE = [
    "docker",
    "compose",
    "-f",
    "docker-compose.yml",
    "-f",
    "docker-compose.local.yml",
    "--env-file",
    os.getenv("COMPOSE_ENV_FILE", ".env.local"),
]
APP_SERVICES = [
    "gateway",
    "identity",
    "catalog",
    "inventory",
    "procurement",
    "assembly",
    "sales",
    "cashier",
    "audit",
    "analytics",
    "files",
]


def pretty(title: str, response: httpx.Response) -> dict | list:
    print(f"\n== {title} [{response.status_code}] ==")
    data = response.json()
    print(json.dumps(data, ensure_ascii=False, indent=2)[:800])
    response.raise_for_status()
    return data


def wait_gateway(client: httpx.Client, attempts: int = 90) -> None:
    for _ in range(attempts):
        try:
            if client.get("/api/v1/health").status_code != 200:
                raise RuntimeError("gateway not ready")
            # Identity must be up for login; health alone is not enough after restart.
            login = client.post(
                "/api/v1/identity/auth/login",
                json={"email": "admin@flowers.local", "password": "admin12345"},
            )
            if login.status_code == 200 and login.json().get("access_token"):
                return
        except Exception:
            pass
        time.sleep(2)
    raise SystemExit("gateway/identity readiness timeout after restart")


def compose(*args: str) -> None:
    cmd = [*COMPOSE, *args]
    print("\n$", " ".join(cmd))
    subprocess.run(cmd, cwd=BACKEND, check=True)


def main() -> None:
    client = httpx.Client(base_url=BASE, timeout=30.0)
    wait_gateway(client)

    tokens = pretty(
        "login",
        client.post(
            "/api/v1/identity/auth/login",
            json={"email": "admin@flowers.local", "password": "admin12345"},
        ),
    )
    assert isinstance(tokens, dict)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    product = pretty(
        "create_product",
        client.post(
            "/api/v1/catalog/products",
            headers=headers,
            json={"name": f"Persist Rose {RUN_ID}", "kind": "flower", "sell_price": "120.00"},
        ),
    )
    assert isinstance(product, dict)
    product_id = product["id"]

    supplier = pretty(
        "create_supplier",
        client.post(
            "/api/v1/procurement/suppliers",
            headers=headers,
            json={"name": f"Persist Supplier {RUN_ID}", "phone": "+1000"},
        ),
    )
    assert isinstance(supplier, dict)

    lot = pretty(
        "create_lot",
        client.post(
            "/api/v1/inventory/lots",
            headers=headers,
            json={"product_id": product_id, "quantity": "10", "unit_cost": "40.00"},
        ),
    )
    assert isinstance(lot, dict)
    lot_id = lot["id"]

    shift = pretty(
        "open_shift",
        client.post(
            "/api/v1/cashier/shifts",
            headers=headers,
            json={"cashier_id": f"persist-cashier-{RUN_ID}", "opening_cash": "1000.00"},
        ),
    )
    assert isinstance(shift, dict)
    shift_id = shift["id"]

    sale = pretty(
        "create_sale",
        client.post(
            "/api/v1/sales/sales",
            headers=headers,
            json={
                "lines": [{"product_id": product_id, "quantity": "1", "unit_price": "120.00"}],
                "payments": [{"method": "cash", "amount": "120.00"}],
                "shift_id": shift_id,
            },
        ),
    )
    assert isinstance(sale, dict)
    sale_id = sale["id"]

    compose("restart", *APP_SERVICES)
    wait_gateway(client)

    tokens = pretty(
        "login_after_restart",
        client.post(
            "/api/v1/identity/auth/login",
            json={"email": "admin@flowers.local", "password": "admin12345"},
        ),
    )
    assert isinstance(tokens, dict)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    products = pretty("products_after", client.get("/api/v1/catalog/products", headers=headers))
    product_items = products if isinstance(products, list) else products.get("items", [])
    assert any(item["id"] == product_id for item in product_items), products

    lot_items = pretty("lots_after", client.get("/api/v1/inventory/lots", headers=headers))
    assert isinstance(lot_items, list)
    assert any(item["id"] == lot_id for item in lot_items), lot_items
    matched = next(item for item in lot_items if item["id"] == lot_id)
    assert float(matched["quantity"]) == 9.0, matched

    suppliers = pretty("suppliers_after", client.get("/api/v1/procurement/suppliers", headers=headers))
    supplier_items = suppliers if isinstance(suppliers, list) else suppliers.get("items", [])
    assert any(item["id"] == supplier["id"] for item in supplier_items), suppliers

    shift_items = pretty("shifts_after", client.get("/api/v1/cashier/shifts", headers=headers))
    assert isinstance(shift_items, list)
    assert any(item["id"] == shift_id for item in shift_items), shift_items

    sale_items = pretty("sales_after", client.get("/api/v1/sales/sales", headers=headers))
    assert isinstance(sale_items, list)
    assert any(item["id"] == sale_id for item in sale_items), sale_items

    time.sleep(2)
    client.post("/api/v1/analytics/internal/drain", headers=headers)
    report = pretty(
        "analytics_after",
        client.get("/api/v1/analytics/reports/revenue-by-day", headers=headers),
    )
    assert isinstance(report, dict) and "items" in report, report

    print("\nPERSIST RESTART SMOKE OK")


if __name__ == "__main__":
    main()
