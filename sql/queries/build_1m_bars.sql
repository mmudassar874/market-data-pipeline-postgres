-- Build 1-minute OHLC bars from synthetic raw ticks.
--
-- Public-safe demo query.
-- No real AlphaQuant data, broker data, or private strategy logic.

WITH tick_buckets AS (
    SELECT
        run_id,
        symbol,
        date_trunc('minute', ts) AS bucket_ts,
        (array_agg(mid ORDER BY ts ASC, tick_id ASC))[1] AS open,
        MAX(mid) AS high,
        MIN(mid) AS low,
        (array_agg(mid ORDER BY ts DESC, tick_id DESC))[1] AS close,
        COUNT(*)::integer AS tick_count,
        AVG(spread) AS avg_spread
    FROM raw.ticks
    GROUP BY
        run_id,
        symbol,
        date_trunc('minute', ts)
)
INSERT INTO derived.bars_1m (
    symbol,
    bucket_ts,
    open,
    high,
    low,
    close,
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
    tick_count,
    avg_spread,
    run_id
FROM tick_buckets
ON CONFLICT (symbol, bucket_ts)
DO UPDATE SET
    open = EXCLUDED.open,
    high = EXCLUDED.high,
    low = EXCLUDED.low,
    close = EXCLUDED.close,
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
    tick_count,
    avg_spread;
