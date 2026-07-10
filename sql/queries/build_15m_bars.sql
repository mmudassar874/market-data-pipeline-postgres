-- Build 15-minute OHLC bars from 1-minute bars.
--
-- Public-safe demo query.
-- This demonstrates derived bar construction and close-time bucket logic.

WITH bar_buckets AS (
    SELECT
        symbol,
        date_bin(
            '15 minutes',
            bucket_ts,
            '1970-01-01 00:00:00+00'::timestamptz
        ) AS bucket_ts,
        (array_agg(open ORDER BY bucket_ts ASC))[1] AS open,
        MAX(high) AS high,
        MIN(low) AS low,
        (array_agg(close ORDER BY bucket_ts DESC))[1] AS close,
        COUNT(*)::integer AS source_bar_count,
        SUM(tick_count)::integer AS tick_count,
        AVG(avg_spread) AS avg_spread,
        MAX(run_id) AS run_id
    FROM derived.bars_1m
    GROUP BY
        symbol,
        date_bin(
            '15 minutes',
            bucket_ts,
            '1970-01-01 00:00:00+00'::timestamptz
        )
)
INSERT INTO derived.bars_15m (
    symbol,
    bucket_ts,
    open,
    high,
    low,
    close,
    source_bar_count,
    tick_count,
    avg_spread,
    run_id
)
SELECT
    symbol,
    bucket_ts,
    open,
    high,
    low,
    close,
    source_bar_count,
    tick_count,
    avg_spread,
    run_id
FROM bar_buckets
ON CONFLICT (symbol, bucket_ts)
DO UPDATE SET
    open = EXCLUDED.open,
    high = EXCLUDED.high,
    low = EXCLUDED.low,
    close = EXCLUDED.close,
    source_bar_count = EXCLUDED.source_bar_count,
    tick_count = EXCLUDED.tick_count,
    avg_spread = EXCLUDED.avg_spread,
    run_id = EXCLUDED.run_id,
    created_at = now()
RETURNING
    symbol,
    bucket_ts,
    open,
    high,
    low,
    close,
    source_bar_count,
    tick_count,
    avg_spread;
