# Gateway conventions and common errors

Short description: Behaviour shared by every gateway route – routing, auth, headers, number formats, error envelope.

## Routing

* Public base URL (local): `http://localhost:8080`.
* Every route is `/api/v1/{service}/{upstream path}`; the gateway forwards to `{service_url}/api/v1/{upstream path}`. Services: `identity`, `catalog`, `inventory`, `procurement`, `assembly`, `sales`, `cashier`, `audit`, `analytics`, `files`.
* Resource names are therefore often repeated: `/api/v1/sales/sales`, `/api/v1/files/files`, `/api/v1/audit/audit`, `/api/v1/inventory/inventory/consume`.
* Gateway-owned routes: `GET /api/v1/health`, `GET /api/v1/ready` (no auth).
* Methods proxied: `GET POST PUT PATCH DELETE OPTIONS`.

## Authentication

* Public (no token): `POST /api/v1/identity/auth/login`, `POST /api/v1/identity/auth/refresh`, `GET /api/v1/identity/health`, `GET /api/v1/health`, `GET /api/v1/ready`.
* Everything else needs `Authorization: Bearer <access_token>` (JWT HS256, `type=access`). The gateway validates the token and forwards `X-User-Id`/`X-User-Email` and `Authorization` upstream.
* Only `identity` enforces permissions (user/role creation); other services trust any valid access token. Role-based UI gating must use `GET /identity/auth/me` (`roles`, `permissions`, `object_scopes`) and `authz/object`.
* Optional per-user rate limit (`RATE_LIMIT_PER_MINUTE`, prod overlay default 120) returns `429`.

## Headers

| Header | Direction | Description |
|---|---|---|
| `Authorization` | request | `Bearer <access_token>` |
| `Content-Type` | request | `application/json` (multipart for file upload) |
| `X-Request-Id` | request/response | Correlation id; generated when absent and always echoed back |

## Data formats

* IDs: opaque UUID strings.
* Timestamps: ISO-8601 UTC (`2026-11-11T11:16:25.791460+00:00`); dates `YYYY-MM-DD`.
* Money/quantities in request bodies: send strings (`"150.00"`) or numbers. Money is RUB with two decimals.
* Responses are **not uniform**: explicitly built dictionaries (products, lots, sales, supplies, refunds, reports) return decimals as **strings**; responses serialized straight from domain objects (recipes, expired lots, write-offs, inventory counts, shifts, assemblies) return **numbers** and money as `{ "amount": <number> }`. Each endpoint doc shows the exact shape.

## Error envelope

Domain/gateway errors:

```json
{ "code": "product_not_found", "message": "Product not found" }
```

Optional `details` object is present for some errors (e.g. `object_forbidden`).

Request-validation errors (FastAPI default, HTTP 422):

```json
{
  "detail": [
    { "type": "missing", "loc": ["body", "opening_cash"], "msg": "Field required", "input": {"cashier_id": "c1"} }
  ]
}
```

Readiness failures (`503`) use `{ "status": "not_ready", "service": ..., "db"|"redis": "error", "detail": ... }`.

## Common errors (all authenticated routes)

| HTTP | code | message | When |
|---|---|---|---|
| 401 | `missing_token` | Bearer access token required | No/invalid `Authorization` scheme |
| 401 | `invalid_token` | Token is invalid or expired | Bad signature or expired |
| 401 | `invalid_token_type` | Unexpected token type | Refresh token sent as access token (or vice versa) |
| 404 | `service_not_found` | Unknown service | `{service}` not in the list above |
| 422 | – | `{"detail": [...]}` | Body/query/path validation |
| 429 | `rate_limited` | Too many requests | Gateway rate limit exceeded |
| 500 | `internal_error` | Internal server error | Unhandled error (includes failed service-to-service calls, e.g. inventory `409` during a sale) |
| 502 | `upstream_unavailable` | `{service}` service unavailable | Upstream unreachable/timed out (gateway timeout `REQUEST_TIMEOUT`, default 10 s) |

Business error codes per endpoint are listed in the individual files.
