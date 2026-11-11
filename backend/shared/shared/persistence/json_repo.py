from __future__ import annotations

import json
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session


class JsonTableRepo:
    """Minimal Postgres JSON document repository used by domain services."""

    def __init__(self, session: Session, schema: str, table: str, pk: str = "id") -> None:
        self.session = session
        self.schema = schema
        self.table = table
        self.pk = pk

    @property
    def fqtn(self) -> str:
        return f'"{self.schema}"."{self.table}"'

    def upsert_payload(self, item_id: str, payload: dict[str, Any]) -> None:
        self.session.execute(
            text(
                f"""
                INSERT INTO {self.fqtn} ({self.pk}, payload)
                VALUES (:id, CAST(:payload AS jsonb))
                ON CONFLICT ({self.pk}) DO UPDATE SET payload = EXCLUDED.payload
                """
            ),
            {"id": item_id, "payload": json.dumps(payload)},
        )

    def get_payload(self, item_id: str) -> dict[str, Any] | None:
        row = self.session.execute(
            text(f"SELECT payload FROM {self.fqtn} WHERE {self.pk} = :id"),
            {"id": item_id},
        ).first()
        if not row:
            return None
        payload = row[0]
        return payload if isinstance(payload, dict) else json.loads(payload)

    def list_payloads(self) -> list[dict[str, Any]]:
        rows = self.session.execute(text(f"SELECT payload FROM {self.fqtn}")).all()
        result: list[dict[str, Any]] = []
        for (payload,) in rows:
            result.append(payload if isinstance(payload, dict) else json.loads(payload))
        return result

    def delete(self, item_id: str) -> None:
        self.session.execute(
            text(f"DELETE FROM {self.fqtn} WHERE {self.pk} = :id"),
            {"id": item_id},
        )
