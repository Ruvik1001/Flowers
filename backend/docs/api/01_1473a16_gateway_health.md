# Gateway health

Short description: Public health probe for the Flowers API gateway.

## Endpoint description

Returns service liveness for load balancers and local smoke checks. Does not require authentication.

## Endpoint name

`GET /api/v1/health`

## Accepted headers

| Header | Required | Description |
|---|---|---|
| `X-Request-Id` | no | Correlation id; generated if omitted |

## Accepted fields / params

None.

## Accepted body

None.

## Request example

```http
GET /api/v1/health HTTP/1.1
Host: localhost:8080
```

## Response example

```json
{
  "status": "ok",
  "service": "gateway"
}
```

## Error codes and messages

| HTTP | code | message |
|---|---|---|
| 500 | `internal_error` | Internal server error |
