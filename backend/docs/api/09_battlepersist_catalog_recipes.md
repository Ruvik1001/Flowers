# Catalog recipes

Short description: List, create and archive bouquet recipes (component lists for a bouquet product).

Recipes are persisted in Postgres (`catalog.recipes`). Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

> Response quirk: recipes are serialized directly from the domain object, so `items[].quantity` is a JSON **number** (e.g. `5`), unlike product `sell_price` which is a string.

## 1. List recipes

### Endpoint description

Plain JSON array. Archived recipes are hidden unless `include_archived=true`.

### Endpoint name

`GET /api/v1/catalog/recipes`

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
GET /api/v1/catalog/recipes HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[
  {
    "id": "d2b26e51-59d9-4396-8fd6-626ab1399835",
    "bouquet_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
    "items": [
      { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": 5 }
    ],
    "archived": false
  }
]
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 422 | – | Validation (`detail[]`) |

## 2. Create recipe

### Endpoint description

Creates a recipe for an existing product of kind `bouquet`. All component products must exist. Responds `201`.

### Endpoint name

`POST /api/v1/catalog/recipes`

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
| `bouquet_id` | string | yes | Product id with `kind = "bouquet"` |
| `items` | array | yes | min 1 element |
| `items[].product_id` | string | yes | Existing product id |
| `items[].quantity` | decimal | yes | > 0 |

### Request example

```http
POST /api/v1/catalog/recipes HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "bouquet_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
  "items": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "5" }
  ]
}
```

### Response example (201)

```json
{
  "id": "d2b26e51-59d9-4396-8fd6-626ab1399835",
  "bouquet_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
  "items": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": 5 }
  ],
  "archived": false
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `invalid_bouquet` | Recipe target must be a bouquet |
| 400 | `invalid_recipe` | Recipe requires valid positive components |
| 422 | – | Validation (empty `items`, `quantity` ≤ 0, ...) |

## 3. Archive recipe

### Endpoint description

Sets `archived: true`.

### Endpoint name

`POST /api/v1/catalog/recipes/{recipe_id}/archive`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `recipe_id` | path | yes | Recipe id |

### Accepted body

None.

### Request example

```http
POST /api/v1/catalog/recipes/d2b26e51-59d9-4396-8fd6-626ab1399835/archive HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "id": "d2b26e51-59d9-4396-8fd6-626ab1399835",
  "bouquet_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
  "items": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": 5 }
  ],
  "archived": true
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `recipe_not_found` | Recipe not found |
