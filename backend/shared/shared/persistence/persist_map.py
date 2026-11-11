from __future__ import annotations

from collections.abc import Callable, Iterable, Iterator, MutableMapping
from typing import TypeVar

K = TypeVar("K")
V = TypeVar("V")


class PersistMap(MutableMapping[K, V]):
    """In-memory map that mirrors mutations to durable storage hooks."""

    def __init__(
        self,
        *,
        on_set: Callable[[K, V], None] | None = None,
        on_del: Callable[[K], None] | None = None,
        on_clear: Callable[[], None] | None = None,
        initial: Iterable[tuple[K, V]] | None = None,
    ) -> None:
        self._data: dict[K, V] = {}
        self._on_set = on_set
        self._on_del = on_del
        self._on_clear = on_clear
        self._muted = False
        if initial:
            with self.mute():
                for key, value in initial:
                    self._data[key] = value

    def mute(self):
        class _Mute:
            def __enter__(_self) -> PersistMap:
                self._muted = True
                return self

            def __exit__(_self, *args: object) -> None:
                self._muted = False

        return _Mute()

    def __getitem__(self, key: K) -> V:
        return self._data[key]

    def __setitem__(self, key: K, value: V) -> None:
        self._data[key] = value
        if not self._muted and self._on_set is not None:
            self._on_set(key, value)

    def __delitem__(self, key: K) -> None:
        del self._data[key]
        if not self._muted and self._on_del is not None:
            self._on_del(key)

    def __iter__(self) -> Iterator[K]:
        return iter(self._data)

    def __len__(self) -> int:
        return len(self._data)

    def clear(self) -> None:
        self._data.clear()
        if not self._muted and self._on_clear is not None:
            self._on_clear()

    def replace_all(self, items: Iterable[tuple[K, V]]) -> None:
        with self.mute():
            self._data.clear()
            for key, value in items:
                self._data[key] = value
