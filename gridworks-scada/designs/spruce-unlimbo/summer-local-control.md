# Spruce summer local control (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: spruce-unlimbo's active spoke — run the summer hack's
> functionality (`starter-scripts/spruce_summer_hack.py`) through the
> scada, on the fully sema-fied hardware layout, with the hardware word
> family promoted to published. Samsung-generic device facts live in the
> PRIMARY doc (Samsung AE055 Drive folder); field events on GRI-11.

## ▶ Next

**Build step 6 — the bench rung.** The relay actor path AND the
OPS-452 bus-actor guard are built (2026-08-12): `I2cRelayComponent`
accepted with board-record resolution; per-op pin-readback confirm
with the false-positive re-read; boot pin-adoption; assert-then-verify
enforcement converging on the held command; `I2cBus` adopt-or-init at
boot (warm takeover preserves latched holds; POR gets
clear-then-configure — outputs are ALL-1s at POR, so configure-first
would drive every relay ON), heartbeat config-register reset guard,
and immediate relay re-assert after repair (`ExpanderReinitialized`
poke). The sim register backend (`drivers/sim_i2c.py`, the
register-level fidelity dial in the simulated-test-environment
design) carries the GRI-11 failure choreography in the suite.
`NolanLocalControl` (`690d584e`) boots into Normal running the
scripted witness — fancoil takeover + call (Caleffi-latency hold),
secondary pump on/off — then segues to Monitor; record-driven off
`Hydronic.ZoneCallCircuits` + board RelayNames.

**The relay path's EDD gate is MET** (2026-08-12, spruce on-peak
windows, honeysuckle bypassed —
`experiments/2026-08-12-spruce-witness-window/`): warm takeover ×2,
six pin-confirmed actuations across three vocabularies, zero
glitches, and the first behavioral numbers — dist response through
the Caleffi box ≤29 s (off ~5 s); secondary-flow 7.46 GPM within
seconds at the 65% EEPROM default (off ~4 s).

**The DAC leg is BUILT and its bench EDD gate MET** (2026-08-12,
`experiments/2026-08-12-dac-bus-bench/`): `I2cDacWriter` rides
`I2cBus` (mux select + Multi-Write + bare EEPROM read as the new
i2c op words), resolves wholly from the layout, asserts the
layout's PowerOn targets (no dispatch surface until the
`i2c.dac.channel.config` binding word), and boot-verifies EEPROM
with the write-cycle settle (the bench finding). Layouts emit the
`gw108-dac2-writer` node natively since the partition correction
(sema `91385fe`) put actor.class/013 on staging node.gt/303. The
spruce-side DAC witness rides the next on-peak window. Skeleton
`I2cRelayBoard` deleted; the defunct note is on
`gw1.actor.class/012+013`.

