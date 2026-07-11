# Data-Quality Audits

This document explains why market-data quality checks matter in the public PostgreSQL market-data pipeline demo.

Bad market data can poison every downstream layer of a trading system:

    bad ticks
      -> bad OHLC bars
      -> bad features
      -> bad labels
      -> bad backtests
      -> bad risk decisions
      -> unsafe live behavior

This repository uses synthetic public-safe examples only. It does not contain private AlphaQuant data, broker feeds, live credentials, or proprietary production schemas.

---

## 1. Tick Gaps

A tick gap means the system expected market updates but did not receive them for an unusually long interval.

Common causes:

- Broker feed interruption
- Network disconnection
- Ingestion process downtime
- Market closure or illiquid period
- Timestamp parsing errors

Why it matters:

- OHLC bars may be incomplete.
- Volatility estimates may become wrong.
- Backtests may assume liquidity that did not exist.
- Models may learn from broken market history.

Relevant query:

- `sql/queries/detect_tick_gaps.sql`

---

## 2. Duplicate Timestamps

Duplicate timestamps can happen when the same tick or bar is inserted more than once.

Common causes:

- Replay jobs running twice
- Retry logic without idempotency
- Missing unique constraints
- Import scripts without conflict handling

Why it matters:

- Volume can be overstated.
- Bar construction can double-count ticks.
- Features can become biased.
- Simulations can show fake liquidity.

Prevention ideas:

- Use primary keys or unique constraints.
- Use `ON CONFLICT` logic where appropriate.
- Audit duplicate timestamp groups.
- Track ingestion run IDs.

---

## 3. Bad Bid/Ask Values

Bad bid/ask values include impossible or suspicious market states.

Examples:

- Bid price less than or equal to zero
- Ask price less than or equal to zero
- Ask lower than bid
- Extreme spread spikes
- Missing bid or ask values

Why it matters:

- Spread estimates become wrong.
- Execution-cost modeling becomes wrong.
- Risk gates may approve trades under false conditions.
- Backtests may become unrealistic.

---

## 4. OHLC Bar Construction Risk

OHLC bars are derived objects.

If raw ticks are bad, bars can also become bad.

Examples of bar-level problems:

- Missing open/high/low/close values
- High lower than low
- Close timestamp mismatch
- Incomplete 1-minute or 15-minute windows
- Duplicate bars for the same symbol and timestamp

Relevant queries:

- `sql/queries/build_1m_bars.sql`
- `sql/queries/build_15m_bars.sql`

---

## 5. Data-Quality Summary

A data-quality summary gives a compact view of market-data health.

It can answer:

- How many ticks were ingested
- Whether timestamps are duplicated
- Whether bad bid/ask values exist
- Whether gaps exist
- Whether derived bars are available

Relevant query:

- `sql/queries/data_quality_summary.sql`

---

## 6. Trading-System Principle

A trading strategy should not trust downstream features unless upstream market data is healthy.

The safe flow is:

    ingest data
      -> audit data
      -> build bars
      -> audit bars
      -> compute features
      -> validate features
      -> run strategy logic
      -> apply risk controls

Data quality is not a database detail.

It is part of trading risk governance.
