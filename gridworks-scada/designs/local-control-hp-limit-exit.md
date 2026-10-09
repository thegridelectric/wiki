# local-control-hp-limit-exit

Status: Draft · Pass 0 · Updated 2026-10-08 · Linear: OPS-577
**EDD: yes** a local test replaying beech's night of 2026-01-04/05 must
reproduce the trap and fail before the fix; the design reaches Verified
only when a field window or a design-day night shows the exit firing.

> What this is: Local Control leaves `HpOnStoreOff` for store charging
> when the heat pump is at its limit, found from the heat pump's own
> behaviour rather than from a constant set by hand.

## Why

On 2026-01-04/05, the coldest night of the season, beech's Local
Control (then HomeAlone) held the heat pump on the buffer in
`HpOnStoreOff` from 21:44 until an Admin takeover at 03:52. The only
exit from that state is "buffer full", and the forecast RSWT (171–179
°F) was above anything the heat pump could reach. Through the coldest
hours the heat pump tripped six times on its high limit (187–189 °F
leaving), with nowhere cooler to send its heat; the store sat uncharged
at 110–137 °F. The analysis and data are in
`experiments/2026-10-08-beech-missing-store-heat-analysis/`.

The partial patch that went in that morning (OPS-186) caps the
buffer-full threshold at `MaxEwtF`. That works only while `MaxEwtF`,
set by hand per house, sits below what the heat pump can reach on the
night. A heat pump's real ceiling moves with outdoor temperature and
output, so a constant will be wrong on some night; the design day is
the night it matters most.

## What exists

- `is_buffer_full` caps its threshold at `ha1_params.MaxEwtF`
  (`gw_spaceheat/actors/hydronic/house0.py:556`, cap at :597–601).
  `MaxEwtF` comes from operational params `HeatingCurve.MaxEwtF`
  (`gw_spaceheat/actors/scada_data.py:168`); in January it came from
  `.env`.
- `hp_in_defrost` (`hydronic/house0.py:537`) reads a per-device-type
  power signature (`DEFROST_SIGNATURES`) and already moves
  `HpOnStoreCharge` to `HpOnStoreOff` on a defrost
  (`local_control/house0/all_tanks_tou.py:234`). A high-limit trip also
  drops outdoor-unit power, so the two must be told apart.
- The sieg loop's `hp_loop_is_getting_hot`
  (`sieg_loop/strat_protect.py:123`) is the nearest precedent for
  reading the heat pump's temperatures against its limit.

All references are to `jm/spruce-unlimbo` at `109d4404`.

## Proposal

While in `HpOnStoreOff`, off-peak, Local Control moves to
`HpOnStoreCharge` when any of these fires:

1. **High-limit trip.** The outdoor unit stops while our relay calls,
   and `hp-lwt` just before the stop was within a few °F of its peak
   over the last hour. A stop with `hp-lwt` already falling is a defrost
   (or something else) and does not count. One trip is enough.
2. **Buffer stopped gaining.** With the heat pump running, the buffer
   bottom has not risen for N minutes.
3. **Backstop.** A maximum time in `HpOnStoreOff`.

On beech's night, signs 1 and 2 fire at about 00:00–00:30, three and a
half hours before the takeover.

Constraints:

- Sign 1 reads outdoor-unit power only where the layout has it; without
  it, signs 2 and 3 carry the exit.
- Once the exit fires, the next "buffer empty" must not send Local
  Control straight back into the same trap within the hour. How long
  it stays out is part of the design.

## Test first

Per the field-bug rule, a local test reproduces the trap before the fix:
drive the sim with beech's readings from 21:30 to 04:00 (the committed
`gw.readings` instance in the experiments folder) and assert that Local
Control leaves `HpOnStoreOff` by about 00:30. It fails on today's code
with `MaxEwtF` set above 170 °F; it passes after.

## Open

- Trip detection: how close to the recent peak counts as "near" (the
  five trips came at 187–189 °F against a peak of 189 °F), and how it
  coexists with `hp_in_defrost` on the same power drop.
- N for sign 2, and the backstop time.
- How long after an exit before `HpOnStoreOff` may be entered again.
- Whether the same exit belongs in the LeafAlly twin
  (`leaf_ally/house0/all_tanks.py`), which has the same state graph.
- Whether repeated high-limit trips also deserve a glitch: they may be
  what leads to a lockout that needs a reset in the basement.
