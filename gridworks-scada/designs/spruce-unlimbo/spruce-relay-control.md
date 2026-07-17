# Spruce relay control — chunk A execution (spoke)

Status: Draft · Pass 0 · Updated 2026-07-15 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — get the scada actuating spruce's i2c relays, with
> the heat pump under a single reliable on/off relay. Design-side record only. Everything
> Samsung-generic — wiring, configuration, service procedures — lives in the Drive doc
> **"PRIMARY — Samsung AE055 EHS mono control interface"** (Samsung AE055 folder, which is
> PUBLIC: no site or homeowner mentions there). Spruce install specifics + the immutable
> field log live on **[GRI-11](https://linear.app/gridworks/issue/GRI-11/spruce)** (the
> per-home issue; field events = comments).

## ▶ Next move (active spoke)

Hardware completion, in order: (1) replace the blown control-box fuse (details in the
PRIMARY doc); (2) land the RIB contact (dead-work procedure, PRIMARY doc) and set the one
Samsung config value that hands on/off authority to the contact; (3) witness the close/open
pair — the running schedule service makes every TOU boundary a free witnessed test. Then:
the ctrl-box CT lands (channel `hp-ctrl-box-pwr`) and the spruce layout regen picks it up
(gen_spruce.py in tlayouts). After spruce is up: HP make/model tracking (below) and the
OPS-27 pump device types.

## The control design (settled 2026-07-15)

- **One gw108 expander relay is the heat pump's on/off line** — the spruce realization of
  the fleet-wide `hp-scada-ops-relay` role. The relay drives a normally-open RIB whose
  contact asserts the control box's external cool-call input, configured as the sole
  compressor on/off authority (Samsung-side step, PRIMARY doc). Closed = HP runs, open =
  stops. No zone machinery involved.
- **A second relay adds the independent heat call** (winter). Candidate functional names:
  `hp-cool-call` / `hp-heat-call`. **Software interlock mandatory: never both closed**
  (manufacturer constraint — PRIMARY doc).
- **Failsafe direction is correct:** control system dead → contacts open → no call → HP
  off. The unit keeps its own protections (defrost, min cycle times, water limits) while
  commanded on — the ctrl-box CT is the behavioral verification that it actually ran.
- **Later, supersedes contact control:** Samsung's MIM-B19N Modbus module, if it reaches
  the US channel (`../../research/awhp-control-box-landscape.md`).

## Deployed and verified (2026-07-15)

- **`starter-scripts/spruce_summer_hack.py` runs under systemd on spruce**
  (`spruce-summer-hack.service`, enabled at boot; the winter twin
  `spruce-service/spruce.service` runs `spruce_hack.py`, disabled for summer). Schedule:
  weekends on; weekdays on 00-07/12-16/20-24, off on-peak. Sequencing per state change:
  iso valve commanded open → secondary-pump 0-10V (60% of max via the Grundfos UPMS 20-78
  curve, OPS-27 field data) → pump relay → HP call; failsafe open on exit (SIGTERM-safe);
  5-minute drift enforcement on the three relays + DAC (heals an accidental
  `gw108_test_code` import, which clears the expander).
- **First live transition witnessed 20:00:17 ET**: iso open → 7.20 V → pump CLOSED →
  hp-call CLOSED, correct order and timing. Schedule side is production-verified; the HP
  side goes live with the hardware completion above.
- MQTT creds moved out of script source into a pydantic-settings `.env`
  (`starter_settings.py`); all starter-script work now flows through git (local edit →
  JM commit/push → pull on spruce).
- Incident note: the control-box fuse blew during live RIB attachment (display went dark;
  fuse identified and replacement specced — PRIMARY doc). Dead-work procedure is the rule.

## What the code survey found (2026-07-15, `jm/spruce-unlimbo`)

**Working:** nolan boots cleanly as `House0Layout` (`Strategy="Nolan"`); the suite runs
against it; exactly one scada-actuatable relay exists — `vdc-relay-gpio-23` (5VDC/
pico-cycler, gw108 GPIO 23), wired end to end. `I2cBus` (`actors/i2c_bus.py`) is a
complete serialized smbus2 bit read-modify-write executor with sim stubs.

**Gaps for scada-driven i2c relays:** (1) no i2c relay nodes in the nolan layout
(`layout_gen/relay.py:646` — "added when their i2c driver is written"); (2)
`I2cRelayBoard` is a skeleton; (3) nothing produces `I2cWriteBit` — `I2cBus` is an orphan
consumer; (4) `I2cBus`/`I2cRelayBoard` unregistered in `actors/__init__.py`; (5)
`relay.py`'s only i2c branch targets the legacy krida multiplexer. The summer hack
bypasses all five (direct expander writes); the scada-actor path is the build that
retires it.

**The fork (open):** extend the gw108 component family minimally vs pull pass-two's thin
`i2c.relay.component.gt` model forward (sema vocabulary already authored). Deploy
question: spruce runs `actual-spruce` (= `td/orig-pred-set`); the scada-actor build lands
on `jm/spruce-unlimbo` per branch discipline — upgrading spruce to it requires the ops
artifact placed first (`82caac3e` deploy note).

