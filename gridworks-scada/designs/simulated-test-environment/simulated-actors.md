# Simulated actors: relays + i2c thermistor reader

Status: Accepted · Pass 1 · Updated 2026-08-12 · Linear: OPS-40

> What this is: simulated-test-environment spoke — simulated relays and a
> simulated i2c thermistor reader so the Nolan scada runs fully locally
> (and the House0 case after it), exercising Thomas's setpoint evaluation
> in test mode. Began life as a spruce-unlimbo spoke ([OPS-392](https://linear.app/gridworks/issue/OPS-392)), executed
> there for momentum; moved here 2026-06-11 when the simulation harness
> was elevated to the top. Still serves spruce-unlimbo's merge gate
> (testing green for both layouts).

## The task — comms first, then the model (see the build spokes)

Step 1 (SimSensor output shape) **passed** (a thin SimSensor output exactly the
20 sensor channels/units, witnessed; reproducer
`sim-time-experiment/sim_sensor_experiment.py`). The build now lives in two
sibling spokes, done **concurrently** (the closed loop needs both ends):

- **`build-plant.md`** — the gwta TerminalAsset that emits `sim.plant.flux`.
- **`sim-sensor-actor.md`** — the scada-side actor that reads it into
  `synced.readings`.

**The method — garbage values first, real plumbing.** First hack a plant that
emits **format-correct `sim.plant.flux` with synthetic (random / constant /
sawtooth) values** on the correct channels, and get the **whole message-passing
loop working** — through the SimSensorActor, the ShNodes, derived energy,
LocalControl, the relays, and the **10-min-no-watchdog dashboard run**. *Then*,
once comms holds, follow EDD to build the plant's actual **physics model** (the
first-pass thermocline below). Fidelity is earned against a working loop, not a
prerequisite for it.

This spoke keeps the physics **model** and the closed-loop **I/O contract**; the
build steps live in the two spokes above.

(Reuse, not rebuild — sensors publish the same reading types real sensor
actors do; actuators reuse `SingleMachineState`. The generic config is bound
by `hardware_layout.py:306-320`: each captured channel's `CapturedByNodeName`
must be the SimSensor node — add `SimSensorActor` to `capturing_classes`.)

## The plant — first-pass model (drives the SimSensor)

The terminal asset's physics: a **thermal storage heating system — 3 store
tanks + 1 buffer tank**.

**The simple first-pass model (Jessica, 2026-06-11) — given directly, no FLO
mining needed:**
- **A thermocline that flows down the 3 store tanks.** Hot water on top, cold
  below, a thermocline boundary between them; charging pushes the thermocline
  *down* (hot fills from the top), discharging lets it rise. Each tank-depth
  temperature follows which side of the thermocline that depth is on.
- **A heat pump that always puts out 160 °F** (the imaginary scenario's fixed HP
  output — no curve, no defrost). HP-on charges the store at 160 °F.
- The buffer tank rides the same logic at the buffer level.
- **Constant heat call**, with a **20° drop across the house at 2 gpm** (the
  distribution/load loop) and a **20° rise across the heat pump at 4 gpm** (the
  source loop). The HP delivers `4 gpm × 20°` while the house draws
  `2 gpm × 20°` — so HP-on overproduces ~2:1 and **charges** the store
  (thermocline descends); HP-off leaves the constant house draw **discharging**
  it (thermocline rises). The whole charge/discharge dynamic falls out of two
  flows and two ΔTs.

That's enough to drive the SimSensor — tank-depth temps respond to HP-on +
charge/discharge relay state — without a thermodynamic model.

**Richer fidelity later** (real control/energy behavior) comes from the control
+ optimizer, *not needed for the first-pass thermocline*:
- **LocalControl** (`gw_spaceheat/actors/local_control/`: `all_tanks_tou.py`,
  `buffer_only_tou.py`, `standby.py`, `tou_base.py`) — TOU charge/discharge.
- **The FLO / optimizer** — moved out of open source into the private
  **`gridworks-innovations`** repo (a `flo.py` stub remains at
  `actors/ltn/flo.py`); read the current optimizer there directly.

## The plant's I/O contract — closed loop with LocalControl (2026-06-11)

The plant is defined by the loop it closes with control: it **listens** to the
relay commands LocalControl emits and **produces** exactly the sensor channels
LocalControl reads back. Tracked through `local_control/` → `ShNodeActor` →
`derived_generator.py` so the model is grounded, not guessed.

**What the plant must EMIT (the channels control consumes).** All temps are
`WaterTempCTimes1000` unless noted; names are `H0CN`:

- **Store tank depth temps** — `tank{1..N}-depth{1,2,3}` (N = `TotalStoreTanks`,
  3 for the store). These are the thermocline, and the *only* temperature input
  to `usable-energy` in AllTanks mode (see the DAG below).
- **Buffer depth temps** — `buffer-depth{1,2,3}`. Gate everything:
  `buffer_temps_available` (`sh_node_actor.py:1340`) must be true or
  `derived_generator` emits no energy at all. Also drive `is_buffer_empty/full`.
- **Entering-water temp** — `store-cold-pipe` (or `hp-ewt`). The "can't charge
  further" ceiling: `is_storage_ready` declares ready once it crosses
  `params.MaxEwtF` (`all_tanks_tou.py:317-330`). Plus `store-hot-pipe`,
  `buffer-cold-pipe`/`buffer-hot-pipe`, `dist-swt`/`dist-rwt`.
- **HP power** — `hp-odu-pwr` (+ `hp-idu-pwr`), `PowerW`. Two readers:
  `hp_in_defrost()` (`sh_node_actor.py:1319`) and the closed-loop verify the
  capability design wants (below).
- **Zone temps** — `zone{N}-...-temp`, `AirTempFTimes1000`. `is_system_cold`
  compares critical zones to setpoint (the Normal→UsingNonElectricBackup gate).
- **Pump powers** — `dist/primary/store-pump-pwr`, for the pump-health monitors.

**What the plant must CONSUME (the commands control emits).** Per the settled
"Actuators — plant listens (one-way)": the plant **subscribes to relay state**
(`SingleMachineState`, `relay.py:358`) and folds it into physics — no down-injector.
The load-bearing set, from `update_relays` / `initialize_actuators`:

| Capability call | Relay (`H0N`) | Plant effect |
| --- | --- | --- |
| `turn_on_HP` / `turn_off_HP` | `hp-scada-ops-relay` (→ `hp-boss` under sieg) | HP draws `hp-odu-pwr`, charges store at target temp |
| `valved_to_charge_store` / `..._discharge_store` | `store-charge-discharge-relay` | thermocline descends (charge) / rises (discharge) |
| `turn_on_store_pump` / `turn_off_store_pump` | `store-pump-failsafe` + `store-010v` | store flow on/off |
| `hp_failsafe_…`, `aquastat_ctrl_…`, `sieg_valve_dormant` | `hp-failsafe`, `aquastat-ctrl`, `hp-loop-on-off` | mode/secondary — first pass can stub |

That closes the spoke's first-pass physics: HP-on + charge-valve drives the
store-tank depth temps up (thermocline down); HP-off + the constant house draw
discharges (thermocline up).

### The energy DAG — and why the plant alone can't drive it

`usable-energy` and `required-energy` are derived by `derived_generator.py`, and
tracing them surfaced a real boundary: **the plant supplies temperatures, but
the energy channels also need forecasts the plant does not produce.**

- **`usable-energy`** (`compute_usable_energy_wh`, ~`:780-856`) — gates on
  `system_mode==Heating`, `buffer_temps_available`, and `heating_forecast`.
  Peels the hottest tank layer down to `rwt_f(hottest)`, accumulating
  `mass·cp·ΔC`. **Leaves:** `tank{i}-depth{1,2,3}` (AllTanks) or
  `buffer-depth{1,2,3}` (BufferOnly) — *plant-produced* — **plus** `rwt_f`
  (`:1125`), which is forecast-constrained: it reads `heating_forecast.RswtF`
  and the `rswt_quadratic` from `Ha1Params` (`IntermediateRswtF`, `DdRswtF`,
  `DdDeltaTF`, `DdPowerKw`).
- **`required-energy`** (`compute_required_energy_wh`, `:886-960`) — needs
  `heating_forecast.Time`/`AvgPowerKw` (load summed over the 7–11/12–15/16–19
  on-peak windows) **and** `weather_forecast.Time`/`OatF` (midday OAT → COP via
  `params.CopMin`/`CopMinOatF`/`CopIntercept`/`CopOatCoeff`, `HpMaxKwEl`). No
  plant temps at all — it's forecast + params + time-of-day.

**DAG, leaves → derived:**

```
plant temps ─┐
 tank*-depth*│→ usable-energy ─┐
 buffer-depth┘   (+ rwt_f)     │
                               ├→ is_storage_ready / is_storage_empty → LocalControl FSM → relays → plant
heating_forecast ─┐            │
 RswtF, AvgPowerKw│→ required-energy ┘
weather_forecast ─┘
 OatF
```

So the plant closes the *temperature* half of the loop; the **forecast half is a
separate input** the harness must stand up. The inputs are exactly two: **a
weather file** and **the params**. `get_forecasts` (`derived_generator.py:1084-1112`)
turns `weather_forecast` (`OatF`, `WindSpeedMph`, `Time`) **plus the params** (the
building model — `DdPowerKw`, the rswt quadratic, …) into `heating_forecast`
(`AvgPowerKw`, `RswtF`, `RswtDeltaTF`); `heating_forecast` is **derived, not
supplied**. **Decision (Jessica, 2026-06-12): start with a secret weather file**
(→ `weather_forecast`) plus a **`flo.params.house0.json`** (→ `Ha1Params`), both
out of git (the state/secret dir, like real credentials). The on-disk params file
follows the Sema-typed-JSON convention — `flo.params.house0.json`, **no version
suffix** (Version is a field; the `…house0.006.json` files are generated snapshot
*samples*, a different convention). **OFI:** get the weather from a *simulated
weather-forecast service* eventually, so the harness gets it the way prod does
rather than from a fixture. Until then a fixed file is enough to make
`usable`/`required` compute and the FSM turn over.

### The sema snapshot is the plant's to choose

Sema **decouples transport from semantics** ("Schemas are transport-agnostic",
`sema/spec/primary.md`; capability design principle 3, "Sema at the wire only").
A **snapshot** is a restricted vocabulary subset + generated codec baked into a
consumer package (`sema/spec/snapshot.md`) — data, not a vendored test suite,
zero-diff deterministic. So `gridworks-terminalasset` **gets to choose its own
sema snapshot**: the subset of types it encodes, independent of scada's carrier
and independent of scada's `gwproto` copies. Consequences:

- gwta is **not** bound to `gwproto`'s hand-version of any reading type. It bakes
  the **canonical sema** definitions into its snapshot instead.
- **The plant's output word is `sim.plant.flux`** (the `sim-sensor-words` spoke,
  decided 2026-06-12; minted + committed in `sema/`) — a sim **source word** the
  plant emits: `ChannelNameList`/`ValueList`/`ScadaReadTimeUnixMs` (sim time) plus
  `ActualTimeUtc` (human-readable ISO 8601 ms, `utc.iso8601.millis`). No
  `Simulates*` fields — the plant's raw emission does not presume its destination;
  the scada-side **SimSensorActor reads it and interprets it** into
  `synced.readings` for the ShNodes (electrical and other derived signals later) —
  the real ingestion path untouched. So gwta does **not** publish `SyncedReadings`
  directly; it emits `sim.plant.flux`.
