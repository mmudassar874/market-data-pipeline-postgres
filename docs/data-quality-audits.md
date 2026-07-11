# Data-Quality Audits

This document explains why market-data quality checks matter in the public PostgreSQL market-data pipeline demo.

Bad market data can poison every downstream layer of a trading system:

```text
bad ticks
  -> bad OHLC bars
  -> bad features
  -> bad labels
  -> bad backtests
  -> bad risk decisions
  -> unsafe live behavior

This repository uses synthetic public-safe examples only. It does not contain private AlphaQuant data, broker feeds, live credentials, or proprietary production schemas.

1. Tick Gaps

A tick gap means the system expected market updates but did not receive them for an unusually long interval.

Common causes:

broker feed interruption
network disconnection
ingestion process downtime
market closure or illiquid period
timestamp parsing errors

Why it matters:

OHLC bars may be incomplete
volatility estimates may become wrong
backtests may assume liquidity that did not exist
models may learn from broken market history

Relevant query:

sql/queries/detect_tick_gaps.sql
2. Duplicate Timestamps

Duplicate timestamps can happen when the same tick or bar is inserted more than once.

Common causes:

replay jobs running twice
retry logic without idempotency
missing unique constraints
import scripts without conflict handling

Why it matters:

volume can be overstated
bar construction can double-count ticks
features can become biased
simulations can show fake liquidity

Prevention ideas:

use primary keys or unique constraints
use ON CONFLICT logic where appropriate
audit duplicate timestamp groups
track ingestion run IDs
3. Bad Bid/Ask Values

Bad bid/ask values include impossible or suspicious market states.

Examples:

bid price less than or equal to zero
ask price less than or equal to zero
ask lower than bid
extreme spread spikes
missing bid or ask values

Why it matters:

spread estimates become wrong
execution-cost modeling becomes wrong
risk gates may approve trades under false conditions
backtests may become unrealistic
4. OHLC Bar Construction Risk

OHLC bars are derived objects.

If raw ticks are bad, bars can also become bad.

Examples of bar-level problems:

missing open/high/low/close values
high lower than low
close timestamp mismatch
incomplete 1-minute or 15-minute windows
duplicate bars for the same symbol and timestamp

Relevant queries:

sql/queries/build_1m_bars.sql
sql/queries/build_15m_bars.sql
5. Data-Quality Summary

A data-quality summary gives a compact view of market-data health.

It can answer:

how many ticks were ingested
whether timestamps are duplicated
whether bad bid/ask values exist
whether gaps exist
whether derived bars are available

Relevant query:

sql/queries/data_quality_summary.sql
6. Trading-System Principle

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
