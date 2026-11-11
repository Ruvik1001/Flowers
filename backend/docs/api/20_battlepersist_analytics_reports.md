# Analytics reports

Short description: Read-model reports built continuously from domain events.

The analytics service keeps a projection updated by a continuous consumer loop on the `domain-events` Redis stream (`CONSUMER_LOOP=1` in prod, default on when `REDIS_URL` is set) and snapshots it to Postgres (`analytics.snapshots`), so reports survive restarts. Events are deduplicated by `event_id`. Data therefore appears a short time (≈ `CONSUMER_POLL_INTERVAL`, 0.5 s, plus outbox delay ≈ 1 s) after the business operation – poll or retry instead of expecting read-your-writes.

All numbers in reports are **strings**. Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

> Internal ops routes `POST /api/v1/analytics/internal/events` and `POST /api/v1/analytics/internal/drain` are reachable through the gateway with any valid token but are **not** part of the FE contract.

## Get report

### Endpoint description

Returns one named report.

| `name` | Fed by | Shape |
|---|---|---|
| `revenue-by-day` | `SaleCompleted` | `{items:[{key: "YYYY-MM-DD", value}]}` |
| `revenue-by-shift` | `SaleCompleted` | `{items:[{key: shift_id or "unassigned", value}]}` |
| `sales-by-product` | `SaleCompleted` | `{items:[{product_id, quantity, revenue}]}` |
| `stock-turnover` | `StockChanged` | `{items:[{product_id, movement, turnover: null, status}]}` (turnover not computed yet) |
| `margin` | `SaleCompleted` | `{revenue, cost, margin}` (cost currently `"0"` – sales does not report COGS) |
| `cash-gaps` | `ShiftClosed` | `{items:[{key: shift_id, value: actual − expected}]}` |
| `write-offs` | `WriteOffCompleted` | `{items:[{product_id, quantity, value}]}` |

### Endpoint name

`GET /api/v1/analytics/reports/{name}`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `name` | path | yes | One of the report names above |

### Accepted body

None.

### Request example

```http
GET /api/v1/analytics/reports/revenue-by-day HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response examples (200)

`revenue-by-day`:

```json
{ "items": [ { "key": "2026-11-11", "value": "300.00" } ] }
```

`sales-by-product`:

```json
{
  "items": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "2", "revenue": "300.00" }
  ]
}
```

`margin`:

```json
{ "revenue": "300.00", "cost": "0", "margin": "300.00" }
```

`cash-gaps`:

```json
{ "items": [ { "key": "e6f0d5c8-8003-4af7-a0c5-120d74275e67", "value": "-4.50" } ] }
```

`stock-turnover`:

```json
{
  "items": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "movement": "2",
      "turnover": null, "status": "inventory-average-required" }
  ]
}
```

No data yet → `{"items": []}` (for `margin`: zeros).

Known gaps: `stock-turnover` and `write-offs` stay empty until inventory emits `StockChanged` / `WriteOffCompleted` (not published yet); `revenue-by-shift` groups under `"unassigned"` because sales does not send `shift_id` in events.

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `report_not_found` | Unknown report |
| 401 | `missing_token` | Bearer access token required |
| 401 | `invalid_token` | Token is invalid or expired |
| 502 | `upstream_unavailable` | analytics service unavailable |