- **Both snapshots carry `sim.plant.flux`:** gwta's (to emit) and the scada's
  gwsproto snapshot (so the SimSensorActor can decode it). It is a sim-boundary
  word; `synced.readings` is what stays internal to the ShNodes.
- Prerequisite: `sim.plant.flux` must be **minted** (sema word-authoring, separate
  `sema/` claim) and present in both snapshots before the publish step.

### Capability-protocol consistency (evaluated 2026-06-11)

Tracked `local_control` → relay commands against the `capability-protocol-and-verify`
design ([OPS-394](https://linear.app/gridworks/issue/OPS-394)). **Largely consistent:** control states drive actuators through
the capability surface (`turn_on/off_HP`, `valved_to_charge/discharge_store`,
`*_switch_to_scada`, `sieg_valve_dormant`), not raw-relay idiom, and `turn_on_HP`
already routes HP authority to `hp-boss` under sieg — the maple-fix shape the
design calls for (principle 2, layouts bind capabilities). **Two gaps the design
itself predicts** (both fine for a Draft):

- `initialize_actuators` (`tou_base.py:371`) still **de-energizes by iterating
  relays** (`de_energize(relay)`) — relay-level, exactly the "residual raw-relay
  idiom" its audit-scope targets.
- The **closed-loop "intent vs observed power" watcher** (principle 7) is not
  implemented — `hp-odu-pwr` is read only for defrost, not to catch "HP commanded
  off but still drawing." **This is where the plant earns its keep:** because the
  plant turns relay state into `hp-odu-pwr`, the harness can finally exercise
  principle 7 and the principle-8 layout×state test matrix (which the design says
  "likely rides [OPS-40](https://linear.app/gridworks/issue/OPS-40)"). The plant is the instrument that makes capability-verify
  testable.

## Live baseline (verified 2026-06-10)

`gws run` against **`gw-dev-rabbit`** (MQTT 1885, TLS off, smqPublic),
nolan layout, `SCADA_IS_SIMULATED=true`, on `jm/spruce-unlimbo`:

- **Runs.** Links connect (`gridworks_mqtt` reaches `awaiting_peer` — an
  LTN would complete the pair); per-zone `GpioSensor` actors and the
  `DerivedGenerator` run ("Preparing for a morning onpeak + afternoon
  onpeak"); LeafAlly keepalive alive.
- **First wall:** `LocalControlTouBase.main` dies at startup —
  `AttributeError: 'NoneType' object has no attribute 'handle'` — a
  House0 relay node (`H0N.*` lookup returning None on the nolan layout).
  Pin the exact node next; this is where layout-aware capability
  binding meets reality.
- Cosmetic: a stale persisted `SlowContractHeartbeat` v000 is rejected
  by the now-v001 literal and ignored loudly (old state dir, harmless).

## The sim seam — decided (2026-06-11): device boundary, the plant pushes

> **Superseded in part by "SimSensorActor — the settled shape" below.** The
> sensor source is a `SimSensorActor` that *publishes readings*; the
> device-emitter detail here ("plant → sim Pico → real conversion") is now an
> optional fidelity dial, not the baseline. The durable parts of this section
> stand: sim is a device-boundary `DeviceType` choice (not a new ActorClass
> fork), no driver hierarchy, and "prove you're real" for the scada.

Resolves "where the sim seam lives" (was open below), from the actor +
component review and the dashboard-experiment design pass:

- **Sim is a hardware-realization choice, declared at the device boundary
  via its `DeviceType`.** A simulated device carries a `Sim*` `DeviceType` (a
  `gw1.device.type` value; the `GridworksSim*` precedent), so the layout reads "sim" at every fake
  device — fact and fiction legible in the artifact, which is what the
  sim/real trust boundary needs. NOT new `ActorClass` values (a simulated
  relay is still a relay — same capability and mechanism, only the
  realization changed), and NOT a driver-class hierarchy (the
  `drivers/power_meter/` ABC → per-model subclass → proxy/registers stack is
  the "Russian dolls" anti-pattern to avoid). The actor gets ONE flat branch
  at its existing I/O point — it already branches on component type.
- **The plant is active and pushes.** A single, flat `SimulatedPlant` holds
  physical state and advances on a clock (wall clock now; coordinator
  `sim.timestep` later, for sped-up time). When it crosses a channel's
  `AsyncCaptureDelta` it **reaches out to the sim device** — exactly how a
  real Pico reports on change — and the sim device emits its reading through
  the REAL inbound path (a sim Pico derives microvolts from the plant temp
  and POSTs them; the real `ApiTankModule` conversion + async-capture code
  runs untouched). Actors never poll. Full loop: a command flows DOWN the
  command tree to an actuator leaf, which writes commanded state into the
  plant; the plant steps physics; crossing a delta it pushes the sim
  sensors; their real readings flow UP to reports / the LTN dashboard.
- **Command-tree invariants honored.** Sensors sit OUTSIDE the command tree
  (the plant pushes to them; they publish). Control/actuator nodes are
  command-tree LEAVES that write into the plant. The plant + sim devices are
  the simulated world — outside the command tree.
- **Sim component *types* only where extra params are needed.**
  `sim.pico.tank.module.component.gt` (carrying `SimulatesTypeName` + the
  synthesis params, and a `Sim*` `DeviceType`) is the case where the
  sim device needs configuration the real one lacks. Otherwise a `Sim*`
  `DeviceType` on the existing component type suffices. Adding `Sim*`
  `gw1.device.type` values is a sema change.
- **Identity — the "make-imaginary" wand.** A simulated house must not wear a
  real house's identity. `make_imaginary_layout.py` (kept in
  `sim-time-experiment/`) turns a real layout imaginary: fresh instance
  UUIDs (it stops claiming to be the real house) while device-type UUIDs go
  canonical (device types are real and shared). Proven on House0.

## Register-level fidelity — the board dial setting (ratified 2026-08-12)

A deeper setting of the fidelity dial, below the actor-role sim
(SimSensorActor + report-only relays) that serves control-logic tests:
a **sim register backend inside the `I2cBus` actor** — a fake chip
presenting the smbus surface (per-address register store, TCA9555
semantics at the expander addresses: POR defaults, input ports
mirroring output flip-flops only when configured as outputs, floats
otherwise) — so the REAL relay/bus/reader actors run their genuine
choreography against it. Its purpose is the i2c hardening surface the
actor-role sim deliberately abstracts away: per-op pin confirm, the
false-positive re-read, held-command retry, expander reset
detect/repair — the spruce field-failure catalog (GRI-11). **Fault
injection is its chaos lever** (transient/permanent EIO per address,
garbled reads), sibling to the broker-off sensor-outage lever.

Placement honors the settled seam: one flat branch at the bus actor's
existing I/O point (the smbus handle), no driver hierarchy, and the
actors above it lose their `is_simulated` branches (the relay's i2c
short-circuits die with it — the "clean out the old `is_simulated`"
task below, i2c slice). Selector: the board's DeviceType in the layout
(a `Sim*` `gw1.device.type` value — sema word-gate pending); until the
word lands, an interim `is_simulated` branch in the bus actor ONLY,
per the graduation note in "Open".

## `is_simulated` is a smell — simulated until proven real (decided 2026-06-11)

The existing code threads a global `ScadaSettings.is_simulated` boolean into
individual actors — `relay.py` skips GPIO when it's set,
`i2c_thermistor_reader.py` skips the I2C bus, etc. That is a smell, two ways:

- **It's on the actors.** An actor should never know it's simulated.
  Sim-ness is a property of the *device* (the component's `DeviceType`); the
  relay actor talks to its relay component — real or sim — as one body of
  code. The redo drives `is_simulated`-in-actors to **zero**; actors stay
  pure and layout-driven.
- **It's a boolean, and the wrong polarity.** "Real by default, simulated if
  flagged" means a missing or wrong flag lets a fake scada act real. Invert
  it: **you are simulated until you can prove you are real.** The proof is a
  valid **TaDeed** (cryptographically verifiable, registered), held by the
  **scada, and only the scada**. No deed → simulated. You cannot
  *accidentally* be real; the worst a misconfiguration does is fail to prove
  realness.

**The concrete check, and its migration path.** Non-simulated is one small
method, **defaulting to simulated** — `is_simulated` becomes the default, not the
flagged case. It starts as a method that simply **looks for an existing on-disk
file** (an interim stand-in for the proof), and we **change that same method**
into verifying the scada holds the **correct signed TaDeed**. The call site and
the simulated-by-default polarity stay constant across the migration; only what
counts as proof hardens (file present → valid registered deed).

Proof gates *consequential real-world action* (acquiring a deed, binding
contracts on the real broker, claiming a real terminal asset), not internal
mechanics — real and sim scada run the same actor code. And the
make-imaginary wand is the enforcement: a layout it produces has a fresh,
unregistered identity, so it is *structurally unable to prove realness* —
simulated by construction. Cross-ref the TaDeed / sim-real boundary rider in
`executor/scada-ltn-link-state.md`.

**Update (2026-08-15): remove `is_simulated` entirely — derive it.** The flag
goes away completely; simulated-ness is *derived*, never stored. Two derivation
sources, in order of arrival:

1. **Any `sim.*` component in the layout ⇒ simulated.** A layout carrying a
   `sim.sensor.component.gt` / `sim.relay.component.gt` (or any `sim.*`
   component) is simulated by construction — the sim marker is in the plant
   description itself, not a runtime boolean. This is now *structurally
   expressible*: `sim.sensor.component.gt` and `sim.relay.component.gt` were
   added to both layout words' Component unions in sema on 2026-08-15
   (`gw.house0.layout` / `gw.nolan.layout`, staging, in-place), with the
   gwsproto `House0Component` / `NolanComponent` mirrors updated in lockstep.
   So "any simulated component means simulated" is a check over the typed
   layout, not a flag.
2. **No valid TaDeed ⇒ simulated** (the harder proof, above): once TaDeeds
   exist, realness is the scada holding its registered signed deed. Absence of
   a deed ⇒ simulated, regardless of components.

Both are the same polarity — simulated by default, realness must be *proven* —
and the derivation method is the single call site the migration hardens
(component-presence now → TaDeed later). `ScadaSettings.is_simulated` and every
in-actor branch are deleted, not re-plumbed.

## SimSensorActor — the settled shape (2026-06-11)

Refines the device-emitter sketch above: the sensor source in a simulated
house is a new ActorClass, fed by the plant over its own broker.

- **`SimSensorActor`** (a new `gw1.actor.class` value, scada-side). In a
  simulated layout it is the node that **sends sensor readings to the rest of
  the ShNodes**: `plant → plant broker → SimSensorActor → ShNodes`. The real
  sensor actors (`ApiTankModule`, the thermistor reader, …) are simply absent
  in a sim layout. Not a per-device fork (still no `SimRelay`/`SimTank`) — one
  dedicated simulation-role actor that *is* the sensor source.
- **Generic config, bound by the layout axiom.** It must publish **multiple
  units** (Temperature, Voltage, Power, FlowRate, …) for **one or more
  `AboutNodeName`s**, so its component takes a generic `ConfigList` of the
  channels it captures. The structure is already enforced:
  `hardware_layout.py:306-320` requires every channel in a capturing node's
  component `ConfigList` to have `CapturedByNodeName == that node`. So a
  `SimSensorActor` node declares (via its ConfigList) exactly the channels it
  produces — any about-node, any unit — and the axiom ties them to it.
  Integration: add `SimSensorActor` to that axiom's `capturing_classes`.
- **Actuators — plant listens (one-way).** Both relay paths converge on
  `relay.py:358` `send_state()` → a `SingleMachineState` (uniform across the
  Gw108 GPIO path, where the actor writes the pin inline, and the
  i2c-multiplexer path, where it defers to the multiplexer actor). The plant
  **subscribes to relay state** and folds it into physics — no per-path
  actuation bridge, no down-injector. Asymmetric with the sensor side on
  purpose.
- **Chaos for free.** Because the sensor stream is its own broker, turning
  that broker off **simulates a sensor data outage** on demand — a first-class
  way to reproduce and test the field failure in
  `executor/scada-ltn-link-state.md` (the ~15-minute broker blackhole).

**Task — clean out the old `is_simulated`.** The redo removes the global
`ScadaSettings.is_simulated` and its in-actor branches (`relay.py:221`
GPIO-skip, `i2c_thermistor_reader.py` I2C-skip, …). Two existing breakages go
with it: the GPIO `is_simulated` early-return also drops the immediate state
report (`relay.py:248` sits below the `return`), and the relay↔multiplexer
report round-trip is commented out (`relay.py:312-316`). Under the redo,
sim-ness lives in the layout (a `SimSensorActor` node), actors stay pure, and
relays always report state on actuation.

## Scope (first increment)

1. **Simulated zone-temperature reader** standing in for
   `i2c_thermistor_reader.py`: constant **70 °F** on each zone's gw-temp
   channel, cheat-mode (no broker); value source built as a seam with a
   stubbed **broker-listen hook** for later synthetic-telemetry mode.
2. **Simulated relays**: the Gw108 GPIO path already no-ops under
   `is_simulated` (relay.py logs "Simulated relay actuation; skipping
   GPIO") — extend so simulated actuation *reports state* (FSM completes,
   relay-state channels update) instead of merely skipping, so admin and
   control states see coherent state. Krida-multiplexer sim follows for
   the House0 case.
3. **Scriptable heat-call** (sim GpioSensor square wave or direct
   injection) — required for the falling-edge setpoint eval to actually
   learn (constant 70 °F alone proves plumbing, not learning).
4. Fix/route around the LocalControl crash so the full actor set runs on
   the nolan layout locally.

House0 side reuses the existing `SimPicoTankModule` path — don't
duplicate.

## Definition of done

- `gws run` on the nolan layout reaches steady state with zero dead
  actor coroutines; derived setpoint channels emit learned values under
  a scripted heat-call.
- The same harness boots the House0 layout (sim Krida) — the merge
  gate's "both cases" at the simulated level.
- Distillate ported: simulated-test-environment design updated (scope
  items 1/4 partially delivered), durable facts to
  `executor/` (likely `running.md` + a future `simulation.md`).

## Open

- ~~Where the sim seam lives~~ — **decided** (see "The sim seam" above):
  device boundary via a `Sim*` `DeviceType`, the plant pushes, one flat
  branch in the actor, no driver hierarchy. The first increment may still
  start with an `is_simulated` branch and graduate to a `Sim*` `DeviceType` as
  the sema word lands.
- Whether the relay-state reporting in (2) is the same change that
  un-comments the House0 FsmAtomicReport path (probably adjacent, not
  identical).
