from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def read_sql(path: str) -> str:
    return (PROJECT_ROOT / path).read_text(encoding="utf-8").lower()


def test_schema_migration_defines_expected_schemas_and_tables():
    sql = read_sql("sql/migrations/001_create_schema.sql")

    assert "create schema if not exists raw" in sql
    assert "create schema if not exists derived" in sql
    assert "create schema if not exists audit" in sql
    assert "create schema if not exists meta" in sql
    assert "create table if not exists raw.ticks" in sql
    assert "create table if not exists derived.bars_1m" in sql
    assert "create table if not exists derived.bars_15m" in sql
    assert "create table if not exists audit.data_quality_audits" in sql


def test_schema_migration_contains_time_series_indexes():
    sql = read_sql("sql/migrations/001_create_schema.sql")

    assert "idx_raw_ticks_symbol_ts" in sql
    assert "idx_raw_ticks_ts_brin" in sql
    assert "idx_bars_1m_symbol_ts" in sql
    assert "idx_bars_15m_symbol_ts" in sql


def test_bar_builder_queries_target_expected_tables():
    build_1m = read_sql("sql/queries/build_1m_bars.sql")
    build_15m = read_sql("sql/queries/build_15m_bars.sql")

    assert "from raw.ticks" in build_1m
    assert "insert into derived.bars_1m" in build_1m
    assert "from derived.bars_1m" in build_15m
    assert "insert into derived.bars_15m" in build_15m


def test_quality_queries_are_public_safe():
    combined_sql = "\n".join(
        [
            read_sql("sql/queries/detect_tick_gaps.sql"),
            read_sql("sql/queries/data_quality_summary.sql"),
        ]
    )

    forbidden_terms = [
        "password",
        "api_key",
        "secret",
        "broker_login",
        "account_number",
        "db_url",
        "db_conn_str",
    ]

    for term in forbidden_terms:
        assert term not in combined_sql
