# Sales

Short description: List completed sales and complete (create) a new sale.

Persisted in Postgres (`sales.sales`). Completing a sale validates payments, consumes stock FIFO through inventory (HTTP) and publishes `SaleCompleted` through the transactional outbox (consumed by audit and analytics). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

Gateway path repeats the service name: `/api/v1/sales/sales`.

## 1. List sales

### Endpoint description

Plain JSON array of all sales (no pagination/filters).

### Endpoint name

`GET /api/v1/sales/sales`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

None.

### Accepted body

None.

### Request example

```http
GET /api/v1/sales/sales HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "0b8f4a4e-31d3-4c11-b0c8-5f2f4e7b9a10",
    "total": "300.00",
    "lines": [
      { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "2", "unit_price": "150.00" }
    ],
    "payments": [ { "method": "cash", "amount": "300.00" } ],
    "allocations": [
      { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
        "lot_id": "296587f4-a7bb-4719-8261-73d37eecc8a0", "quantity": "2", "unit_cost": "40.00" }
    ]
  }
]
```

### Error codes and messages

Only the common gateway/auth errors.

## 2. Complete sale

### Endpoint description

Creates a sale. Rules: at least one line and one payment; sum of `payments[].amount` must equal the computed total (`Σ quantity × unit_price`, rounded to 2 decimals). Stock is consumed per line in order; unit prices come from the request (not re-read from the catalog). Responds `201`.

Extra body fields (e.g. `shift_id`) are ignored by the service; to attribute cash to a shift call `POST /api/v1/cashier/shifts/{id}/cash` separately.

### Endpoint name

`POST /api/v1/sales/sales`

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
| `lines` | array | yes | min 1 |
| `lines[].product_id` | string | yes | Product id |
| `lines[].quantity` | decimal | yes | > 0 |
| `lines[].unit_price` | decimal | yes | ≥ 0 |
| `payments` | array | yes | min 1 |
| `payments[].method` | enum | yes | `cash` \| `card` \| `transfer` |
| `payments[].amount` | decimal | yes | > 0 |

### Request example

```http
POST /api/v1/sales/sales HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "lines": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "2", "unit_price": "150.00" }
  ],
  "payments": [
    { "method": "cash", "amount": "300.00" }
  ]
}
```

### Response example (201)

```json
{
  "id": "0b8f4a4e-31d3-4c11-b0c8-5f2f4e7b9a10",
  "total": "300.00",
  "lines": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "2", "unit_price": "150.00" }
  ],
  "payments": [ { "method": "cash", "amount": "300.00" } ],
  "allocations": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
      "lot_id": "296587f4-a7bb-4719-8261-73d37eecc8a0", "quantity": "2", "unit_cost": "40.00" }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `invalid_sale` | Sale requires positive line quantities |
| 400 | `payment_mismatch` | Payments must equal sale total |
| 422 | – | Validation (empty `lines`/`payments`, bad `method`, ...) |
| 500 | `internal_error` | Inventory call failed – **insufficient stock is currently surfaced as 500** (the sales service does not translate the inventory `409 insufficient_stock`). Check stock via `GET /inventory/lots` first. |
