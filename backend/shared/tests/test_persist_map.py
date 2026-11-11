from shared.persistence import PersistMap


def _tracked() -> tuple[PersistMap[str, int], list[tuple]]:
    calls: list[tuple] = []
    store: PersistMap[str, int] = PersistMap(
        on_set=lambda k, v: calls.append(("set", k, v)),
        on_del=lambda k: calls.append(("del", k)),
        on_clear=lambda: calls.append(("clear",)),
    )
    return store, calls


def test_write_through_hooks() -> None:
    store, calls = _tracked()
    store["a"] = 1
    store["b"] = 2
    del store["a"]
    store.clear()
    assert calls == [("set", "a", 1), ("set", "b", 2), ("del", "a"), ("clear",)]
    assert len(store) == 0


def test_replace_all_does_not_trigger_hooks() -> None:
    store, calls = _tracked()
    store["x"] = 0
    calls.clear()
    store.replace_all([("a", 1), ("b", 2)])
    assert calls == []
    assert dict(store) == {"a": 1, "b": 2}


def test_initial_and_mute_are_silent() -> None:
    calls: list[tuple] = []
    store: PersistMap[str, int] = PersistMap(
        on_set=lambda k, v: calls.append((k, v)), initial=[("a", 1)]
    )
    assert store["a"] == 1
    with store.mute():
        store["b"] = 2
    assert calls == []
    store["c"] = 3
    assert calls == [("c", 3)]


def test_behaves_like_plain_dict_without_hooks() -> None:
    store: PersistMap[str, int] = PersistMap()
    store["a"] = 1
    assert "a" in store and list(store.values()) == [1]
    store.clear()
    assert not store
