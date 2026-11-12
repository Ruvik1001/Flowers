# Files (photo evidence)

Short description: Upload an image, download it, or read its metadata.

Metadata is persisted in Postgres (`files.objects`); binary content lives on the `uploads` volume (`UPLOAD_DIR`, default 5 MB limit via `MAX_UPLOAD_BYTES`). Uploaded ids are used as `photo_ids` for write-offs and defect refunds. Gateway-level errors (`401`, `429`, `502`, `500`) apply – see `22_battlepersist_common_errors.md`.

Gateway path repeats the service name: `/api/v1/files/files...`.

Allowed types: `image/jpeg`, `image/png`, `image/webp` – the part's `Content-Type` must be one of these **and** the file magic bytes must match.

## 1. Upload file

### Endpoint description

Multipart upload of a single image. Responds `201` with metadata (the server path is never exposed).

### Endpoint name

`POST /api/v1/files/files`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `Content-Type` | yes | `multipart/form-data; boundary=...` (set by the HTTP client) |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

None.

### Accepted body

Multipart form:

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | binary | yes | JPEG/PNG/WebP, ≤ 5 MB |

### Request example

```http
POST /api/v1/files/files HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
Content-Type: multipart/form-data; boundary=----flowers

------flowers
Content-Disposition: form-data; name="file"; filename="wilted.jpg"
Content-Type: image/jpeg

<binary>
------flowers--
```

```bash
curl -H "Authorization: Bearer $TOKEN" -F "file=@wilted.jpg;type=image/jpeg" \
  http://localhost:8080/api/v1/files/files
```

### Response example (201)

```json
{
  "id": "8599abce-d348-4fe6-b66a-b6762f936d81",
  "original_name": "wilted.jpg",
  "content_type": "image/jpeg",
  "size": 48213
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 413 | `file_too_large` | File exceeds 5MB limit |
| 415 | `invalid_file_type` | Only JPEG, PNG and WebP images are allowed |
| 422 | – | Validation (`detail[]`): `file` part missing |

## 2. Download file

### Endpoint description

Returns the raw image bytes with the stored `Content-Type` and a `Content-Disposition` carrying the original file name.

### Endpoint name

`GET /api/v1/files/files/{file_id}`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` – browsers cannot send it via `<img src>`; fetch as a blob |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `file_id` | path | yes | File id from upload |

### Accepted body

None.

### Request example

```http
GET /api/v1/files/files/8599abce-d348-4fe6-b66a-b6762f936d81 HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```http
HTTP/1.1 200 OK
Content-Type: image/jpeg
Content-Disposition: attachment; filename="wilted.jpg"

<binary>
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `file_not_found` | File not found (unknown id or file missing on disk) |

## 3. File metadata

### Endpoint description

Returns the metadata JSON without the binary.

### Endpoint name

`GET /api/v1/files/files/{file_id}/metadata`

### Accepted headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | yes | `Bearer <access_token>` |
| `X-Request-Id` | no | Correlation id |

### Accepted fields / params

| Param | In | Required | Description |
|---|---|---|---|
| `file_id` | path | yes | File id |

### Accepted body

None.

### Request example

```http
GET /api/v1/files/files/8599abce-d348-4fe6-b66a-b6762f936d81/metadata HTTP/1.1
Host: localhost:8080
Authorization: Bearer <access_token>
```

### Response example (200)

```json
{
  "id": "8599abce-d348-4fe6-b66a-b6762f936d81",
  "original_name": "wilted.jpg",
  "content_type": "image/jpeg",
  "size": 48213
}
```

### Error codes and messages

| HTTP | code | message |
|---|---|---|
| 404 | `file_not_found` | File not found |
