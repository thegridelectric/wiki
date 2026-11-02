# bruce FLO — the heat-pump-and-water-tank asset model

Status: Draft · Pass 0 · Updated 2026-11-01

> What this is: the spec of the FLO in `optimal-flexibility` (the `bruce`
> package): what it takes as a request, what it assumes about the plant
> it optimizes, and what it returns. Companion to `primary.md`; the
> service shape is OPS-514.

## Overview

The FLO builds a graph of storage states over the horizon from one
request, finds the shortest path against the electricity price and
weather forecasts, and returns a bid recommendation. A request is the
per-run word: the plant's facts, the FLO's tuning, the current tank
state, and the forecasts. The plant it models is one heat pump charging
one stratified water store that serves one distribution system.

## The store

The store is `num_layers` equal layers of water, `storage_volume_gallons`
in all, described at any step by a top, middle and bottom temperature and
two thermocline indices. Energy is relative to the coldest allowed
state; `storage_losses_percent` of the energy above that floor leaks per
hour.

## The heat pump

The heat pump is described by its electrical envelope
(`hp_min_kw_elec`, `hp_max_kw_elec`), its thermal cap (`hp_max_kw_th`),
its warm-up (`hp_turn_on_minutes`), a coefficient-of-performance curve
in outdoor temperature (`cop_intercept`, `cop_oat_coeff`, `cop_min`,
`cop_min_oat_f`; `cop_lwt_coeff` is accepted and unused), and a
**constant lift**, `hp_constant_lift_f`.

**The lift reaches the tank layer directly.** When the heat pump charges
the store, the model takes water from a layer at temperature T and
returns it at T + `hp_constant_lift_f`, the same rise whatever T, the
outdoor temperature or the heat pump's output that step. The heated
water moves the thermoclines: bottom water heated to the top's
temperature joins the top; heated to less than the top, it forms a new
middle. So the lift sets how far up the stratification each unit of
heat moves, and therefore how many kWh the store accepts before its top
reaches `max_tank_temp_f`. A lift larger than the plant's puts heat too
high in the tank in the model; a lift smaller spreads it too low. The
value is 20 F for every house today; what the plant does is the
leaving-water temperature minus the entering-water temperature across
the heat pump, which varies with its thermal output over the primary
flow.

## The distribution system

Water drawn from the store top at temperature T to serve the hour's load
comes back at `rwt(T, bucket)`: an intercept plus a slope times T, one
line per load bucket (`load_bucket_upper_kwh` sets the bucket edges,
`rwt_intercept_by_bucket` and `rwt_slope_by_bucket` the lines), clamped
to at least `rwt_min` and at most T. The required supply temperature per
hour, `rswt_f`, is a forecast input the FLO penalizes against and does
not model.

## Costs and penalties

Electricity at the forecast price is the cost; the rest are penalties
with a weight and a switch each: the store falling below the required
supply temperature (`rswt_penalty_*`), filling from off below full power
(`short_cycle_penalty_*`), departing from the previous plan
(`stability_penalty_*`, fed by the three `previous_*` fields), and a
terminal cost over the last `terminal_cost_end_window_hours` of the
horizon. `bid_min_price_mwh` and `bid_max_price_mwh` bound the price
range the bid sweeps.

## The response

The bid is the plant's electricity at each price in the range: for each
trial price the cheapest hour-0 edge from the current state, kept as a
new price-quantity pair whenever the quantity changes. Each pair's edge
leads to a next state, and that state's energy and onward electrical
plan are the plan for the hour if that price clears. Bid-time updates
may change only the current tank state and the heat pump's on/off; any
other change is refused.

## Invariants

- `rwt_intercept_by_bucket` and `rwt_slope_by_bucket` each have one more
  entry than `load_bucket_upper_kwh`, whose entries are positive and
  strictly increasing.
- The thermocline indices lie in `[1, num_layers]` with the second at or
  below the first.
- `elec_price_mwh` and `timestep_duration_hours` have `horizon` entries;
  `bid_min_price_mwh` is below `bid_max_price_mwh`.

## Admissibility

bruce models one heat pump charging one stratified store that serves one
distribution system. An ops instance names it only where that holds: a
House0 family whose `SiegLoopStrategy` is `HoldFullSend` or
`StratProtect`. A Nolan family, or a House0 family running `LwtControl`,
names `flo.tuning.alice`, the stub FLO that answers every request with a
recommendation holding no price-quantity pairs, from which no bid is
made. The rule is an axiom on
`gw.operational.params`, not a judgment in the caller.

## Open

- Whether the constant lift holds against the fleet's measured lift:
  the design that tests it is in this domain's `designs/`.
- `cop_lwt_coeff` is accepted and unused by the COP curve.
