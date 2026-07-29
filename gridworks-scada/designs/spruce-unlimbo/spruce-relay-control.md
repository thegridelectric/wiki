# Spruce relay control — chunk A execution (spoke)

Status: Draft · Pass 0 · Updated 2026-07-22 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — get the scada actuating spruce's i2c relays, with
> the heat pump under a single reliable on/off relay. Design-side record only. Everything
> Samsung-generic — wiring, configuration, service procedures — lives in the Drive doc
> **"PRIMARY — Samsung AE055 EHS mono control interface"** (Samsung AE055 folder, which is
> PUBLIC: no site or homeowner mentions there). Spruce install specifics + the immutable
> field log live on **[GRI-11](https://linear.app/gridworks/issue/GRI-11/spruce)** (the
> per-home issue; field events = comments).

## ▶ Next move (active spoke)

Two lanes:

**Field (spruce, with George):** hardware completion, in order: (1) replace the blown
control-box fuse (details in the PRIMARY doc); (2) land the RIB contact (dead-work
procedure, PRIMARY doc) and set the one Samsung config value that hands on/off authority
to the contact; (3) witness the close/open pair — the running schedule service makes
every TOU boundary a free witnessed test. Then: the ctrl-box CT lands (channel
`hp-ctrl-box-pwr`) and the spruce layout regen picks it up (gen_spruce.py in tlayouts).

**Scada (the I2cBus build, on `jm/spruce-unlimbo`):** the single-bus-owner data model is
landed (sema `e9b050f`, scada `75746bfe` — the board record owns the physical facts; the
reader resolves via `AdcName`; `75746bfe` is local-only — push before any box pull).
What remains is the bus-op path itself, sharpened by the 2026-07-22 code survey:

- `I2cBus` already consumes `I2cWriteBit`/`I2cReadBit` and echoes `TriggerId` on
  `I2cResult`, but the reply is hardcoded to `primary_scada`
  (`actors/i2c_bus.py:91-105`) — reply-to is a **rerouting** change (read
  `Header.Src`), not a new reply path.
- The reader still reads blinka/adafruit-direct
  (`actors/i2c_thermistor_reader.py:72-77`); moving it onto `I2cBus` ops is the
  build (decide: raw reg-ops from the reader vs an ADC-read primitive on the bus
  actor — lean primitive, every ADC consumer repeats the same sequence).
- `I2cBus` and `I2cRelayBoard` exist as `ActorClass` values but are NOT registered
  in `actors/__init__.py` — a layout declaring a bus node fails to instantiate
  until registration lands; move layout and registration together.
- No actor-level i2c tests exist (only named-type serialization) — the reader→bus
  build brings the first.
- The OPS-452 init-guard + input-register readback fold into the bus actor.

**Verification: reader→bus experiments run directly on spruce, ADC path only** (JM
2026-07-21; decided when the home bench gw108 would not power up — since revived,
see the 2026-07-23 update below). The arrangement that keeps this safe:

- **Broker isolation.** The experiment scada (`jm/spruce-unlimbo` code + the ops
  artifact) runs in its own environment on the spruce pi with NO production-broker
  credentials — dev broker only, aliases dev-ified (the universe guardrail enforces
  `d1` ⇔ dev broker). This keeps the staging layout tier inside its dev-brokers-only
  boundary. Prod-affecting steps on the pi (stopping services, placing env files) are
  JM's to execute; the session preps commands + a watch-list.
- **One ADS reader at a time.** The deployed `actual-spruce` scada is STOPPED during
  experiment windows — ADS1115 reads are multi-transaction with per-device state, so
  two readers on the same ADC corrupt each other. The summer hack never touches the
  ADS chips, so hack + experiment are disjoint on the bus.
- **The experiment's `I2cBus` touches ONLY the ADS devices.** No expander access (the
  OPS-452 clear-then-configure init-guard would stomp the hack's relay states — the
  init-guard is built but enabled only for devices the actor owns, ADS in this phase)
  and no TCA9548A mux access (the documented shared-state hazard).
