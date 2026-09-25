# Start-up signatures

Status: Draft · Pass 0 · Updated 2026-09-21

> What this is: what a heat pump start looks like in the scada's channels,
> per heat pump model, with the Siegenthaler loop open and closed: the
> delay, the power ramp and its wobble, the thresholds that tell a running
> compressor from a stopped one, lift, and what happens at the upper limit.
> Read from the journal DB (beech from 2024-10, maple's Ecodan from
> 2026-03-20). The companion for defrosts is
> [`defrost-signatures.md`](defrost-signatures.md).

## Reading the channels

`hp-odu-pwr` reports on a 300 W change, polled each second, with a 300 s
periodic capture. During a ramp samples land seconds apart; in steady
running the gap is up to five minutes. Structure finer than 300 W is
invisible, and dwell times under about a minute rest on thin data.
`hp-lwt` and `hp-ewt` report on 0.5 °C where a TSnap1 ADS reads them (all
of maple; beech in spring 2025) and on 0.2 °C where a BTU pico does (beech
from the 2025–26 winter). Relay 6 (`hp-scada-ops-relay6` at maple) is the
on command: 0 is closed, commanded on. Loop closed means `sieg-flow` near
`primary-flow`; loop open means `sieg-flow` near zero. Beech's journal
carries no sieg-loop state machine in any month, so valve position there
is read from relays 14 and 15 and `sieg-flow`.

## Running and stopped, from power

A compressor that stopped itself while commanded on is read with two
thresholds on `hp-odu-pwr`, each held for a dwell: power has been over
the high one, then falls under the low one. The indoor channel is not
summed in: at beech `hp-idu-pwr` carries the LG's circulator at 342 W,
8 W under the low line, and a monobloc has none.

| | High | held | Low | held | Evidence |
| --- | --- | --- | --- | --- | --- |
| Mitsubishi Ecodan (maple) | 1500 W | 30 s | 500 W | 30 s | 291 starts, 2026-03-20 to 2026-09-21: no false fire; closest recovering dip after arming 1200 W; 22 of 28 self-stops caught, the six misses under a minute long |
| LG (beech) | 2000 W | 30 s | 350 W | 60 s | 1,321 commanded-on runs over two seasons: every compressor stop fell to 288 W or less; no run that kept going fell under 433 W after 2000 W; shortest stop 92 s |

A single 500 W line fails at both houses. At maple the median start sits
at 760 W for minutes after first crossing 500 W, and one start
(2026-04-11 10:31 ET) crossed 1000 W and fell to 1 W on the way up. At
beech four runs dipped under 500 W without stopping, and a low threshold
of 800 W would fire on about 7 % of normal runs. Dwells of 20 to 45 s score
alike at maple; from 60 s up real stops are lost.

A defrost fires the same rule (64 of 67 at maple; all five found at
beech): on power a defrost is a stop. Lift separates them, negative in a
defrost.

Neither heat pump has winter data taken this way with the loop closed.

## Mitsubishi Ecodan (maple)

- Standby 58 W (p10 55, p90 72).
- From relay 6 closing, nothing for a median 215 s; a second cluster of
  starts waits about ten minutes (p90 613 s, longest 894 s).
- Then one near-vertical step, 0 to 1 kW in about 18 s, with no separate
  pump or fan stage. About half the starts hold at 1.0–1.4 kW for a few
  minutes; 1500 W comes at a median 414 s from the command.
- Steady running about 3.4 kW median (p10 1.4, p90 4.4) by ten to fifteen
  minutes.
- A self-stop falls to 34–449 W, in one case 2859 W to 95 W in 4 s, and
  stays under 500 W for a median 99 s. A defrost falls to a median 73 W
  for a median 137 s.
- Thirty-day maximum LWT 138.9 F. Its upper limit with the loop closed
  has not been observed.

## LG (beech)

- Standby 26 W on `hp-odu-pwr`; `hp-idu-pwr` steps 26 to 342 W when the
  LG's own circulator starts.
- From relay 6 closing: the scada's primary pump at about 140 s, the LG's
  circulator at about 310 s, the compressor at a median 379 s (p10 356,
  p90 400).
- `hp-odu-pwr` sits flat at standby until the compressor ramp, then
  climbs in steps without overshoot: 300 W to 1000 W in about 11 s, 2000 W
  at +77 s, 3000 W at +108 s, one dip of about 10 % near 4 kW. Steady
  running 7.2–7.6 kW median, to 14.1 kW.
- A self-stop falls to 20–74 W within one reporting interval and stays
  there 92 s to 43 minutes, median 299 s.

## Samsung AE055FEYMCG (spruce)

33 starts, 2026-09-21 to -24, from the journal DB under the spruce
winter hack (heat call on the TOU schedule; the secondary pump then
followed `hp-odu-pwr` above 120 W). At spruce `hp-odu-pwr` samples land
about a second apart during a ramp, in steps well under 300 W.

- Standby and idle behaviour: [`idle-signatures.md`](idle-signatures.md).
- In the traced 2026-09-23 20:00 start the Samsung's water pump reached
  11.3 gpm at 20:00:07 and the compressor's first reading over 120 W came
  at 20:00:23.
