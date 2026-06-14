# Build the simulated loop — gwta emits `sim.plant.flux`, scada reads it

Status: Accepted · Pass 1 · Updated 2026-06-13 · Linear: OPS-40

> What this is: simulated-test-environment spoke — the **construction plan** for
> the whole simulated **message-passing loop**: a `gridworks-terminalasset` (gwta)
> GNode that **emits `sim.plant.flux`** over its own broker, **and** the scada-side
> **SimSensorActor** that reads it back into `synced.readings`. **One task, one
> spoke** — the loop is the thing, and it can't be exercised end-to-end without
> both ends, so they're built together. The physics *model* and the closed-loop
> *I/O contract* live in `simulated-actors.md` ("The plant — first-pass model",
> "The plant's I/O contract"); this spoke is how we build the loop. Calibration
> questions, the cross-carrier round-trip harness, and other parked notes live in
> `gleanings.md`; new sema words awaiting Jessica's sign-off are in
> `new-sema-words-to-review.md`.

## Do this now — wait on the hardware-layout pass, then Phase A

The device-type model and the high-volume scada migration the sim layout depends on are a
**separate, shared piece of work** — its own Ops issue (**OPS-407**), depended on by this
harness and spruce-unlimbo Chunk B. Its durable home is `executor/hardware-layout.md`
("Resolution"): device identity becomes a `gw1.device.type` enum value (`DeviceType`,
`pascal.case` format), **ALL `cac_id` / UUID identity is removed** (scada and sema), and
`layout_gen` is restructured around it. The sim component types
(`sim.sensor.component.gt`, `sim.relay.component.gt`) land in that pass — flat, carrying
`DeviceType`, no `cac_id`.

**This spoke's work resumes at Phase A** once that pass lands the new component shape:
build + prove the comms loop with the sim layout using `sim.sensor.component.gt` /
`sim.relay.component.gt`. **Then Phase B** — first-pass plant physics.

## Why one layout file — plant and scada read the same `hardware-layout.json`

The end goal (the WHY): the plant (`gridworks-terminalasset`) reads and processes
the **same** `hardware-layout.json` the scada runs from — one layout file, both
sides consume it. For that the plant needs the layout's vocabulary in sema as
flat, generated runtime types, so it can parse that file and stand up its
simulated world directly from the scada's own layout (in a gwta snapshot these
types are referenced by their **local names**). Closing `gw.nolan.layout` was the
vehicle that swept most of that shared vocabulary into the sema canon — vocabulary
en route to **spruce-unlimbo** (the layout-pipeline rework) and exactly what we
reuse as we add **simulated** components. Two standing rules (Jessica, 2026-06-12):

- **Shared-infra words land NON-draft** — they get runtime classes so scada can
  import and emit them, which is how we verify them (the cross-carrier round-trip
  harness in `gleanings.md`). `gw.nolan.layout` itself stays **draft**; we only
  reconcile its refs to the now-published words. De-drafting is a later step.
- **Simulated things wear "sim" in their names** — the sim hardware layout is
  visibly simulated; its components are `sim.*` types (e.g. the existing
  `sim.pico.tank.module.component.gt`, and `sim.sensor.component.gt`), not real
  component types reused.

## The first sema layout word — `gw1.simple.sim.layout`

The pared-down single-zone layout becomes the **first sema layout word**: a full
hardware-layout type, not just the component vocabulary it references. That is the
cleanest way for gwta and the sim scada to share **one** layout — both parse the same
sema-typed file instead of the plant re-deriving the graph — and it is on the
**critical path for spruce-unlimbo**: getting layouts into sema is Chunk B / OPS-334,
so this word is the on-ramp the rework reuses.

**Name: `gw1.simple.sim.layout`.** Sim-ness is *not* a primary part of a hardware-layout
name — the production layouts (`gw.nolan.layout` / `gw.house0.layout`) don't carry
"real", and a production layout *type* run with sim components is still that type. So
there are **no `sim.*` twins** of the production layouts: you run nolan/house0 *with* sim
components, you don't fork their type. This word is the deliberate exception worth
flagging: it is **not designed for any built production system** — a purpose-built,
simplest-possible layout that exists *only* for the simulated test environment. The
`sim` in the name is an honest flag that this type has **no real-deployment counterpart**,
not a claim that sim-ness generally belongs in layout names. The `gw1.` prefix is a
deliberate fresh start in the new GridWorks namespace (`gw1.device.type` /
`gw1.actor.class`) — the layout words may migrate off the legacy `gw.` names
(`gw.nolan.layout` / `gw.house0.layout`) starting here. Distinct from `layout.lite` (the
lightweight wire snapshot, not the full hardware layout).

