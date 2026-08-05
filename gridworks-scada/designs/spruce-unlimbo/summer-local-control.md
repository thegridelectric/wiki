# Spruce summer local control (spoke)

Status: Draft · Pass 0 · Updated 2026-07-30 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — the scada takes over the summer
> cooling job from `starter-scripts/spruce_summer_hack.py`: the TOU
> schedule, the actuation sequencing, the zone holds, and (new, the point)
> **behavioral verification with a Critical glitch when the heat pump does
> not actually turn on**. Samsung-generic device facts live in the PRIMARY
> doc (Samsung AE055 Drive folder); field events on GRI-11.

## Why this exists (2026-07-30 incident)

The heat pump did not run overnight although the cool call was physically
asserted ~10.9 of the 11 ON hours (pin-level readbacks green): the unit was
OFF at the panel, and the external contact commands thermo-on/off only
within a running unit. Nothing in the system noticed — the call was
verified electrically, never behaviorally. The eGauge now meters the heat
pump directly, so commanded-vs-actual is finally observable. Full timeline
in the GRI-11 field log (2026-07-30 comment).

## The requirement — commanded ≠ actual is a CRITICAL glitch

- **hp-not-starting:** cool (or heat) call commanded closed and HP power
  stays below a running threshold past a grace window ⇒ Critical Glitch.
  Grace must tolerate the unit's own protections (min-cycle timers,
  defrost); the witnessed starts show primary pump within ~10 s and
  compressor ramp inside ~2 min, so a 3–5 min grace is the starting point.
- **hp-not-stopping (symmetric):** call open and draw persists past the
  off-delay plus grace ⇒ Critical Glitch. The off-delay is real and
  witnessed: **the Samsung stands down ~4 minutes after the call opens**
  (2026-07-30, watched on the eGauge to the second).
- The power observable is the eGauge HP metering (landed 2026-07-30);
  channel naming/layout carriage to settle when the spruce layout regen
  lands.
- These checks generalize the summer hack's semantic flow check (pump
  commanded vs measured flow) from one actuator to the system's behavior.

## What carries over from the summer hack

- **Schedule:** weekends ON; weekdays ON 00–07 / 12–16 / 20–24, OFF
  on-peak. Becomes a LocalControl concern, not a standalone script.
- **Sequencing:** ON = iso open → DAC volts → pump on → call closed;
  OFF = call open → pump off; DAC never zeroed (some circulators treat
  0 V as "default curve") — the pump relay is the on/off authority.
- **The secondary pump must match the primary's flow (~7.5 GPM) across
  the HX** — the 65 % / 7.55 V setting realizes that. The Grundfos's
  min-speed-on-signal-loss fallback is a FAULT condition to alarm on
  (broken heat exchange), not a degraded operating mode: the 0-10V DAC
  path is required equipment, and a dead DAC (dac3, 2026-07-30) blocks
  proper cooling until re-landed on a healthy DAC channel or replaced.
- **Zone holds:** held zones = failsafe energized + scada relay 0,
  enforced, deliberately latched if the service stops.
- **Drift enforcement + expander reset auto-repair:** detect (config regs
  in input mode, confirm re-read), CRITICAL with register snapshot,
  re-init + re-assert. In the actor world this hardening lives in the
  durable actors (bus actor init-guard, per-op glitches) rather than a
  polling loop — a failure reports immediately, not at the next 5-minute
  pass.

## Device-behavior facts (Samsung AE055, spruce-witnessed)

- External contact commands thermo-on/off **only within a running unit**;
  panel OFF ⇒ a closed call does nothing (2026-07-16, re-confirmed
  2026-07-30). Open question: whether a power event can leave the unit
  panel-OFF (the 2026-07-30 03:10 electrical-event hypothesis, GRI-11) —
  if so, recovery needs a panel-side answer (a power-on-restore FSV if one
  exists — PRIMARY doc question) and the hp-not-starting glitch is the
  detection either way.
- Stand-down ~4 min after call opens (witnessed 2026-07-30); primary pump
  responds in ~8–10 s; min-run timer ~5 min (2026-07-16 cycles).

## Build dependencies (sequenced elsewhere in this design)

- The i2c relay path through `I2cBus` (chunk A — the call/pump/iso relays
  as scada relay actors on the gw108 expanders).
- `I2cDacWriter` for the secondary-pump 0-10V (landed 2026-07-30 as an
  unconnected actor: contained writes, glitch on failure, heartbeat
  re-assert; layout wiring waits on an actor.class value and the
  bare-byte mux op vocabulary).
- The spruce layout regen with the gw108 board record, i2c-bus node, and
  the HP power channel.
- The owned-address allowlist on `I2cBus` before any window in which the
  scada and the hack share the bus.

## Open

- Cutover shape: the hack stays the TOU/failsafe authority until the scada
  path is verified end to end on the bench and in a spruce window; define
  the witnessed handover test.
- Grace-window values for both glitches (tune against real eGauge traces).
- Where the schedule lives (ops artifact values vs LocalControl code).
