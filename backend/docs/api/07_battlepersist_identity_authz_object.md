# Identity object-level authorization check

Short description: Ask whether the current user may access a concrete resource (object-level ACL).

## Endpoint description

Evaluates the caller's `object_scopes` (stored on the user) for `resource_type` / `resource_id`. Admins always pass. A scope list containing `"*"` or the exact id passes. Intended for FE guards (e.g. hide a shift the cashier does not own). Note: downstream business services do **not** call this automatically – the FE/BFF should use it when object scoping matters.

## Endpoint name

`GET /api/v1/identity/authz/object/{resource_type}/{resource_id}`

## Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

## Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `resource_type` | path | yes | Scope key, e.g. `cash_shift`, `sale` |
| `resource_id` | path | yes | Resource id or any string |

## Accepted body

None.

## Request example

```http
GET /api/v1/identity/authz/object/cash_shift/6f3a1c52 HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

## Response example (200)

```json
{ "allowed": true }
```

Denied (403):

```json
{
  "code": "object_forbidden",
  "message": "No access to sale:abc",
  "details": { "resource_type": "sale", "resource_id": "abc" }
}
```

## Error codes and messages

| HTTP | code | message |
|---|---|---|
| 401 | `missing_token` | Bearer access token required |
| 401 | `invalid_token` | Token is invalid or expired |
| 403 | `object_forbidden` | No access to {resource_type}:{resource_id} |
| 404 | `user_not_found` | User not found |
| 502 | `upstream_unavailable` | identity service unavailable |