**Why a third layout — the point of it.** `gw1.simple.sim.layout` is a deliberate third
choice alongside House0 and Nolan: the simplest plant we can imagine (fake the physics,
stub the devices) that is *still a genuine thermal-storage heat-pump system*. Its value is
a **forcing function** — two real layouts that differ mostly in hardware generation can
still let House0 assumptions leak, but a third radically-simpler fake-physics plant that
*also* has to run is different enough to break any House0-coupling that survived. Making
the scada handle all three gracefully is what proves the plant-abstraction seams are real,
not aspirational — and the same artifact doubles as the minimal fixture that stands up the
simulated terminalasset. (Durable principle behind this — *the layout encodes the plant's
sense/control surface; the scada protocols share + disambiguate, grounded in the
thermal-storage heat-pump domain* — lives in `executor/hardware-layout.md`.)

**Minimal-axiom first.** Carry only axioms that replicate **today's** hardware-layout
load-time validations — tank count 1–6; `TankTempCalibrationMap` matches the tanks'
derived channels; `usable-energy` / `required-energy` present by name; the
referential-integrity checks (`CapturedByNodeName` / `AboutNodeName` /
`InputChannelNames` resolve) — and **not** the fuller axiom set being spelled out in
`gw.nolan.layout`. Match current behavior first; richer axioms later. Mint via
`/make-sema-word` (read `sema/CLAUDE.md` first) when ready to author.

## Next tasks (ordered)

The build order, recorded here so it survives across files (the hub just points at
this spoke; the ordered plan lives here):

0. **Device-type pivot + SCADA migration** — see "Do this now" above: mint
   `gw1.device.type` (+ the `DeviceType` `pascal.case` field), drop ALL `cac_id`
   (scada and sema), then the high-volume scada migration (`layout_gen`,
   `CACS_BY_MAKE_MODEL`).