- **Cooling continuity is never in the experiment's hands** — the summer hack stays
  untouched as the TOU/failsafe authority throughout.
- **Relay-path actuation experiments do NOT ride this arrangement.** They need
  deliberate, scheduled hack-off windows (failsafe direction is safe: contacts open,
  HP off, cooling pauses) or a working bench board; the OPS-452 half-2 induced-reset
  reproducer is parked on the same condition.

Then the relay path rides the same bus actor, gated on that windows/bench decision.

**Update 2026-07-23 — the bench gw108 is alive** (the fuse was loose) and wired to
the pi `honeysuckle` (tailscale `100.118.30.38`, key-only ssh since 2026-07-23).
That reopens the bench option the 2026-07-21 arrangement assumed away: relay-path
actuation and the OPS-452 induced-reset reproducer can run on the bench with zero
cooling stakes, and the reader→bus path can shake down there before any spruce
window. **i2c scan (2026-07-23): the bench board matches the standard gw108 map**
— ADS1115s at 0x48 and 0x49 (config regs fingerprinted), expanders at 0x20/0x21,
the TCA9548A mux at 0x70 (DACs behind mux channels 1–3). The two ADCs are
role-distinct, exactly as the device type models them
(`gwsproto/data_classes/device_types/scada_gw108.py`): 0x49 is the thermistor ADC
(`ThermistorAdcs`, `I2cThermistorInterfaceCapability`, divider parameters), 0x48
is the **CT ADC** (`CtAdc`, plain `I2cAdcCapability`, ct1–ct4 per
`starter-scripts/gw108_test_code.py` — a current-sensing circuit, not a divider).
The `gw108_nolan_zones.py` single-thermistor-ADC guard stays valid; CT sensing is
a separate capability, which is where the actual-spruce CT1/CT2 notes land in the
port. Bench blockers: `~/gridworks-scada` there is mid-update (dev @ `8a0e1689`,
venv broken on the private gridworks-flo editable) — see fleet-inventory.

### Readiness — the dev-spruce layout and the boot ladder

The experiment scada boots on a **dev-spruce layout**: the spruce house on the Nolan
scheme with identity `d1.isone.me.versant.keene.spruce.scada`. Identity comes wholly
from the layout (`MyScadaGNode` etc. — `scada_app.py:142-146`), carried as full
`g.node.gt` records with freshly minted dev ids. The layout is the scada's local
authority for its GNode trio — the same role the sema-validated `g.node.gt.json`
artifact plays for a gwbase service (`gwbase/gridworks_actor.py`); the fleet
authority stays the grid-node-registry, and FIS reconciles the two (the
mtls-fis-auth design binds cert CN to the immutable GNodeId and checks the alias
against the registry). The universe guardrail passes because `localhost ⇒ d1`
(`universe.py:32-37`); the broker the pi sees must present as localhost — SSH
tunnel to the laptop's `gw-dev-rabbit` for the first window; a rabbit container on
the pi if windows become routine (open choice).

**The layout is built in tlayouts on a branch off `jm/spruce`** (the sema-native
machinery). The `actual-spruce` `gen_spruce.py` is a working Nolan gen but rides
the retired scada `layout_gen` machinery and the single-artifact format; the scada
repo's own spruce gen (`scratch2.py`) is broken scaffolding. In order:

1. **Sema snapshot rebuild** (`./build_tlayouts_snapshot.sh`) after the sema
   `jm/single-bus-owner` ↔ `dev` merge lands — picks up reader `/003`,
   `gw1.device.type` (incl. `Gw108Adc`), `gw108.gpio.relay.component.gt` (add to
   `tlayouts_seed_request.yaml` explicitly if closure does not reach it).
2. **Port the Nolan emitters** into `house0_sema_gen.py` — the machinery is
   House0/krida-flavored today (no gw108 zones or relays); mirror
   `layout_gen/gw108_nolan_zones.py` + `add_nolan_relays`.
