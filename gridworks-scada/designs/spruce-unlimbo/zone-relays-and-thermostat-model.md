# Zone relays + the thermostat model in the layout (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: spruce-unlimbo spoke settling how zones, zone-call
> circuits, thermostats, and their relays are modeled in the layout —
> the design the i2c-relay build (steps 3 + 6 in
> `summer-local-control.md`) codes against. The grill walked the tree
> 2026-08-11; the model below is resolved, pending the sema word-gate
> discussion before any vocabulary lands. Board facts:
> [`gw108-board.md`](gw108-board.md). Code gaps:
> [`spruce-relay-control.md`](spruce-relay-control.md). Surviving
> both-cases survey facts: [`gleanings.md`](gleanings.md).

## ▶ Next move

**The word-gate discussion for the vocabulary this model needs** —
read `sema/spec/primary.md` + the registry/authoring spokes for the
kinds touched (types: `gw1.hvac.zone` restructure, the new circuit
record, the `SetGovernance` command, the setpoint-belief word; enums:
`zone.call.circuit.event`/`.state`,
`zone.circuit.governance.event`/`.state`, `ZoneCallSource`,
`SetpointPhase`; board-record field: `SupportsPinReadback`), then
bring the per-kind summary for confirmation before editing. All
touches are in-place staging edits under the sequencing rule below.

## The model: three concepts

The spruce living room forces the split — a baseload heating-only
stat driving the floor AND a rapid-response heat/cool fancoil stat,
two of today's `Hydronic.Zones` entries for one room.

**Zone — the thermal space** (keeps the industry word). Name,
`Critical`, `KwhPerDegF`, and an explicit `TempChannelName` reference
to the room's air-temp channel. The reference is source-agnostic: a
gw108 thermistor feeds it on Nolan, the Honeywell itself on House0,
absent for an untracked zone. One temp truth per room.

**Zone-call-circuit — the chain**: wall stat → whitewire → relay pair
→ actuator. One FSM actor per circuit. Fields: `CircuitPosition` (the
board's Z1–Z6), `ServesZone`, `ActuatorKind` (FloorLoop | Fancoil |
…), role (`Baseload | RapidResponse`), `CanCool`, `SetpointSource`
(`FromThermostat | Learned`), the inline thermostat record, and
explicit bindings — whitewire channel, failsafe relay node, ops relay
node. The gen derives bindings from position at generation time; the
record carries them spelled out; code resolves references, never
re-derives board positions from list order. Setpoint is per-circuit
(each stat has its own dial; the living room has two), learned
against the zone's one temp channel. House0 degenerates to 1:1
circuit:zone.

**Thermostat — a small inline record on the circuit**:
`ThermostatType` enum (mechanical dial | Honeywell via Hubitat |
future kinds) + optional component ref for comms-capable stats.
Promotable to a device-type word when a third kind appears. A comms
stat can BE the zone's temperature source.

Axioms: `Learned` ⇒ `ServesZone` has a temperature channel;
`FromThermostat` ⇒ the thermostat type is comms-capable. `FromThermostat`
means READ — no setpoint write path exists on any fleet (survey
below). Learned setpoint values + `SetpointPhase` belief stay runtime
state, never layout.

`ActuatorKind` bounds what a call may mean — a radiant floor cannot
cool (condensation hazard), a fan coil heats and cools; `CanCool` is
the emitter's fact, not the stat's.

Spare board positions are derivable, not modeled: the gw108
device-type record carries all six positions; the circuit list emits
only wired ones (five at spruce); "Z6: unwired" is their difference.

## The circuit FSM

Paired enums, system convention:

- **`zone.call.circuit.event`**: `WakeUp`, `GoDormant` (command
  tree); `Release`, `ScadaHold`, `ScadaCall` (the axis-1 posture
  surface — control states speak ONLY these); `ConfirmHeld`,
  `ConfirmCalling`, `ConfirmReleased`, `ActuationFailed`.
- **`zone.call.circuit.state`**: `Dormant`, `Released` (default — the
  hardware failsafe posture), `TakingHold`, `Held`, `StartingCall`,
  `Calling`, `StoppingCall`, `Releasing`.

