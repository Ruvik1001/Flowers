from __future__ import annotations

from collections import defaultdict
from decimal import Decimal

from shared.messaging.events import DomainEvent, EventNames


def _money(value: object) -> Decimal:
    return Decimal(str(value or 0))


class AnalyticsProjection:
    def __init__(self) -> None:
        self._seen: set[str] = set()
        self.revenue_day: dict[str, Decimal] = defaultdict(Decimal)
        self.revenue_shift: dict[str, Decimal] = defaultdict(Decimal)
        self.product_sales: dict[str, dict[str, Decimal]] = defaultdict(
            lambda: {"quantity": Decimal(0), "revenue": Decimal(0)}
        )
        self.revenue = Decimal(0)
        self.cost = Decimal(0)
        self.cash_gap_by_shift: dict[str, Decimal] = {}
        self.stock_movements: dict[str, Decimal] = defaultdict(Decimal)
        self.write_offs: dict[str, dict[str, Decimal]] = defaultdict(
            lambda: {"quantity": Decimal(0), "value": Decimal(0)}
        )

    def consume(self, event: DomainEvent) -> None:
        if event.event_id in self._seen:
            return
        self._seen.add(event.event_id)
        payload = event.payload
        if event.name == EventNames.SALE_COMPLETED:
            total = _money(payload.get("total", payload.get("revenue")))
            cost = _money(payload.get("cost"))
            day = str(payload.get("day") or event.occurred_at[:10])
            shift = str(payload.get("shift_id") or "unassigned")
            self.revenue_day[day] += total
            self.revenue_shift[shift] += total
            self.revenue += total
            self.cost += cost
            for item in payload.get("items", []):
                product_id = str(item.get("product_id", "unknown"))
                self.product_sales[product_id]["quantity"] += _money(item.get("quantity"))
                self.product_sales[product_id]["revenue"] += _money(
                    item.get("total", item.get("revenue"))
                )
        elif event.name == EventNames.STOCK_CHANGED:
            product_id = str(payload.get("product_id", "unknown"))
            self.stock_movements[product_id] += abs(_money(payload.get("delta")))
        elif event.name == EventNames.SHIFT_CLOSED:
            shift = str(payload.get("shift_id", "unknown"))
            self.cash_gap_by_shift[shift] = _money(payload.get("cash_actual")) - _money(
                payload.get("cash_expected")
            )
        elif event.name == EventNames.WRITE_OFF_COMPLETED:
            product_id = str(payload.get("product_id", "unknown"))
            self.write_offs[product_id]["quantity"] += _money(payload.get("quantity"))
            self.write_offs[product_id]["value"] += _money(payload.get("value"))

    @staticmethod
    def _serialize(rows: dict[str, Decimal]) -> list[dict[str, str]]:
        return [{"key": key, "value": str(value)} for key, value in sorted(rows.items())]

    def report(self, name: str) -> dict:
        if name == "revenue-by-day":
            return {"items": self._serialize(self.revenue_day)}
        if name == "revenue-by-shift":
            return {"items": self._serialize(self.revenue_shift)}
        if name == "sales-by-product":
            return {
                "items": [
                    {"product_id": key, **{metric: str(value) for metric, value in row.items()}}
                    for key, row in sorted(self.product_sales.items())
                ]
            }
        if name == "stock-turnover":
            return {
                "items": [
                    {
                        "product_id": key,
                        "movement": str(value),
                        "turnover": None,
                        "status": "inventory-average-required",
                    }
                    for key, value in sorted(self.stock_movements.items())
                ]
            }
        if name == "margin":
            return {
                "revenue": str(self.revenue),
                "cost": str(self.cost),
                "margin": str(self.revenue - self.cost),
            }
        if name == "cash-gaps":
            return {"items": self._serialize(self.cash_gap_by_shift)}
        if name == "write-offs":
            return {
                "items": [
                    {"product_id": key, **{metric: str(value) for metric, value in row.items()}}
                    for key, row in sorted(self.write_offs.items())
                ]
            }
        raise KeyError(name)
