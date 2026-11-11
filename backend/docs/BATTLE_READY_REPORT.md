# Flowers Backend — Battle-Ready Report

Date: 2026-11-11  
Branch: `feat/battle-ready` → merge target `backend`  
Author of commits: Viktor `<ruvik1001@gmail.com>`

## 1. Local Docker images used

| Image | Tag | Role |
|---|---|---|
| `python` | `3.12-slim` | build/runtime for all app services + migrate |
| `postgres` | `16` | primary DB (local image; not alpine) |
| `redis` | `7-alpine` | streams / cache bus |
| `otel/opentelemetry-collector-contrib` | `0.120.0` | traces/metrics collector (local tag; was 0.113.0 in earlier draft) |

Built project images: `flowers-local-{gateway,identity,catalog,inventory,procurement,assembly,sales,cashier,files,audit,analytics}`.

## 2. Configuration

### Compose overlays
- Base: `docker-compose.yml`
- Local: `docker-compose.local.yml` (ports 8080/5432/6379, upload bind)
- Dev/Prod overlays remain available

### Env (local)
File: `.env.local` (from example; secrets not committed)

Key vars:
- `DATABASE_URL=postgresql+psycopg://flowers:flowers@postgres:5432/flowers`
- `REDIS_URL=redis://redis:6379/0`
- `JWT_SECRET` (≥32 chars)
- `EVENT_STREAM=domain-events`
- `OTLP_ENDPOINT=http://otel-collector:4318/v1/traces`
- Bootstrap admin: `admin@flowers.local` / `admin12345`

### Public edge
- Gateway: `http://localhost:8080/api/v1/...`
- Public routes without JWT: `identity/auth/login`, `identity/auth/refresh`, health

## 3. Migrations

### Mechanism
1. **Cold init:** `db/init.sql` mounted into Postgres `docker-entrypoint-initdb.d`
2. **Idempotent migrate job:** service `migrate` runs `scripts/migrate_standalone.py` (psycopg) before app containers
3. **Per-service boot:** each app container runs `scripts/migrate.py` / SQLAlchemy `shared.persistence.migrate` as startup step

### Created schemas
`identity`, `catalog`, `procurement`, `inventory`, `assembly`, `sales`, `cashier`, `files`, `audit`, `analytics`

### Tables (selected)
- `identity.users`, `identity.roles`
- `catalog.products`, `catalog.recipes`
- `inventory.lots`, `inventory.write_offs`, `inventory.counts`
- `sales.sales`, `cashier.shifts`, `files.objects`, `audit.events`, `analytics.snapshots`
- procurement suppliers/supplies payload tables

### Status observed on live stack
Migrate container exited **0**. Schemas/tables present in Postgres.

