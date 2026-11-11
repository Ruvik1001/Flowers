# Catalog products

Short description: List, create and archive sellable products (flowers, materials, bouquets).

Products are persisted in Postgres (`catalog.products`). There is no hard delete; "delete" is `archive`. There is no update/get-by-id route.

All routes need `Authorization: Bearer <access_token>`. Gateway-level errors (`401 missing_token|invalid_token|invalid_token_type`, `429 rate_limited`, `502 upstream_unavailable`, `500 internal_error`) apply to every endpoint – see `22_battlepersist_common_errors.md`. Downstream services do not check permissions: any valid access token works.

`kind` enum: `flower`, `material`, `bouquet`. `sell_price` is returned as a **string** with two decimals.

## 1. List products

### Endpoint description

Returns a plain JSON array. Archived products are hidden unless `include_archived=true`.

### Endpoint name

`GET /api/v1/catalog/products`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `include_archived` | query | no | boolean, default `false` |

### Accepted body

None.

### Request example

```http
GET /api/v1/catalog/products?include_archived=true HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  { "id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "name": "Rose", "kind": "flower", "sell_price": "150.00", "archived": true },
  { "id": "a0f2386d-2398-4c4c-a623-4e423963c850", "name": "Spring bouquet", "kind": "bouquet", "sell_price": "1500.00", "archived": false }
]
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`), e.g. non-boolean `include_archived` |

## 2. Create product

### Endpoint description

Creates a product. Responds `201`.

### Endpoint name

`POST /api/v1/catalog/products`

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
| `name` | string | yes | Display name |
| `kind` | enum | yes | `flower` \| `material` \| `bouquet` |
| `sell_price` | decimal (string or number) | yes | ≥ 0; rounded to 2 decimals (RUB) |

### Request example

```http
POST /api/v1/catalog/products HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "name": "Rose", "kind": "flower", "sell_price": "150.00" }
```

### Response example (201)

```json
{
  "id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "name": "Rose",
  "kind": "flower",
  "sell_price": "150.00",
  "archived": false
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation, e.g. `kind` not in enum, `sell_price` < 0 (`detail[]`) |

## 3. Archive product

### Endpoint description

Marks a product `archived: true` (idempotent). Archived products stay referenced by lots, sales and recipes.

### Endpoint name

`POST /api/v1/catalog/products/{product_id}/archive`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `product_id` | path | yes | Product id |

### Accepted body

None.

### Request example

```http
POST /api/v1/catalog/products/882dcff1-b5bd-41e9-867f-c3c5a1a70a25/archive HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
  "name": "Rose",
  "kind": "flower",
  "sell_price": "150.00",
  "archived": true
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `product_not_found` | Product not found |
