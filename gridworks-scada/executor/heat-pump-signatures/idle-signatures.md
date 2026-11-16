Status: Draft · Pass 0 · Updated 2026-11-16

# Idle signatures

What this is: what a heat pump does in the scada's channels while its
compressor is off, per model: standby draw, and anything the unit runs on
its own that code could mistake for a start. Standby draw for the Ecodan
and the LG is in [`startup-signatures.md`](startup-signatures.md).

## Mitsubishi Ecodan (maple)

Read from the journal DB (`hw1.isone.me.versant.keene.maple.scada`),
2026-11-11 to 2026-11-16 ET, and from maple's service log for the
commands. Channels: `hp-odu-pwr`, `hp-idu-pwr`, `primary-flow` (the sum
of `sieg-flow` and `sieg-send-flow`), `hp-scada-ops-relay`.

**The primary pump does not show on `hp-idu-pwr`,** which reads 0 ± 4 W
with the pump running or stopped, so the pump is read from
`primary-flow`: about 5.0 gpm with the valve at full keep, 4.2 to 4.3
gpm at full send, 0 when stopped. `hp-odu-pwr` at standby reads 54 to
60 W while the pump runs and 32 to 34 W while it is stopped.

**The pump runs while the heat pump is off.** With the call closed and the
compressor at thermo-off it runs through the gap (every gap of 2026-11-11
to 2026-11-13 12:00, the longest 06:59 to 12:04 on the 13th, at 5.0 gpm).
With the call open it stops for about 30 s as the call opens, then runs
again at about 5 gpm for the rest of the off period: every HpOff period
from 2026-11-13 15:58 to 2026-11-16 02:33 ET, the longest 6.5 h. One off
in that span stopped the pump: 2026-11-16 00:28 ET, the compressor
running 2.5 min past the call opening, the pump stopping 3.4 min after
the compressor and staying off 22 min. With the valve at full keep the
stopped loop cools on its own, about 55 °C at 5 min, 36 °C at 2 h, LWT
0.5 to 1.6 °C under EWT, while the buffer top holds.

**The pump economy setting.** On 2026-11-13 at about 12:30 ET a Mitsubishi
technician changed a setting at the unit to stop the pump between
cycles; the setting is read as the Hydrobox service menu's "Economy
settings for pump" (Auxiliary settings; On with a delay of 3 to 60
minutes, factory default On, 10 minutes; the manual's description is
"Water pump stops automatically in certain period of time from when
operation is finished"), with the delay at its 3-minute minimum.
Confirmation of the setting's name and value from Mitsubishi is pending.
In the three cycles of the visit the pump stopped with the compressor:

| Case | Compressor off | Pump |
| --- | --- | --- |
| thermo-off, call still closed (12:41:54) | falls to standby in 2 s | 4.3 to 0.95 gpm within 5 s, 0 at 12:45:00, 3 min after the stop |
| off while the call is open (13:28:43, 13:47:24) | falls to standby in 1 s | 0 within seconds |
| before a compressor start (13:22:01, 13:41:13, 13:53:07) | | starts 192, 192 and 183 s before the compressor; within about 30 s of a call closing |

From 15:58 the same day the pump runs through the off periods as above,
and no thermo-off gap since has lasted over 2.3 min, so what the setting
does at thermo-off is unmeasured. Its one steady effect is the 30 s
stop at the call opening, which the unit did not do before.

The service manual's fault 27, "does not start operation smoothly", names
too short a delay in this setting as a cause; nothing of the kind has
shown since.

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

- Why the Ecodan's pump runs through an off period with the economy
  setting on, stopping only for about 30 s at the call opening and once
  for 22 min, and what it does at a thermo-off longer than the three
  minutes; whether the setting is what the technician set, with
  Mitsubishi.
- What the Samsung does during an idle pulse, and what starts a run of
  them (outdoor temperature not yet checked against the two runs).
- Whether the idle water-pump cadence is a Samsung field setting.
