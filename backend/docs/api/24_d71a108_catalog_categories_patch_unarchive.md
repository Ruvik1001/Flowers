# Catalog categories, product PATCH, unarchive

Short description: Category CRUD (archive/unarchive), optional `category_id` on products, PATCH product fields, and restore archived products/recipes.

`kind` remains the product type (`flower` / `material` / `bouquet`). Categories are a separate grouping (e.g. «Розы»). Gateway paths under `/api/v1/catalog/...`. Common gateway errors apply – see `22_battlepersist_common_errors.md`.

## 1. List categories

### Endpoint description

Plain JSON array of categories. Archived hidden unless `include_archived=true`.

### Endpoint name

`GET /api/v1/catalog/categories`

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
GET /api/v1/catalog/categories HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  { "id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6", "name": "Розы", "archived": false }
]
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`) |

## 2. Create category

### Endpoint description

Creates a category. Responds `201`.

### Endpoint name

`POST /api/v1/catalog/categories`

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
| `name` | string | yes | Non-empty display name |

### Request example

```http
POST /api/v1/catalog/categories HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "name": "Розы" }
```

### Response example (201)

```json
{ "id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6", "name": "Розы", "archived": false }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`) |

## 3. Archive / unarchive category

### Endpoint description

Soft-archive or restore a category.

### Endpoint name

`POST /api/v1/catalog/categories/{category_id}/archive`  
`POST /api/v1/catalog/categories/{category_id}/unarchive`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `category_id` | path | yes | Category id |

### Accepted body

None.

### Request example

```http
POST /api/v1/catalog/categories/7c000676-d905-4f7b-a715-6ce4ebafbfa6/archive HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{ "id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6", "name": "Розы", "archived": true }
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `category_not_found` | Category not found |

## 4. PATCH product

### Endpoint description

Partial update of `name`, `kind`, `sell_price`, `category_id` without recreating the product. Omitting a field leaves it unchanged; sending `"category_id": null` clears the category.

Product create/list responses now include nullable `category_id`.

### Endpoint name

`PATCH /api/v1/catalog/products/{product_id}`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `product_id` | path | yes | Product id |

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | no | Display name |
| `kind` | string | no | `flower` \| `material` \| `bouquet` |
| `sell_price` | decimal string | no | ≥ 0 |
| `category_id` | string \| null | no | Existing category or `null` to clear |

### Request example

```http
PATCH /api/v1/catalog/products/a9ef6c76-d223-423e-b4d1-c24ff97008e3 HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{ "sell_price": "130.00", "category_id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6" }
```

### Response example (200)

```json
{
  "id": "a9ef6c76-d223-423e-b4d1-c24ff97008e3",
  "name": "Smoke Rose",
  "kind": "flower",
  "sell_price": "130.00",
  "archived": false,
  "category_id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6"
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `product_not_found` | Product not found |
| 404 | `category_not_found` | Category not found |
| 422 | – | Validation (`detail[]`) |

## 5. Unarchive product / recipe

### Endpoint description

Restores an archived product or recipe (`archived=false`).

### Endpoint name

`POST /api/v1/catalog/products/{product_id}/unarchive`  
`POST /api/v1/catalog/recipes/{recipe_id}/unarchive`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `product_id` / `recipe_id` | path | yes | Entity id |

### Accepted body

None.

### Request example

```http
POST /api/v1/catalog/products/a9ef6c76-d223-423e-b4d1-c24ff97008e3/unarchive HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "id": "a9ef6c76-d223-423e-b4d1-c24ff97008e3",
  "name": "Smoke Rose",
  "kind": "flower",
  "sell_price": "130.00",
  "archived": false,
  "category_id": "7c000676-d905-4f7b-a715-6ce4ebafbfa6"
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `product_not_found` / `recipe_not_found` | Entity not found |
