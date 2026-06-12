# Build the simulated loop — gwta emits `sim.plant.flux`, scada reads it

Status: Draft · Pass 0 · Updated 2026-06-12 · Linear: OPS-40

> What this is: simulated-test-environment spoke — the **construction plan** for
> the whole simulated **message-passing loop**: a `gridworks-terminalasset` (gwta)
> GNode that **emits `sim.plant.flux`** over its own broker, **and** the scada-side
> **SimSensorActor** that reads it back into `synced.readings`. **One task, one
> spoke** — the loop is the thing, and it can't be exercised end-to-end without
> both ends, so they're built together. The physics *model* and the closed-loop
> *I/O contract* live in `simulated-actors.md` ("The plant — first-pass model",
> "The plant's I/O contract"); this spoke is how we build the loop.

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
   physical state and advancing on a clock. First-pass model (the thermocline,
   per `simulated-actors.md`): 3 store tanks × 3 depths + 1 buffer × 3 depths;
   the heat pump puts out a target temp matching the hottest store; a constant
   heat call with a 20 °F drop across the house at 2 gpm (load loop) and a 20 °F
   rise across the HP at 4 gpm (source loop), so HP-on overproduces ~2:1 and
   charges (thermocline descends), HP-off discharges (rises). No thermodynamic
   model — enough to move the tank-depth temps in response to relay state.
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

For this experiment, **don't use the full sim oak** — prune to **two rooms**, each
carrying **Thomas' derived-setpoint channels** (Jessica, 2026-06-12). Per room,
two simple pieces:

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
them. The questions below are what these guesses stand in for.

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
2. Stand up `sim-sensor-actor.md` concurrently and **close the loop** into real
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

- **A reasonable plant.** Simple thermal-storage + two-room thermal model behaving
  to a coherent model — every relay + sensor plumbed in, charge/discharge dynamics
  visible on the LTN dashboard.
- **White-wire + simulated temp sensors, Thomas' derived setpoint.** The two-room
  layout replaces the Hubitats with **simulated white-wire + temperature sensors**
  and carries **Thomas' derived-setpoint channels**. "Running the falling-edge
  setpoint eval" is **purely a layout concern — no new control code from us**: make
  the layout carry the derived-setpoint channels and the right simulated sensor
  types, and Thomas' existing code evaluates. (Nolan's opto/white-wire world.)

**Post-MVP flair:**

- **Jiggle in the flux.** Add noise so thermistor readings *jiggle* like real
  sensors. The noise lives in the plant-truth↔sensor-reading gap the `flux` name
  was built around — the honest home for sensor imperfection. After the MVP loop
  works (Jessica, 2026-06-12).

## Questions about the real system's behavior (for tomorrow's DB access)

Obvious things to confirm against real per-room data (best-guesses above stand in
until then; add questions as they arise):

- **The room heat-input law (the key one).** In **beech** — our only non-spruce
  house with a room thermostat (spruce has a radiant floor) — how does the
  **downstairs wired temp sensor** vary with energy put into the downstairs? That
  curve *is* the room model (heat-need → room-temp + heat-input-when-on).
- Typical **pump speeds** — the actual 0–10 V values for the dist / primary /
  store pumps.
- Per-room **thermal mass / time-constant** — how fast does a room's temp respond
  to heat on/off (and how little does flow gpm move it — the "water speed matters
  less" claim)?
- **Thermocline** parameters — real hot/cold temps and charge/discharge rates (for
  the sharp-thermocline MVP, just the two temps + the boundary speed).
- Typical **on/off cadence** of each relay in normal operation (so Phase-A
  synthetic values are plausible).
- _(Post-MVP — MVP assumes no defrost:)_ **defrost** cadence and its `hp-odu-pwr`
  signature.

## Open

- **Plant clock for the MVP** — wall clock first (simplest), coordinator
  `sim.timestep` once the dashboard run is green (sped-up time is the comms
  redo, not the plant).
- **How rich the thermocline** — start coarse (depth temps track a single
  thermocline boundary); richer layering is a later iteration.
- **Exact home of the secret files** — the scada state/secret dir vs a gwta-local
  one; settle when the first fixture lands.
