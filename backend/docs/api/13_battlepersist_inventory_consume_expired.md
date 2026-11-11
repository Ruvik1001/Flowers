# Inventory consume and expired stock

Short description: FIFO stock consumption and the expired-lots report.

Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

## 1. Consume stock (FIFO)

### Endpoint description

Consumes `quantity` of a product from the oldest lots first (`received_at`, then `id`), reducing lot quantities atomically (`SELECT ... FOR UPDATE` on Postgres). Returns the lot allocations used for COGS. Normally called by sales/assembly, but available to the FE for manual corrections. All-or-nothing: if total stock is insufficient nothing is consumed.

### Endpoint name

`POST /api/v1/inventory/inventory/consume`

> The gateway path repeats `inventory` (`/api/v1/{service}` + upstream `/api/v1/inventory/consume`).

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

None.

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `product_id` | string | yes | Product id |
| `quantity` | decimal | yes | > 0 |

### Request example

```http
POST /api/v1/inventory/inventory/consume HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "3" }
```

### Response example (200)

```json
[
  { "lot_id": "296587f4-a7bb-4719-8261-73d37eecc8a0", "quantity": "3", "unit_cost": "40.00" }
]
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `invalid_quantity` | Quantity must be positive |
| 409 | `insufficient_stock` | Insufficient stock |
| 422 | – | Validation (`detail[]`) |

## 2. Expired lots

### Endpoint description

Lots with `expires_on <= on` and `quantity > 0`. `on` defaults to today (UTC). Plain JSON array.

> Response quirk: items are serialized directly from the domain object – `quantity` is a JSON number and `unit_cost` is an object `{ "amount": <number> }`, unlike `GET /lots` (strings). Normalize on the client.

### Endpoint name

`GET /api/v1/inventory/inventory/expired`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `on` | query | no | Date `YYYY-MM-DD`; default today |

### Accepted body

None.

### Request example

```http
GET /api/v1/inventory/inventory/expired?on=2026-12-01 HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "296587f4-a7bb-4719-8261-73d37eecc8a0",
    "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
    "quantity": 10,
    "unit_cost": { "amount": 40.0 },
    "received_at": "2026-11-11T11:16:32.666256+00:00",
    "expires_on": "2026-11-18"
  }
]
```

No expired stock → `[]`.

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`), e.g. invalid `on` date |
