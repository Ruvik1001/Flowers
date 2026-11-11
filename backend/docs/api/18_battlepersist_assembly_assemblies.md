# Assembly (bouquets)

Short description: List assemblies and assemble bouquets from stock components.

Persisted in Postgres (`assembly.assemblies`). Assembling consumes every component FIFO from inventory (HTTP), receives the finished bouquet as a new lot (unit cost = total component cost / bouquet quantity) and publishes `AssemblyCompleted` through the transactional outbox. Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

Gateway path: `/api/v1/assembly/assemblies`.

> Response quirk: serialized from the domain object. `quantity` fields are JSON numbers, `cost` is `{ "amount": <number> }`, while `allocations[]` values come from inventory and are strings.

## 1. List assemblies

### Endpoint description

Plain JSON array of all assemblies.

### Endpoint name

`GET /api/v1/assembly/assemblies`

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
GET /api/v1/assembly/assemblies HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
[]
```

(See the `201` example below for the item shape.)

### Error codes and messages

Only the common gateway/auth errors.

## 2. Create assembly

### Endpoint description

Builds `quantity` bouquets. For every component the service consumes `component.quantity × quantity` units. `kind = "recipe"` requires `recipe_id` (the recipe is **not** loaded or compared to `components` – the FE sends the resolved component list); `kind = "free"` is a free-form bouquet. Responds `201`.

### Endpoint name

`POST /api/v1/assembly/assemblies`

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
| `bouquet_product_id` | string | yes | Product id of the finished bouquet |
| `quantity` | decimal | yes | > 0, number of bouquets |
| `kind` | enum | yes | `recipe` \| `free` |
| `recipe_id` | string \| null | required if `kind=recipe` | Catalog recipe id |
| `components` | array | yes | min 1 |
| `components[].product_id` | string | yes | Component product id |
| `components[].quantity` | decimal | yes | > 0, per one bouquet |

### Request example

```http
POST /api/v1/assembly/assemblies HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "bouquet_product_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
  "quantity": "2",
  "kind": "recipe",
  "recipe_id": "d2b26e51-59d9-4396-8fd6-626ab1399835",
  "components": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": "5" }
  ]
}
```

### Response example (201)

```json
{
  "id": "7e2d5d3b-1b88-4c5b-a1c0-9d3a6a6c4f33",
  "bouquet_product_id": "a0f2386d-2398-4c4c-a623-4e423963c850",
  "quantity": 2,
  "kind": "recipe",
  "components": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25", "quantity": 5 }
  ],
  "recipe_id": "d2b26e51-59d9-4396-8fd6-626ab1399835",
  "cost": { "amount": 400.0 },
  "allocations": [
    { "product_id": "882dcff1-b5bd-41e9-867f-c3c5a1a70a25",
      "lot_id": "296587f4-a7bb-4719-8261-73d37eecc8a0", "quantity": "10", "unit_cost": "40.00" }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 400 | `recipe_required` | Recipe assembly requires recipe_id |
| 400 | `invalid_components` | Assembly requires positive components |
| 422 | – | Validation (`quantity` ≤ 0, empty `components`, bad `kind`) |
| 500 | `internal_error` | Inventory call failed – **insufficient stock is currently surfaced as 500** (inventory `409` is not translated). Components consumed before the failing one are not rolled back. |
