# Identity login

Short description: Exchange employee credentials for JWT access/refresh tokens via gateway.

## Endpoint description

Authenticates a staff user created by admin. Public route (no Bearer token). On success returns access and refresh tokens for subsequent gateway calls.

## Endpoint name

`POST /api/v1/identity/auth/login`

## Accepted headers

| Header | Required | Description |
|---|---|---|
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

## Accepted fields / params

None (no query/path params).

## Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `email` | string | yes | Employee email |
| `password` | string | yes | Employee password |

## Request example

```http
POST /api/v1/identity/auth/login HTTP/1.1
Host: localhost:8080
Content-Type: application/json

{
  "email": "admin@flowers.local",
  "password": "admin12345"
}
```

## Response example

```json
{
  "access_token": "<jwt>",
  "refresh_token": "<jwt>",
  "token_type": "bearer"
}
```

## Error codes and messages

| HTTP | code | message |
|---|---|---|
| 401 | `invalid_credentials` | Invalid email or password |
| 401 | `invalid_token` | Token is invalid or expired |
| 502 | `upstream_unavailable` | identity service unavailable |
| 500 | `internal_error` | Internal server error |
