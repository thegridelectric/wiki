# I²C / board-resident components — actor layer (spoke — deferred to pass-two)

Status: Accepted · Pass 1 · Updated 2026-06-27 · Linear: OPS-407

> What this is: the board-resident / i2c-bus model and the relay decommission. **Deferred to
> pass-two** — it is a value-changing layout migration that touches the actor runtime (Phase 3), which
> pass-one defers. Pass-one keeps today's positional `relayN` dc shape so `sema_to_dc` reproduces the
> current layout. Documented here so the next agent has the plan; **not executed this pass.**

The durable model lives in [`../../executor/hardware-layout.md`](../../executor/hardware-layout.md)
"I²C and board-resident components": the three layers (bus / board / device), the board as single
source of physical truth, the full `i2c.*` + board sema vocabulary, the two enforcement tiers, the
`BusMembership` / cross-consistency / layout bijection invariants, and the decision to route ADC reads
through `I2cBus`. The sema words are authored and green (Batches 1–3 — sema `dc6800e` + the gw108 board
example) **and** the gwsproto bus-op types are aligned to the composed family
(`I2cWriteBit`/`I2cReadBit`/`I2cWriteReg`/`I2cReadReg`/`I2cResult`, nested `Address`, `Operation` enum).
What remains is the **actor wiring** to make the board the resolved source of truth at runtime.

## Remaining build steps (rough dependency order — pass-two)

1. **Device-type values first.** Mint the `gw1.device.type` enum values for the board-resident coarse
   `DeviceType`s — "ADC on gw108" and "I²C relay on gw108" (e.g. `Gw108Adc`, `Gw108I2cRelay`). The
   thermistor and relay components below carry these, so they come first.
2. **Thermistor reader → `i2c.thermistor.reader.component.gt/003`.** A version bump dropping
   `AdcAddress`, `AdcReferenceVolts`, `SeriesResistanceKOhms`, and `Bus` (all now on the board); keep
   `TempCalcMethod` + `ConfigList`; `DeviceType` becomes the `Gw108Adc` value; the reader names its
   board ADC by `Name`. Full version ritual (schema `/003` + registry + `002→003` upgrade template +
   regen), then align the gwsproto type and set the moved facts in `scada_gw108`.
3. **Relay decommission → `i2c.relay.component.gt`.** Retire `I2cMultichannelDtRelayComponent` for
   one-relay-per-component: a new `ComponentBase` type carrying `RelayName` + chosen `WiringConfig` +
   the one `relay.actor.config`, `DeviceType` = `Gw108I2cRelay`. Remove `i2c_relay_multiplexer` +
   `i2c_relay_board`; rework `relay.py` to resolve `RelayName` against the board and write via
   `I2cBus`. Layout + fixture migration (every relay node re-pointed) — its own chunk. This is also
   where **functional relay ShNode names** replace the positional `relay{krida-idx}` the gen builds
   today.
4. **Wire the `I2cBus` actor.** Have it receive the composed bus-ops and reply `I2cResult` to the
   **requester** (today it goes to `primary_scada`; needs the `Header.Src` reply-to so the result
   returns with its `TriggerId`). Route the ADC reads through `I2cBus` per the executor decision.
5. **Layout bijection axiom.** Add to each layout type (`gw.house0.layout`, `gw.nolan.layout`,
   `gw1.simple.sim.layout`) that the DataChannel set is in bijection with the `ChannelName` set across
   all component `ConfigList`s.

## Open

- **`I2cResult` routing** — the reply-to (step 4) so a relay can confirm its own actuation by
  `TriggerId`.
- **Bus actor ↔ hardware bus bijection** (a hardware-layout axiom, deferred with the actor wiring):
  each `I2cBus` actor ShNode (`spaceheat.name`, e.g. `default-bus`) ↔ a board `BusList` entry
  (`i2c.bus`, `pascal.case` `Name`, e.g. `DefaultBus`), via the `pascal.case ↔ spaceheat.name` casing
  map.
- **Device-type value names** — the exact `gw1.device.type` strings for "ADC on gw108" / "I²C relay on
  gw108" (e.g. `Gw108Adc`, `Gw108I2cRelay`).
