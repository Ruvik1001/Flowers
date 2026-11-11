from __future__ import annotations

from collections import defaultdict
from datetime import UTC, datetime
from decimal import Decimal

from shared.messaging.events import DomainEvent, EventNames
from shared.persistence.models import AnalyticsSnapshotRow
from shared.persistence.runtime import db_session, persistence_enabled

SNAPSHOT_NAME = "projection"


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
        self._persist = persistence_enabled()
        if self._persist:
            self._load()

    # --- snapshot (de)serialization -------------------------------------------------

    def to_state(self) -> dict:
        def flat(rows: dict[str, Decimal]) -> dict[str, str]:
            return {key: str(value) for key, value in rows.items()}

        def nested(rows: dict[str, dict[str, Decimal]]) -> dict[str, dict[str, str]]:
            return {key: {k: str(v) for k, v in row.items()} for key, row in rows.items()}

        return {
            "seen": sorted(self._seen),
            "revenue_day": flat(self.revenue_day),
            "revenue_shift": flat(self.revenue_shift),
            "product_sales": nested(self.product_sales),
            "revenue": str(self.revenue),
            "cost": str(self.cost),
            "cash_gap_by_shift": flat(self.cash_gap_by_shift),
            "stock_movements": flat(self.stock_movements),
            "write_offs": nested(self.write_offs),
        }

    def load_state(self, state: dict) -> None:
        def flat(raw: dict | None) -> dict[str, Decimal]:
            return {key: Decimal(str(value)) for key, value in (raw or {}).items()}

        def nested(raw: dict | None) -> dict[str, dict[str, Decimal]]:
            return {
                key: {k: Decimal(str(v)) for k, v in row.items()} for key, row in (raw or {}).items()
            }

        self._seen = set(state.get("seen") or [])
        self.revenue_day.clear()
        self.revenue_day.update(flat(state.get("revenue_day")))
        self.revenue_shift.clear()
        self.revenue_shift.update(flat(state.get("revenue_shift")))
        self.product_sales.clear()
        self.product_sales.update(nested(state.get("product_sales")))
        self.revenue = Decimal(str(state.get("revenue", "0")))
        self.cost = Decimal(str(state.get("cost", "0")))
        self.cash_gap_by_shift = flat(state.get("cash_gap_by_shift"))
        self.stock_movements.clear()
        self.stock_movements.update(flat(state.get("stock_movements")))
        self.write_offs.clear()
        self.write_offs.update(nested(state.get("write_offs")))

    def _load(self) -> None:
        with db_session() as session:
            row = session.get(AnalyticsSnapshotRow, SNAPSHOT_NAME)
            state = dict(row.payload) if row is not None else None
        if state:
            self.load_state(state)

    def _save(self) -> None:
        state = self.to_state()
        with db_session() as session:
            row = session.get(AnalyticsSnapshotRow, SNAPSHOT_NAME) or AnalyticsSnapshotRow(
                name=SNAPSHOT_NAME
            )
            row.payload = state
            row.updated_at = datetime.now(UTC)
            session.merge(row)

    def consume(self, event: DomainEvent) -> None:
        if event.event_id in self._seen:
            return
        self._apply(event)
        if self._persist:
            self._save()

    def _apply(self, event: DomainEvent) -> None:
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
