# Identity token refresh

Short description: Exchange a refresh token for a new access/refresh token pair.

## Endpoint description

Public route (no Bearer token). The body must contain a valid **refresh** token issued by `auth/login` or a previous refresh. An access token is rejected with `invalid_token_type`. The user is re-read from storage, so changed roles/permissions are reflected in the new access token. Refresh tokens are not rotated server-side (the old one stays valid until `exp`).

Default lifetimes: access token 30 min, refresh token 14 days (configurable via identity settings).

## Endpoint name

`POST /api/v1/identity/auth/refresh`

## Accepted headers

| Header | Required | Description |
|---|---|---|
| `Content-Type` | yes | `application/json` |
| `X-Request-Id` | no | Correlation id |

## Accepted fields / params

None.

## Accepted body

| Field | Type | Required | Description |
|---|---|---|---|
| `refresh_token` | string | yes | JWT of type `refresh` |

## Request example

```http
POST /api/v1/identity/auth/refresh HTTP/1.1
Host: localhost:8080
Content-Type: application/json

{ "refresh_token": "<refresh_jwt>" }
```

## Response example (200)

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
| 401 | `invalid_token` | Token is invalid or expired |
| 401 | `invalid_token_type` | Unexpected token type |
| 404 | `user_not_found` | User not found |
| 422 | – | FastAPI validation body `{"detail": [...]}` (missing `refresh_token`) |
| 502 | `upstream_unavailable` | identity service unavailable |
| 500 | `internal_error` | Internal server error |
