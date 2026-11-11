# Cashier shifts, cash and close

Short description: Open/list cash shifts, record cash movements and close a shift with cash-gap calculation.

Shifts are persisted in Postgres (`cashier.shifts`). Closing publishes `ShiftClosed` through the transactional outbox (consumed by analytics `cash-gaps`). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

> Response quirk: `list`, `open` and `cash` return the raw shift object, where money fields are objects `{ "amount": <number> }` (`opening_cash`, `cash_sales`, `cash_refunds`, `actual_cash`) and `opened_at`/`closed_at` are ISO-8601 UTC strings. `close` returns a flattened object with plain numbers.

Formula: `expected_cash = opening_cash + cash_sales − cash_refunds`; `discrepancy = actual_cash − expected_cash`.

Gateway path: `/api/v1/cashier/shifts...`

## 1. List shifts

### Endpoint description

Plain JSON array of all shifts (open and closed).

### Endpoint name

`GET /api/v1/cashier/shifts`

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
GET /api/v1/cashier/shifts HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "e6f0d5c8-8003-4af7-a0c5-120d74275e67",
    "cashier_id": "c1",
    "opening_cash": { "amount": 1000.0 },
    "opened_at": "2026-11-11T11:16:25.791460+00:00",
    "cash_sales": { "amount": 300.0 },
    "cash_refunds": { "amount": 50.5 },
    "closed_at": null,
    "actual_cash": null
  }
]
```

### Error codes and messages

Only the common gateway/auth errors.

## 2. Open shift

### Endpoint description

Opens a shift for a cashier. Only one open shift per `cashier_id` is allowed. `cashier_id` is a free-form string (typically the identity user id). Responds `201`.

### Endpoint name

`POST /api/v1/cashier/shifts`

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
| `cashier_id` | string | yes | Cashier identifier |
| `opening_cash` | decimal | yes | ≥ 0 |

### Request example

```http
POST /api/v1/cashier/shifts HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "cashier_id": "c1", "opening_cash": "1000.00" }
```

### Response example (201)

```json
{
  "id": "e6f0d5c8-8003-4af7-a0c5-120d74275e67",
  "cashier_id": "c1",
  "opening_cash": { "amount": 1000.0 },
  "opened_at": "2026-11-11T11:16:25.791460+00:00",
  "cash_sales": { "amount": 0.0 },
  "cash_refunds": { "amount": 0.0 },
  "closed_at": null,
  "actual_cash": null
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 409 | `shift_already_open` | Cashier already has an open shift |
| 422 | – | Validation (`detail[]`) |

## 3. Record cash movement

### Endpoint description

Adds a cash sale (`refund: false`) or cash refund (`refund: true`) to an open shift. This is not linked automatically to `POST /sales/sales`; the FE must call it for cash payments.

### Endpoint name

`POST /api/v1/cashier/shifts/{shift_id}/cash`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `shift_id` | path | yes | Shift id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `amount` | decimal | yes | > 0 |
| `refund` | boolean | no | Default `false`; `true` = cash paid out |

### Request example

```http
POST /api/v1/cashier/shifts/e6f0d5c8-8003-4af7-a0c5-120d74275e67/cash HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "amount": "300.00", "refund": false }
```

### Response example (200)

```json
{
  "id": "e6f0d5c8-8003-4af7-a0c5-120d74275e67",
  "cashier_id": "c1",
  "opening_cash": { "amount": 1000.0 },
  "opened_at": "2026-11-11T11:16:25.791460+00:00",
  "cash_sales": { "amount": 300.0 },
  "cash_refunds": { "amount": 0.0 },
  "closed_at": null,
  "actual_cash": null
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `shift_not_found` | Shift not found |
| 409 | `shift_closed` | Shift is closed |
| 422 | – | Validation (`amount` ≤ 0, ...) |

## 4. Close shift

### Endpoint description

Closes the shift with the counted cash and returns expected cash and discrepancy. Publishes `ShiftClosed`.

### Endpoint name

`POST /api/v1/cashier/shifts/{shift_id}/close`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `shift_id` | path | yes | Shift id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `actual_cash` | decimal | yes | ≥ 0, counted cash in drawer |

### Request example

```http
POST /api/v1/cashier/shifts/e6f0d5c8-8003-4af7-a0c5-120d74275e67/close HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "actual_cash": "1245.00" }
```

### Response example (200)

```json
{
  "id": "e6f0d5c8-8003-4af7-a0c5-120d74275e67",
  "cashier_id": "c1",
  "opened_at": "2026-11-11T11:16:25.791460+00:00",
  "closed_at": "2026-11-11T11:16:25.824545+00:00",
  "expected_cash": 1249.5,
  "actual_cash": 1245.0,
  "discrepancy": -4.5
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `shift_not_found` | Shift not found |
| 409 | `shift_closed` | Shift is already closed |
| 422 | – | Validation (`detail[]`) |
