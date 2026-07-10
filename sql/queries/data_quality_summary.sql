-- Data-quality summary for synthetic market-data pipeline.
--
-- Public-safe demo query.
-- Does not expose private AlphaQuant data or strategy logic.

WITH tick_stats AS (
    SELECT
        symbol,
        COUNT(*) AS tick_count,
        MIN(ts) AS first_tick_ts,
        MAX(ts) AS last_tick_ts,
        MIN(bid) AS min_bid,
        MAX(ask) AS max_ask,
        AVG(spread) AS avg_spread
    FROM raw.ticks
    GROUP BY symbol
),
duplicate_tick_groups AS (
    SELECT
        symbol,
        ts,
        bid,
        ask,
        COUNT(*) AS duplicate_count
    FROM raw.ticks
    GROUP BY symbol, ts, bid, ask
    HAVING COUNT(*) > 1
),
duplicates AS (
    SELECT
        symbol,
        COUNT(*) AS duplicate_identity_groups
    FROM duplicate_tick_groups
    GROUP BY symbol
),
bad_ticks AS (
    SELECT
        symbol,
        COUNT(*) AS bad_tick_count
    FROM raw.ticks
    WHERE bid <= 0
       OR ask <= 0
       OR ask < bid
    GROUP BY symbol
),
ordered_ticks AS (
    SELECT
        symbol,
        ts,
        LAG(ts) OVER (
            PARTITION BY symbol
            ORDER BY ts
        ) AS previous_ts
    FROM raw.ticks
),
gaps AS (
    SELECT
        symbol,
        COUNT(*) AS gap_count_over_60s,
        MAX(EXTRACT(EPOCH FROM (ts - previous_ts))) AS max_gap_seconds
    FROM ordered_ticks
    WHERE previous_ts IS NOT NULL
      AND EXTRACT(EPOCH FROM (ts - previous_ts)) > 60
    GROUP BY symbol
),
bars_1m AS (
    SELECT
        symbol,
        COUNT(*) AS bars_1m_count
    FROM derived.bars_1m
    GROUP BY symbol
),
bars_15m AS (
    SELECT
        symbol,
        COUNT(*) AS bars_15m_count
    FROM derived.bars_15m
    GROUP BY symbol
)
SELECT
    t.symbol,
    t.tick_count,
    t.first_tick_ts,
    t.last_tick_ts,
    t.min_bid,
    t.max_ask,
    t.avg_spread,
    COALESCE(d.duplicate_identity_groups, 0) AS duplicate_identity_groups,
    COALESCE(b.bad_tick_count, 0) AS bad_tick_count,
    COALESCE(g.gap_count_over_60s, 0) AS gap_count_over_60s,
    COALESCE(g.max_gap_seconds, 0) AS max_gap_seconds,
    COALESCE(b1.bars_1m_count, 0) AS bars_1m_count,
    COALESCE(b15.bars_15m_count, 0) AS bars_15m_count
FROM tick_stats t
LEFT JOIN duplicates d
    ON d.symbol = t.symbol
LEFT JOIN bad_ticks b
    ON b.symbol = t.symbol
LEFT JOIN gaps g
    ON g.symbol = t.symbol
LEFT JOIN bars_1m b1
    ON b1.symbol = t.symbol
LEFT JOIN bars_15m b15
    ON b15.symbol = t.symbol
ORDER BY t.symbol;
