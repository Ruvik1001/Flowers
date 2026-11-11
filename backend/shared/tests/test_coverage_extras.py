from __future__ import annotations

from datetime import datetime

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from shared.db.base import ensure_schemas, make_engine, make_session_factory, session_scope
from shared.errors import AppError
from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.http.client import InternalClient
from shared.messaging.events import DomainEvent
from shared.messaging.streams import RedisStreamBus
from shared.telemetry.setup import bind_request_context, get_logger, init_telemetry
from shared.utils.money import Money
from shared.utils.time import to_moscow


def test_money_eq_and_repr() -> None:
    assert Money("1.00") != object()
    assert "Money" in repr(Money("1.00"))


def test_to_moscow_naive() -> None:
    value = to_moscow(datetime(2024, 1, 1, 12, 0, 0))
    assert value.tzinfo is not None


def test_session_scope_commit_and_rollback() -> None:
    engine = make_engine("sqlite+pysqlite:///:memory:")
    factory = make_session_factory(engine)

    gen = session_scope(factory)
    session = next(gen)
    assert session is not None
    gen.close()

    gen2 = session_scope(factory)
    next(gen2)
    with pytest.raises(RuntimeError):
        gen2.throw(RuntimeError("boom"))


def test_install_readiness_ready_when_checks_skipped() -> None:
    app = FastAPI()
    install_readiness(app, "gateway")

    client = TestClient(app)
    response = client.get("/api/v1/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready", "service": "gateway"}


def test_fastapi_ext_handlers_and_middleware() -> None:
    app = FastAPI()
    install_exception_handlers(app)
    install_request_context_middleware(app, "test-svc")

    @app.get("/ok")
    def ok():
        return {"ok": True}

    @app.get("/app-error")
    def app_error():
        raise AppError("x", "y", status_code=418)

    @app.get("/boom")
    def boom():
        raise RuntimeError("nope")

    client = TestClient(app, raise_server_exceptions=False)
    assert client.get("/ok").headers["X-Request-Id"]
    assert client.get("/app-error").status_code == 418
    assert client.get("/boom").status_code == 500


def test_internal_client_error_paths(monkeypatch: pytest.MonkeyPatch) -> None:
    client = InternalClient("http://example.com", timeout=0.1)

    class Resp:
        status_code = 500
        text = "fail"

        def json(self):
            raise ValueError("bad json")

    class RespJson:
        status_code = 400
        text = "x"

        def json(self):
            return {"code": "bad"}

    monkeypatch.setattr(client._client, "request", lambda *a, **k: Resp())
    with pytest.raises(AppError) as exc:
        client.get("/x")
    assert exc.value.status_code == 502

    monkeypatch.setattr(client._client, "request", lambda *a, **k: RespJson())
    with pytest.raises(AppError):
        client.post("/y", json={"a": 1})
    client.close()


def test_redis_stream_bus_with_fake_redis() -> None:
    class FakeRedis:
        def __init__(self):
            self.messages = []
            self.groups = set()
            self.acked = []

        def xadd(self, stream, fields, maxlen=None, approximate=None):
            self.messages.append((stream, fields))
            return b"1-0"

        def xgroup_create(self, stream, group, id="0", mkstream=True):
            key = (stream, group)
            if key in self.groups:
                raise Exception("BUSYGROUP")
            self.groups.add(key)

        def xreadgroup(self, group, consumer, streams, count=100, block=1):
            if not self.messages:
                return []
            stream = next(iter(streams))
            _stream, fields = self.messages.pop(0)
            return [[stream, [["1-0", fields]]]]

        def xack(self, stream, group, message_id):
            self.acked.append((stream, group, message_id))

    fake = FakeRedis()
    bus = RedisStreamBus(fake)
    received = []
    bus.subscribe("s", "g", received.append)
    bus.subscribe("s", "g", lambda e: None)  # group exists path
    event = DomainEvent(name="X", payload={"a": 1})
    bus.publish("s", event)
    assert bus.drain("s", "g") == 1
    assert received[0].payload["a"] == 1
    assert bus.drain("s", "g") == 0


def test_telemetry_init_and_bind() -> None:
    init_telemetry("svc-test", otlp_endpoint="http://127.0.0.1:9/v1/traces")
    bind_request_context("rid-1", foo="bar")
    log = get_logger("t")
    log.info("hello")


def test_jwt_claim_and_invalid(monkeypatch: pytest.MonkeyPatch) -> None:
    from shared.auth.jwt import create_access_token, decode_token

    token = create_access_token("u", secret="x" * 32, claims=None)
    decode_token(token, secret="x" * 32, expected_type="access")
    with pytest.raises(AppError):
        decode_token("not-a-token", secret="x" * 32)
