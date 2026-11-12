"""Add catalog.categories and products.category_id.

Revision ID: 0002
Revises: 0001
"""

from __future__ import annotations

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS catalog.categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            archived BOOLEAN NOT NULL DEFAULT FALSE
        )
        """
    )
    op.execute(
        """
        ALTER TABLE catalog.products
        ADD COLUMN IF NOT EXISTS category_id TEXT NULL
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE catalog.products DROP COLUMN IF EXISTS category_id")
    op.execute("DROP TABLE IF EXISTS catalog.categories")
