# mix-or-not

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-572

**EDD: yes** every claim in the paper stands only when a re-runnable pull
and analysis under `experiments/` tests it against fleet data from all
houses.

> What this is: the work plan for the mix-or-not whitepaper
> ([`../mix-or-not.md`](../mix-or-not.md)): the ordered steps that turn
> its claims register into tested claims. The paper holds the argument
> and the findings; this file holds what to do next.

## Do this next

Step 1: make last winter's data pullable as sema.

## Steps

In order. Each analysis step ends by updating the paper's claims
register Status column and writing the finding into the paper.

1. **Fix the January pull.** `experiments/pull_readings.py` stops on the
   `layout.lite` version the houses emitted last winter (`Unsupported
   version 006 for layout.lite`). The vendored sema snapshot in the
   experiments repo needs that version before any sema-typed evidence
   can be pulled. Everything below depends on this.
2. **Open the evidence folder.** A topic branch in the experiments repo
   and `experiments/2026-10-06-mix-or-not/`, from the experiment README
   template, with a logbook line.
3. **Claim 2 across all houses.** Flow-weighted emitter temperature drop
   in constant-heat-call hours, by supply temperature, for the 2025–26
   season, using `dist-flow` (the flow of record). Tests the 20 °F figure
   and the `DdDeltaTF` parameter together.
4. **Forecast against measured, fall shoulder, per house.** The scada's
   `heating.forecast` (`AvgPowerKw`, `RswtF`) against measured
   distribution energy and the supply temperature at which the house
   held setpoint in near-constant heat call. Then, per shoulder day:
   charge temperature, on-peak draw, surplus above RSWT when the heat
   pump returned, and its COP cost. This is the test of claim 11.
5. **Claim 3 on milder days with a hot store.** Return temperature
   against heat-call fraction at fixed supply temperature, on days with
   infrequent heat calls. The discharge half rests on this.
6. **The remaining claims.** Capacity against entering water temperature
   (6), heat delivered below RSWT (8), stratification under fast flow
   (9), solar gain at beech (10), COP against lift per house (1), burst
   return spread (4), comfort overshoot (5).
7. **Store accounting for both modes.** With measured return
   temperatures, the usable energy of one full tank sent unmixed against
   mixed to RSWT, with the floor temperature stated.
8. **Verify the RSWT code read.** The calculation in the paper was read
   from current branches. Check each point against the commits the
   houses ran last season (`FloGitCommit` in `flo.params.house0` for the
   FLO).

## Open

- Scope of the data: proposed is the 2025–26 heating season and every
  house with distribution supply, return and flow channels.
- Whether any zone has emitters in series with a temperature sensor at
  more than one of them; claim 12 has no test without one.
