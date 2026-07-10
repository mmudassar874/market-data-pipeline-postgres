-- Detect time gaps between consecutive ticks.
--
-- Public-safe demo query.
-- A real trading system would tune the gap threshold by symbol, session, and data source.

WITH ordered_ticks AS (
    SELECT
        symbol,
        ts,
        LAG(ts) OVER (
            PARTITION BY symbol
            ORDER BY ts
        ) AS previous_ts
    FROM raw.ticks
),
gap_scan AS (
    SELECT
        symbol,
        previous_ts,
        ts AS current_ts,
        EXTRACT(EPOCH FROM (ts - previous_ts)) AS gap_seconds
    FROM ordered_ticks
    WHERE previous_ts IS NOT NULL
)
SELECT
    symbol,
    previous_ts,
    current_ts,
    gap_seconds
FROM gap_scan
WHERE gap_seconds > 60
ORDER BY
    symbol,
    current_ts;
