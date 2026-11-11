# Sales refunds

Short description: Refund (part of) a sale with optional stock return or defect write-off.

Refunds are persisted in Postgres (`sales.refunds`); the sale's refunded total is updated in `sales.sales`. Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`. There is no `GET` for refunds.

## 1. Create refund

### Endpoint description

Refunds `amount` against a sale; cumulative refunds may not exceed the sale total. Behaviour by `kind`:

| `kind` | Effect |
|---|---|
| `money_only` | Only money is refunded |
| `stock_back` | If `product_id` and `quantity` are given: a new lot (`unit_cost` 0) is received back into inventory |
| `defect_write_off` | Requires 1..10 `photo_ids`. If `product_id` and `quantity` are given: inventory write-off with reason `refund_defect` |

For `stock_back` / `defect_write_off`, inventory is only touched when **both** `product_id` and `quantity` are present. To record the cash payout on the shift, also call `POST /api/v1/cashier/shifts/{id}/cash` with `"refund": true`.

### Endpoint name

`POST /api/v1/sales/sales/{sale_id}/refunds`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `sale_id` | path | yes | Sale id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `amount` | decimal | yes | > 0, ≤ remaining refundable amount |
| `kind` | enum | yes | `stock_back` \| `money_only` \| `defect_write_off` |
| `product_id` | string \| null | no | Needed for stock actions |
| `quantity` | decimal \| null | no | Needed for stock actions |
| `photo_ids` | string[] | no | Default `[]`; 1..10 required for `defect_write_off` |

### Request example

```http
POST /api/v1/sales/sales/0b8f4a4e-31d3-4c11-b0c8-5f2f4e7b9a10/refunds HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "amount": "150.00",
  "kind": "defect_write_off",
  "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "quantity": "1",
  "photo_ids": ["8599abce-d348-4fe6-b66a-b6762f936d81"]
}
```

Money-only example body: `{ "amount": "150.00", "kind": "money_only" }`.

### Response example (201)

```json
{ "id": "5d1c1c9e-0a43-4f3a-90a6-3c6e6f3b7d02", "amount": "150.00", "kind": "defect_write_off" }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `invalid_refund` | Refund exceeds refundable amount |
| 400 | `photos_required` | Defect write-off requires 1..10 photo ids |
| 404 | `sale_not_found` | Sale not found |
| 422 | – | Validation (`amount` ≤ 0, bad `kind`, ...) |
| 500 | `internal_error` | Inventory call failed (e.g. insufficient stock for the defect write-off); the sale's refunded total is increased in the service's memory before the inventory call, so a retry after such a failure may be rejected with `invalid_refund` until the service restarts |
