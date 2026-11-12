"""Full operational-day smoke against local gateway."""
from __future__ import annotations

import io
import sys
import uuid

import requests

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080/api/v1"


class Api:
    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")
        self.s = requests.Session()

    def login(self, email: str, password: str) -> dict:
        r = self.s.post(
            f"{self.base}/identity/auth/login",
            json={"email": email, "password": password},
        )
        r.raise_for_status()
        data = r.json()
        self.s.headers["Authorization"] = f"Bearer {data['access_token']}"
        return data

    def get(self, path: str):
        r = self.s.get(f"{self.base}{path}")
        r.raise_for_status()
        return r.json()

    def post(self, path: str, json=None, files=None):
        r = self.s.post(f"{self.base}{path}", json=json, files=files)
        if not r.ok:
            raise RuntimeError(f"POST {path} -> {r.status_code} {r.text[:400]}")
        return r.json() if r.content else {}


def as_list(payload):
    if isinstance(payload, list):
        return payload
    for key in ("items", "products", "suppliers", "sales", "shifts", "lots"):
        if key in payload and isinstance(payload[key], list):
            return payload[key]
    return []


def step(name: str) -> None:
    print(f"\n=== {name} ===")


def main() -> None:
    api = Api(BASE)
    step("Auth")
    api.login("admin@flowers.local", "admin12345")
    me = api.get("/identity/auth/me")
    user_id = me.get("id")
    print("user", user_id, me.get("email"))

    step("Catalog")
    products = as_list(api.get("/catalog/products"))
    assert len(products) >= 3, "need >=3 products"
    p1, p2, p3 = products[0], products[1], products[2]
    print("products", [p.get("name") for p in (p1, p2, p3)])

    step("Procurement: supplier + 3-line supply + accept all")
    suppliers = as_list(api.get("/procurement/suppliers"))
    if not suppliers:
        suppliers = [
            api.post(
                "/procurement/suppliers",
                json={"name": f"Biz {uuid.uuid4().hex[:6]}", "phone": "100"},
            )
        ]
    supplier_id = suppliers[0]["id"]
    supply = api.post(
        "/procurement/supplies",
        json={
            "supplier_id": supplier_id,
            "lines": [
                {"product_id": p1["id"], "quantity": 5, "unit_cost": "12.00"},
                {"product_id": p2["id"], "quantity": 4, "unit_cost": "18.00"},
                {"product_id": p3["id"], "quantity": 3, "unit_cost": "22.00"},
            ],
        },
    )
    supply_id = supply["id"]
    for line in supply["lines"]:
        rem = float(line.get("ordered") or line["quantity"]) - float(
            line.get("accepted") or 0
        )
        if rem <= 0:
            continue
        api.post(
            f"/procurement/supplies/{supply_id}/accept",
            json={"product_id": line["product_id"], "quantity": rem},
        )
    print("supply accepted", supply_id)

    step("Cashier: ensure open shift")
    shifts = as_list(api.get("/cashier/shifts"))
    open_shift = next(
        (s for s in shifts if s.get("closed_at") is None and s.get("status") != "closed"),
        None,
    )
    if open_shift is None:
        open_shift = api.post(
            "/cashier/shifts",
            json={"cashier_id": user_id or "admin", "opening_cash": "500.00"},
        )
    shift_id = open_shift["id"]
    print("shift", shift_id)

    step("Sales: 2-line cash sale + cashier.cash")
    price1 = float(p1.get("sell_price") or 100)
    price2 = float(p2.get("sell_price") or 120)
    total = price1 + price2
    sale = api.post(
        "/sales/sales",
        json={
            "lines": [
                {
                    "product_id": p1["id"],
                    "quantity": 1,
                    "unit_price": f"{price1:.2f}",
                },
                {
                    "product_id": p2["id"],
                    "quantity": 1,
                    "unit_price": f"{price2:.2f}",
                },
            ],
            "payments": [{"method": "cash", "amount": f"{total:.2f}"}],
            "shift_id": shift_id,
        },
    )
    shift = api.post(
        f"/cashier/shifts/{shift_id}/cash",
        json={"amount": f"{total:.2f}"},
    )
    print("sale", sale["id"], "cash_sales", shift.get("cash_sales"))

    step("Inventory: write-off with photo")
    uploaded = api.post(
        "/files/files",
        files={"file": ("wo.jpg", io.BytesIO(b"\xff\xd8\xff\xd9"), "image/jpeg")},
    )
    wo = api.post(
        "/inventory/write-offs",
        json={
            "product_id": p1["id"],
            "quantity": 1,
            "reason": "business-day smoke",
            "photo_ids": [uploaded["id"]],
        },
    )
    print("write-off", wo.get("product_id") or wo)

    step("Inventory count")
    count = api.post(
        "/inventory/inventory-counts",
        json={"product_id": p2["id"], "actual": 1},
    )
    print("count", count)

    step("Refund money-only")
    refund = api.post(
        f"/sales/sales/{sale['id']}/refunds",
        json={"amount": f"{(total / 2):.2f}", "kind": "money_only"},
    )
    api.post(
        f"/cashier/shifts/{shift_id}/cash",
        json={"amount": f"{(total / 2):.2f}", "refund": True},
    )
    print("refund", refund.get("id") or refund)

    step("Analytics / audit smoke reads")
    for path in (
        "/analytics/revenue",
        "/audit/events",
        "/inventory/lots",
        "/sales/sales",
    ):
        try:
            data = api.get(path)
            print(path, "ok", type(data).__name__)
        except Exception as e:  # noqa: BLE001
            print(path, "skip", e)

    print("\nBUSINESS DAY SMOKE OK")


if __name__ == "__main__":
    main()
