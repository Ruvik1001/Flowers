# Inventory lot patch/delete and folders

Short description: Edit or delete lots; organize lots into warehouse folders.

Gateway RBAC: `PATCH` needs `inventory.write` or `inventory.write_off`; `DELETE` needs `inventory.write`.

## PATCH `/api/v1/inventory/lots/{lot_id}`

Body (all optional): `quantity` (≥0), `unit_cost`, `expires_on`, `clear_expires_on`, `folder_id`, `clear_folder`, `sort_order`.

Qty changes publish `STOCK_CHANGED` with delta (`reason=adjust`).

## DELETE `/api/v1/inventory/lots/{lot_id}`

Responds `204`. If qty > 0, publishes `STOCK_CHANGED` (`reason=delete`).

## Folders

| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/inventory/folders` | `include_archived` optional |
| POST | `/api/v1/inventory/folders` | `{ "name", "sort_order?" }` → 201 |
| PATCH | `/api/v1/inventory/folders/{id}` | name / sort_order |
| POST | `/api/v1/inventory/folders/{id}/archive` | clears `folder_id` on lots |

Lot responses include `folder_id` and `sort_order`. FIFO consume ignores folder/sort.
