"""In-memory stand-in for ``db_session`` so persistence code runs without Postgres.

The fake understands the handful of patterns used by the PersistMap-backed stores:
``get``/``merge``/``add``/``delete`` on ORM rows, ``scalars(select(Model))`` and
``execute(delete(Model))``.
"""

from __future__ import annotations

import sys
from collections.abc import Generator
from contextlib import contextmanager
from types import ModuleType
from typing import Any

from sqlalchemy.exc import IntegrityError
from sqlalchemy.sql.dml import Delete


class _Rows:
    def __init__(self, rows: list[Any]) -> None:
        self._rows = rows

    def all(self) -> list[Any]:
        return list(self._rows)


def _pk(obj: Any) -> Any:
    return getattr(obj, "id", None) or getattr(obj, "name", None)


class FakeDB:
    """Holds rows per ORM model and records session activity."""

    def __init__(self) -> None:
        self.tables: dict[type, dict[Any, Any]] = {}
        self.commits = 0
        self.fail_with: Exception | None = None

    def table(self, model: type) -> dict[Any, Any]:
        return self.tables.setdefault(model, {})

    def rows(self, model: type) -> list[Any]:
        return list(self.table(model).values())

    def seed(self, *objs: Any) -> None:
        for obj in objs:
            self.table(type(obj))[_pk(obj)] = obj

    @contextmanager
    def session(self, *_args: Any, **_kwargs: Any) -> Generator[FakeSession, None, None]:
        if self.fail_with is not None:
            raise self.fail_with
        yield FakeSession(self)
        self.commits += 1


class FakeSession:
    def __init__(self, db: FakeDB) -> None:
        self.db = db

    def get(self, model: type, key: Any) -> Any:
        return self.db.table(model).get(key)

    def merge(self, obj: Any) -> Any:
        self.db.table(type(obj))[_pk(obj)] = obj
        return obj

    def add(self, obj: Any) -> None:
        table = self.db.table(type(obj))
        key = _pk(obj)
        if key in table:
            raise IntegrityError("INSERT", {}, Exception("duplicate key"))
        table[key] = obj

    def delete(self, obj: Any) -> None:
        self.db.table(type(obj)).pop(_pk(obj), None)

    def execute(self, stmt: Any) -> None:
        if isinstance(stmt, Delete):
            self.db.table(stmt.entity_description["entity"]).clear()
            return None
        raise NotImplementedError(f"unsupported statement: {stmt!r}")

    def scalars(self, stmt: Any) -> _Rows:
        model = stmt.column_descriptions[0]["entity"]
        return _Rows(self.db.rows(model))


def install_fake_db(monkeypatch: Any, module: str | ModuleType, db: FakeDB | None = None) -> FakeDB:
    """Force persistence on for ``module`` and route its ``db_session`` to a FakeDB."""
    db = db or FakeDB()
    target = sys.modules[module] if isinstance(module, str) else module
    monkeypatch.setattr(target, "persistence_enabled", lambda *a, **k: True)
    monkeypatch.setattr(target, "db_session", db.session)
    return db
