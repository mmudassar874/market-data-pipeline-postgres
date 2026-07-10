from market_data_pipeline.synthetic import generate_synthetic_ticks


def test_generate_synthetic_ticks_count():
    ticks = generate_synthetic_ticks(minutes=10, ticks_per_minute=6)

    assert len(ticks) == 60


def test_generate_synthetic_ticks_are_ordered_and_valid():
    ticks = generate_synthetic_ticks(minutes=5, ticks_per_minute=4)

    assert ticks == sorted(ticks, key=lambda tick: tick.ts)

    for tick in ticks:
        assert tick.symbol == "SYNTH_XAUUSD"
        assert tick.bid > 0
        assert tick.ask > 0
        assert tick.ask >= tick.bid


def test_generate_synthetic_ticks_rejects_bad_inputs():
    try:
        generate_synthetic_ticks(minutes=0)
    except ValueError as exc:
        assert "minutes" in str(exc)
    else:
        raise AssertionError("expected ValueError")
