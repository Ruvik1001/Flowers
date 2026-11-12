# Cashier shift deposit / collection movements

Short description: Record non-sale cash drawer movements (внос / самоинкассация) on an open shift without mixing them into sale/refund `/cash`.

Formula (all responses that expose expected cash):  
`expected_cash = opening_cash + cash_sales + cash_in − cash_refunds − cash_out`.

Shift list/open/cash/movements return money fields as `{ "amount": <number> }`. Close still returns flattened numbers and includes `cash_in` / `cash_out`. Do **not** use `/cash` for deposit or collection.

Gateway path: `/api/v1/cashier/shifts/{shift_id}/movements`

## 1. Record movement

### Endpoint description

Adds a deposit (`cash_in`) or collection (`cash_out`) to an open shift. Responds with the updated shift object.

### Endpoint name

`POST /api/v1/cashier/shifts/{shift_id}/movements`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `shift_id` | path | yes | Open shift id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `kind` | string | yes | `deposit` or `collection` |
| `amount` | decimal | yes | > 0 |

### Request example

```http
POST /api/v1/cashier/shifts/e6f0d5c8-8003-4af7-a0c5-120d74275e67/movements HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "kind": "deposit", "amount": "50.00" }
```

### Response example (200)

```json
{
  "id": "e6f0d5c8-8003-4af7-a0c5-120d74275e67",
  "cashier_id": "c1",
  "opening_cash": { "amount": 100.0 },
  "opened_at": "2026-11-12T13:00:00+00:00",
  "cash_sales": { "amount": 0.0 },
  "cash_refunds": { "amount": 0.0 },
  "cash_in": { "amount": 50.0 },
  "cash_out": { "amount": 0.0 },
  "closed_at": null,
  "actual_cash": null
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `shift_not_found` | Shift not found |
| 409 | `shift_closed` | Shift is closed |
| 422 | – | Validation (`kind` not in enum, `amount` ≤ 0, …) |
