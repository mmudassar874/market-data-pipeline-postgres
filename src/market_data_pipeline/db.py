"""Database helpers for the public-safe PostgreSQL market-data demo."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

import psycopg

from market_data_pipeline.synthetic import SyntheticTick


PROJECT_ROOT = Path(__file__).resolve().parents[2]


def read_sql(relative_path: str) -> str:
    """Read a SQL file relative to the repository root."""

    return (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")


def reset_demo_schemas(conn: psycopg.Connection) -> None:
    """Drop demo schemas so integration tests can start from a clean state."""

    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA IF EXISTS raw CASCADE;")
        cur.execute("DROP SCHEMA IF EXISTS derived CASCADE;")
        cur.execute("DROP SCHEMA IF EXISTS audit CASCADE;")
        cur.execute("DROP SCHEMA IF EXISTS meta CASCADE;")


def apply_migrations(conn: psycopg.Connection) -> None:
    """Apply all SQL migrations in sorted order."""

    migrations_dir = PROJECT_ROOT / "sql" / "migrations"

    for migration_path in sorted(migrations_dir.glob("*.sql")):
        with conn.cursor() as cur:
            cur.execute(migration_path.read_text(encoding="utf-8"))


def execute_query_file(conn: psycopg.Connection, relative_path: str) -> None:
    """Execute a SQL file relative to the repository root."""

    with conn.cursor() as cur:
        cur.execute(read_sql(relative_path))


def create_ingestion_run(
    conn: psycopg.Connection,
    source_name: str,
    symbol: str,
) -> int:
    """Create a synthetic ingestion run and return its run_id."""

    with conn.cursor() as cur:
        row = cur.execute(
            """
            INSERT INTO meta.ingestion_runs (source_name, symbol)
            VALUES (%s, %s)
            RETURNING run_id;
            """,
            (source_name, symbol),
        ).fetchone()

    if row is None:
        raise RuntimeError("failed to create ingestion run")

    return int(row[0])


def insert_ticks(
    conn: psycopg.Connection,
    run_id: int,
    ticks: Iterable[SyntheticTick],
) -> int:
    """Insert synthetic ticks into raw.ticks."""

    tick_rows = [
        (run_id, tick.symbol, tick.ts, tick.bid, tick.ask)
        for tick in ticks
    ]

    if not tick_rows:
        return 0

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO raw.ticks (run_id, symbol, ts, bid, ask)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (symbol, ts, bid, ask) DO NOTHING;
            """,
            tick_rows,
        )

    return len(tick_rows)


def finish_ingestion_run(
    conn: psycopg.Connection,
    run_id: int,
    rows_received: int,
    rows_inserted: int,
    rows_rejected: int = 0,
    status: str = "completed",
) -> None:
    """Mark a synthetic ingestion run as finished."""

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE meta.ingestion_runs
            SET
                finished_at = now(),
                status = %s,
                rows_received = %s,
                rows_inserted = %s,
                rows_rejected = %s
            WHERE run_id = %s;
            """,
            (
                status,
                rows_received,
                rows_inserted,
                rows_rejected,
                run_id,
            ),
        )


def build_bars(conn: psycopg.Connection) -> None:
    """Build 1-minute and 15-minute bars from synthetic ticks."""

    execute_query_file(conn, "sql/queries/build_1m_bars.sql")
    execute_query_file(conn, "sql/queries/build_15m_bars.sql")


def count_rows(conn: psycopg.Connection, qualified_table: str) -> int:
    """Return row count from a known demo table."""

    allowed_tables = {
        "raw.ticks",
        "derived.bars_1m",
        "derived.bars_15m",
        "meta.ingestion_runs",
        "audit.data_quality_audits",
    }

    if qualified_table not in allowed_tables:
        raise ValueError(f"table is not allowlisted: {qualified_table}")

    with conn.cursor() as cur:
        row = cur.execute(f"SELECT COUNT(*) FROM {qualified_table};").fetchone()

    if row is None:
        raise RuntimeError(f"failed to count rows from {qualified_table}")

    return int(row[0])
