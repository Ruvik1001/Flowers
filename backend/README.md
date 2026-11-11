# Flowers Backend

Microservice backend for flower shop management. Public edge: **gateway** on `/api/v1`.

Read [docs/architecture.md](docs/architecture.md) (RU: [docs/architecture_RU.md](docs/architecture_RU.md)) before any feature work.

## Layout

- `shared/` — reusable libs (auth, messaging, telemetry, db, http, errors, persistence/outbox)
- `services/*` — independently deployable FastAPI services
- `db/` — `init.sql` + central Alembic (`alembic upgrade head`)
- `docs/api/` — FE-facing API docs (`xx_<commit>_desc.md`) after commits
- `postman/` — Postman collection
- Compose overlays: `local` / `dev` / `prod`

## Quick start (local)

```bash
cp .env.local.example .env.local
docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file .env.local up --build
curl http://localhost:8080/api/v1/health
curl http://localhost:8080/api/v1/ready   # gateway readiness (proxied services expose /api/v1/ready too)
```

Default admin (identity bootstrap):

- email: `admin@flowers.local`
- password: `admin12345`

## Production

```bash
cp .env.prod.example .env.prod   # fill secrets; never commit .env.prod
docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod config
docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

Prod overlay: no source bind-mounts, only gateway published, resource limits, `APP_ENV=prod`, OTLP without console as sole sink.

### Secrets checklist

| Secret / setting | Where | Notes |
|---|---|---|
| `POSTGRES_PASSWORD` | `.env.prod` | Strong unique password |
| `DATABASE_URL` | `.env.prod` | Must match Postgres credentials |
| `JWT_SECRET` | `.env.prod` | ≥32 bytes random; rotate carefully |
| `BOOTSTRAP_ADMIN_PASSWORD` | `.env.prod` | Change from defaults |
| `OTLP_ENDPOINT` | `.env.prod` | App → collector (`…:4318/v1/traces`) |
| `OTLP_MONITORING_ENDPOINT` | `.env.prod` / collector | Collector → MonitoringPLTG |
| `.env.prod` itself | host only | **Not in git** |

### Backup / restore (Postgres volume)

```bash
# backup
docker compose exec -T postgres pg_dump -U flowers flowers > backup-$(date +%F).sql

# restore (stack stopped or connections drained)
docker compose exec -T postgres psql -U flowers flowers < backup-YYYY-MM-DD.sql
```

Volumes: `postgres-data`, `redis-data`, `uploads`. Keep dump + uploads copy for full recovery.

### Migrations

Compose `migrate` job runs Alembic (`DB_MIGRATE_MODE=auto`, fallback to `db/init.sql`). Apps also run migrate on boot (no-op at head).

```bash
# from host with DATABASE_URL
cd db && alembic upgrade head
```

## Tests & smoke

```bash
# from backend/
python scripts/run_all_tests.py
python scripts/smoke_all_paths.py
python scripts/smoke_persist_restart.py
python scripts/latency_smoke.py
```

Coverage gate: **≥ 90%** per package.  
Latency SLO via gateway: **p95 < 0.5s**, **p99 < 1.5s**.

## Health

- Liveness: `GET /api/v1/health`
- Readiness: `GET /api/v1/ready` (DB/Redis checks where configured)

## Feature branches

Long-lived line: `backend`. Feature branches: `feat/<name>` (Git cannot nest `backend/feat-*` under existing `backend` ref).
