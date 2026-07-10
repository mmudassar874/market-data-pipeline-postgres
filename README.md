# Market Data Pipeline Postgres

![Tests](https://github.com/mmudassar874/market-data-pipeline-postgres/actions/workflows/tests.yml/badge.svg)

A public-safe PostgreSQL + Python demo for market-data ingestion, bar construction, and data-quality auditing.

This repository is inspired by private AlphaQuant database engineering work, but it does not contain private AlphaQuant code, real tick data, broker information, strategy thresholds, database credentials, or production schemas.

---

## Purpose

This repo demonstrates how a systematic trading system can structure market-data storage and validation.

It focuses on:

- Synthetic tick ingestion
- PostgreSQL schema design
- Timestamp and symbol indexing
- 1-minute and 15-minute bar construction
- Data-quality audit checks
- Ingestion run tracking
- SQL migrations
- Python ingestion utilities
- Pytest validation
- GitHub Actions CI with PostgreSQL

---

## Why This Matters

Trading systems depend on data quality.

A bad signal may be obvious.

Bad market data is more dangerous because it can silently poison every downstream layer:

- features
- regimes
- signals
- labels
- simulations
- ML training
- live/offline parity

This repository demonstrates the clean public version of a market-data pipeline.

---

## What This Repo Does Not Include

- Real tick data
- Private AlphaQuant V12 schema
- Broker credentials
- Database URLs
- API keys
- Live execution logic
- Proprietary strategy thresholds
- Model files
- Financial advice

---

## Planned Pipeline

    synthetic ticks
    -> raw_ticks table
    -> ingestion_runs table
    -> data quality checks
    -> bars_1m table
    -> bars_15m table
    -> audit reports
    -> tested SQL/Python workflow

---

## Maintainer

**Muhammad Mudassir**  
Self-taught quantitative trading systems developer and FinTech SaaS founder.
