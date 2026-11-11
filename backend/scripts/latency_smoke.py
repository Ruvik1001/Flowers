from __future__ import annotations

import argparse
import statistics
import time

import httpx


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, max(0, int(round((pct / 100) * (len(ordered) - 1)))))
    return ordered[idx]


def main() -> None:
    parser = argparse.ArgumentParser(description="Gateway interactive latency smoke")
    parser.add_argument("--base-url", default="http://localhost:8080")
    parser.add_argument("--iterations", type=int, default=50)
    args = parser.parse_args()

    times: list[float] = []
    with httpx.Client(base_url=args.base_url, timeout=5.0) as client:
        # warm-up
        for _ in range(5):
            client.get("/api/v1/health")
        for _ in range(args.iterations):
            started = time.perf_counter()
            response = client.get("/api/v1/health")
            elapsed = time.perf_counter() - started
            response.raise_for_status()
            times.append(elapsed)

    p95 = percentile(times, 95)
    p99 = percentile(times, 99)
    print(f"samples={len(times)} p95={p95:.4f}s p99={p99:.4f}s mean={statistics.mean(times):.4f}s")
    if p95 >= 0.5 or p99 >= 1.5:
        raise SystemExit(f"SLO failed: p95={p95:.4f}s p99={p99:.4f}s")
    print("SLO ok")


if __name__ == "__main__":
    main()
