# Procurement supplies and acceptance

Short description: Create supply orders, list them and accept delivered quantities into inventory.

Persisted in Postgres (`procurement.supplies`). Accepting a line synchronously calls inventory (`POST /api/v1/lots`) and emits `SupplyAccepted` through the transactional outbox (relayed to Redis by the outbox worker; consumed by audit/analytics). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

All quantities in supply responses are **strings**; `quantity` and `ordered` carry the same value (kept for FE compatibility).
`created_at` is an ISO-8601 timestamp set when the supply is created (stored in the JSONB payload).

## 1. List supplies

### Endpoint description

Plain JSON array of all supplies.

### Endpoint name

`GET /api/v1/procurement/supplies`

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
GET /api/v1/procurement/supplies HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "9c1b6c4f-5b0e-4f55-8b2c-0d9b5a7a3e21",
    "supplier_id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11",
    "created_at": "2026-03-20T10:15:00+00:00",
    "lines": [
      {
        "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
        "quantity": "20",
        "ordered": "20",
        "unit_cost": "50.00",
        "accepted": "10"
      }
    ]
  }
]
```

### Error codes and messages

Only the common gateway/auth errors.

## 2. Create supply

### Endpoint description

Creates a supply for an existing supplier. Nothing reaches inventory until lines are accepted. Product ids are not validated against the catalog. Responds `201`.

### Endpoint name

`POST /api/v1/procurement/supplies`

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
| `supplier_id` | string | yes | Existing supplier |
| `lines` | array | yes | min 1 element |
| `lines[].product_id` | string | yes | Product id |
| `lines[].quantity` | decimal | yes | > 0 (ordered quantity) |
| `lines[].unit_cost` | decimal | yes | ≥ 0 |

### Request example

```http
POST /api/v1/procurement/supplies HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "supplier_id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11",
  "lines": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "20", "unit_cost": "50.00" }
  ]
}
```

### Response example (201)

```json
{
  "id": "9c1b6c4f-5b0e-4f55-8b2c-0d9b5a7a3e21",
  "supplier_id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11",
  "created_at": "2026-03-20T10:15:00+00:00",
  "lines": [
    {
      "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
      "quantity": "20",
      "ordered": "20",
      "unit_cost": "50.00",
      "accepted": "0"
    }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `supplier_not_found` | Supplier not found |
| 422 | – | Validation (empty `lines`, `quantity` ≤ 0, `unit_cost` < 0) |

## 3. Accept supply line

### Endpoint description

Accepts a (partial) delivery of one line. Increases `accepted`, creates an inventory lot at the line's `unit_cost` (HTTP call to inventory) and publishes `SupplyAccepted`. May be called multiple times per line until `accepted == ordered`.

### Endpoint name

`POST /api/v1/procurement/supplies/{supply_id}/accept`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `supply_id` | path | yes | Supply id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `product_id` | string | yes | Must match a line of the supply |
| `quantity` | decimal | yes | > 0 and `accepted + quantity <= ordered` |

### Request example

```http
POST /api/v1/procurement/supplies/9c1b6c4f-5b0e-4f55-8b2c-0d9b5a7a3e21/accept HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "10" }
```

### Response example (200)

```json
{
  "id": "9c1b6c4f-5b0e-4f55-8b2c-0d9b5a7a3e21",
  "supplier_id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11",
  "created_at": "2026-03-20T10:15:00+00:00",
  "lines": [
    {
      "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
      "quantity": "20",
      "ordered": "20",
      "unit_cost": "50.00",
      "accepted": "10"
    }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `invalid_acceptance` | Accepted quantity must be positive and not exceed ordered |
| 404 | `supply_not_found` | Supply not found |
| 404 | `line_not_found` | Supply line not found |
| 422 | – | Validation (`detail[]`) |
| 500 | `internal_error` | Inventory call failed (inventory returned an error or timed out after 2 s) |
