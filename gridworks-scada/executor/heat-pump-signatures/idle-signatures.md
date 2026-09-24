Status: Draft · Pass 0 · Updated 2026-09-24

# Idle signatures

What this is: what a heat pump does in the scada's channels while its
compressor is off, per model: standby draw, and anything the unit runs on
its own that code could mistake for a start. Standby draw for the Ecodan
and the LG is in [`startup-signatures.md`](startup-signatures.md).

## Samsung AE055FEYMCG (spruce)

Read from the journal DB (`hw1.isone.me.versant.keene.spruce.ta`),
2026-09-21 16:00 to 2026-09-24 16:00 ET, under the spruce winter hack.
`hp-odu-pwr` read 0–2 W from 2026-09-17 to -20, so earlier days carry
nothing. Channels: `hp-odu-pwr`, `hp-ctrl-box-pwr`, `primary-flow`,
`secondary-flow`, `hp-lwt`, `hp-ewt`.

**Standby has two levels.** Overnight on 2026-09-23 the outdoor unit sat
at 10–14 W from 21:10, when the compressor stopped, until 02:10, then
stepped to 64–70 W; it was back at 12–14 W from 07:30, after the last
idle pulse.

**Idle pulses.** With the compressor off and no heat call, the outdoor
unit draws 168–318 W for about 60 s, every 5 minutes, in groups of five:
after every fifth pulse one is skipped and the next comes 11 minutes
later. `primary-flow` stays 0, so the Samsung's
water pump is not running during them.

| Run (ET) | Pulses | Length | Peak | Hours since the compressor stopped |
| --- | --- | --- | --- | --- |
| 2026-09-23 06:51–07:11 | 5 | 59 s median | 172–258 W | 19 |
| 2026-09-24 02:53–07:21 | 45 | 60 s median | 168–318 W | 6 |

Both runs came in the early morning and ended between 07:10 and 07:20.
While a run lasts it adds about 50–60 W on average to standby.

**Idle water-pump runs.** The Samsung runs its own water pump with the
compressor off, at the same 11.6 gpm it uses while heating:

| Start (ET) | Length | `hp-odu-pwr` median / max | `hp-ctrl-box-pwr` median / max |
| --- | --- | --- | --- |
| 2026-09-23 12:07 | 6.0 min | 62 / 62 W | 66 / 100 W |
| 2026-09-24 04:08 | 7.0 min | 148 / 232 W | 82 / 102 W |
| 2026-09-24 05:18 | 7.0 min | 76 / 86 W | 80 / 100 W |
| 2026-09-24 06:30 | 7.0 min | 228 / 308 W | 86 / 102 W |

The outdoor-unit readings above standby at 04:08 and 06:30 are idle
pulses falling inside the run. `hp-lwt` stays within about 2 °F of
`hp-ewt`: no heat is made. On 2026-09-24 the runs came about 70 minutes
apart.

**`hp-ctrl-box-pwr` shows the water pump.** It reads about 100 W whenever
the Samsung's pump runs, heating or idle, and 0–4 W otherwise. It shows
that water is moving, not that the compressor is running.

### What follows for the code

- A "compressor running" threshold on `hp-odu-pwr` must sit above 318 W.
  The spruce winter hack starts the secondary pump above 500 W
  (`starter-scripts/spruce_winter_hack.py`, quote:
  `PUMP_ON_ABOVE_W = 500.0`); start-up timing against that line is in
  [`startup-signatures.md`](startup-signatures.md) "Samsung AE055FEYMCG
  (spruce)".
- A circulator that follows `hp-odu-pwr` at a lower line runs through
  every idle pulse. On 2026-09-24 that ran the secondary pump 45 times
  and de-stratified the buffer with no heat call.

## Open

- What the Samsung does during an idle pulse, and what starts a run of
  them (outdoor temperature not yet checked against the two runs).
- Whether the idle water-pump cadence is a Samsung field setting.
