# Relay-actor enforcement (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-392

> What this is: the relay actor keeps every relay reliable on the new code —
> assert-then-verify enforcement with I2C self-heal, confirmed state from
> pin-readback, and honest boot. A launch item because the summer hack has
> this behavior today on the 0x21 cooling actuators; deploying new code
> without it is a field-reliability regression. One relay actor body serves
> all relays (zone, plant, cooling), so this is not zone-specific.

## Where it stands

Built on the branch, with in-process tests (`tests/actors/test_relay_i2c.py`):
the `I2cCommand` enforcement target with `_attempt_command` /
`_verify_and_report`, `_boot_adopt` off the pin on readback boards,
`SupportsPinReadback` on the board record, the bus actor's config-register
reset check and the `ExpanderReinitialized` poke, glitches once per
failure streak. Covered: power-on boot adopts de-energized, warm takeover
inherits an energized hold, actuation confirms then reports, a transient
EIO heals on the verify pass, a permanent one glitches once per streak,
a reset is detected, repaired and re-asserted, the repair pokes an
immediate re-assert, a garbled read does not false-positive.

What is left: the MonitorOnly gate (below, unbuilt), the two test slices
the in-process set still misses (a readback that disagrees with the
write, and a command arriving before boot adoption being deferred), and
the design's own bar: the self-heal witnessed against a real I2C fault
on the bench or box, not only the sim rig.

## Assert-then-verify enforcement (the self-heal)

The relay's 5-minute loop re-asserts its target UNCONDITIONALLY (enforcement
must not depend on the readback being trustworthy), then confirms at the pin;
the output register is read first purely as drift evidence. The target is the
pending command when one is unconfirmed — a commanded transition that fails
confirmation is held as the enforcement target (`I2cCommand`, a scada-internal
record) and retried every pass until it confirms, then commits and sends the
late `FsmFullReport`. So a transient EIO heals within ≤5 min without the boss
re-commanding. The boss MAY still re-command (a newer command supersedes the
held target) but is not the only healer. Glitches throttle to once per failure
streak.

After an expander reset the bus actor pokes the affected relays
(`ExpanderReinitialized`, a process-internal payload carrying the expander
address — never crosses the broker, not a sema word): each relay on that chip
re-asserts immediately instead of waiting for its next verify pass. The reset
is detected by the TCA9555 config-port all-1s power-on-reset signature (the
OPS-452 detection; the 0x21 map and register note are in OPS-532's
`gw108-board.md`). 0x21 carries the critical cooling actuators — the hack
repairs in the same pass, and so must we.

## Confirmed state, and honest boot

- Reported state becomes CONFIRMED state (post pin-readback), not commanded
  belief; a commanded-vs-pin mismatch is a glitch. Add `Unknown`; kill the
  assumed de-energized initial (`relay.py:498-505`).
- **`Unknown` is internal machine state only — never on the wire:** the state
  vocabularies carry no Unknown value, and an out-of-vocab wire value silently
  coerces to the enum default at decode (`Unknown → WallThermostat` would be a
  lie). The relay reports nothing until its first confirmation — readback
  boards adopt from the pins at boot (sub-second); no-readback boards resolve
  `Unknown` by ASSERTING the required posture (the only way to know a krida's
  state is to set it). A failed boot readback is a Glitch and honest silence
  on the channel.
- **One state channel per relay, not two:** the gw108 offers two reads
  (output register = commanded, input register = actual pin), but they diverge
  only during a fault, and the divergence IS the fault evidence — it rides the
  Glitch's register snapshot, not a second journal channel. The channel's
  meaning upgrades from commanded belief to pin-confirmed state; name and UUID
  unchanged.
- **Readback is a declared board capability** (`SupportsPinReadback` on the
  board record — gw108 true, krida false). Readback boards: confirmed
  semantics, boot adopts from pins. No-readback boards: commanded-belief
  semantics, enforce re-asserts rather than verifies. Flipping the declaration
  upgrades a fleet with zero actor-code change.
- No transitional states at the relay level — a single-bit actuation is one
  serialized bus round-trip; command and readback ride the same op.
  In-betweens belong to the circuit FSM.

## MonitorOnly: no physical write of any kind

`ActuationAuthority.MonitorOnly` on the ops word means the scada performs
no physical write, board initialization included: the bus actor does not
initialize expanders (no adopt-or-init, no power-on-reset clear-then-
configure), relay actors do not boot-assert no-readback boards, the
enforcement loop does not re-assert, reset repair does not re-drive pins,
and admin actuation is refused. Read-only telemetry continues: gw108 pin
adoption is a read, so a readback board still reports confirmed state.

Nothing enforces this today. Only `scada.py`'s `layout.lite` builder and
the two strategy loaders read `ActuationAuthority`; `relay.py` and
`i2c_bus.py` never do. The actuator and bus actors read the authority at
boot and gate every write path on it. The default of the word is
MonitorOnly, so an ops artifact that fails to say otherwise degrades to
non-actuation, which is the direction a decode mistake should fall.

Test: boot the sim pair with `ActuationAuthority: MonitorOnly` and assert
no bus write is issued through boot, an enforcement pass, and an admin
command (refused with a glitch); then `Active` and assert the same paths
write.

## Testing (the EDD bar)

Confidence here comes from an experiment that drives a real (or sim) I2C fault
and watches the self-heal, not from unit tests over a backdoor. Two relay-test
gaps are pulled forward to launch (they are gaps 2 and 4 of OPS-532's relay
test catalog):

1. **Failed confirmation and the retry loop.** Drive `_attempt_command` /
   `_verify_and_report` against a readback that disagrees with the write and a
   bus-op timeout: assert the Critical glitch to the boss, the state staying
   put, the `_i2c_command` enforcement target retried on the next verify pass,
   and the commit on the retry once the fault clears — the ≤5-min self-heal
   witnessed.
2. **Boot adoption on a readback board.** `_boot_adopt` reads the pin and
   adopts state without writing, holding `Unknown` until then: assert the
   relay adopts `EnergizedState` at start from a pin that reads energized (no
   assumed de-energized), and a command received before adoption is deferred,
   not lost.

The harness stays a re-runnable reproducer under `experiments/`; findings
distill into scoped Verified claims.

## Open

- hp-boss consuming the `FsmFullReport` to alert on a relay-reported failure
  (OPS-532 relay-test gap 5): the enforcement loop self-heals whether or not
  the boss listens, so the alert path is a separate layer — in scope only if
  this spoke claims "the boss learns of failure."
- Krida commanded-belief branch (OPS-532 relay-test gap 9) matters only if a
  krida board is in the launch fleet.
- five-v-restore-liveness (OPS-532): a 5 V hold expiring the pico liveness
  clock triggers a full relay power cycle at the next TurnOn — one real power
  cycle per turn-on on real hardware, which the hack does not do. Small, and
  kept post-launch.
