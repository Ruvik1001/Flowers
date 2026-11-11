# Identity users and roles

Short description: Create staff users, list roles, create custom roles.

> There is **no** `GET /users` or user-update route yet; user creation is the only users endpoint. Users and roles are persisted in Postgres (`identity.users`, `identity.roles`) and survive restarts.

All routes require `Authorization: Bearer <access_token>`. Common error rows (not repeated per endpoint): `401 missing_token`, `401 invalid_token`, `401 invalid_token_type`, `429 rate_limited`, `502 upstream_unavailable`, `500 internal_error` (see `22_battlepersist_common_errors.md`).

Seeded roles (first start): `admin` and `owner` (`["*"]`), `florist`, `cashier`, `analyst`. The bootstrap admin (default `admin@flowers.local`, from `BOOTSTRAP_ADMIN_EMAIL`/`BOOTSTRAP_ADMIN_PASSWORD`) is created on startup.

Role ids are random UUIDs that differ per environment – resolve them via `GET /roles`, never hard-code.

## 1. Create user

### Endpoint description

Creates a staff user with roles and optional object-level scopes. Requires `is_admin` or permission `identity.users.write`. Email is lower-cased. Also emits `UserRoleChanged` through the outbox.

### Endpoint name

`POST /api/v1/identity/users`

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
| `email` | string | yes | Unique (case-insensitive) |
| `password` | string | yes | min length 8 |
| `role_ids` | string[] | yes | Existing role ids (may be empty) |
| `object_scopes` | object `{resource_type: [resource_id \| "*"]}` | no | Default `{}`; used by `authz/object` |

### Request example

```http
POST /api/v1/identity/users HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "email": "cashier1@flowers.local",
  "password": "password1",
  "role_ids": ["7af74722-add3-4580-85da-6fe379cd2d6c"],
  "object_scopes": { "cash_shift": ["*"] }
}
```

### Response example (200 — note: not 201)

```json
{
  "id": "b56e116c-63ce-4142-9b09-f4b49776d628",
  "email": "cashier1@flowers.local",
  "role_ids": ["7af74722-add3-4580-85da-6fe379cd2d6c"]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 403 | `forbidden` | Admin or identity.users.write required |
| 404 | `role_not_found` | Role {role_id} not found |
| 409 | `email_taken` | Email already registered |
| 422 | – | Validation (`detail[]`), e.g. password shorter than 8 |

## 2. List roles

### Endpoint description

Returns all roles for assignment UIs. Any authenticated user may call it (no permission check is enforced today).

### Endpoint name

`GET /api/v1/identity/roles`

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
GET /api/v1/identity/roles HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "items": [
    { "id": "7af26edc-89b4-4d3c-82c0-de4a939221ea", "name": "admin", "permissions": ["*"] },
    { "id": "7af74722-add3-4580-85da-6fe379cd2d6c", "name": "cashier",
      "permissions": ["sales.write", "sales.read", "cashier.write", "cashier.read", "catalog.read"] }
  ]
}
```

### Error codes and messages

Only the common auth/gateway errors listed at the top.

## 3. Create role

### Endpoint description

Creates a custom role. Admin only (`is_admin`).

### Endpoint name

`POST /api/v1/identity/roles`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` of an admin |
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

None.

### Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Unique role name |
| `permissions` | string[] | yes | e.g. `["sales.read", "catalog.read"]` or `["*"]` |

### Request example

```http
POST /api/v1/identity/roles HTTP/1.1
Host: localhost:8080
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{ "name": "shift_lead", "permissions": ["sales.read", "cashier.read"] }
```

### Response example (200)

```json
{
  "id": "f3737925-c12a-409c-bbfa-bd053df82474",
  "name": "shift_lead",
  "permissions": ["sales.read", "cashier.read"]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 403 | `forbidden` | Admin required |
| 409 | `role_exists` | Role already exists |
| 422 | – | Validation (`detail[]`) |
