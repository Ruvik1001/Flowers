"""Add inventory.folders and lot folder/sort columns.

Revision ID: 0003
Revises: 0002
"""

from __future__ import annotations

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS inventory.folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            archived BOOLEAN NOT NULL DEFAULT FALSE
        )
        """
    )
    op.execute(
        """
        ALTER TABLE inventory.lots
        ADD COLUMN IF NOT EXISTS folder_id TEXT NULL
        """
    )
    op.execute(
        """
        ALTER TABLE inventory.lots
        ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_lots_folder_id
        ON inventory.lots (folder_id)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS inventory.ix_lots_folder_id")
    op.execute("ALTER TABLE inventory.lots DROP COLUMN IF EXISTS sort_order")
    op.execute("ALTER TABLE inventory.lots DROP COLUMN IF EXISTS folder_id")
    op.execute("DROP TABLE IF EXISTS inventory.folders")