- Power passes 500 W 4–12 s after its first reading over 120 W (median
  6 s) and 800 W in 7–17 s (median 11 s). The first three minutes peak at
  1.8–4.7 kW.
- At the 500 W crossing lift is still the difference the water held
  before the start, 0–3.3 °F. Lift 2 °F above that comes 15–26 s after
  the crossing in 20 restarts with a warm loop, and 83–133 s after it in
  11 first starts of a charge from a cold loop.

## Loop closed against loop open

Beech, spring 2025, medians, aligned on the compressor reaching 2 kW; 19
closed starts against 316 open in the same months, starting LWT near
100 F in both.

| | Closed | Open |
| --- | --- | --- |
| Power, first three minutes | 2.1 to 3.7 kW | the same |
| Power, three to five minutes | 3.4 to 3.9 kW | climbing toward 6.7 kW at ten minutes |
| LWT rise, first three minutes | 9 to 19 °F a minute | 3 to 4 °F a minute |
| EWT rise, first two minutes | 18.6 °F | 0.9 °F |
| Lift at two and at ten minutes | 10.5 °F, 8.2 °F | 11.3 °F, 29.4 °F |
| Reaches the upper limit inside ten minutes | 6 of 19; every start held closed five minutes | 20 of 316 |

On power the two are alike for three minutes, after which the closed
start holds near 3.8 kW and the open one keeps climbing. Lift does not separate
them early at beech: in the closed loop EWT trails LWT by the loop's
transit time while LWT climbs fast, so closed lift is not small. EWT does:
a rise of more than 6 °F in the first two minutes marks a closed loop, 21
of 22 closed starts caught against 6 % of open ones. Beech's closed starts
show `sieg-flow` at 83–94 % of `primary-flow`, either a real bypass of
about 0.5 gpm or two flow meters disagreeing.

Held at full keep, the LG's LWT climbs to the limit without slowing. Of the
19 closed starts the valve was opened in nine, 70 to 310 s after the
compressor reached 2 kW; four were commanded off; six tripped, two of them
restarts into a loop still at 171 °F that tripped in about 100 s. All six
starts that stayed closed for five minutes reached 178–188 °F. The rise
rate, full keep only, is a median 12 °F a minute at 90–99 °F LWT, 19 at
140–159 °F and 14 at 180–189 °F; cut at the instant each valve leaves keep,
median LWT is 173 °F at 300 s and 181 °F at 360 s. No closed start lasts
ten minutes. A median trace that is not cut there shows a false plateau
near 164 °F, made of opened valves and censored trips. Traces and the
per-start table: `scratch/basic-sieg/full-keep-traces/`.

Maple has eight loop-closed starts, three of them doubtful (flow readings
minutes old, relay travel before the start), so its numbers are
indicative. The longest, 600 s closed on 2026-04-19, reached 146 °F with
the rise down to under 1 °F a minute, and the Ecodan then stopped itself.
Otherwise: power lower when closed
(1.9–3.0 kW through ten minutes against 2.6 to 4.3 kW open), lift near
zero (1.3 °F at two minutes against 10.5 °F), LWT rising about 7 °F a
minute, EWT up 13.3 °F in two minutes against 0.9 °F. EWT tracks LWT with
almost no lag there.

When the valve opens on a running heat pump, LWT dips about a minute
later as the cold water arrives: a median 11 °F at beech in winter (back
in about two minutes), 20 °F in spring 2025 (about five minutes), 11 °F at
maple (about three). Lift jumps to about 16 °F. Beech's power rises
(3.6 to 4.6 kW); maple's eases slightly.

## The LG at its upper limit

The LG stops its compressor at 182–188 °F LWT; across two seasons 85 trips
cluster at 185–190 °F. With the loop closed and LWT rising 13–18 °F a
minute the limit comes about six minutes after the compressor starts,
and again every ten to twelve minutes, with 7.2–7.6 kW between and
standby after. With the loop open against a hot buffer it comes about 25
minutes in; every limit trip of the 2025–26 winter was of that kind.

Six loop-closed episodes of repeated trips, all spring 2025:

| Evening (ET) | Trips | LWT at the trips | Ended |
| --- | --- | --- | --- |
| 2025-03-21 | 6 | 183–184 °F | valve opened, recovered |
| 2025-03-31 | 3 | 102–133 °F | valve nudged, recovered; not at the limit |
| 2025-04-01 | 3 | 105–166 °F | valve opened, recovered |
| 2025-04-09 | 3 | 141–172 °F | valve opened, recovered |
| 2025-04-21 | 7 | 181–188 °F | no power above 2 kW for 15 hours, through later on commands |
| 2025-05-01 | 7 | 182–188 °F | no power above 2 kW for 45 hours |

The last two are read as the LG locking out with a fault that is cleared
by hand at the unit: the journal carries no LG fault code, so the lockout
is inferred from a commanded-on heat pump sitting at standby. Seven trips
came before each.
