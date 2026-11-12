import types

import pytest
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError

from shared.persistence.models import AnalyticsSnapshotRow, RoleRow
from shared.testing import FakeDB, install_fake_db


def test_session_get_merge_delete_and_clear():
    db = FakeDB()
    db.seed(RoleRow(id="r1", name="a", permissions=[]))
    with db.session() as session:
        assert session.get(RoleRow, "r1").name == "a"
        assert session.get(RoleRow, "zzz") is None
        session.merge(RoleRow(id="r2", name="b", permissions=[]))
        assert {r.id for r in session.scalars(select(RoleRow)).all()} == {"r1", "r2"}
        session.delete(session.get(RoleRow, "r1"))
    assert db.commits == 1
    with db.session() as session:
        assert session.execute(delete(RoleRow)) is None
    assert db.rows(RoleRow) == []


def test_name_keyed_rows_and_unsupported_statement():
    db = FakeDB()
    with db.session() as session:
        session.merge(AnalyticsSnapshotRow(name="projection", payload={}))
        assert session.get(AnalyticsSnapshotRow, "projection") is not None
        with pytest.raises(NotImplementedError):
            session.execute(update(RoleRow).values(name="x"))


def test_add_duplicate_raises_integrity_error():
    db = FakeDB()
    with db.session() as session:
        session.add(RoleRow(id="r1", name="a", permissions=[]))
        with pytest.raises(IntegrityError):
            session.add(RoleRow(id="r1", name="a", permissions=[]))


def test_fail_with_and_install(monkeypatch):
    module = types.ModuleType("fake_module")
    module.persistence_enabled = lambda: False
    module.db_session = None
    db = install_fake_db(monkeypatch, module)
    assert module.persistence_enabled() is True
    db.fail_with = RuntimeError("boom")
    with pytest.raises(RuntimeError):
        with module.db_session():
            pass

    import sys

    sys.modules["fake_module_by_name"] = module
    try:
        again = install_fake_db(monkeypatch, "fake_module_by_name", FakeDB())
        assert again is not db
    finally:
        del sys.modules["fake_module_by_name"]
