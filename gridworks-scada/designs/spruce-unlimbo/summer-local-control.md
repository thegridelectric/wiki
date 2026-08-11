# Spruce summer local control (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: spruce-unlimbo's active spoke — run the summer hack's
> functionality (`starter-scripts/spruce_summer_hack.py`) through the
> scada, on the fully sema-fied hardware layout, with the hardware word
> family promoted to published. Samsung-generic device facts live in the
> PRIMARY doc (Samsung AE055 Drive folder); field events on GRI-11.

## Experiment gate met (2026-08-11)

The ADS-at-declared-rate EDD gate is met: the bench rung (2026-08-10,
both pairings) and the spruce window (2026-08-11, real thermistors:
zero i2c errors, zero readback mismatches, four zones publishing real
temperatures, noise floors in the 8 SPS band) both PASS — record in
`experiments/2026-08-10-ads-declared-rate/`. Running before promote
paid twice: the bench caught the `GNodeGt` 005 pin (fixed `7b734d85`);
the window caught the LocalControl Nolan-layout crash (step 7 note
below).

## The goal

The scada replaces the hack as spruce's cooling authority, at hack
parity: TOU schedule, ON/OFF sequencing, zone holds, secondary-pump DAC
speed, 5-minute enforcement (drift correction + expander-reset
detection with register forensics), semantic flow check. Everything the
hack knows moves into the layout — the board record carries the
mux/DAC/EEPROM facts, the components carry the deployment choices, the
actors resolve them; no hard-coded addresses. The hardware word family
goes to published on the way: staging is dev-brokers-only, and the
deployed spruce scada speaks to the prod broker, so production words are
a boot requirement, not a nicety.

## The build, in dependency order

1. ✅ **Hardware words** (sema `1d02655`, on `jm/hardware-words` — merge
   to sema dev pending): mux model, DAC writer + EEPROM channel configs,
   ADS menu + `DataRateSps`, coupling axioms stashed with the layout's.
2. ✅ **gwsproto mirrors** (scada `87c1768f`): named types + enums +
   axioms; gw108 board record carries the real DAC topology (Dac1/2/3
   behind DacMux); the reader builds its config word from the
   component's `DataRateSps`, conversion wait computed from it.
   `sema validate` green on all new/changed types; the reader component
   validates except for the known pre-existing nested divergence (next
   item).
3. ◐ **Layout regen** (tlayouts `jm/spruce`): DONE — snapshot rebuilt
   from the hardware words (DAC writer seeded in), board record with
   mux + DAC topology + SPS menu, reader `DataRateSps: 8` declared with
   a gen-time menu check, GNodes at published `g.node.gt/006`, the
   fancoil/floor1/pipes1 pico removal carried from actual-spruce
   (`a71617e`), both outputs regenerated + snapshot-validated.
   REMAINING for later steps: emit the DAC writer component (with the
   spruce EEPROM defaults) and the i2c relay nodes (iso valve,
   secondary pump, hp call, zone failsafe/scada pairs) on
   `i2c.relay.component.gt`.
4. ✅ **ADS-at-declared-rate experiment** — the pre-promote EDD gate,
   met: bench rung 2026-08-10 (both pairings) + spruce window
   2026-08-11 (real thermistors, zero errors, noise in band) —
   `experiments/2026-08-10-ads-declared-rate/`.
5. **Promote the hardware-word closure to published** (`sema promote`,
   hash-pinned, immutable after) — **held to the END of
   spruce-unlimbo** (settled 2026-08-11, sequencing in the
   zone-relays-and-thermostat-model spoke): the closure stays staging
   while the zone/relay vocabulary settles as in-place edits, and the
   promote additionally gates on the `house0.layout` sema word running
   on ALL the House0 homes. Open decision at promote time: the
   closure includes `i2c.thermistor.channel.config/002`, whose sema
   shape (capture tuning moved to layout channel configs) today's
   gwsproto `ChannelConfigBase` inheritance does not conform to when
   capture fields are populated — the known flaw the proactor port
   sweeps up. Either promote (the sema word is the contract; gwsproto
   catches up at the port) or hold that word back from the set.
   Also fold in: the reader-example `DataRateSps` 16 → 8 flip.
