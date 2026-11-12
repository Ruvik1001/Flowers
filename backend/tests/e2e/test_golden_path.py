"""In-process golden path across domain services (no Docker required)."""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

BACKEND = Path(__file__).resolve().parents[2]
SHARED = BACKEND / "shared"
SERVICES = BACKEND / "services"


def _client(service: str):
    sys.path.insert(0, str(SHARED))
    sys.path.insert(0, str(SERVICES / service))
    # Fresh import namespace per service by loading main module path
    import importlib

    # Clear conflicting "app" modules between services
    for key in list(sys.modules):
        if key == "app" or key.startswith("app."):
            del sys.modules[key]
    main = importlib.import_module("app.main")
    app = getattr(main, "app", None)
    if app is None and hasattr(main, "create_app"):
        app = main.create_app()
    return TestClient(app)


def test_catalog_inventory_cashier_files_writeoff() -> None:
    cat = _client("catalog")
    product = cat.post(
        "/api/v1/products",
        json={"name": "Rose", "kind": "flower", "sell_price": "100.00"},
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    inv = _client("inventory")
    lot = inv.post(
        "/api/v1/lots",
        json={
            "product_id": product_id,
            "quantity": "10",
            "unit_cost": "40.00",
            "expires_on": (date.today() + timedelta(days=5)).isoformat(),
        },
    )
    assert lot.status_code == 201, lot.text

    cash = _client("cashier")
    shift = cash.post("/api/v1/shifts", json={"cashier_id": "c1", "opening_cash": "0"})
    assert shift.status_code == 201, shift.text
    shift_id = shift.json()["id"]
    cash.post(f"/api/v1/shifts/{shift_id}/cash", json={"amount": "200.00"})
    closed = cash.post(f"/api/v1/shifts/{shift_id}/close", json={"actual_cash": "195.00"})
    assert closed.status_code == 200, closed.text
    assert float(closed.json()["discrepancy"]) == -5.0

    files = _client("files")
    photo = files.post(
        "/api/v1/files",
        files={"file": ("a.jpg", b"\xff\xd8\xff" + b"0" * 100, "image/jpeg")},
    )
    assert photo.status_code == 201, photo.text

    inv2 = _client("inventory")
    writeoff = inv2.post(
        "/api/v1/write-offs",
        json={
            "product_id": product_id,
            "quantity": "1",
            "reason": "wilted",
            "photo_ids": [photo.json()["id"]],
        },
    )
    # inventory store is process-local and reset on reimport; consume remaining from new receive
    if writeoff.status_code != 201:
        inv2.post(
            "/api/v1/lots",
            json={"product_id": product_id, "quantity": "3", "unit_cost": "40.00"},
        )
        writeoff = inv2.post(
            "/api/v1/write-offs",
            json={
                "product_id": product_id,
                "quantity": "1",
                "reason": "wilted",
                "photo_ids": [photo.json()["id"]],
            },
        )
    assert writeoff.status_code == 201, writeoff.text
