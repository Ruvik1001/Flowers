# Frontend API docs

Files are added **after** commits that change FE-facing contracts.

Mask: `xx_<commit>_desc.md`

Required sections in each file:

1. Title
2. Short file description
3. Endpoint description
4. Endpoint name
5. Accepted headers (+ required)
6. Accepted fields/params (+ required)
7. Accepted body (+ required)
8. Request/response examples
9. Expected error codes and messages

Files `04`–`22` use the placeholder commit `battlepersist` (persistence/outbox work); rename them to the real hash once committed. Multi-endpoint files repeat sections 3–9 per endpoint.

Start with [`22_battlepersist_common_errors.md`](22_battlepersist_common_errors.md): routing (`/api/v1/{service}/...`), auth, headers, number formats and the error envelope.

Gateway base URL (local): `http://localhost:8080`. A ready-made Postman collection lives at [`../../postman/Flowers.postman_collection.json`](../../postman/Flowers.postman_collection.json) (variables `baseUrl`, `accessToken`; run **Auth Login** first – its test script stores the token).

## Index

| # | File | Service | Method + gateway path | Auth |
|---|---|---|---|---|
| 01 | [01_1473a16_gateway_health.md](01_1473a16_gateway_health.md) | gateway | `GET /api/v1/health` | public |
| 02 | [02_1473a16_auth_login.md](02_1473a16_auth_login.md) | identity | `POST /api/v1/identity/auth/login` | public |
| 03 | [03_1473a16_auth_me.md](03_1473a16_auth_me.md) | identity | `GET /api/v1/identity/auth/me` | Bearer |
| 04 | [04_battlepersist_health_ready.md](04_battlepersist_health_ready.md) | gateway + all | `GET /api/v1/ready`, `GET /api/v1/{service}/health`, `GET /api/v1/{service}/ready`, `GET /api/v1/identity/health` | gateway/identity health public; others Bearer |
| 05 | [05_battlepersist_identity_auth_refresh.md](05_battlepersist_identity_auth_refresh.md) | identity | `POST /api/v1/identity/auth/refresh` | public |
| 06 | [06_battlepersist_identity_users_roles.md](06_battlepersist_identity_users_roles.md) | identity | `POST /api/v1/identity/users`, `GET /api/v1/identity/roles`, `POST /api/v1/identity/roles` | Bearer (users/roles create: admin) |
| 07 | [07_battlepersist_identity_authz_object.md](07_battlepersist_identity_authz_object.md) | identity | `GET /api/v1/identity/authz/object/{resource_type}/{resource_id}` | Bearer |
| 08 | [08_battlepersist_catalog_products.md](08_battlepersist_catalog_products.md) | catalog | `GET/POST /api/v1/catalog/products`, `POST .../products/{id}/archive` | Bearer |
| 09 | [09_battlepersist_catalog_recipes.md](09_battlepersist_catalog_recipes.md) | catalog | `GET/POST /api/v1/catalog/recipes`, `POST .../recipes/{id}/archive` | Bearer |
| 10 | [10_battlepersist_procurement_suppliers.md](10_battlepersist_procurement_suppliers.md) | procurement | `GET/POST /api/v1/procurement/suppliers` | Bearer |
| 11 | [11_battlepersist_procurement_supplies.md](11_battlepersist_procurement_supplies.md) | procurement | `GET/POST /api/v1/procurement/supplies`, `POST .../supplies/{id}/accept` | Bearer |
| 12 | [12_battlepersist_inventory_lots.md](12_battlepersist_inventory_lots.md) | inventory | `GET/POST /api/v1/inventory/lots` | Bearer |
| 13 | [13_battlepersist_inventory_consume_expired.md](13_battlepersist_inventory_consume_expired.md) | inventory | `POST /api/v1/inventory/inventory/consume`, `GET /api/v1/inventory/inventory/expired` | Bearer |
| 14 | [14_battlepersist_inventory_writeoffs_counts.md](14_battlepersist_inventory_writeoffs_counts.md) | inventory | `POST /api/v1/inventory/write-offs`, `POST /api/v1/inventory/inventory-counts` | Bearer |
| 15 | [15_battlepersist_sales.md](15_battlepersist_sales.md) | sales | `GET/POST /api/v1/sales/sales` | Bearer |
| 16 | [16_battlepersist_sales_refunds.md](16_battlepersist_sales_refunds.md) | sales | `POST /api/v1/sales/sales/{id}/refunds` | Bearer |
| 17 | [17_battlepersist_cashier_shifts.md](17_battlepersist_cashier_shifts.md) | cashier | `GET/POST /api/v1/cashier/shifts`, `POST .../shifts/{id}/cash`, `POST .../shifts/{id}/close` | Bearer |
| 18 | [18_battlepersist_assembly_assemblies.md](18_battlepersist_assembly_assemblies.md) | assembly | `GET/POST /api/v1/assembly/assemblies` | Bearer |
| 19 | [19_battlepersist_files.md](19_battlepersist_files.md) | files | `POST /api/v1/files/files`, `GET .../files/{id}`, `GET .../files/{id}/metadata` | Bearer |
| 20 | [20_battlepersist_analytics_reports.md](20_battlepersist_analytics_reports.md) | analytics | `GET /api/v1/analytics/reports/{name}` | Bearer |
| 21 | [21_battlepersist_audit_list.md](21_battlepersist_audit_list.md) | audit | `GET /api/v1/audit/audit` | Bearer |
| 22 | [22_battlepersist_common_errors.md](22_battlepersist_common_errors.md) | all | Conventions, auth, error envelope | – |

## Not part of the FE contract

`POST /api/v1/analytics/internal/events`, `POST /api/v1/analytics/internal/drain`, `POST /api/v1/audit/internal/audit`, `POST /api/v1/audit/internal/drain` are ops/testing hooks (reachable through the gateway with any valid token). Do not use them from the frontend.
