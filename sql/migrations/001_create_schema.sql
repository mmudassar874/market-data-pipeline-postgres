-- Market Data Pipeline Postgres
-- Public-safe demo schema.
--
-- This migration uses synthetic/demo market data only.
-- It does not contain private AlphaQuant schemas, real tick data,
-- broker credentials, strategy thresholds, or production logic.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS derived;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS meta;

-- ============================================================
-- Ingestion run tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS meta.ingestion_runs (
    run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running',
    rows_received INTEGER NOT NULL DEFAULT 0,
    rows_inserted INTEGER NOT NULL DEFAULT 0,
    rows_rejected INTEGER NOT NULL DEFAULT 0,
    notes TEXT,

    CONSTRAINT chk_ingestion_status
        CHECK (status IN ('running', 'completed', 'failed')),

    CONSTRAINT chk_ingestion_row_counts
        CHECK (
            rows_received >= 0
            AND rows_inserted >= 0
            AND rows_rejected >= 0
        ),

    CONSTRAINT chk_ingestion_finished_after_started
        CHECK (
            finished_at IS NULL
            OR finished_at >= started_at
        )
);

COMMENT ON TABLE meta.ingestion_runs IS
'Tracks each synthetic market-data ingestion run for auditability.';

-- ============================================================
-- Raw tick table
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.ticks (
    tick_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES meta.ingestion_runs(run_id),
    symbol TEXT NOT NULL,
    ts TIMESTAMPTZ NOT NULL,
    bid NUMERIC(18, 8) NOT NULL,
    ask NUMERIC(18, 8) NOT NULL,
    mid NUMERIC(18, 8) GENERATED ALWAYS AS ((bid + ask) / 2.0) STORED,
    spread NUMERIC(18, 8) GENERATED ALWAYS AS (ask - bid) STORED,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_tick_positive_prices
        CHECK (bid > 0 AND ask > 0),

    CONSTRAINT chk_tick_ask_not_below_bid
        CHECK (ask >= bid),

    CONSTRAINT uq_tick_identity
        UNIQUE (symbol, ts, bid, ask)
);

COMMENT ON TABLE raw.ticks IS
'Public-safe synthetic tick table. Designed to demonstrate time-series market-data ingestion.';

CREATE INDEX IF NOT EXISTS idx_raw_ticks_symbol_ts
    ON raw.ticks (symbol, ts DESC);

CREATE INDEX IF NOT EXISTS idx_raw_ticks_ts
    ON raw.ticks (ts DESC);

CREATE INDEX IF NOT EXISTS idx_raw_ticks_run_id
    ON raw.ticks (run_id);

CREATE INDEX IF NOT EXISTS idx_raw_ticks_ts_brin
    ON raw.ticks USING brin (ts);

-- ============================================================
-- 1-minute bars
-- ============================================================

CREATE TABLE IF NOT EXISTS derived.bars_1m (
    symbol TEXT NOT NULL,
    bucket_ts TIMESTAMPTZ NOT NULL,
    open NUMERIC(18, 8) NOT NULL,
    high NUMERIC(18, 8) NOT NULL,
    low NUMERIC(18, 8) NOT NULL,
    close NUMERIC(18, 8) NOT NULL,
    tick_count INTEGER NOT NULL,
    avg_spread NUMERIC(18, 8),
    run_id BIGINT NOT NULL REFERENCES meta.ingestion_runs(run_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (symbol, bucket_ts),

    CONSTRAINT chk_bars_1m_ohlc_positive
        CHECK (open > 0 AND high > 0 AND low > 0 AND close > 0),

    CONSTRAINT chk_bars_1m_high_low
        CHECK (high >= low),

    CONSTRAINT chk_bars_1m_open_close_inside_range
        CHECK (
            open BETWEEN low AND high
            AND close BETWEEN low AND high
        ),

    CONSTRAINT chk_bars_1m_tick_count
        CHECK (tick_count > 0)
);

COMMENT ON TABLE derived.bars_1m IS
'One-minute OHLC bars built from synthetic raw ticks.';

CREATE INDEX IF NOT EXISTS idx_bars_1m_symbol_ts
    ON derived.bars_1m (symbol, bucket_ts DESC);

CREATE INDEX IF NOT EXISTS idx_bars_1m_run_id
    ON derived.bars_1m (run_id);

-- ============================================================
-- 15-minute bars
-- ============================================================

CREATE TABLE IF NOT EXISTS derived.bars_15m (
    symbol TEXT NOT NULL,
    bucket_ts TIMESTAMPTZ NOT NULL,
    open NUMERIC(18, 8) NOT NULL,
    high NUMERIC(18, 8) NOT NULL,
    low NUMERIC(18, 8) NOT NULL,
    close NUMERIC(18, 8) NOT NULL,
    source_bar_count INTEGER NOT NULL,
    tick_count INTEGER NOT NULL,
    avg_spread NUMERIC(18, 8),
    run_id BIGINT NOT NULL REFERENCES meta.ingestion_runs(run_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (symbol, bucket_ts),

    CONSTRAINT chk_bars_15m_ohlc_positive
        CHECK (open > 0 AND high > 0 AND low > 0 AND close > 0),

    CONSTRAINT chk_bars_15m_high_low
        CHECK (high >= low),

    CONSTRAINT chk_bars_15m_open_close_inside_range
        CHECK (
            open BETWEEN low AND high
            AND close BETWEEN low AND high
        ),

    CONSTRAINT chk_bars_15m_source_bar_count
        CHECK (source_bar_count > 0),

    CONSTRAINT chk_bars_15m_tick_count
        CHECK (tick_count > 0)
);

COMMENT ON TABLE derived.bars_15m IS
'Fifteen-minute OHLC bars built from one-minute bars.';

CREATE INDEX IF NOT EXISTS idx_bars_15m_symbol_ts
    ON derived.bars_15m (symbol, bucket_ts DESC);

CREATE INDEX IF NOT EXISTS idx_bars_15m_run_id
    ON derived.bars_15m (run_id);

-- ============================================================
-- Data-quality audit table
-- ============================================================

CREATE TABLE IF NOT EXISTS audit.data_quality_audits (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id BIGINT REFERENCES meta.ingestion_runs(run_id),
    audit_name TEXT NOT NULL,
    severity TEXT NOT NULL,
    issue_count INTEGER NOT NULL DEFAULT 0,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_audit_severity
        CHECK (severity IN ('info', 'warning', 'error')),

    CONSTRAINT chk_audit_issue_count
        CHECK (issue_count >= 0)
);

COMMENT ON TABLE audit.data_quality_audits IS
'Stores public-safe synthetic data-quality audit results.';

CREATE INDEX IF NOT EXISTS idx_data_quality_audits_run_id
    ON audit.data_quality_audits (run_id);

CREATE INDEX IF NOT EXISTS idx_data_quality_audits_severity
    ON audit.data_quality_audits (severity);

CREATE INDEX IF NOT EXISTS idx_data_quality_audits_details_gin
    ON audit.data_quality_audits USING gin (details);

-- ============================================================
-- Pipeline state
-- ============================================================

CREATE TABLE IF NOT EXISTS meta.pipeline_state (
    component_name TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    last_success_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,

    CONSTRAINT chk_pipeline_state_status
        CHECK (status IN ('ready', 'running', 'failed', 'disabled'))
);

COMMENT ON TABLE meta.pipeline_state IS
'Tracks high-level demo pipeline component status.';
