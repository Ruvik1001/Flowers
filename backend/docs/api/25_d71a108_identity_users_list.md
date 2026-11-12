# Identity list users

Short description: List staff users for the admin desk (`GET /users`). Complements create-user / roles docs in `06_battlepersist_identity_users_roles.md`.

Requires bootstrap admin or permission `identity.users.write` (gateway RBAC uses the same permission for GET and POST users).

## 1. List users

### Endpoint description

Returns `{ "items": [...] }` sorted by email. Each item includes role names resolved from `role_ids`.

### Endpoint name

`GET /api/v1/identity/users`

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
GET /api/v1/identity/users HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "items": [
    {
      "id": "b56e116c-63ce-4142-9b09-f4b49776d628",
      "email": "admin@flowers.local",
      "is_admin": true,
      "is_active": true,
      "role_ids": [],
      "roles": []
    },
    {
      "id": "c1a2b3c4-d5e6-7890-abcd-ef1234567890",
      "email": "cashier1@flowers.local",
      "is_admin": false,
      "is_active": true,
      "role_ids": ["7af74722-add3-4580-85da-6fe379cd2d6c"],
      "roles": ["cashier"]
    }
  ]
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 403 | `forbidden` | Admin or identity.users.write required |
