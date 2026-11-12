# Backend gaps for FE (priority)

Tracked for the backend team. Frontend currently uses workarounds where possible.

1. **Pagination / search / sort** on list endpoints (products, sales, lots, supplies, shifts, assemblies). Today FE loads full arrays.
2. **Sale ↔ shift linkage** — accept `shift_id` on `POST /sales/sales` and record cash atomically (today FE must call `POST /cashier/shifts/{id}/cash` separately).
3. **Product images** — attach `image_ids` (files service) to catalog products for staff UI.
4. **Propagate `409 insufficient_stock`** from inventory through sales/assembly instead of gateway `500 internal_error`.
5. Nice-to-have later: `GET /identity/users`, update endpoints, get-by-id.

Out of scope (confirmed): B2C cart/storefront, self-signup, offline, push.
