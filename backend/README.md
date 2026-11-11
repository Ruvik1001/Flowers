# Flowers Backend

Microservice backend for flower shop management. Public edge: **gateway** on `/api/v1`.

Read [docs/architecture.md](docs/architecture.md) (RU: [docs/architecture_RU.md](docs/architecture_RU.md)) before any feature work.

## Layout

- `shared/` — reusable libs (auth, messaging, telemetry, db, http, errors)
- `services/*` — independently deployable FastAPI services
- `docs/api/` — FE-facing API docs (`xx_<commit>_desc.md`) after commits
- `postman/` — Postman collection
- Compose overlays: `local` / `dev` / `prod`

## Quick start (local)

```bash
cp .env.local.example .env.local
docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file .env.local up --build
curl http://localhost:8080/api/v1/health
```

Default admin (identity bootstrap):

- email: `admin@flowers.local`
- password: `admin12345`

Login via gateway:

```bash
curl -X POST http://localhost:8080/api/v1/identity/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@flowers.local\",\"password\":\"admin12345\"}"
```

## Tests

```bash
# from backend/
python -m pip install -e ./shared pytest pytest-cov pytest-asyncio httpx fastapi uvicorn pydantic-settings PyJWT "passlib[bcrypt]" structlog opentelemetry-api opentelemetry-sdk sqlalchemy
python scripts/run_all_tests.py
```

Coverage gate: **≥ 90%** per package.

## Latency SLO

Interactive sync via gateway: **p95 < 0.5s**, **p99 < 1.5s**.

```bash
python scripts/latency_smoke.py
```

## Feature branches

Long-lived line: `backend`. Feature branches: `feat/<name>` (Git cannot nest `backend/feat-*` under existing `backend` ref).
