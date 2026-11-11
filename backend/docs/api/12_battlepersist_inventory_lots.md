# Inventory lots

Short description: List stock lots and receive a new lot.

Lots are persisted in Postgres (`inventory.lots`). Stock is tracked per lot (FIFO by `received_at`). Procurement acceptance, assembly output and refund `stock_back` also create lots through `POST /lots`. Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

## 1. List lots

### Endpoint description

Plain JSON array of all lots (including depleted lots with `quantity` `"0"`). Compute on-hand stock per product by summing `quantity`.

### Endpoint name

`GET /api/v1/inventory/lots`

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
GET /api/v1/inventory/lots HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "296587f4-a7bb-4719-8261-73d37eecc8a0",
    "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
    "quantity": "10",
    "unit_cost": "40.00",
    "received_at": "2026-11-11T11:16:32.666256+00:00",
    "expires_on": "2026-11-18"
  }
]
```

`quantity` and `unit_cost` are strings, `expires_on` is `YYYY-MM-DD` or `null`.

### Error codes and messages

Only the common gateway/auth errors.

## 2. Receive lot

### Endpoint description

Registers incoming stock as a new lot. Responds `201`. `product_id` is not validated against the catalog.

### Endpoint name

`POST /api/v1/inventory/lots`

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
| `unit_cost` | decimal | yes | ≥ 0 |
| `expires_on` | date (`YYYY-MM-DD`) | no | Expiry date |

### Request example

```http
POST /api/v1/inventory/lots HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "quantity": "10",
  "unit_cost": "40.00",
  "expires_on": "2026-11-18"
}
```

### Response example (201)

```json
{
  "id": "296587f4-a7bb-4719-8261-73d37eecc8a0",
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "quantity": "10",
  "unit_cost": "40.00",
  "received_at": "2026-11-11T11:16:32.666256+00:00",
  "expires_on": "2026-11-18"
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`): `quantity` ≤ 0, `unit_cost` < 0, bad date |
