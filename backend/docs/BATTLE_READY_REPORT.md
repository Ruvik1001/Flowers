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

> Note: runtime domain state for many services is still primarily **in-memory process state** with Postgres schemas ready for persistence evolution. Events flow through **Redis Streams** (`domain-events`) for audit/analytics.

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

1. Move all domain stores from in-memory to Postgres repositories using existing schemas/tables (identity/inventory first).
2. Outbox table + reliable publish workers (currently direct Redis publish from services).
3. Alembic revision history per service (today: SQL bootstrap + idempotent apply).
4. Expand FE API docs beyond auth/health for every FE-facing route.
5. Prod overlay secrets via host env/files; MonitoringPLTG sink instead of debug exporter.

## 8. How to reproduce

```bash
cd backend
cp .env.local.example .env.local   # set long JWT_SECRET
docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file .env.local up -d --build
python scripts/smoke_all_paths.py http://localhost:8080
python scripts/latency_smoke.py --base-url http://localhost:8080
```