The three postures factor as ownership + call; the call is
mode-agnostic demand (whether it heats or cools is plant state — the
fancoil's dual role proves it). Command-and-confirm is in: every
actuation verified at the op via input-port registers (the 08-10
brownout was caught only at the 5-min enforce readback; per-op
confirm catches it at the op). `ActuationFailed` ⇒ glitch with
register snapshot (OPS-452 reset signature diagnosed in place), no
dedicated Fault state — the machine holds its last confirmed state;
the boss may re-command. The whitewire sense stays OUT of the FSM (an
independent input channel); the four-value display state
(`WallThermostat-Idle/Calling · ScadaHeld · ScadaCalling`) is a
derived view (FSM state × whitewire) on its own channel. `GoDormant`
leaves pins untouched — latched holds survive service stops. The
relay pair stays two flat actuator nodes (House0 precedent) commanded
only by the circuit actor — the layering that would have made the
2026-08-10 window's ScadaBlind crash impossible.

## The governance machine (the circuit's top machine)

The circuit actor runs TWO machines — the LocalControl precedent
(`top_machine` + `machine`). Above the posture executor sits the
**governance machine**: which authority rules this circuit. Per
CIRCUIT, not per zone — the spruce living room proves it (floor
circuit held all summer while the fancoil circuit defers to its
stat).

- **`zone.circuit.governance.state`**: `Dormant · StatRules · Off ·
  ScadaThermostatic`.
- **`zone.circuit.governance.event`**: `WakeUp`, `GoDormant`,
  `SwitchToStatRules` (⇒ posture `Released`), `SwitchToOff` (⇒
  posture `Held`, latched), `SwitchToThermostatic` (⇒ the takeover
  loop: commanded setpoint vs the zone's temp channel, cycling
  `Held`/`Calling`).

`Off` is a scada-owned hold, deliberately distinct from `Released`:
releasing a floor circuit in summer lets a turned-up dial push cold
water through the floor — a condensation hazard, actively harmful,
not merely wasteful. That invariant is why holds stay latched
through `GoDormant` and service stops — `Off` protects the actuator
from the stat, not just the schedule from noise. Today's summer hack
holds ARE this state, informally; hack parity = commanding
`SwitchToOff` on the floor circuits.

Bosses (LocalControl, the LTN↔Scada surface, the future UI, admin)
command GOVERNANCE, not postures: a `SetGovernance` command of
(circuit handle, event, `SetpointF?`), axiom: `SetpointF` present ⇔
event is `SwitchToThermostatic`. Takeover works uniformly on every
stat kind because no setpoint write path exists anywhere — takeover
is always "stop deferring to the stat; run the scada-side loop
through the postures." Zone-LEVEL concerns (the critical guarantee,
baseload-vs-trim coordination across a room's circuits) stay in
LocalControl — no zone-boss actor until one earns its place; a
critical zone served by two circuits gives the guarantee redundancy
for free.

## Setpoint belief — no number when Unknown

A `Learned` circuit's setpoint is a BELIEF, never a bare number: the
pair (`SetpointPhase`, `Value?`) with the axiom **`Phase = Unknown` ⇔
no value at all** — not a placeholder, not a default, no number in
the record, on the channel, or in the UI. `Suspect±` phases keep the
last value, labeled as suspect ("the dial probably moved; last known
was 68"); only `Unknown` is valueless. `SetpointPhase` elevates from
its file-local embryo (`derived_generator.py:37-41`: `Unknown |
LastHeatCallEndTemp | SuspectZoneBelowSetpoint |
SuspectZoneAboveSetpoint`) into vocabulary. Consumers declare their
Unknown behavior explicitly (LocalControl's critical-zone check
cannot silently treat Unknown as satisfied); any conservative
fallback is the consumer's declared policy input, never written into
the belief.

## Admin: two altitudes

- **First pass (the existing contract, unchanged):** admin takes the
  command tree, relays report directly to admin, both circuit
  machines go dormant — and Dormant's pins-untouched semantics makes
  the takeover seamless (holds stay latched; nothing moves because
  admin arrived). Raw relay control remains for bench debugging and
  board bring-up.
- **The improvement — admin at the governance dial:** a second
  altitude where the machines stay awake and admin issues
  `SetGovernance` per circuit (`StatRules | Off |
  Thermostatic(+setpoint)`). Safety by construction — raw admin can
  express the cold-water mistake, governance admin cannot; and the
  journal records intent, not pin flips. Governance mode becomes the
  operating default; lands in `admin-for-nolan.md`'s scope when that
  work resumes.

## The relay actor, adjusted

- Reported state becomes CONFIRMED state (post pin-readback), not
  commanded belief; commanded-vs-pin mismatch ⇒ glitch. Add
  `Unknown`; kill the assumed de-energized initial
  (`relay.py:498-505`).
- No transitional states at the relay level — a single-bit actuation
  is one serialized bus round-trip; command and readback ride the
  same op. In-betweens belong to the circuit FSM.
- The dead krida-multiplexer round-trip path is deleted, not revived.
- `HeatcallSource → ZoneCallSource` (`WallThermostat | Scada`)
  renames at `relay.py:466-472` + the new vocabulary — season-neutral.
- **Readback is a declared board capability**: `SupportsPinReadback`
  on the board record — gw108 true (TCA9555 input registers), krida
  false (no known query path). Readback boards: confirmed semantics,
  boot adopts from pins. No-readback boards: commanded-belief
  semantics, boot resolves `Unknown` by ASSERTING the required
  posture (the only way to know a krida's state is to set it);
  enforce re-asserts rather than verifies. If a bench test ever
  proves the krida readable (`starter-scripts/single_krida.py` rig),
  flipping the declaration upgrades the House0 fleet with zero
  actor-code change.

## Enfolding the Honeywell mechanism (survey 2026-08-11)

Code pins verified on `jm/spruce-unlimbo`:

- **No setpoint write path exists anywhere** — `heatingSetpoint` is
  read-only polled telemetry (double-GET refresh, 300 s;
  `actors/hubitat_poller.py:60-70`); the relay pair has always been
  the sole zone authority. (The hub's House0 capability example says
  "Honeywell setpoint write" — divergence flagged, hub not yet
  corrected.)
- The inline thermostat record lands on `HvacZone`
  (`named_types/hvac_zone.py:8-18` — today zero thermostat
  awareness; `-stat` nodes exist only as a naming side-effect).
- The legacy hubitat family (`hubitat_gt.py`,
  `hubitat_component_gt.py`, the three actors) is already fenced
  "legacy, five homes, no expansion, not in sema" — pointed at via
  the optional component ref, never absorbed.
- `-set` / `-state` demote from required-per-zone to
  conditional-on-thermostat-type; the falling-edge-setpoint gen drops
  its `Strategy=="Nolan"` gate so `Learned` circuits work in any
  layout family.
- The web-listen path is provably dead (missing `import time`
  swallowed at `actors/hubitat_interface.py:156-160` + the s/s2
  process split — handlers can never register in either direction) —
  delete it when touched, don't fix it. Only the 300 s poll is real.
- Runtime consumers that substring-scan channel names
  (`sh_node_actor.py:100`, `ltn.py:1498`, `ltn/config.py:29-38`,
  dashboard `containers.py:191-203` which hardcodes Honeywell per
  zone) switch to reading the record.

## Sequencing

**The promote holds until the end of spruce-unlimbo.** The
hardware-word closure stays staging while this design's vocabulary
lands as in-place edits; the promote additionally gates on the
`house0.layout` sema word running on ALL the House0 homes — the merge
gate's both-cases bar applied to the vocabulary freeze. One promote,
at the epic's end, freezes the finished shape.

No channel renames now — deployed names and UUIDs keep journal
continuity; the chain-flavored prefixes (`zone2-living-rm-gw-temp`)
are cosmetic legacy for the proactor port.

## Open

- Falling-edge learning semantics for a cooling call (the edge
  relates to the setpoint from the other side; the learner needs the
  circuit's mode in hand).
- Zone 0-10V analog outputs (dac1/dac2 a-c): in the capability
  surface someday (variable-speed zone circulators), or out until a
  house uses one. Not blocking; the DAC map is in `gw108-board.md`.
- Mode is system-level (`SystemMode`): capability declarations turn
  mode changes into checkable safety semantics — a system entering
  cooling mode must not route cold water to heat-only emitters. Meet
  this when the circuit words land (axiom candidate on the layout).
- Accuracy adequacy for `Learned` (axiom checks presence of the temp
  channel; "accurate enough" is an engineering fact that could later
  live on the sensor's device type — the gw108 thermistors measure
  sd ≈ 0.01 °C, comfortably enough).
