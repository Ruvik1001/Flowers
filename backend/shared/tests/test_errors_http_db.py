from shared.db import SCHEMAS, make_engine, make_session_factory
from shared.db.base import ensure_schemas
from shared.errors import AppError, error_payload
from shared.http import InternalClient
from shared.utils.ids import new_id
from shared.utils.time import now_utc, to_moscow


def test_error_payload() -> None:
    payload = error_payload("x", "y", {"a": 1})
    assert payload == {"code": "x", "message": "y", "details": {"a": 1}}
    err = AppError("c", "m", status_code=409, details={"k": "v"})
    assert err.to_payload().to_dict()["code"] == "c"


def test_ids_and_time() -> None:
    assert len(new_id()) == 36
    assert to_moscow(now_utc()).tzinfo is not None


def test_db_sqlite_engine() -> None:
    engine = make_engine("sqlite+pysqlite:///:memory:")
    ensure_schemas(engine)  # no-op for sqlite
    factory = make_session_factory(engine)
    with factory() as session:
        assert session is not None
    assert "inventory" in SCHEMAS


def test_internal_client_success(httpx_mock_server=None) -> None:
    # Lightweight unit: instantiate client; real calls covered in service tests.
    client = InternalClient("http://example.invalid", timeout=0.1)
    assert client._client.base_url.host == "example.invalid"
    client.close()