3. **`gen_spruce_sema.py`**: d1 identity, a spruce `OpsSpec` (cooling-season
   values — oak's block is heating defaults), and the deployed-gen content carried
   over: the hp-ctrl-box eGauge register (9010), the gw108 CT notes (CT1
   current-type 100A→50mA, store pump; CT2 egauge-type 20A, secondary pump), the
   zone-5 fancoil cooling zone, the identity derived channels, real pico HW uids.
   UUID stability via `LayoutIDMap` keyed off the deployed `spruce.json`.

**Boot ladder, cheapest gate first:** suite green on `jm/spruce-unlimbo` (conftest
pins the nolan fixture + its ops artifact, `tests/conftest.py:34-58`) → gen-time
validation (the gen refuses to write a layout that does not decode; `sema validate`
for hand-written gwsproto types) → **sim-boot the dev-spruce artifacts on local
`gw-dev-rabbit`** (the oak precedent) → the box window.

**Known blockers for unlimbo code on the box:**

- The deployed `spruce.json` does not decode on unlimbo gwsproto (the
  CaptureTuning reshape, reader `/003` board-record resolution, DeviceType `/001`)
  — regeneration is mandatory, not optional.
- The ops artifact is a boot requirement since `82caac3e`
  (`SCADA_OPERATIONAL_PARAMS_PATH`; default is the sibling dir of
  `SCADA_PATHS__HARDWARE_LAYOUT`, itself defaulting to
  `~/.config/gridworks/scada/hardware-layout.json`).
- The layout must carry the gw108 board record for `AdcName` resolution.
- The `hw1` hardcodes sit in the LTN (`ltn.py` P_NODE constants, price-service
  URLs) — inert while the experiment runs scada-only.
- Fresh checkout + venv on the pi (`tools/mkenv.sh`), its own `.env`, dev
  credentials only.

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

**The fork (resolved 2026-07-19): pull pass-two's thin `i2c.relay.component.gt` model
forward, scoped to the nolan/gw108 slice.** The alternative (extending the gw108
component family minimally) would mint a third relay-modeling scheme and another
hard-coded `relay.py` branch — the axis-3 leak the hub's conceptual model exists to
remove. The sema vocabulary is already authored (2026-07-03/09), so the remaining cost
is actor wiring either way; the single-bus-owner prerequisite below already routes ADC
reads through `I2cBus`, and the OPS-452 hardening (expander init-guard, input-register
readback) gets built once, in the durable actor. The slice: `Gw108Adc` device-type
value + thermistor-reader `/003`, `I2cBus` wiring with reply-to, i2c relay nodes in the
nolan layout gen on `i2c.relay.component.gt`, and a `relay.py` path resolving
`RelayName` against the board record. The krida decommission and the House0 layout
migration stay pass-two
([`../hardware-layout-pass-one/i2c-board-components.md`](../hardware-layout-pass-one/i2c-board-components.md)).
Deploy note: spruce runs `actual-spruce` (= `td/orig-pred-set`); the scada-actor build
lands on `jm/spruce-unlimbo` per branch discipline — upgrading spruce to it requires the
ops artifact placed first (`82caac3e` deploy note).

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

- **CT sensing wants its own device-type vocabulary.** The gw108 `CtAdc`
  (0x48) will carry physically different CTs per channel — spruce's notes: CT1
  is a current-output CT (100 A → 50 mA, external burden on the board), CT2 an
  eGauge-style voltage-output CT (20 A, internal burden, mV out). A future
  sema word (e.g. `ct.device.type.gt`) should record OutputKind
  (CurrentOutput | VoltageOutput), rated primary amps, and rated output
  (mA or mV), with the CT-ADC channel config referencing it per channel —
  mirroring how `AdsChannelConfig.ThermistorDeviceType` works. Not part of the
  dev-spruce layout (the deployed layout has no CT channels yet); the notes
  ride as comments in `gen_spruce_sema.py` until the word exists.
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