**Step 7's first increment is BUILT** (2026-08-12): Normal runs
TOU cooling — schedule, state-command sequencing (each actuator's
own event vocabulary via the new `send_state_command` single
construction site), zone holds on circuits 1/2/4; suite-verified
against the spruce artifact. **Crash prevention moved into the
layout contract**: `gw.nolan.layout` axiom 3 (LocalControlPlant)
forces the plant NODES by spaceheat name (never board RelayNames);
actors declare `REQUIRED_NODES` and crash-with-Glitch on a bypass —
no Monitor segue, never partially blind. The pinned suite fixture
is the regenerated honeysuckle artifact (circuits + plant + DAC +
sim-uid primary BTU), retiring the legacy-format one; `sema_to_dc`
gained the uniform `load_layout` entry point (the LTN's
legacy-only load was a live gap). Carryovers as Open items:
schedule/holds as operational params (OFI, joint with the derived
generator's required-energy cleanup) and the `gw1.system.mode`
Cooling gate. **Next: sim-boot on gw-dev-rabbit, then the spruce
window → witnessed handover at a real TOU boundary** (the hack
stays authority until it passes).
(Order settled 2026-08-12: DAC → local control → the H0N/H0CN name
sweep.) The original step-7 framing: the hack-parity TOU
schedule + zone holds as `SwitchToOff` governance, replacing the
scripted witness. Ride-along items: relay channel readings (0/1
energization at confirm + verify pass — settled shape in the zone
spoke), the `snap_watch.py` state-list patch (starter-scripts), and
the runbook rule that restore gates on the literal `window done`
line, never wall-clock arithmetic. Then the H0N/H0CN sweep
(both-cases conftest first, then parity test → port → delete
`house_0_names`; pyright enumerates the sites; the sweep also
renames the `House0Layout` dc class — today the runtime layout
class for BOTH families, surfaced by the `load_layout` question). Later rungs: the
behavioral glitches (hp-not-starting/stopping). Sema pendings:
the epic-end promote before any spruce deploy (`GridworksSimGw108`
landed in-place on staging 001, sema `3524b73`); NEW
`new.command.tree` + `scada.control.capabilities` versions are
expected before the promote — both are functional-scada surfaces
(the command tree carrying the full actor set incl. the DAC
writer; capabilities is the OPS-394 vocabulary) — they re-entered
staging in the 2026-08-12 partition correction and evolve freely
until the epic-end freeze. Code pins and the
window arrangement:
[`spruce-relay-control.md`](spruce-relay-control.md).

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
3. ✅ **Layout regen** (tlayouts `jm/spruce`): snapshot rebuilt from
   the hardware words (DAC writer seeded in), board record with mux +
   DAC topology + SPS menu, reader `DataRateSps: 8` declared with a
   gen-time menu check, GNodes at published `g.node.gt/006`, the
   fancoil/floor1/pipes1 pico removal carried from actual-spruce
   (`a71617e`). The full hack-parity roster is emitted (2026-08-11):
   DAC writer component (spruce EEPROM defaults), hp call, secondary
   pump, five zone failsafe/ops pairs, and `iso-valve-relay` on the
   valve words (wiring fact as config data; `iso-valve-failsafe`
   removed from the board record).
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

The hack's **semantic flow check** (secondary-flow agrees with the
commanded pump state) does NOT port into the relay actor — it is
system-level truth (command ↔ water ↔ HP power), and it joins the two
glitches below as part of a standing **system-working EDD harness**
(settled with Jessica 2026-08-12): a re-runnable experiment asserting
commanded posture against measured flow and power on the real system,
riding the verification ladder rather than pin-level code.

**The harness's first two experiments (Jessica, 2026-08-12),
runnable in an on-peak window:**

- **Secondary pump start/stop** — command the pump relay (DAC holding
  the 65% speed), verify at `secondary-flow`: ON ⇒ ~7.4 GPM across
  the HX, OFF ⇒ ~0. The hack's semantic check as a witnessed
  experiment. (Known diagnostic muddiness: the secondary-BTU pico
  drops out — treat a stale reading as no-evidence, never as
  failure.)
- **Fancoil path takeover** — take the zone-5 fancoil circuit
  (failsafe → Scada), command the call, verify at the distribution
  response. **Plant fact: a Caleffi zone-control box likely sits
  between our zone relays and the distribution pump**, adding seconds
  to ~half a minute of latency — grace windows size to it, and the
  box is a real axis-2 binding (call → Caleffi → dist pump) for the
  capability model. During on-peak there is no chilled water, so the
  takeover moves air and water plumbing only — reversible, ends back
  at StatRules.

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
- **OFI — TOU schedule + held-circuit set as operational params**
  (settled 2026-08-12: in-code constants for the hack-parity build; the
  ops-params surface grows deliberately, once). Same cleanup family: the
  derived generator's "required energy" hack — its heating-season
  assumptions want the same operational-params pass rather than another
  in-code special case.
- **`gw1.system.mode` needs a Cooling value** (000 is published →
  additive 001) and the TOU loop its mode gate before any
  heating-season deploy of NolanLocalControl — today's loop is
  mode-blind exactly like the hack (the spruce ops artifact still says
  Heating). Joins the zone spoke's mode-is-system-level thread.
- Axiom constants (sweep overhead ms, slack fraction) — settle at word
  authoring with the measured anchors (135 ms/read at 8 SPS, 16 ms at
  128).