> ~~Note: runtime domain state for many services is still primarily **in-memory process state** with Postgres schemas ready for persistence evolution. Events flow through **Redis Streams** (`domain-events`) for audit/analytics.~~
>
> **Superseded** by [section 9 «Persistence complete»](#9-persistence-complete): Postgres is now the source of truth for all domain stores; Redis Streams remain the event transport (fed through the transactional outbox).

## 4. Stack status (verified)

All containers up:
- postgres (healthy), redis (healthy), otel-collector
- migrate (completed)
- gateway + 10 domain/platform services (Up)

Gateway health:
```json
{"status":"ok","service":"gateway"}
```

## 5. Scenario walkthrough (smoke)

Script: `scripts/smoke_all_paths.py`  
Result: **SMOKE OK**

| Step | Gateway path | Result |
|---|---|---|
| Health | `GET /api/v1/health` | 200 |
| Login | `POST /api/v1/identity/auth/login` | 200 JWT |
| Me | `GET /api/v1/identity/auth/me` | 200 admin |
| Roles | `GET /api/v1/identity/roles` | 200 |
| Create user | `POST /api/v1/identity/users` | 200 |
| Create product | `POST /api/v1/catalog/products` | 201 |
| Create supplier | `POST /api/v1/procurement/suppliers` | 201 |
| Create supply | `POST /api/v1/procurement/supplies` | 201 |
| Accept supply → inventory | `POST .../accept` | 200 (stock received via HTTP) |
| Extra lot | `POST /api/v1/inventory/lots` | 201 |
| Open shift | `POST /api/v1/cashier/shifts` | 201 |
| Sale (FIFO consume) | `POST /api/v1/sales/sales` | 201 + allocations |
| Close shift / cash gap | `POST .../close` | 200 discrepancy **-5.0** |
| Upload photo | `POST /api/v1/files/files` | 201 |
| Write-off | `POST /api/v1/inventory/write-offs` | 201 |
| Refund money-only | `POST .../refunds` | 201 |
| Analytics revenue | `GET /api/v1/analytics/reports/revenue-by-day` | 200 (`300.00`) |
| Audit list | `GET /api/v1/audit/audit` | 200 (`SupplyAccepted`, `SaleCompleted`, ...) |

Cross-service sync path proven: **sales → inventory FIFO consume**.  
Async path proven: **Redis domain-events → audit/analytics drain**.

## 6. Latency SLO check

Script: `scripts/latency_smoke.py` (gateway health interactive samples)

Thresholds: p95 < 0.5s, p99 < 1.5s  
(Measured against live gateway; see command output from verification run.)

## 7. Remaining hardening (honest backlog)

> **Superseded (items 1–5 delivered, see [section 9](#9-persistence-complete)).** Original list kept for history; the still-open items are in section 9.8.

1. ~~Move all domain stores from in-memory to Postgres repositories using existing schemas/tables (identity/inventory first).~~ Done – `PersistMap` stores.
2. ~~Outbox table + reliable publish workers (currently direct Redis publish from services).~~ Done – `messaging.outbox` + `OutboxPublisher`/`OutboxWorker`.
3. ~~Alembic revision history per service (today: SQL bootstrap + idempotent apply).~~ Done – single Alembic revision `0001` (shared baseline for all schemas, not per service).
4. ~~Expand FE API docs beyond auth/health for every FE-facing route.~~ Done – `docs/api/04`–`22` + Postman collection.
5. ~~Prod overlay secrets via host env/files; MonitoringPLTG sink instead of debug exporter.~~ Done – `docker-compose.prod.yml`, `.env.prod.example`, `otel-collector-config.prod.yml`.

## 8. How to reproduce

```bash
cd backend
cp .env.local.example .env.local   # set long JWT_SECRET
docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file .env.local up -d --build
python scripts/smoke_all_paths.py http://localhost:8080
python scripts/latency_smoke.py --base-url http://localhost:8080
```

## 9. Persistence complete

Commit placeholder: `battlepersist`. This section supersedes the in-memory note in section 3 and the backlog in section 7.

### 9.1 Postgres is the source of truth (`PersistMap` stores)

Every domain store wraps its collections in `shared.persistence.persist_map.PersistMap` – a dict-like map that keeps an in-memory cache and mirrors each `set` / `del` / `clear` to Postgres through `db_session()` hooks (`on_set`, `on_del`, `on_clear`). On startup each store `_load()`s its rows back into the cache (`replace_all`, muted so loading does not write back).

| Service | Persisted collections (schema.table) |
|---|---|
| identity | `identity.users`, `identity.roles` (roles seeded on first start, bootstrap admin created if missing) |
| catalog | `catalog.products`, `catalog.recipes` |
| procurement | `procurement.suppliers`, `procurement.supplies` |
| inventory | `inventory.lots`, `inventory.write_offs`, `inventory.counts` |
| assembly | `assembly.assemblies` |
| sales | `sales.sales`, `sales.refunds` |
| cashier | `cashier.shifts` |
| files | `files.objects` (metadata; binaries stay on the `uploads` volume) |
| audit | `audit.events` (unique `idempotency_key`) |
| analytics | `analytics.snapshots` (projection state) |

Persistence is enabled automatically when `DATABASE_URL` is PostgreSQL (`persistence_enabled()`); `PERSISTENCE_ENABLED=0` forces the in-memory mode used by unit tests and quick local runs. Inventory FIFO consume takes row locks (`SELECT ... FOR UPDATE`) on Postgres so concurrent sales cannot over-consume a lot.

### 9.2 Alembic `0001` and `messaging.outbox`

* `backend/db/alembic/versions/0001_baseline.py` creates all service schemas plus the new `messaging` schema, using idempotent `IF NOT EXISTS` statements (safe on top of a database bootstrapped from `db/init.sql`).
* `messaging.outbox` columns: `id`, `service_name`, `event_name`, `payload` (JSONB), `idempotency_key` (unique partial index), `created_at`, `published_at` (partial index `outbox_unpublished_idx` for pending rows).
* Migration strategy (`DB_MIGRATE_MODE`): `auto` (default) runs `alembic upgrade head` when alembic + `db/alembic.ini` are available and falls back to `db/init.sql`; `alembic` requires alembic; `sql` always applies `init.sql`. Runs in the `migrate` compose job and again (with retries) from each container's `scripts/entrypoint.sh` → `scripts/migrate.py`.

### 9.3 OutboxPublisher / OutboxWorker

* Request path: `OutboxStreamBus.publish()` (built by `build_outbox_bus`) stages the event with `OutboxPublisher.enqueue()` (`INSERT ... ON CONFLICT DO NOTHING` on `idempotency_key`) and commits in a short session – the request never talks to Redis. Without persistence it delegates to the inner bus.
* Delivery: `OutboxWorker` polls unpublished rows (`FOR UPDATE SKIP LOCKED`, ordered by `created_at`), publishes each to the Redis stream `EVENT_STREAM` (`domain-events`) and sets `published_at` only after the bus accepted it → **at-least-once** delivery; consumers dedupe by `event_id`/`idempotency_key`.
* The worker runs as an asyncio background task in each publishing service's lifespan (`outbox_lifespan`): identity, procurement, assembly, sales, cashier. Poll interval `OUTBOX_POLL_INTERVAL` (default 1 s).
* Known limitation: the outbox row is written in its own transaction right after the domain write (not in the same DB transaction as the `PersistMap` write), so a crash between the two can lose the event; a true same-transaction outbox would need repository-level transactions.

### 9.4 Continuous audit / analytics consumers

* `audit` and `analytics` subscribe to `domain-events` via `ConsumerRunner` (`consumer_lifespan`) – a background loop that drains the Redis stream group repeatedly (`CONSUMER_POLL_INTERVAL`, default 0.5 s). It is enabled by `CONSUMER_LOOP=1` (set in the prod overlay) and by default whenever `REDIS_URL` is configured.
* `POST /api/v1/{audit,analytics}/internal/drain` stays as an ops/test hook, serialised with the loop by a lock.
* Both projections are idempotent: audit stores events with a unique `idempotency_key`; analytics keeps a `seen` set and snapshots its state to `analytics.snapshots` after every event, so both survive restarts and replays.
* Currently emitted event types: `SaleCompleted`, `ShiftClosed`, `SupplyAccepted`, `UserRoleChanged`, `AssemblyCompleted`. `StockChanged` / `WriteOffCompleted` are defined and handled by analytics but not yet emitted by inventory (so `stock-turnover` and `write-offs` reports stay empty).

### 9.5 Production overlay, MonitoringPLTG, readiness

* `docker-compose.prod.yml`: image-only builds (no bind mounts), `restart: always`, CPU/memory limits, `env_file: .env.prod` (template `.env.prod.example`, secrets never committed), gateway as the only published port with `RATE_LIMIT_PER_MINUTE` (default 120), `CONSUMER_LOOP=1` for audit/analytics, `uploads` named volume for files, migrate job honours `DB_MIGRATE_MODE`.
* **MonitoringPLTG**: `otel-collector-config.prod.yml` forwards traces to `OTLP_MONITORING_ENDPOINT` via `otlphttp/monitoring` (required by the overlay; TLS insecure toggle `OTLP_MONITORING_INSECURE`), keeping the `debug` exporter (basic verbosity) only as a secondary sink; metrics go to `debug`.
* **Readiness**: every service exposes `GET /api/v1/ready` (`install_readiness`) in addition to `/api/v1/health`. It runs `SELECT 1` against Postgres and/or `PING` against Redis (per service), reports `"skipped"` when the URL is not configured and returns `503 not_ready` with `detail` on failure. Via the gateway: `GET /api/v1/{service}/ready` (Bearer) and the gateway's own `GET /api/v1/ready`. See `docs/api/04_battlepersist_health_ready.md`.

### 9.6 `scripts/smoke_persist_restart.py`

```bash
cd backend
python scripts/smoke_persist_restart.py http://localhost:8080   # uses docker-compose.yml + docker-compose.local.yml, COMPOSE_ENV_FILE (default .env.local)
```

Flow: log in → create product, supplier, lot, shift, sale → `docker compose restart` of all app services (postgres/redis volumes kept) → wait for gateway health → log in again and assert the product, lot (quantity reduced by the sale), supplier, shift, sale and the analytics report are still returned.

### 9.7 FE docs and Postman

`docs/api/04`–`22` (placeholder commit `battlepersist`) document every public gateway route; `postman/Flowers.postman_collection.json` covers auth, roles/users, catalog, procurement, inventory, files, cashier, sales, assembly, analytics, audit and ready/health (collection variables `baseUrl`, `accessToken`; login test script stores the token).

### 9.8 Remaining backlog after persistence

1. Make outbox enqueue part of the same DB transaction as the domain write (see 9.3 limitation).
2. Emit `StockChanged` / `WriteOffCompleted` from inventory; report real `cost` (COGS) and `shift_id` in `SaleCompleted`.
3. Translate inventory `409 insufficient_stock` into a client error in sales/assembly/procurement (currently surfaces as `500`).
4. Enforce RBAC permissions in downstream services (today only identity checks permissions; others only require a valid access token).
5. Per-service Alembic histories and a shared test run of the persistence smoke in CI (the smoke script is run manually against the compose stack).
