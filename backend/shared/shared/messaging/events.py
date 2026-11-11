from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from typing import Any

from shared.utils.ids import new_id


class EventNames:
    SALE_COMPLETED = "SaleCompleted"
    STOCK_CHANGED = "StockChanged"
    SHIFT_CLOSED = "ShiftClosed"
    SUPPLY_ACCEPTED = "SupplyAccepted"
    USER_ROLE_CHANGED = "UserRoleChanged"
    WRITE_OFF_COMPLETED = "WriteOffCompleted"
    ASSEMBLY_COMPLETED = "AssemblyCompleted"


@dataclass(slots=True)
class DomainEvent:
    name: str
    payload: dict[str, Any]
    event_id: str = field(default_factory=new_id)
    occurred_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
    idempotency_key: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "DomainEvent":
        return cls(
            name=data["name"],
            payload=data.get("payload", {}),
            event_id=data.get("event_id", new_id()),
            occurred_at=data.get("occurred_at", datetime.now(UTC).isoformat()),
            idempotency_key=data.get("idempotency_key"),
        )
