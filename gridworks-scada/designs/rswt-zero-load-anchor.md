# RSWT zero-load anchor

Status: Draft · Pass 0 · Updated 2026-10-30 · Linear: OPS-646

**EDD: yes** the verification is the fleet's `heating.forecast` journal
after the roll: no house forecasts an RSWT below room temperature at any
load, elm's zero-load RSWT is room temperature rather than 100 F, and
the overnight RSWT of fir, oak, maple and beech at the same outdoor
temperature moves only where the design says it should. A unit test on
the curve with each house's published heating-curve params is the
re-runnable reproducer.

> What this is: the required-source-water-temperature (RSWT) curve in
> the derived generator anchors zero heating load at the balance-point
> outdoor temperature and fits a quadratic with no monotonicity check,
> so it answers below room temperature for most houses and never below
> 100 F for elm. The small design that grounds the anchor at room
> temperature and makes the fit monotone, with tests. Code read on
> `main` at `78a06838`, `gw_spaceheat/actors/derived_generator.py:745`
> (`no_power_rswt`), `:751` (`rswt_quadratic_params`), `:1096`
> (`required_swt`); the LTN's `get_RSWT` at
> `gw_spaceheat/actors/ltn/ltn.py:1308` repeats the same formula.

## The field record (fleet journal, 2026-10-29 and 30, ET)

Read from `heating.forecast` in the journal DB, hourly per house. The
house curves are the tlayouts `output/<house>/*operational.params.json`
HeatingCurve blocks, and the legacy line's `.env` values gave the same
forecasts hour for hour, so the curve did not change across the roll to
main.

| house | alpha | beta | zero-load anchor (F) | parabola vertex (F) | RSWT at zero load (F) |
|---|---|---|---|---|---|
| fir | 7.5 | -0.13 | 57.7 | 46.9 | 57.7 |
| oak | 7.6 | -0.13 | 58.5 | 66.6 | 74.7 |
| maple | 6.6 | -0.09 | 73.3 | 68.0 | 73.3 |
| beech | 8.6 | -0.14 | 61.4 | 69.1 | 76.8 |
| elm | 5.5 | -0.10 | 55.0 | 77.6 | 100.1 |
| spruce | 8.6 | -0.14 | 61.4 | 29.3 | 61.4 |
| template (fir, maple, oak gen files before 21:17 on 10-29) | 5.5 | -0.10 | 55.0 | 43.6 | 55.0 |

What the journal showed:

- Fir on the legacy line forecast 57.69 F all afternoon on 10-29 and 68
  to 76 F overnight at 53 to 55 F outdoors.
- From the first main boot at 19:47 to the 21:26 reboot on 10-29, fir,
  maple, oak and spruce forecast an identical 55.0 F at zero load, then
  61.85, 74.31, 103.50 and 109.95 F at 0.1, 0.4, 1.7 and 2.1 kW. The
  template curve reproduces every one of those to the cent. Beech ran the
  template from its 10-28 19:23 boot to 21:27 on 10-29.
- Elm forecast 100.12 F at zero load every hour of 10-29 and 101.95 F at
  0.1 kW. Its `is_buffer_empty` threshold was therefore never below
  100 F.

## What the code does

- `no_power_rswt` is `-alpha/beta`: the outdoor temperature at which the
  house load `alpha + beta*oat` is zero. The curve uses it as the water
  temperature at which the emitters deliver zero power. Those are the
  same number only when the balance point equals room temperature; with
  internal gains the balance point is 55 to 61 F.
- `rswt_quadratic_params` solves the parabola through
  `(no_power_rswt, 0)`, `(IntermediateRswtF, IntermediatePowerKw)` and
  `(DdRswtF, DdPowerKw)`. `required_swt` returns the "+" root. When the
  vertex lies above the anchor (oak, beech, elm) the "+" root at zero
  load is the parabola's other zero, not the anchor, and the curve is
  not monotone between the two.
- Consumers: `is_buffer_empty` (`hydronic/shared.py:240`) uses the
  3-hour max RSWT as the buffer-empty threshold; `is_buffer_full`
  (`hydronic/house0.py:568`) uses the same number as the full
  threshold; `rwt_f`, `delta_T` and the usable- and required-energy
  estimates read `RswtF` and `RswtDeltaTF`; the LTN's `get_RSWT` feeds
  the FLO's buffer energy.

## Principle

The heating curve maps delivered heating power to the source water
temperature the emitters need. Zero power is delivered at room
temperature, whatever the outdoor balance point. A curve the scada
accepts is monotone over its working range: more power always needs
hotter water.

## Design

1. **Anchor zero load at room temperature.** `no_power_rswt` becomes a
   room-temperature constant for the fit. Whether that constant is a
   named module constant (70 F) or a new `heating.curve` field
   (`ZeroLoadRswtF`, or a room setpoint) is the first decision below.
2. **Make the fit monotone, or refuse the curve.** With the anchor at
   room temperature every current house curve has its vertex below the
   anchor except elm (anchor 70 F, vertex 77.6 F). Two options, decided
   in the grill: (a) a monotone fit (for example a quadratic constrained
   to have its vertex at or below the anchor, falling back to the
   piecewise-linear interpolation of the three points when the
   unconstrained fit is not monotone), or (b) a `heating.curve` axiom in
   sema and its `check_axiom` twin that rejects a non-monotone triple at
   load time, so the boot fails on a bad curve and elm's params are
   re-specified.
3. **One formula.** The LTN's `get_RSWT` calls the derived generator's
   curve (or a shared pure function) instead of repeating the algebra.
4. **Tests.** A parametrised test over the published house curves
   asserts: RSWT at zero load equals the anchor; RSWT is non-decreasing
   in load; RSWT at `IntermediatePowerKw` and `DdPowerKw` returns the
   published points. A test with elm's params asserts whichever of 2(a)
   or 2(b) is chosen.

## Out of scope

- The heating-curve values themselves (alpha, beta, gamma, the two
  power points) and whether a zone should have its own RSWT: OPS-315.
- The buffer-only control flipping HpOn/HpOff every minute while the
  buffer sits at RSWT (maple, 23:35 and 02:34 on 10-29/30): a buffer
  deadband bug in `is_buffer_empty` versus `is_buffer_full`, its own
  issue.
- `LoadOverestimationPercent` and the required-energy logic.

## Open

- Room-temperature anchor: a constant, an ops-params field, or the
  house's zone setpoints. A constant is enough for the hundred homes
  this winter; the sema word can grow a field later.
- Monotone fit (2a) or reject (2b). Rejecting is simpler and makes a
  bad curve a boot failure; the fit keeps elm running on its current
  params.
- Whether `RswtDeltaTF` (`delta_T`) needs the same anchor treatment: it
  scales the design-day delta T by delivered power from the same
  parabola, so it inherits whatever the fit does.

## Plan

- Grill the two open decisions, Pass 1.
- Write the parametrised curve test against the published house params
  so it fails on main today.
- Implement 1 to 3 on a `jm/rswt-zero-load-anchor` branch; regenerate
  the sema snapshot if 2(b) adds an axiom.
- Roll one house (fir, the clearest case), then read its
  `heating.forecast` for a mild evening and a cold night.

**Do this next:** grill the anchor and the monotone-or-reject decisions.
