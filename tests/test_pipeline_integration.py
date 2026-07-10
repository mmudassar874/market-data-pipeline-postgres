import os

import pytest


TEST_DATABASE_URL = os.getenv("MARKET_DATA_TEST_DATABASE_URL")


@pytest.mark.skipif(
    not TEST_DATABASE_URL,
    reason="MARKET_DATA_TEST_DATABASE_URL is not set",
)
def test_full_market_data_pipeline_with_postgres():
    pytest.importorskip("psycopg")

    from market_data_pipeline.db import (
        apply_migrations,
        build_bars,
        count_rows,
        create_ingestion_run,
        finish_ingestion_run,
        insert_ticks,
        reset_demo_schemas,
    )
    from market_data_pipeline.synthetic import generate_synthetic_ticks
    import psycopg

    ticks = generate_synthetic_ticks(minutes=30, ticks_per_minute=4)

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        reset_demo_schemas(conn)
        apply_migrations(conn)

        run_id = create_ingestion_run(
            conn,
            source_name="synthetic_test_generator",
            symbol="SYNTH_XAUUSD",
        )

        inserted_count = insert_ticks(conn, run_id=run_id, ticks=ticks)

        finish_ingestion_run(
            conn,
            run_id=run_id,
            rows_received=len(ticks),
            rows_inserted=inserted_count,
        )

        build_bars(conn)

        assert count_rows(conn, "meta.ingestion_runs") == 1
        assert count_rows(conn, "raw.ticks") == 120
        assert count_rows(conn, "derived.bars_1m") == 30
        assert count_rows(conn, "derived.bars_15m") == 2
