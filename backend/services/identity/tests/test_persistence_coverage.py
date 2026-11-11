import importlib

import pytest

from shared.errors import AppError
from shared.persistence.models import RoleRow, UserRow
from shared.testing import install_fake_db

store_module = importlib.import_module("app.infrastructure.store")


def test_row_converters_default_missing_values():
    role = store_module._role_from_row(RoleRow(id="r", name="n", permissions=None))
    assert role.permissions == []
    user = store_module._user_from_row(
        UserRow(
            id="u",
            email="a@b.c",
            password_hash="h",
            is_admin=None,
            is_active=None,
            role_ids=None,
            object_scopes=None,
        )
    )
    assert (user.is_admin, user.is_active, user.role_ids, user.object_scopes) == (False, False, [], {})


def test_persisted_store_seeds_saves_and_reloads(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.IdentityStore()
    # empty database -> default roles are seeded and written through
    assert {r.name for r in db.rows(RoleRow)} == {"admin", "owner", "florist", "cashier", "analyst"}

    admin = store.bootstrap_admin("Admin@Example.com", "secret-pass")
    assert store.bootstrap_admin("admin@example.com", "other") is admin
    florist = next(r for r in store.roles.values() if r.name == "florist")
    user = store.create_user(
        email="Flo@Example.com",
        password="secret-pass",
        role_ids=[florist.id],
        object_scopes={"store": ["1"]},
    )
    custom = store.create_role("auditor", ["audit.read"])
    user.is_active = False
    store.users[user.id] = user  # re-save an existing user
    assert {u.email for u in db.rows(UserRow)} == {"admin@example.com", "flo@example.com"}
    saved = db.table(UserRow)[user.id]
    assert saved.role_ids == [florist.id]
    assert saved.object_scopes == {"store": ["1"]}
    assert db.table(RoleRow)[custom.id].permissions == ["audit.read"]

    reloaded = store_module.IdentityStore()
    assert reloaded.get_by_email("FLO@example.com").id == user.id
    assert reloaded.get_user(user.id).is_active is False
    assert reloaded.get_user(admin.id).is_admin is True
    assert reloaded.roles[custom.id].name == "auditor"
    assert set(reloaded.permissions_for(reloaded.get_user(user.id))) == set(florist.permissions)
    assert reloaded.permissions_for(reloaded.get_user(admin.id)) == ["*"]

    del store.users[user.id]
    del store.roles[custom.id]
    store._delete_user("unknown")
    store._delete_role("unknown")
    assert user.id not in db.table(UserRow)
    assert custom.id not in db.table(RoleRow)

    store.users.clear()
    assert db.rows(UserRow) == []
    store.roles.clear()
    assert db.rows(RoleRow) == []


def test_lookup_and_validation_errors():
    store = store_module.IdentityStore()
    role = next(iter(store.roles.values()))
    user = store.create_user(email="a@b.c", password="secret-pass", role_ids=[role.id])
    with pytest.raises(AppError) as exc:
        store.create_user(email="A@B.C", password="x", role_ids=[role.id])
    assert exc.value.status_code == 409
    with pytest.raises(AppError) as exc:
        store.create_user(email="z@b.c", password="x", role_ids=["missing"])
    assert exc.value.status_code == 404
    with pytest.raises(AppError) as exc:
        store.get_user("missing")
    assert exc.value.status_code == 404
    with pytest.raises(AppError) as exc:
        store.get_by_email("nobody@b.c")
    assert exc.value.status_code == 401
    with pytest.raises(AppError) as exc:
        store.create_role(role.name, [])
    assert exc.value.status_code == 409
    assert store.get_user(user.id).email == "a@b.c"
