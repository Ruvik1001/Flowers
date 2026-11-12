from __future__ import annotations

import importlib
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import pytest

from shared.messaging import InMemoryStreamBus
from shared.messaging.streams import RedisStreamBus
from shared.persistence import bus as bus_module
from shared.persistence.json_repo import JsonTableRepo
from shared.persistence.session import get_engine, get_session_factory, is_postgres

# `shared.persistence.migrate` the function shadows the submodule attribute.
migrate_module = importlib.import_module("shared.persistence.migrate")

PG_URL = "postgresql+psycopg://u:p@localhost:5432/db"


class _FakeConn:
    def __init__(self) -> None:
        self.statements: list[str] = []

    def execute(self, statement: Any, params: Any = None) -> None:
        self.statements.append(str(statement))


class _FakeEngine:
    dialect = type("D", (), {"name": "postgresql"})()

    def __init__(self) -> None:
        self.conn = _FakeConn()

    @contextmanager
    def begin(self):
        yield self.conn


@pytest.fixture()
def fake_engine(monkeypatch: pytest.MonkeyPatch) -> _FakeEngine:
    engine = _FakeEngine()
    monkeypatch.setattr(migrate_module, "get_engine", lambda url=None: engine)
    return engine


def test_sqlite_migrate_is_noop() -> None:
    migrate_module.migrate("sqlite+pysqlite:///:memory:")


def test_unknown_mode_rejected() -> None:
    with pytest.raises(ValueError):
        migrate_module.migrate(PG_URL, mode="nope")


def test_sql_mode_applies_init_sql(fake_engine: _FakeEngine) -> None:
    migrate_module.migrate(PG_URL, mode="sql")
    joined = "\n".join(fake_engine.conn.statements)
    assert "messaging.outbox" in joined
    assert "sales.refunds" in joined
    assert "CREATE SCHEMA IF NOT EXISTS" in joined


def test_auto_prefers_alembic(monkeypatch: pytest.MonkeyPatch, fake_engine: _FakeEngine) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        migrate_module, "run_alembic_upgrade", lambda url=None, revision="head": calls.append("a") or True
    )
    migrate_module.migrate(PG_URL, mode="auto")
    assert calls == ["a"]
    assert fake_engine.conn.statements == []


def test_auto_falls_back_to_init_sql(monkeypatch: pytest.MonkeyPatch, fake_engine: _FakeEngine) -> None:
    monkeypatch.setattr(migrate_module, "run_alembic_upgrade", lambda url=None, revision="head": False)
    migrate_module.migrate(PG_URL, mode="auto")
    assert fake_engine.conn.statements


def test_alembic_mode_requires_alembic(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(migrate_module, "run_alembic_upgrade", lambda url=None, revision="head": False)
    with pytest.raises(RuntimeError):
        migrate_module.migrate(PG_URL, mode="alembic")


def test_run_alembic_unavailable_cases(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("ALEMBIC_INI", str(tmp_path / "missing.ini"))
    assert migrate_module.run_alembic_upgrade(PG_URL) is False
    monkeypatch.setenv("ALEMBIC_INI", str(Path(migrate_module.__file__).parents[3] / "db" / "alembic.ini"))
    monkeypatch.delenv("DATABASE_URL", raising=False)
    assert migrate_module.run_alembic_upgrade(None) is False


def test_paths_resolve_to_repo_db_dir(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DB_INIT_SQL", raising=False)
    monkeypatch.delenv("ALEMBIC_INI", raising=False)
    assert migrate_module._init_sql_path().name == "init.sql"
    ini = migrate_module._alembic_ini_path()
    assert ini is not None and ini.name == "alembic.ini"
    monkeypatch.setattr(migrate_module, "_first_existing", lambda *_a: None)
    with pytest.raises(FileNotFoundError):
        migrate_module._init_sql_path()


def test_session_helpers() -> None:
    url = "sqlite+pysqlite:///:memory:"
    assert get_engine(url) is get_engine(url)
    assert get_session_factory(url) is not None
    assert is_postgres(PG_URL) and not is_postgres(url)


def test_build_stream_bus(monkeypatch: pytest.MonkeyPatch) -> None:
    assert isinstance(bus_module.build_stream_bus(""), InMemoryStreamBus)

    class _Client:
        def ping(self) -> None:
            pass

    monkeypatch.setattr(bus_module.redis.Redis, "from_url", lambda *a, **k: _Client())
    assert isinstance(bus_module.build_stream_bus("redis://x:6379/0"), RedisStreamBus)


class _Result:
    def __init__(self, rows: list[tuple[Any, ...]]) -> None:
        self._rows = rows

    def first(self) -> tuple[Any, ...] | None:
        return self._rows[0] if self._rows else None

    def all(self) -> list[tuple[Any, ...]]:
        return self._rows


class _FakeSession:
    def __init__(self, rows: list[tuple[Any, ...]]) -> None:
        self.rows = rows
        self.sql: list[str] = []

    def execute(self, stmt: Any, params: Any = None) -> _Result:
        self.sql.append(str(stmt))
        return _Result(self.rows)


def test_json_table_repo() -> None:
    session = _FakeSession([('{"a": 1}',), ({"b": 2},)])
    repo = JsonTableRepo(session, "sales", "sales")  # type: ignore[arg-type]
    assert repo.fqtn == '"sales"."sales"'
    repo.upsert_payload("1", {"a": 1})
    repo.delete("1")
    assert repo.get_payload("1") == {"a": 1}
    assert repo.list_payloads() == [{"a": 1}, {"b": 2}]
    assert JsonTableRepo(_FakeSession([]), "s", "t").get_payload("x") is None  # type: ignore[arg-type]