1. **Phase A** — build + prove the comms loop (format-correct plant →
   `SimSensorActor` → real `ScadaApp(is_simulated)` + `LtnApp` + dashboard;
   done-when 10 minutes, zero watchdog-pat deaths). Stand up the hardware layout
   with `sim.sensor.component.gt` and validate that is the kind of component a
   `SimSensorActor` has. Have the plant consume the hardware layout (requires a
   sema snapshot with all the layout's words) and use it to decide which flux
   words to send; likewise wire the plant to RECEIVE `sim.plant.actuation`. Start
   by emitting random-but-plausible values.
2. **First-pass plant physics** (Phase B step 4) — only after Phase A is proven.
3. **JM review of the new sema words** (mostly Jessica) — sign off every
   added/bumped word in `new-sema-words-to-review.md` (schema + descriptions). The
   words are committed under the `jm/sim-vocab` permission but **not finalized**
   until reviewed; this is the gate that finalizes them.

### Sema changes needed for Phase A (analysis 2026-06-13)

The shared layout vocabulary landed (sema `6f73174`). To stand up a *simulated*
layout and the actuation path, Phase A still needs a small fresh sema mini-sweep
(all tracked in `new-sema-words-to-review.md`):

- **`gw1.device.type/000`** (new enum) — the universal device-type key: PascalCase
  values (existing `pascal.case` format), pruned to the device types scada actually
  uses, including `GridworksSimSensor` and `GridworksSimRelayBank`. Replaces
  make/model-as-CAC. Components carry a `DeviceType` field of the existing `pascal.case`
  format; the layout enforces `DeviceType ∈ gw1.device.type`. **No `cac_id` anywhere.**
- **`sim.sensor.component.gt/000` / `sim.relay.component.gt/000`** — the sim component
  types, flat: `ComponentId`, `DeviceType` (`pascal.case`), `ConfigList` (channel
  configs for the sensor; `relay.actor.config/003` for the relay), `DisplayName`,
  `HwUid`. **No `ComponentAttributeClassId`.** Sensor vs relay are distinct device types
  (`GridworksSimSensor` / `GridworksSimRelayBank`).
- **Superseded:** the `spaceheat.make.model/008` sim makes (`GRIDWORKS__SIM_SENSOR` /
  `GRIDWORKS__SIM_RELAY_BANK`, already committed) are now **legacy/orphaned** —
  `gw1.device.type` replaces make/model-as-CAC; `spaceheat.make.model` stays frozen, the
  values are harmless. The earlier `gw1.device.type.gt` / `gw1.device.type.id` /
  `gw1.make.model.device.type.id` projection plan is **abandoned** (see "Do this now").
- Already minted (prior sprint): `sim.plant.flux`, `sim.plant.actuation`,
  `change.relay.pin`, `gw1.actor.class/012` (SimSensorActor / SimRelayActor).

**Actuation path:** `SimRelayActor` receives the control command the real relay
actor would, and emits `sim.plant.actuation` (`RelayName` + `change.relay.pin`
Energize/DeEnergize + sim time + `ActualTimeUtc`) to the plant's broker; the plant
resolves what energizing each relay *does* from the (sim) layout and folds it into
physics. So the sim layout's relay nodes carry `sim.relay.component.gt` components
whose `DeviceType` is `GridworksSimRelayBank`.

## Where it lives

`gridworks-terminalasset/src/gwta`, built on **gwbase** (`GridworksActor`), on
the same GNode pattern as `gridworks-timecoordinator`'s `gwtc` and the existing
`gwta` hello actor (`hello.py` — provisions the exchange topology, connects to
dev rabbit, beats). The plant is a `TerminalAsset` GNodeClass — the avatar for a
real-world transactive device — not a scada actor.

## Status (carried from the SimSensor experiment)

**Step 1 — DONE (PASS, 2026-06-11).** A thin SimSensor, configured generically
from `house0.imaginary`'s sensor channels, output **exactly** the 20 sensor
channels/units (3 Power, 8 Temperature, 9 Voltage), witnessed by an independent
observer — 0 missing, 0 extra, quantity-consistent. Reproducer
`sim-time-experiment/sim_sensor_experiment.py`; worked example in
`../../experiments/logbook.md`. That proved the **output shape**; this spoke makes
it real and physics-driven.

## What we build

1. **`SimulatedPlant` — the physics object.** A single, flat object holding
   physical state (3 store tanks × 3 depths + 1 buffer × 3 depths, a sharp
   thermocline boundary, relay/pump states) and advancing on a clock.
   **Flagrantly simple thermodynamics (Jessica, 2026-06-12):**
   - **Heat pump:** always outputs **160 °F** (a Siegenthaler loop), **constant
     COP = 2** regardless of output or outside temp. Assume a **fixed HP thermal
     output `Q_hp`**, so HP flow follows from the entering water temp:
     `ṁ_hp = Q_hp / (c · (160 − EWT))` — a warm return (small ΔT) means more gpm.
   - **House = a SINGLE ZONE.** Distribution is **2 gpm when the zone calls, 0
     otherwise**, with a 20 °F drop across the house (the load).
   - **Charge/discharge:** the store thermocline descends when HP delivery exceeds
     the house draw (charging), rises otherwise — driven by the flow imbalance,
     not a thermodynamic model.
   - **Open — flag, don't guess (per the simplicity directive):** the exact
     buffer↔store↔house plumbing — what flows into the buffer vs. the house, and
     where HP flow lands (store vs. buffer); and the value of `Q_hp`. Pick the
     simplest topology that works with the scada code; leave a question if unsure.

   Enough to move the tank-depth temps in response to relay state.
2. **The flux emitter.** When the plant crosses a channel's `AsyncCaptureDelta`
   it emits **`sim.plant.flux`** (the committed sema type) on the plant's **own
   rabbit broker/exchange**: `ChannelNameList` / `ValueList` (scaled ints by
   `TelemetryName`), `ScadaReadTimeUnixMs` = **sim time**, `ActualTimeUtc` =
   wall-clock (human-readable ISO ms). gwta **bakes `sim.plant.flux` into its
   snapshot** (canonical sema runtime, `SimPlantFlux`). Actors never poll.
3. **Listen to commands (one-way).** The plant **subscribes to
   `sim.plant.actuation`** (sent by the scada-side SimRelayActor, below) and folds
   it into physics — `hp-scada-ops-relay` (→ HP power + charge),
   `store-charge-discharge-relay` (thermocline direction), `store-pump-failsafe` +
   `store-010v` (flow). No down-injector; the plant just hears the actuations.
   (Full command set: `simulated-actors.md` I/O contract.)
4. **Fixtures (out of git, the state/secret dir).** A **secret weather file**
   (→ `weather_forecast`: `OatF`, `WindSpeedMph`, `Time`) and a
   **`flo.params.house0.json`** (→ `Ha1Params` — the building model). The scada's
   `derived_generator.get_forecasts` derives `heating_forecast` from these two, so
   `usable`/`required` energy compute and LocalControl's FSM turns over. **OFI:** a
   simulated weather-forecast service later, so the harness gets weather the way
   prod does.

## Channels the plant emits

Do not duplicate — the leaf set (store/buffer depth temps, `store-cold-pipe` /
`hp-ewt`, `hp-odu-pwr`, zone temps, pump powers) and why each matters is the
"What the plant must EMIT" table in `simulated-actors.md` ("The plant's I/O
contract"). This spoke produces exactly those channels.

## The "own broker" win

The plant's flux rides its **own rabbit broker/exchange**, distinct from the
scada↔LTN fabric. Killing it is a one-command **sensor data-outage** test — the
field blackhole in `executor/scada-ltn-link-state.md` — reproducible on demand.

## The room thermal model (first pass)

For this experiment, **don't use the full sim oak** — prune to a **single zone /
one room** carrying **Thomas' derived-setpoint channels** (Jessica, 2026-06-12).
One zone means distribution is 2 gpm on / 0 off. The room needs two simple pieces:

1. **Heat-need → room temperature.** From the room's heat need (derived from
   `flo.params` + weather) and a **per-room thermal mass**, integrate to a room
   air-temperature reading. Thermal mass sets how fast the room responds.
2. **Heat input when the zone turns on.** How much heat the hydronic loop delivers
   to the room while the zone calls — a **well-known hydronic engineering
   calculation with a simple closed-form approximation**. Notably, **water speed
   matters less than one would think**: delivered power is dominated by other
   terms, so flow can be treated coarsely.

The room temp drives the thermostat / setpoint logic (the white-wire heat-call
signal), closing the control loop: cold room → heat call → zone relay on →
hydronic heat in → room warms → call clears.

**MVP simplifications — assume away the hard parts (Jessica, 2026-06-12):**

- **No defrost.** The HP never defrosts in the MVP.
- **Heat pump always outputs 160 °F.** Fixed — no curve, no defrost; the store
  never exceeds it. We do **not** model real hot/cold temps or charge/discharge
  rates.
- **Totally sharp thermocline.** No mixing zone — a clean 160 °F-hot / cold-return
  step in the store; depths above the boundary are hot, below cold. The boundary
  just moves with charge/discharge.
- **Tanks don't leak.** No standby heat loss into the basement.
- **No distribution return-temp dip; radiators transfer ZERO heat on the water
  side.** Don't model the cold-slug transient at heat-call start; `dist-rwt` ≈
  `dist-swt`. This **decouples** the water-loop model (store/buffer/pipe temps,
  driven by HP + thermocline) from the room model (heat-need → room temp, its own
  closed-form). The radiator is the real-world coupling; the MVP zeroes it on the
  water side and handles room heat input separately.
- **Simplest model that still works with our code.** Mine the data only for
  realistic *simple parameters*, not added fidelity.

**Best-guess parameters — ungate now, calibrate against the DB (all GUESSES):**

- Per-room **thermal time constant** τ ≈ 1–2 h; design **heat loss** ≈ 3 kW/room
  at design ΔT.
- **Zone heat input when on** ≈ 4 kW (closed-form ~ `UA_rad·(T_water − T_room)`,
  flow-insensitive) — overcomes loss and warms the room.
- **Pump speeds** ≈ 50 % (≈ 5 V on the 0–10 V outputs); flows per the loop model
  (house ~2 gpm, source ~4 gpm).

Placeholders flagged GUESS — enough to build and run the loop; the DB calibrates
them. The calibration questions these stand in for are in `gleanings.md`
("Questions about the real system's behavior").

## The two scada-side sim actors

The loop has two scada-repo actors — both new `gw1.actor.class` values. Adding
them is a **versioned-enum bump of `gw1.actor.class`** (additive → a new version;
this is the build's **first sema step**). Both are built with the plant (one task):

- **`SimSensorActor`** (sensor reads). Subscribes to the plant's broker, decodes
  **`sim.plant.flux`**, keeps `ActualTimeUtc` for the log/CSV, and re-emits plain
  `synced.readings` to the ShNodes. In a sim layout it is the sensor source; the
  real sensor actors (`ApiTankModule`, the thermistor reader) are **absent**. Its
  component carries a generic `ConfigList`; `hardware_layout.py:306-320` ties each
  channel to `CapturedByNodeName == the SimSensorActor node` (add it to
  `capturing_classes`).
- **`SimRelayActor`** (actuation sends). Stands in for the relay actor in a sim
  layout: receives the control command the normal relay actor would, and instead
  of touching GPIO/i2c **sends `sim.plant.actuation`** — `RelayName` + `Action`
  (**Energize / DeEnergize**, the i2c multiplexer's atomic pin *event* via the new
  `change.relay.pin` enum — an event, not a state, and not closed/open) + sim time
  + `ActualTimeUtc` — to the plant's broker. The plant resolves what energizing
  each relay *does* from the layout (role + wiring) and folds it into physics. The
  symmetric inverse of the sensor path: `sim.plant.flux` out, `sim.plant.actuation`
  in.

**Hand-add the two sim words to `gwsproto` (PascalCase).** The scada is not
generated from sema; its named-types are hand-maintained pydantic in **PascalCase**
(field names like `ChannelNameList` directly), unlike the sema runtime's snake_case
fields + CamelCase aliases. So add `SimPlantFlux` and `SimPlantActuation` by hand in
that style, matching the scada's `SyncedReadings` / `SingleMachineState`. **Known
discrepancy** (Jessica, 2026-06-12): the casing gap reconciles when the proactor
rework makes the scada "sema-compliant like gwbase"
(`executor/scada-ltn-link-state.md`), which will mint new sema types rather than
versioning in place. Harmless now; worth being aware of.

## Identity — simulated by construction

The plant runs on a **wanded** layout (`make_imaginary_layout.py` →
`house0.imaginary.json`): fresh instance UUIDs, canonical device-type UUIDs. It
**cannot prove it is real** (no registered TaDeed), so it is simulated by
construction — the sim/real trust boundary (`simulated-actors.md`,
"simulated until proven real").

## Approach & increments — comms first (correct format), model second

Two phases, deliberately. The harness was elevated **comms-first** (hub): most of
what we need to test now is message infrastructure, so a fake-but-format-correct
plant exercises every transport seam without waiting on physics. Build and prove
in the **`sim-time-experiment/`** scratch workspace first (the proven pattern —
`harness.py`, `sim_sensor_experiment.py`), then graduate into `gwta/src`.

**Phase A — hack a format-correct plant; get the message passing working.**
The plant emits **valid `sim.plant.flux`** on the **correct channels** with real
identity and cadence, but **synthetic values** (constant / sawtooth / random in
plausible range). No physics; it need not even listen to relays yet. Garbage
values, real plumbing.

1. `SimulatedPlant` shell + flux emitter on wall-clock time, synthetic values on
   the correct channels — **round-trip the real `SimPlantFlux` type** on the
   plant's own broker (scratch).
2. Stand up the SimSensorActor concurrently and **close the loop** into real
   `ScadaApp(is_simulated)` + `LtnApp` + the LTN dashboard. **Done-when: 10
   minutes, zero watchdog-pat deaths** (also Verifies `sim-time`'s "bridge is
   watchdog-safe").
3. Fixtures (secret weather file + `flo.params.house0.json`) so derived energy +
   LocalControl's FSM turn over even on the synthetic stream.

**Phase B — model the plant by the method (EDD).** Once the loop holds, build the
real physics — fidelity earned against a working loop, not blocking it.

4. Plant **listens to relay state** → first-pass thermocline charge/discharge
   (`simulated-actors.md`); buffer + store depth temps move plausibly and the
   dashboard shows charge/discharge dynamics.
5. Graduate into `gwta/src/gwta`; coordinator `sim.timestep` clock (replaces wall
   clock, rides `sim-time`); the fidelity ladder — an hour of CSV under *sped-up*
   time (needs cadence-decoupling, the comms redo, not the plant).

## Fidelity ladder

**In the MVP model:**

- **A reasonable plant.** Simple thermal-storage + single-zone room model behaving
  to a coherent model — every relay + sensor plumbed in, charge/discharge dynamics
  visible on the LTN dashboard.
- **White-wire + simulated temp sensors, Thomas' derived setpoint.** The
  single-zone layout replaces the Hubitats with **simulated white-wire + temperature
  sensors** and carries **Thomas' derived-setpoint channels**. "Running the
  falling-edge setpoint eval" is **purely a layout concern — no new control code
  from us**: make the layout carry the derived-setpoint channels and the right
  simulated sensor types, and Thomas' existing code evaluates. (Nolan's
  opto/white-wire world.)

**Post-MVP flair:**

- **Jiggle in the flux.** Add noise so thermistor readings *jiggle* like real
  sensors. The noise lives in the plant-truth↔sensor-reading gap the `flux` name
  was built around — the honest home for sensor imperfection. After the MVP loop
  works (Jessica, 2026-06-12).

## Sema cascade — the `ActorClass` ripple (do first, on `jm/sim-vocab`)

Adding the two sim actor classes (`gw1.actor.class/012` — **done, green**) ripples
through every type that pins the enum or embeds a node. Plan:

1. **`spaceheat.node.gt` 301 → 302** — re-point `ActorClass` to
   `gw1.actor.class/012`. Trivial 1:1 upgrade (the enum is additive); the
   three-places delta (upgrade template + registry summary + `direct_dependencies`);
   `301` stays as superseded (keeps its example).
2. **`layout.lite`** — embeds `spaceheat.node.gt`; bump to ref `:302`.
3. **`scada.control.capabilities`** — also embeds `spaceheat.node.gt`. Its `001`
   was **never drafted/published** (limbo), so **fold the actor-class update into
   `001` in place** (pre-publication edits are allowed) rather than minting a new
   version; then **update gridworks-admin** accordingly (Jessica, 2026-06-12).
4. **Check `data.channel.gt` / `derived.channel.gt`** and any other
   `spaceheat.node.gt` dependents — bump those that must carry sim-actor nodes.
5. Regen + `pytest` green after each.

**Smelly (noted, Jessica's latitude 2026-06-12):** one new actor class forces a
version bump of `spaceheat.node.gt` and everything embedding it (layouts,
capabilities, channels). A real coupling smell — recorded here, not silent.
**Mitigation:** new actor classes are *rare*, so the cascade is paid infrequently;
not worth re-architecting now.

## Journalkeeper must track the bumped versions — but NOT the sim types

The cascade bumps **real** types the journalkeeper (JK) journals off the prod
broker, so JK's sema snapshot must add the new versions to decode them. Old scada
keeps emitting old versions (JK already knows those), so this is additive — JK
tracks both old and new. **JK will need to track:**

- `spaceheat.node.gt/302` (+ `gw1.actor.class/012`)
- `layout.lite/014`
- `new.command.tree/001`
- `scada.control.capabilities/001`
- `gw.nolan.layout/000` (if/when nolan layouts are journaled)

**JK will NOT capture the sim messages** (Jessica, 2026-06-12) — `sim.plant.flux`,
`sim.plant.actuation`, and the `change.relay.pin` enum are the sim boundary, not
prod fleet traffic, so JK needs none of them. This is a **flag for the JK session**
(spry-granite, `wiki/gridworks-journalkeeper/`), not an edit into their domain.

## Open

- **Plant clock for the MVP** — wall clock first (simplest), coordinator
  `sim.timestep` once the dashboard run is green (sped-up time is the comms
  redo, not the plant).
- **How rich the thermocline** — start coarse (depth temps track a single
  thermocline boundary); richer layering is a later iteration.
- **Exact home of the secret files** — the scada state/secret dir vs a gwta-local
  one; settle when the first fixture lands.
