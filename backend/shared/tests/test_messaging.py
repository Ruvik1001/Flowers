from shared.messaging import DomainEvent, EventNames, IdempotencyStore, InMemoryStreamBus


def test_inmemory_stream_bus_publish_and_drain() -> None:
    bus = InMemoryStreamBus()
    received: list[DomainEvent] = []
    bus.subscribe("events.sales", "analytics", received.append)
    event = DomainEvent(name=EventNames.SALE_COMPLETED, payload={"sale_id": "s1"})
    bus.publish("events.sales", event)
    assert bus.drain("events.sales", "analytics") == 1
    assert received[0].payload["sale_id"] == "s1"
    assert bus.drain("events.sales", "analytics") == 0


def test_idempotency_store() -> None:
    store = IdempotencyStore()
    assert store.mark("k1") is True
    assert store.mark("k1") is False
    assert store.seen("k1") is True
    store.clear()
    assert store.seen("k1") is False


def test_domain_event_roundtrip() -> None:
    event = DomainEvent(name=EventNames.STOCK_CHANGED, payload={"sku": "rose"}, idempotency_key="i1")
    restored = DomainEvent.from_dict(event.to_dict())
    assert restored.name == EventNames.STOCK_CHANGED
    assert restored.payload["sku"] == "rose"
    assert restored.idempotency_key == "i1"
