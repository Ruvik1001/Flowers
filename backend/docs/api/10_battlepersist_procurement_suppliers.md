# Procurement suppliers

Short description: List and create suppliers.

Persisted in Postgres (`procurement.suppliers`). No update/delete routes. Gateway-level errors (`401 missing_token|invalid_token|invalid_token_type`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

## 1. List suppliers

### Endpoint description

Returns a plain JSON array of all suppliers.

### Endpoint name

`GET /api/v1/procurement/suppliers`

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
GET /api/v1/procurement/suppliers HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  { "id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11", "name": "Garden LLC", "phone": "+7 900 000-00-00" }
]
```

### Error codes and messages

Only the common gateway/auth errors.

## 2. Create supplier

### Endpoint description

Creates a supplier. Responds `201`.

### Endpoint name

`POST /api/v1/procurement/suppliers`

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
| `name` | string | yes | Supplier name |
| `phone` | string \| null | no | Contact phone |

### Request example

```http
POST /api/v1/procurement/suppliers HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "name": "Garden LLC", "phone": "+7 900 000-00-00" }
```

### Response example (201)

```json
{ "id": "3a8f0c1e-6d55-4b0e-9f1a-2d6a7c9d0e11", "name": "Garden LLC", "phone": "+7 900 000-00-00" }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`), e.g. missing `name` |