6. **Scada actors** (`jm/spruce-unlimbo`): register `I2cBus` /
   `I2cRelayBoard` in `actors/__init__.py`; reply-to from `Header.Src` on
   `I2cResult`; the relay path resolving `RelayName` against the board
   record; the OPS-452 init-guard in the bus actor; mux ops on the bus
   so `I2cDacWriter` drives the secondary pump (dac2 channel_c behind
   mux channel 2) through the single bus owner; startup DAC-EEPROM
   verify (read → note mismatch → reprogram → re-verify).
   **Next-version addition — layout-address validation on `I2cBus`**
   (2026-08-10; originally conceived as window-safety, re-scoped when
   the window protocol simplified to stopping both services): the bus
   actor derives the set of legal i2c addresses from the layout's
   board record and (a) refuses at boot if any component or relay in
   the layout declares an address outside the board's namespace — a
   typo'd relay address becomes a refusal to run, not a runtime
   surprise — and (b) glitches and refuses any runtime op targeting an
   undeclared address. Validation of the layout against the board's
   physical truth, with the layout as the authority.
7. **Local control** — TOU schedule + sequencing + zone holds +
   enforcement as scada behavior, hack parity (where the schedule lives —
   ops artifact vs code — is an Open below). The zone side codes
   against the circuit/governance model in
   `zone-relays-and-thermostat-model.md` — hack parity's zone holds =
   `SwitchToOff` on the floor circuits.
   **Known crash to fix on the way in** (2026-08-11 spruce window):
   LocalControl's ScadaBlind entry calls `turn_off_store_pump` →
   `self.store_pump_failsafe.handle` on a node the Nolan layout does
   not have (`sh_node_actor.py:797`, `tou_base.py:442`) — the actor
   dies at the 5-min missing-forecast mark. The deployed
   `actual-spruce` line guards the equivalent case ("Store pump
   recovery disabled: required relay/010V nodes are not present in
   layout"); the unlimbo path needs the same layout-conditional guard —
   an instance of the axis-3 leak the hub's conceptual model removes.
8. **Verification ladder** (EDD): suite green → gen-time validation →
   honeysuckle bench boot per step (relay actuation + DAC write on the
   bench board, zero cooling stakes) → sim-boot the spruce layout on
   local `gw-dev-rabbit` → spruce box window → **witnessed handover**:
   hack stopped, scada takes a real TOU boundary (every boundary is a
   free witnessed test).

The reader→bus leg of this ladder is already verified on the bench
(2026-07-30 run log, [`spruce-relay-control.md`](spruce-relay-control.md));
that spoke also carries the code-survey pins (what exists, what is
skeleton) and the spruce-window safety arrangement (broker isolation,
one-ADS-reader rule, allowlist precondition).

## Behavioral verification — the post-parity increment (2026-07-30 incident)

The heat pump did not run overnight although the cool call was physically
asserted ~10.9 of the 11 ON hours (pin-level readbacks green): the unit
was OFF at the panel, and the external contact commands thermo-on/off
only within a running unit. Nothing noticed — the call was verified
electrically, never behaviorally. The eGauge now meters the HP directly,
so commanded-vs-actual is observable. First increment after hack parity:

- **hp-not-starting:** call commanded closed and HP power below a running
  threshold past a grace window ⇒ Critical Glitch. Grace must tolerate
  the unit's own protections; witnessed starts show primary pump within
  ~10 s and compressor ramp inside ~2 min, so 3–5 min is the starting
  point.
- **hp-not-stopping (symmetric):** call open and draw persists past the
  off-delay plus grace ⇒ Critical Glitch. The off-delay is real: the
  Samsung stands down ~4 min after the call opens (2026-07-30, watched on
  the eGauge to the second).
- These generalize the hack's semantic flow check from one actuator to
  the system's behavior.

## What carries over from the summer hack

- **Schedule:** weekends ON; weekdays ON 00–07 / 12–16 / 20–24, OFF
  on-peak.
- **Sequencing:** ON = iso open → DAC volts → pump on → call closed;
  OFF = call open → pump off; DAC never zeroed (some circulators treat
  0 V as "default curve") — the pump relay is the on/off authority.
- **The secondary pump must match the primary's flow (~7.5 GPM) across
  the HX** — the 65 % / 7.55 V setting realizes that. The Grundfos's
  min-speed-on-signal-loss fallback is a FAULT condition to alarm on
  (broken heat exchange), not a degraded operating mode: the 0-10V DAC
  path is required equipment. The speed wire lands on the Z6 output —
  dac2 channel_c — since the 2026-08-10 rewire (dac3's i2c interface
  died 2026-07-30), with EEPROM power-on defaults programmed the same
  day.
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

## Open

- Cutover shape: the hack stays the TOU/failsafe authority until the
  witnessed handover passes; the hack's systemd unit is then disabled,
  not deleted (winter twin precedent).
- Grace-window values for both glitches (tune against real eGauge traces).
- Where the schedule lives (ops artifact values vs LocalControl code).
- Axiom constants (sweep overhead ms, slack fraction) — settle at word
  authoring with the measured anchors (135 ms/read at 8 SPS, 16 ms at
  128).
