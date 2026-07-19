# I²C / board-resident components — actor layer (spoke — deferred to pass-two)

Status: Accepted · Pass 1 · Updated 2026-07-19 · Linear: OPS-407

**Nolan slice pulled forward (2026-07-19):** the spruce relay work
([OPS-392](https://linear.app/gridworks/issue/OPS-392), the spruce-unlimbo design's
`spruce-relay-control.md` spoke) executes this model for the nolan/gw108 case now:
the `Gw108Adc` value + thermistor-reader `/003` (steps 1–2), `I2cBus` wiring with
reply-to (step 4), and the nolan layout's relay nodes on `i2c.relay.component.gt`
with `relay.py` resolving `RelayName` against the board record (the nolan half of
step 3). The krida decommission and the House0 layout migration remain pass-two,
this spoke.

**Capability reshape (2026-07-09, landed with the functional-relay-names work):** the board-record
vocabulary went through a naming + shape correction. `i2c.relay.config` → **`i2c.relay.capability`**
(the record describes what the board OFFERS, not a chosen configuration — the "config" name collided
with `relay.control.config`, which IS the chosen configuration); siblings renamed the same way
(`i2c.adc.capability`, `i2c.dac.capability`, `i2c.thermistor.interface.capability`). New
**`i2c.expander`** word: per-relay entries carry expander-relative position (ExpanderIdx +
Register/Bit), and the board's `Expanders` list carries the addressing — fixed `I2cAddress`
(soldered, gw108) or `AllowedI2cAddressList` (DIP switches, krida); the chosen address is a
deployment fact on the component's `I2cAddressList`, index-aligned with Expanders. The published
`i2c.relay.config/000` stays frozen with `replaced_by`. **`KridaDoubleRelayBoard16` now has its
`gw1.scada.device.type.gt` record** (`gwsproto/data_classes/device_types/scada_krida.py`): the
two-board GridWorks panel is ONE device — its basement markings `Relay1`–`Relay32` are the
RelayNames, and the first-bank inversion (marking 1 → pin 7, …, 8 → pin 0) is declared pin data,
harvested from the multiplexer's `gw_to_pin`. Both follow-ons from that thread landed 2026-07-09:
the mux resolves pins from the krida record instead of `gw_to_pin` (scada `ba6c6e65`), and the
tlayouts gen emits the record into each House0 layout's `DeviceTypes` (tlayouts `d75cae0`; oak
fixture adopted in scada `7000d3a7`).

> What this is: the board-resident / i2c-bus model and the relay decommission. **Deferred to
> pass-two** — it is a value-changing layout migration that touches the actor runtime (Phase 3), which
> pass-one defers. The **naming slice was pulled forward into pass-one** (scada `4182d88c`,
> 2026-07-09): relay ShNodes carry functional names, the krida board position lives in `RelayIdx`.
> Documented here so the next agent has the plan; the actor layer is **not executed
> this pass** (the sema vocabulary was authored ahead — see below).

The durable model lives in [`../../executor/hardware-layout.md`](../../executor/hardware-layout.md)
"I²C and board-resident components": the three layers (bus / board / device), the board as single
source of physical truth, the full `i2c.*` + board sema vocabulary, the two enforcement tiers, the
`BusMembership` / cross-consistency / layout bijection invariants, and the decision to route ADC reads
through `I2cBus`. The sema words are authored and green (Batches 1–3 — sema `dc6800e` + the gw108 board
example) **and** the gwsproto bus-op types are aligned to the composed family
(`I2cWriteBit`/`I2cReadBit`/`I2cWriteReg`/`I2cReadReg`/`I2cResult`, nested `Address`, `Operation` enum).
The **relay vocabulary** was authored ahead too (2026-07-03, sema `11be3be` + `fae8d27` — see steps
1 and 3 below), so pass-two needs no further sema round for the relay decommission. What remains is
the **actor wiring** to make the board the resolved source of truth at runtime.

## Remaining build steps (rough dependency order — pass-two)

1. **Device-type values first.** ✅ *Relay values minted* — `gw1.device.type/001` appended
   `Gw108I2cRelay` + `Gw108GpioRelay` (sema `11be3be`, 2026-07-03). The ADC value ("ADC on gw108",
   e.g. `Gw108Adc`) is still to mint before step 2.
2. **Thermistor reader → `i2c.thermistor.reader.component.gt/003`.** A version bump dropping
   `AdcAddress`, `AdcReferenceVolts`, `SeriesResistanceKOhms`, and `Bus` (all now on the board); keep
   `TempCalcMethod` + `ConfigList`; `DeviceType` becomes the `Gw108Adc` value; the reader names its
   board ADC by `Name`. Full version ritual (schema `/003` + registry + `002→003` upgrade template +
   regen), then align the gwsproto type and set the moved facts in `scada_gw108`.
3. **Relay decommission → `i2c.relay.component.gt`.** *Sema half* ✅ (sema `fae8d27`, 2026-07-03):
   `relay.control.config/000` (= `relay.actor.config/004` minus the positional `RelayIdx`, axioms
   ported) + the board-generic thin per-relay components `i2c.relay.component.gt/000` and
   `gpio.relay.component.gt/000` (`RelayName`/`GpioName` resolved against the board's
   `I2cRelays`/`NativeGpioOutputs` map; the board stays the single source of the physical address);
   `relay.actor.config` carries the advisory `replaced_by` marker. *Scada half remains:* retire
   `I2cMultichannelDtRelayComponent`, remove `i2c_relay_multiplexer` + `i2c_relay_board`, rework
   `relay.py` to resolve `RelayName` against the board and write via `I2cBus`. Layout + fixture
   migration (every relay node re-pointed) — its own chunk. The **functional relay ShNode names**
   half was pulled forward into pass-one (scada `4182d88c`, 2026-07-09; board position in
   `RelayIdx`) — what remains here is the component/actor migration.
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
- **The ADC device-type value name** — the `gw1.device.type` string for "ADC on gw108" (e.g.
  `Gw108Adc`); the relay values are settled (`Gw108I2cRelay` / `Gw108GpioRelay`, v001).
