-- Flowers MVP schema bootstrap (applied on first Postgres init)
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS procurement;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS assembly;
CREATE SCHEMA IF NOT EXISTS sales;
CREATE SCHEMA IF NOT EXISTS cashier;
CREATE SCHEMA IF NOT EXISTS files;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS messaging;

-- identity
CREATE TABLE IF NOT EXISTS identity.roles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    permissions JSONB NOT NULL DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS identity.users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    role_ids JSONB NOT NULL DEFAULT '[]',
    object_scopes JSONB NOT NULL DEFAULT '{}'
);

-- catalog
CREATE TABLE IF NOT EXISTS catalog.categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS catalog.products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    sell_price NUMERIC(12,2) NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    category_id TEXT NULL
);

CREATE TABLE IF NOT EXISTS catalog.recipes (
    id TEXT PRIMARY KEY,
    bouquet_id TEXT NOT NULL,
    items JSONB NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT FALSE
);

-- procurement
CREATE TABLE IF NOT EXISTS procurement.suppliers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS procurement.supplies (
    id TEXT PRIMARY KEY,
    supplier_id TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'
);

-- inventory
CREATE TABLE IF NOT EXISTS inventory.lots (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    unit_cost NUMERIC(12,2) NOT NULL,
    received_at TIMESTAMPTZ NOT NULL,
    expires_on DATE NULL
);

CREATE INDEX IF NOT EXISTS ix_lots_product_id
    ON inventory.lots (product_id);

CREATE TABLE IF NOT EXISTS inventory.write_offs (
    id TEXT PRIMARY KEY,
    payload JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS inventory.counts (
    id TEXT PRIMARY KEY,
    payload JSONB NOT NULL
);

-- assembly
CREATE TABLE IF NOT EXISTS assembly.assemblies (
    id TEXT PRIMARY KEY,
    payload JSONB NOT NULL
);

-- sales
CREATE TABLE IF NOT EXISTS sales.sales (
    id TEXT PRIMARY KEY,
    payload JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS sales.refunds (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_refunds_sale_id
    ON sales.refunds (sale_id);

-- cashier
CREATE TABLE IF NOT EXISTS cashier.shifts (
    id TEXT PRIMARY KEY,
    payload JSONB NOT NULL
);

-- files
CREATE TABLE IF NOT EXISTS files.objects (
    id TEXT PRIMARY KEY,
    original_name TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size INTEGER NOT NULL,
    path TEXT NOT NULL
);

-- audit
CREATE TABLE IF NOT EXISTS audit.events (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    payload JSONB NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    idempotency_key TEXT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS audit_events_idempotency_uidx
    ON audit.events (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- analytics projections (simple key/value snapshots)
CREATE TABLE IF NOT EXISTS analytics.snapshots (
    name TEXT PRIMARY KEY,
    payload JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- messaging: transactional outbox shared by all services
CREATE TABLE IF NOT EXISTS messaging.outbox (
    id TEXT PRIMARY KEY,
    service_name TEXT NOT NULL,
    event_name TEXT NOT NULL,
    payload JSONB NOT NULL,
    idempotency_key TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS ix_outbox_service_name
    ON messaging.outbox (service_name);

CREATE UNIQUE INDEX IF NOT EXISTS outbox_idempotency_uidx
    ON messaging.outbox (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS outbox_unpublished_idx
    ON messaging.outbox (created_at)
    WHERE published_at IS NULL;
