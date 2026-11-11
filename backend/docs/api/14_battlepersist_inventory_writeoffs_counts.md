# Inventory write-offs and inventory counts

Short description: Record write-offs (with photo evidence) and stocktake counts.

Both are persisted in Postgres (`inventory.write_offs`, `inventory.counts`). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

## 1. Create write-off

### Endpoint description

Consumes stock FIFO (same rules as `inventory/consume`) and stores a write-off act. **1–10 photo ids are mandatory**; upload photos first via `POST /api/v1/files/files` and pass the returned `id`s (ids are not verified against the files service).

> Response quirk: serialized from the domain object – `quantity` and allocation `quantity`/`unit_cost` are JSON numbers.

### Endpoint name

`POST /api/v1/inventory/write-offs`

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
| `reason` | string | yes | e.g. `wilted`, `damaged` |
| `photo_ids` | string[] | yes | 1..10 file ids |

### Request example

```http
POST /api/v1/inventory/write-offs HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "quantity": "1",
  "reason": "wilted",
  "photo_ids": ["8599abce-d348-4fe6-b66a-b6762f936d81"]
}
```

### Response example (201)

```json
{
  "id": "6f839130-4991-4b38-b414-d7eb65ea82ea",
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "quantity": 1,
  "reason": "wilted",
  "photo_ids": ["8599abce-d348-4fe6-b66a-b6762f936d81"],
  "allocations": [
    { "lot_id": "296587f4-a7bb-4719-8261-73d37eecc8a0", "quantity": 1, "unit_cost": 40.0 }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 409 | `insufficient_stock` | Insufficient stock |
| 422 | – | Validation: empty or >10 `photo_ids`, `quantity` ≤ 0 (`detail[]`) |

(`photos_required` – "Write-off requires 1..10 photo ids" – is also enforced in the domain, but request validation rejects it first with 422.)

## 2. Create inventory count

### Endpoint description

Records a stocktake: compares `actual` with the current system quantity (sum of lots for the product) and returns the discrepancy. **It does not adjust stock** – post a write-off or receive a lot to correct differences. Responds `201`. Quantities are JSON numbers.

### Endpoint name

`POST /api/v1/inventory/inventory-counts`

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
| `actual` | decimal | yes | ≥ 0, counted quantity |

### Request example

```http
POST /api/v1/inventory/inventory-counts HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "actual": "5" }
```

### Response example (201)

```json
{
  "id": "c8e432fd-c390-46dd-8196-52d6aa9ebdf0",
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "expected": 6,
  "actual": 5,
  "discrepancy": -1
}
```

`discrepancy = actual - expected`.

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`), e.g. `actual` < 0 |
