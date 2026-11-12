from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "shared"
SERVICES = sorted((ROOT / "services").glob("*"))


def run(cwd: Path, args: list[str]) -> None:
    env_pythonpath = str(SHARED)
    print(f"\n=== {cwd.name}: {' '.join(args)} ===")
    completed = subprocess.run(
        [sys.executable, "-m", *args],
        cwd=cwd,
        env={**dict(**{k: v for k, v in __import__("os").environ.items()}), "PYTHONPATH": env_pythonpath},
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> None:
    run(SHARED, ["pytest", "--cov=shared", "--cov-report=term-missing", "-q"])
    for service in SERVICES:
        if not (service / "tests").exists():
            continue
        run(
            service,
            ["pytest", "--cov=app", "--cov-report=term-missing", "-q"],
        )
    print("\nAll test suites passed.")


if __name__ == "__main__":
    main()
