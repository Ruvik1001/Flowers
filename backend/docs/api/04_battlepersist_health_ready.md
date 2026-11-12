# Health and readiness probes

Short description: Liveness (`health`) and readiness (`ready`) probes exposed by the gateway and proxied to every backend service.

> Placeholder commit: `battlepersist` (replace with the real hash when the persistence work is committed).

## Endpoint description

* **health** – cheap liveness check, never touches Postgres/Redis.
* **ready** – readiness check. When `DATABASE_URL` starts with `postgresql` the service runs `SELECT 1`; when `REDIS_URL` starts with `redis://` it runs `PING`. Missing config is reported as `"skipped"`. Any failure returns `503 not_ready`.

The gateway itself answers `GET /api/v1/health` and `GET /api/v1/ready` (no upstream call, no auth). Per-service probes are reachable through the proxy as `/api/v1/{service}/health` and `/api/v1/{service}/ready` and **require a Bearer token**, except `identity/health`, which is public.

Services checked by `ready`:

| Service | DB check | Redis check |
|---|---|---|
| gateway | – | – |
| identity, procurement, sales, cashier, assembly, audit, analytics | yes | yes |
| catalog, inventory, files | yes | – |

(Services that publish to or consume from the event stream also check Redis.)

## 1. Gateway health

### Endpoint name

`GET /api/v1/health`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `X-Request-Id` | no | Correlation id; generated if omitted, always echoed back |

### Accepted fields / params

None.

### Accepted body

None.

### Request example

```http
GET /api/v1/health HTTP/1.1
Host: localhost:8080
```

### Response example (200)

```json
{ "status": "ok", "service": "gateway" }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 500 | `internal_error` | Internal server error |

## 2. Gateway readiness

### Endpoint name

`GET /api/v1/ready`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

None.

### Accepted body

None.

### Request example

```http
GET /api/v1/ready HTTP/1.1
Host: localhost:8080
```

### Response example (200)

```json
{ "status": "ready", "service": "gateway" }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 500 | `internal_error` | Internal server error |

## 3. Service health via gateway

### Endpoint name

`GET /api/v1/{service}/health`

`{service}` ∈ `identity | catalog | inventory | procurement | assembly | sales | cashier | audit | analytics | files`.

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes (all services except `identity`) | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `service` | path | yes | Service name from the list above |

### Accepted body

None.

### Request example

```http
GET /api/v1/catalog/health HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{ "status": "ok", "service": "catalog" }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 401 | `missing_token` | Bearer access token required |
| 401 | `invalid_token` | Token is invalid or expired |
| 401 | `invalid_token_type` | Unexpected token type |
| 404 | `service_not_found` | Unknown service |
| 429 | `rate_limited` | Too many requests |
| 502 | `upstream_unavailable` | `{service}` service unavailable |

## 4. Service readiness via gateway

### Endpoint name

`GET /api/v1/{service}/ready`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `service` | path | yes | Service name |

### Accepted body

None.

### Request example

```http
GET /api/v1/sales/ready HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response examples

200 – Postgres and Redis reachable:

```json
{ "status": "ready", "service": "sales", "db": "ok", "redis": "ok" }
```

200 – no `DATABASE_URL`/`REDIS_URL` (in-memory dev mode):

```json
{ "status": "ready", "service": "catalog", "db": "skipped" }
```

503 – dependency down:

```json
{
  "status": "not_ready",
  "service": "sales",
  "db": "error",
  "detail": "connection refused"
}
```

(For Redis failure the key is `"redis": "error"` instead of `"db"`.)

### Error codes and messages

| HTTP | code / status | message |
|---|---|---|
| 503 | `status: "not_ready"` | body has `db`/`redis` = `"error"` and `detail`; no `code` field |
| 401 | `missing_token` | Bearer access token required |
| 401 | `invalid_token` | Token is invalid or expired |
| 404 | `service_not_found` | Unknown service |
| 502 | `upstream_unavailable` | `{service}` service unavailable |

## 5. Identity health (public)

### Endpoint name

`GET /api/v1/identity/health`

No `Authorization` header needed (explicit public route in the gateway). Response:

```json
{ "status": "ok", "service": "identity" }
```

Errors: `502 upstream_unavailable` – identity service unavailable; `500 internal_error`.
