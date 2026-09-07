# grundfos-pump-curve (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**Spruce secondary pump, Grundfos UPMS 20-78 F on the 0-10 V output
(measured 2026-09-06, `experiments/2026-09-06-spruce-pump-speed-sweep/`
"Found").** Flow versus DAC volts, settled, same up, down and in
jumps to within 0.06 gpm: 3.0 -> 0.63, 3.5 -> 1.57, 4.0 -> 2.3,
4.5 -> 3.05, 5.0 -> 3.76, 5.5 -> 4.5, 6.0 -> 5.2, 6.5 -> 5.9,
7.0 -> 6.61, 7.5 -> 7.3, 8.0 -> 8.01, 8.5 -> 8.68, 9.0 to 10.0 ->
9.0 gpm flat. Linear 3.5-8.5 V at 1.45 gpm/V; maximum from 9 V.
- **Stop region is a two-state machine, not the booklet's bands.**
  States: Running (speed follows volts, minimum 0.7 gpm) and
  Stopped. Rising: Running at 0 V and 0.7 V (minimum speed),
  Stopped from 1.5 V through 2.5 V, Running again at 3 V (and the
  2.5 -> 3 V edge is unmeasured; 2.5 -> 4 V restarted it). Falling:
  Running down to 3 V, Stopped at 2.5, 1.5 and 0.7 V, Running
  (minimum speed) only at 0 V. Not measured: the exact rising edge
  between 0.7 and 1.5 V and the falling restart between 0 and 0.7 V.
- **Values to use, both directions.** Work in 3-9 V only: 3 V is
  the reliable minimum (0.6 gpm) and 9 V the maximum (9.0 gpm);
  never park between 0 and 3 V expecting speed. To stop: 1.5 V (or
  2.5 V) from any running state. To start from Stopped: go to 3 V or
  above, never 2.5 V (it leaves the pump wherever it was). 0 V means
  minimum speed, not off (booklet signal-fail behaviour), so a
  "safe" 0 V default runs the pump. Restore level today is 7.6 V,
  about 7.4 gpm.
- **The pump type belongs in the layout.** The 0-10 V output's
  config names the channel and power-on level and nothing about what
  hangs off it; the curve, the stop machine and the usable band above
  are facts of the pump model, not the DAC. A pump device-type word
  (make/model, control signal profile, min/max volts, the stop
  thresholds, nameplate flow/head) referenced from the
  `dac.output.config` entry would let the actor and the control
  layer read these instead of carrying them in code; today nothing
  in the layout says a Grundfos UPMS 20-78 is on `secondary-010v`.
