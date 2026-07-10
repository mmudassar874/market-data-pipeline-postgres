"""Synthetic market-data generator for the public demo pipeline."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta


@dataclass(frozen=True)
class SyntheticTick:
    symbol: str
    ts: datetime
    bid: float
    ask: float


def generate_synthetic_ticks(
    symbol: str = "SYNTH_XAUUSD",
    start_ts: datetime | None = None,
    minutes: int = 30,
    ticks_per_minute: int = 4,
    base_price: float = 2000.0,
) -> list[SyntheticTick]:
    """
    Generate deterministic synthetic ticks.

    This function creates fake public demo data only.
    It does not use broker data, real tick data, or private AlphaQuant data.
    """

    if minutes <= 0:
        raise ValueError("minutes must be positive")

    if ticks_per_minute <= 0:
        raise ValueError("ticks_per_minute must be positive")

    start_ts = start_ts or datetime(2026, 1, 1, 0, 0, tzinfo=UTC)

    ticks: list[SyntheticTick] = []

    for minute in range(minutes):
        for tick_index in range(ticks_per_minute):
            seconds_offset = int((60 / ticks_per_minute) * tick_index)
            ts = start_ts + timedelta(minutes=minute, seconds=seconds_offset)

            wave = math.sin((minute + tick_index / ticks_per_minute) / 3.0) * 0.8
            trend = minute * 0.015
            micro_move = tick_index * 0.002

            mid = base_price + trend + wave + micro_move
            spread = 0.04 + (0.005 * (tick_index % 2))

            bid = round(mid - spread / 2.0, 5)
            ask = round(mid + spread / 2.0, 5)

            ticks.append(
                SyntheticTick(
                    symbol=symbol,
                    ts=ts,
                    bid=bid,
                    ask=ask,
                )
            )

    return ticks