**Prerequisite (JM 2026-07-15): single bus owner before scada-driven i2c relays.** The
deployed thermistor reader (`i2c_thermistor_reader.py`, blinka/ADS1115, direct at its own
address) does raw i2c on the same physical bus the relay commands use. Before the scada
controls i2c relays, its ADC reads must move onto the serialized **`I2cBus` actor** —
the executor decision the i2c-board-components spoke already carries (its step 4) —
so exactly one actor owns `/dev/i2c-1` inside the scada. Cross-process note: the kernel
serializes individual i2c transactions, and per-device state keeps the running summer
hack and the scada's ADS reads from corrupting each other today; the one genuinely
shared-state device is the **TCA9548A DAC mux** (channel select is global bus state), so
while the hack runs, manual DAC use from a second process (the interactive
`gw108_test_code` session) is the collision to avoid.

## Field facts (GridWorks side)

- **The gw108 expander map** is authored in `starter-scripts/gw108_test_code.py` (two
  TCA9555 expanders, all relays named; zone opto inputs ×6; ADS1115 CTs + thermistors;
  three MCP4728 DACs behind a TCA9548A mux). The board's `gw1.scada.device.type.gt`
  record matches it. DAC observation: 10 V at raw ≈4000, linear.
- **Power sensing:** no HP power metering until the eGauge lines cross the garage roof.
  Interim: George's CT on the ctrl-box feed → channel **`hp-ctrl-box-pwr`** (named for
  the metered circuit; ≈ primary-pump power is an interpretation). The gw108 CT inputs
  need a **current-out** CT (a voltage-out eGauge-type read nothing).
- The tmux monitor (`nolan_air.py`) prints snapshot channels; the secondary pump is a
  **Grundfos UPMS 20-78 with 0-10V control** (curve + type-key analysis in the OPS-27
  design, `../circulator-pump-0-10v-models.md`).

## HP make/model tracking

**Canonized 2026-07-17 into the hardware-layout design:**
[`../hardware-layout-pass-one/hp-device-types.md`](../hardware-layout-pass-one/hp-device-types.md)
is now the single source — the two record families, the three primary-pump facts, the
enum values, layout carriage, open decisions, and the execution checklist. The section
below is superseded by that spoke and kept only until this design's next consolidation
pass removes it.

## HP make/model tracking (superseded — see pointer above)

`gwsproto.enums.HpModel` (4 values, never sema-registered) rides `ScadaSettings.hp_model`
with a silent default (`config.py:58`, `# TODO: move to layout`); consumers branch control
behavior on it. Direction: retire `hp.model` into the device-type model — mint
`gw1.device.type` values per real model (nameplate-grounded: spruce outdoor
`AE055FCYDCG`, control box `AE055FEYMCG`) with **two record families**:

- **`hp.device.type.gt`** — compressor-bearing units (hp-odu): capacity, refrigerant,
  compressor amps, MCA/MOP; absorbs `HpMaxKwEl`.
- **`hp.control.box.device.type.gt`** — control boxes (hp-ctrl-box): water-pump amps,
  backup-heater options.
- **Primary-pump facts, three per-model + one per-install (refined 2026-07-16):** on both
  record families as applicable — `PrimaryPumpFactoryInstalled` (pump ships inside the
  unit vs field-supplied), `PrimaryPumpOverridable` (the unit exposes its pump-control
  signal so an interrupt can be wired — the Samsung/LG two-stage terminal-block pattern;
  false where the pump is sealed inside, e.g. the AE055 box), `PrimaryPumpAlwaysOn`
  (under the unit's own control the pump never stops — maple's unit). The per-install
  fact — *is the override interrupt wired at this house* — is NOT a new schema: **the
  presence of the `primary-pump-ops`/`primary-pump-failsafe` relay nodes in the layout IS
  that declaration** (failsafe de-energized = unit keeps control, the relay-semantics
  pattern). Capability-wired-but-unused, if it ever needs a tunable, follows the
  `SiegLoopPlumbed`(layout)/`UseSiegLoop`(ops) precedent. Cross-consistency axiom
  (relays present ⇒ record says overridable) is a later add — the layout words are
  staging. The live defect this exposed is
  [OPS-450](https://linear.app/gridworks/issue/OPS-450) (maple's pump doctor runs
  against unattached relays).

The control box appears as a **thin component** on the `hp-ctrl-box` node (identity +
DeviceType + ConfigList; model facts on the record); layout, not ops (rewiring test).
Nameplate/manual artifacts live in the team Drive folder; sema minting goes through
`/make-sema-word` with the sema-spec discussion rule. Executes under
hardware-layout-pass-one when it resumes.

## Provenance

Read-only agent survey of `jm/spruce-unlimbo` + on-site work with George (2026-07-15).
Key pins to re-verify when building: `relay.py:196-282`, `i2c_bus.py:70-144`,
`layout_gen/relay.py:646-649`, `actors/__init__.py`.
