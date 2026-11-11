"""Alembic environment for the central Flowers database.

URL precedence: ``config.attributes["database_url"]`` > ``DATABASE_URL`` env > alembic.ini.
Models metadata is imported from ``shared.persistence.models`` when the shared package
is installed (needed for autogenerate); migrations themselves do not require it.
"""

from __future__ import annotations

import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool, text

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name, disable_existing_loggers=False)

try:  # shared may be absent in the slim migrate container
    from shared.persistence.models import Base

    target_metadata = Base.metadata
except ImportError:  # pragma: no cover
    target_metadata = None

# Arbitrary constant: serializes concurrent `upgrade` runs (service boots + migrate job).
_ADVISORY_LOCK_ID = 7_251_001


def _database_url() -> str:
    url = (
        config.attributes.get("database_url")
        or os.getenv("DATABASE_URL")
        or config.get_main_option("sqlalchemy.url")
    )
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    if url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://") :]
    return url


def run_migrations_offline() -> None:
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(_database_url(), poolclass=pool.NullPool, future=True)
    with engine.connect() as connection:
        is_pg = connection.dialect.name == "postgresql"
        if is_pg:
            connection.execute(text("SELECT pg_advisory_lock(:id)"), {"id": _ADVISORY_LOCK_ID})
            connection.commit()
        try:
            context.configure(
                connection=connection,
                target_metadata=target_metadata,
                include_schemas=True,
            )
            with context.begin_transaction():
                context.run_migrations()
        finally:
            if is_pg:
                connection.rollback()
                connection.execute(text("SELECT pg_advisory_unlock(:id)"), {"id": _ADVISORY_LOCK_ID})
                connection.commit()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
