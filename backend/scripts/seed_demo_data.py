#!/usr/bin/env python3
"""Populate Flowers local stack with demo data via the gateway API.

Usage:
  python scripts/seed_demo_data.py
  python scripts/seed_demo_data.py --base-url http://localhost:8080
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import date, timedelta
from typing import Any


DEFAULT_BASE = "http://localhost:8080"
ADMIN_EMAIL = "admin@flowers.local"
ADMIN_PASSWORD = "admin12345"


class Api:
    def __init__(self, base_url: str) -> None:
        self.base = base_url.rstrip("/") + "/api/v1"
        self.token: str | None = None

    def _request(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        auth: bool = True,
    ) -> Any:
        data = None if body is None else json.dumps(body).encode("utf-8")
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if auth and self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        req = urllib.request.Request(
            self.base + path,
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path} -> {exc.code}: {detail}") from exc

    def login(self, email: str, password: str) -> None:
        pair = self._request(
            "POST",
            "/identity/auth/login",
            body={"email": email, "password": password},
            auth=False,
        )
        self.token = pair["access_token"]
        print(f"OK login {email}")

    def get(self, path: str) -> Any:
        return self._request("GET", path)

    def post(self, path: str, body: dict[str, Any] | None = None) -> Any:
        return self._request("POST", path, body=body)


def role_map(api: Api) -> dict[str, str]:
    items = api.get("/identity/roles")["items"]
    return {r["name"]: r["id"] for r in items}


def ensure_user(api: Api, email: str, password: str, role_ids: list[str]) -> str:
    try:
        user = api.post(
            "/identity/users",
            {
                "email": email,
                "password": password,
                "role_ids": role_ids,
                "object_scopes": {"cash_shift": ["*"], "sale": ["*"]},
            },
        )
        print(f"OK user {email} ({user['id']})")
        return user["id"]
    except RuntimeError as exc:
        if "email_taken" in str(exc) or "409" in str(exc):
            print(f"SKIP user {email} (already exists)")
            return ""
        raise


def find_or_create_product(
    api: Api,
    existing: list[dict[str, Any]],
    *,
    name: str,
    kind: str,
    sell_price: str,
) -> dict[str, Any]:
    for p in existing:
        if p.get("name") == name and not p.get("archived"):
            print(f"SKIP product {name}")
            return p
    product = api.post(
        "/catalog/products",
        {"name": name, "kind": kind, "sell_price": sell_price},
    )
    print(f"OK product {name} ({product['id']})")
    existing.append(product)
    return product


def find_or_create_supplier(
    api: Api,
    existing: list[dict[str, Any]],
    *,
    name: str,
    phone: str,
) -> dict[str, Any]:
    for s in existing:
        if s.get("name") == name:
            print(f"SKIP supplier {name}")
            return s
    supplier = api.post(
        "/procurement/suppliers",
        {"name": name, "phone": phone},
    )
    print(f"OK supplier {name} ({supplier['id']})")
    existing.append(supplier)
    return supplier


def seed(base_url: str) -> None:
    api = Api(base_url)
    api.login(ADMIN_EMAIL, ADMIN_PASSWORD)

    roles = role_map(api)
    print(f"roles: {', '.join(sorted(roles))}")

    cashier_id = ensure_user(
        api,
        "cashier1@flowers.local",
        "cashier123",
        [roles["cashier"]] if "cashier" in roles else [],
    )
    ensure_user(
        api,
        "florist1@flowers.local",
        "florist123",
        [roles["florist"]] if "florist" in roles else [],
    )
    ensure_user(
        api,
        "analyst1@flowers.local",
        "analyst123",
        [roles["analyst"]] if "analyst" in roles else [],
    )

    products = list(api.get("/catalog/products?include_archived=false") or [])
    rose = find_or_create_product(
        api, products, name="Роза красная", kind="flower", sell_price="180.00"
    )
    tulip = find_or_create_product(
        api, products, name="Тюльпан", kind="flower", sell_price="90.00"
    )
    eucalyptus = find_or_create_product(
        api, products, name="Эвкалипт", kind="material", sell_price="40.00"
    )
    paper = find_or_create_product(
        api, products, name="Крафт-бумага", kind="material", sell_price="25.00"
    )
    spring = find_or_create_product(
        api, products, name="Букет Весна", kind="bouquet", sell_price="2500.00"
    )
    romance = find_or_create_product(
        api, products, name="Букет Романтика", kind="bouquet", sell_price="3200.00"
    )

    recipes = list(api.get("/catalog/recipes?include_archived=false") or [])
    spring_recipe = next((r for r in recipes if r.get("bouquet_id") == spring["id"]), None)
    if spring_recipe is None:
        spring_recipe = api.post(
            "/catalog/recipes",
            {
                "bouquet_id": spring["id"],
                "items": [
                    {"product_id": tulip["id"], "quantity": "7"},
                    {"product_id": eucalyptus["id"], "quantity": "3"},
                    {"product_id": paper["id"], "quantity": "1"},
                ],
            },
        )
        print(f"OK recipe Весна ({spring_recipe['id']})")
    else:
        print("SKIP recipe Весна")

    romance_recipe = next((r for r in recipes if r.get("bouquet_id") == romance["id"]), None)
    if romance_recipe is None:
        romance_recipe = api.post(
            "/catalog/recipes",
            {
                "bouquet_id": romance["id"],
                "items": [
                    {"product_id": rose["id"], "quantity": "11"},
                    {"product_id": eucalyptus["id"], "quantity": "4"},
                    {"product_id": paper["id"], "quantity": "1"},
                ],
            },
        )
        print(f"OK recipe Романтика ({romance_recipe['id']})")
    else:
        print("SKIP recipe Романтика")

    suppliers = list(api.get("/procurement/suppliers") or [])
    garden = find_or_create_supplier(
        api, suppliers, name="Garden LLC", phone="+7 900 111-22-33"
    )
    flora = find_or_create_supplier(
        api, suppliers, name="Флора Опт", phone="+7 900 444-55-66"
    )

    supplies = list(api.get("/procurement/supplies") or [])
    has_garden_supply = any(s.get("supplier_id") == garden["id"] for s in supplies)
    if not has_garden_supply:
        supply = api.post(
            "/procurement/supplies",
            {
                "supplier_id": garden["id"],
                "lines": [
                    {
                        "product_id": rose["id"],
                        "quantity": "50",
                        "unit_cost": "70.00",
                    },
                    {
                        "product_id": tulip["id"],
                        "quantity": "80",
                        "unit_cost": "35.00",
                    },
                    {
                        "product_id": eucalyptus["id"],
                        "quantity": "40",
                        "unit_cost": "15.00",
                    },
                ],
            },
        )
        print(f"OK supply Garden ({supply['id']})")
        for line in supply["lines"]:
            accepted = api.post(
                f"/procurement/supplies/{supply['id']}/accept",
                {
                    "product_id": line["product_id"],
                    "quantity": line["quantity"],
                },
            )
            print(f"  accepted {line['product_id'][:8]}… -> {accepted['id']}")
    else:
        print("SKIP Garden supply (exists)")

    has_flora_supply = any(s.get("supplier_id") == flora["id"] for s in supplies)
    if not has_flora_supply:
        supply = api.post(
            "/procurement/supplies",
            {
                "supplier_id": flora["id"],
                "lines": [
                    {
                        "product_id": paper["id"],
                        "quantity": "100",
                        "unit_cost": "8.00",
                    },
                    {
                        "product_id": rose["id"],
                        "quantity": "30",
                        "unit_cost": "75.00",
                    },
                ],
            },
        )
        print(f"OK supply Флора ({supply['id']})")
        # Partial accept for roses — leaves remainder for accept UI testing
        api.post(
            f"/procurement/supplies/{supply['id']}/accept",
            {"product_id": paper["id"], "quantity": "100"},
        )
        api.post(
            f"/procurement/supplies/{supply['id']}/accept",
            {"product_id": rose["id"], "quantity": "10"},
        )
        print("  accepted paper fully, roses partially (10/30)")
    else:
        print("SKIP Флора supply (exists)")

    # Extra lots with near expiry for inventory/expired screen
    expires_soon = (date.today() + timedelta(days=2)).isoformat()
    expires_later = (date.today() + timedelta(days=10)).isoformat()
    lots_before = len(api.get("/inventory/lots") or [])
    api.post(
        "/inventory/lots",
        {
            "product_id": tulip["id"],
            "quantity": "12",
            "unit_cost": "32.00",
            "expires_on": expires_soon,
        },
    )
    api.post(
        "/inventory/lots",
        {
            "product_id": rose["id"],
            "quantity": "8",
            "unit_cost": "68.00",
            "expires_on": expires_later,
        },
    )
    print(f"OK extra lots (was {lots_before}, +2)")

    # Assemble a couple of spring bouquets into stock
    try:
        assembly = api.post(
            "/assembly/assemblies",
            {
                "bouquet_product_id": spring["id"],
                "quantity": "2",
                "kind": "recipe",
                "recipe_id": spring_recipe["id"],
                "components": [
                    {"product_id": tulip["id"], "quantity": "7"},
                    {"product_id": eucalyptus["id"], "quantity": "3"},
                    {"product_id": paper["id"], "quantity": "1"},
                ],
            },
        )
        print(f"OK assembly Весна x2 ({assembly['id']})")
    except RuntimeError as exc:
        print(f"SKIP assembly: {exc}")

    # Open shift for cashier (or admin if cashier user already existed without id)
    shift_cashier = cashier_id or "admin-demo"
    shifts = list(api.get("/cashier/shifts") or [])
    open_shift = next(
        (
            s
            for s in shifts
            if s.get("cashier_id") == shift_cashier and s.get("closed_at") is None
        ),
        None,
    )
    if open_shift is None:
        shift = api.post(
            "/cashier/shifts",
            {"cashier_id": shift_cashier, "opening_cash": "5000.00"},
        )
        print(f"OK open shift {shift['id']} for {shift_cashier}")
    else:
        print(f"SKIP shift already open ({open_shift['id']})")

    # One demo sale (cash)
    try:
        sale = api.post(
            "/sales/sales",
            {
                "lines": [
                    {
                        "product_id": rose["id"],
                        "quantity": "3",
                        "unit_price": "180.00",
                    },
                    {
                        "product_id": spring["id"],
                        "quantity": "1",
                        "unit_price": "2500.00",
                    },
                ],
                "payments": [{"method": "cash", "amount": "3040.00"}],
            },
        )
        print(f"OK sale {sale['id']} total={sale['total']}")
        if open_shift is None:
            # record cash on the shift we just opened
            shifts = list(api.get("/cashier/shifts") or [])
            open_shift = next(
                (
                    s
                    for s in shifts
                    if s.get("cashier_id") == shift_cashier and s.get("closed_at") is None
                ),
                None,
            )
        if open_shift is not None:
            api.post(
                f"/cashier/shifts/{open_shift['id']}/cash",
                {"amount": "3040.00", "refund": False},
            )
            print(f"OK cash movement on shift {open_shift['id']}")
    except RuntimeError as exc:
        print(f"SKIP sale: {exc}")

    products_n = len(api.get("/catalog/products") or [])
    lots_n = len(api.get("/inventory/lots") or [])
    sales_n = len(api.get("/sales/sales") or [])
    print()
    print("=== Demo seed complete ===")
    print(f"products={products_n} lots={lots_n} sales={sales_n}")
    print("Accounts:")
    print(f"  admin    {ADMIN_EMAIL} / {ADMIN_PASSWORD}")
    print("  cashier  cashier1@flowers.local / cashier123")
    print("  florist  florist1@flowers.local / florist123")
    print("  analyst  analyst1@flowers.local / analyst123")


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed Flowers demo data via gateway")
    parser.add_argument("--base-url", default=DEFAULT_BASE)
    args = parser.parse_args()
    try:
        seed(args.base_url)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
