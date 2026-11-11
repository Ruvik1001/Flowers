# Audit log

Short description: Query the append-only audit trail projected from domain events.

The audit service consumes the `domain-events` stream continuously (`CONSUMER_LOOP=1` in prod, default on when `REDIS_URL` is set) and stores events in Postgres (`audit.events`, unique `idempotency_key`), so the log survives restarts and replays are ignored. Events appear shortly after the business operation (outbox delay ≈ 1 s + consumer poll 0.5 s). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

Gateway path repeats the service name: `/api/v1/audit/audit`.

Event names currently published by services: `SaleCompleted`, `ShiftClosed`, `SupplyAccepted`, `UserRoleChanged`, `AssemblyCompleted`. (`StockChanged` and `WriteOffCompleted` are defined but not yet emitted by inventory, so inventory write-offs do not appear in the audit log yet.)

> Internal ops routes `POST /api/v1/audit/internal/audit` and `POST /api/v1/audit/internal/drain` are reachable through the gateway with any valid token but are **not** part of the FE contract.

## List audit records

### Endpoint description

Returns records in insertion order, filtered with AND semantics and paginated with `limit`/`offset`. `count` is the size of the returned page, not the total. `actor_id`, `entity_type`, `entity_id` are taken from the event payload and are `null` for events that do not carry them (all current events).

### Endpoint name

`GET /api/v1/audit/audit`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `event_name` | query | no | Exact event name, e.g. `SaleCompleted` |
| `actor_id` | query | no | Exact match |
| `entity_type` | query | no | Exact match |
| `entity_id` | query | no | Exact match |
| `occurred_from` | query | no | ISO-8601 string; `occurred_at >= value` (lexicographic compare) |
| `occurred_to` | query | no | ISO-8601 string; `occurred_at <= value` |
| `limit` | query | no | 1..1000, default 100 |
| `offset` | query | no | ≥ 0, default 0 |

### Accepted body

None.

### Request example

```http
GET /api/v1/audit/audit?event_name=SaleCompleted&limit=20&offset=0 HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "items": [
    {
      "event_id": "4f0d3a1b-5c9e-4a8e-8a53-7a2b5e0f9c14",
      "event_name": "SaleCompleted",
      "occurred_at": "2026-11-11T11:20:41.114522+00:00",
      "payload": {
        "sale_id": "0b8f4a4e-31d3-4c11-b0c8-5f2f4e7b9a10",
        "total": "300.00",
        "revenue": "300.00",
        "cost": "0",
        "day": "2026-11-11",
        "items": [
          { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "2", "total": "300.00" }
        ]
      },
      "actor_id": null,
      "entity_type": null,
      "entity_id": null
    }
  ],
  "count": 1
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 401 | `missing_token` | Bearer access token required |
| 401 | `invalid_token` | Token is invalid or expired |
| 422 | – | Validation (`detail[]`): `limit` outside 1..1000, negative `offset` |
| 502 | `upstream_unavailable` | audit service unavailable |
