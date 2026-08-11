# five-minute-flos

Status: Draft · Pass 0 · Updated 2026-08-10 · Linear: OPS-491

**EDD: yes** verified by a real LTN running the FLO every 5 minutes
against live (or sped-up) weather and price inputs — sustained cadence
witnessed, not code review.

> What this is: move the LTN's FLO from once-an-hour to every 5 minutes.
> Today the FLO runs once per hour at a settings-driven minute
> (`create_graph_minute`; historically randomized to spread heavy
> processing load — commented `random.randint` at
> `gw_spaceheat/actors/ltn/ltn.py:516`, `send_bid_minute = 57`), building
> predicted energy use over the next 48 hours from the weather forecast
> carried into flo_params (`ltn.py:1041-1042`, horizon capped at
> `flo_horizon_hours`, `ltn.py:998-1010`).

## Sequencing

1. **First step: the LTN gwbase port** (OPS-435) — this design builds on
   the ported LTN, not on `actors/ltn/` in the scada repo.
2. **Riders: weather and price forecast delivery.** A 5-minute FLO
   changes the freshness its inputs need. The weather-side vocabulary,
   cadence, and direct-report mechanism are designed under OPS-436; the
   price forecast service carries the same rider.

## Open

- Input freshness contract: what staleness the 5-minute FLO tolerates
  for current weather, forecast, and price, and whether it pulls
  (direct report request) or relies on broadcasts.
- Processing-load strategy: the hourly-era randomness spread load
  across the hour; a 5-minute cadence needs its own answer (staggering
  across houses, cheaper incremental FLO runs, or both).
