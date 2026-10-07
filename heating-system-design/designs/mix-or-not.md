# mix-or-not

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-572

**EDD: yes** every claim in the paper stands only when a re-runnable pull
and analysis under `experiments/` tests it against fleet data from all
houses.

> What this is: the work plan for the mix-or-not whitepaper
> (`heating-system-design/mix-or-not.md`, in the heating-system-design
> repo): the ordered steps that turn
> its claims register into tested claims. The paper holds the argument
> and the findings; this file holds what to do next.

## Do this next

Heat pump entering water temperature with a hot buffer top (the new step 4).

## Steps

In order. Each analysis step ends by updating the paper's claims
register Status column and writing the finding into the paper.

1. ✅ **Fix the January pull.** The experiments snapshot carries
   `layout.lite` 004 through 013 and `pull_readings.py` pulls from every
   version the houses emitted in the 2025–26 season (004 to 012), tested
   with a one-day `dist-%` pull per version. Layouts 004 to 006 (through
   2026-01-08) carry their computed channels as `synth.channel.gt`,
   which `gw.readings` does not hold, so those channels are not pullable
   for that period; data channels are.
2. ✅ **Open the evidence folder.** Branch `jm/mix-or-not` in the
   experiments repo and `experiments/2026-10-06-mix-or-not/`, with a
   logbook line.
3. ✅ **Claim 2 across all houses.** Flow-weighted emitter temperature
   drop in steady-circulation hours, by supply temperature, for the
   2025–26 season, using `dist-flow` (the flow of record). The folder's
   hourly files (`emitter_drop.py`) hold every valid hour with its
   circulation fraction, which claim 3 reads without a new pull. The
   comparison against each house's `DdDeltaTF` is not done: it needs the
   parameter values, which step 5 pulls.
4. **Heat pump entering water temperature with a hot buffer top.** The
   paper's "How hot the water comes back" has the return from
   distribution; the open half is what reaches the heat pump. Per house:
   the heat pump's entering water temperature in hours it ran while the
   buffer top was hot, against the highest entering temperature that
   heat pump model accepts, and the bottom-of-buffer temperature in the
   same hours. Needs the entering-water, heat pump power and buffer
   depth channels added to the hourly pull.
5. **Forecast against measured, fall shoulder, per house.** First add
   `heating.forecast` and `flo.params.house0` to the experiments
   snapshot seed (both are in the registry, neither is seeded). The scada's
   `heating.forecast` (`AvgPowerKw`, `RswtF`) against measured
   distribution energy and the supply temperature at which the house
   held setpoint in near-constant heat call. Then, per shoulder day:
   charge temperature, on-peak draw, surplus above RSWT when the heat
   pump returned, and its COP cost. This is the test of claim 11.
6. ✅ **Claim 3.** Return temperature against circulation fraction at
   fixed supply temperature, all houses, from the hourly files
   (`return_temp.py`).
7. **The remaining claims.** Capacity against entering water temperature
   (6), heat delivered below RSWT (8), stratification under fast flow
   (9), solar gain at beech (10), COP against lift per house (1), burst
   return spread (4), comfort overshoot (5).
8. **Store accounting for both modes.** With measured return
   temperatures, the usable energy of one full tank sent unmixed against
   mixed to RSWT, with the floor temperature stated.
9. **Verify the RSWT code read.** The calculation in the paper was read
   from current branches. Check each point against the commits the
   houses ran last season (`FloGitCommit` in `flo.params.house0` for the
   FLO).

## Open

- Scope of the data: proposed is the 2025–26 heating season and every
  house with distribution supply, return and flow channels.
- Whether any zone has emitters in series with a temperature sensor at
  more than one of them; claim 12 has no test without one.
