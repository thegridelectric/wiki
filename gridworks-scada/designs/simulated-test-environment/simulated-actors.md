# Simulated actors: relays + i2c thermistor reader

Status: Accepted · Pass 1 · Updated 2026-06-11 · Linear: OPS-40

> What this is: simulated-test-environment spoke — simulated relays and a
> simulated i2c thermistor reader so the Nolan scada runs fully locally
> (and the House0 case after it), exercising Thomas's setpoint evaluation
> in test mode. Began life as a spruce-unlimbo spoke (OPS-392), executed
> there for momentum; moved here 2026-06-11 when the simulation harness
> was elevated to the top. Still serves spruce-unlimbo's merge gate
> (testing green for both layouts).

## DO THIS NEXT — the SimSensor experiment (2026-06-11)

**Step 1 — DONE (PASS).** A thin SimSensor, configured generically from
`house0.imaginary`'s sensor channels, output **exactly** the 20 sensor
channels/units (3 Power, 8 Temperature, 9 Voltage), witnessed by an
independent observer — 0 missing, 0 extra, quantity-consistent. Reproducer
`sim-time-experiment/sim_sensor_experiment.py`; worked example in
`../../experiments/logbook.md`.

**Next move — build the real SimSensor in `gridworks-terminalasset`.** The
SimSensor is a **native gwbase entity** in `gridworks-terminalasset/src/gwta`
(the simulated terminal asset), publishing synthetic sensor telemetry over
**rabbit** — *not* a scada actor (Jessica, 2026-06-11). The paho stand-in above
proved the output shape; now make it real there, on the gwbase GNode pattern
(cf. `gridworks-timecoordinator`'s `gwtc`). Then:
1. Publish the **real `SyncedReadings`** type on the real channel topics.
2. The terminal-asset stream is its **own rabbit broker/exchange** — killing it
   is a one-command **data-outage** test (the field blackhole in
   `executor/scada-ltn-link-state.md`).
3. Drive values from the **plant** (the terminal asset's physics), not scripted
   constants.
4. **Scada side:** a `SimSensorActor` *ingests* that stream and relays to the
   ShNodes — the producer lives in gwta, the ingestion lives in scada. Wire it
   into the real scada + LTN dashboard (the **10-min-no-watchdog-death** run).

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
- **A heat pump that puts out a target water temperature matching the hottest
  water in the store.** HP-on charges the store at that temp.
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
> stand: sim is a device-boundary `MakeModel` choice (not a new ActorClass
> fork), no driver hierarchy, and "prove you're real" for the scada.

Resolves "where the sim seam lives" (was open below), from the actor +
component review and the dashboard-experiment design pass:

- **Sim is a hardware-realization choice, declared at the device boundary
  via `MakeModel`.** A simulated device carries a `Sim*` make/model (the
  `GRIDWORKS__SIM*` precedent), so the layout reads "sim" at every fake
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
  synthesis params, and a `Sim*` MakeModel in its Cac) is the case where the
  sim device needs configuration the real one lacks. Otherwise a `Sim*`
  MakeModel on the existing component type suffices. Minting `Sim*`
  make/models is a sema change (`/make-sema-word`).
- **Identity — the "make-imaginary" wand.** A simulated house must not wear a
  real house's identity. `make_imaginary_layout.py` (kept in
  `sim-time-experiment/`) turns a real layout imaginary: fresh instance
  UUIDs (it stops claiming to be the real house) while device-type UUIDs go
  canonical (device types are real and shared). Proven on House0.

## `is_simulated` is a smell — simulated until proven real (decided 2026-06-11)

The existing code threads a global `ScadaSettings.is_simulated` boolean into
individual actors — `relay.py` skips GPIO when it's set,
`i2c_thermistor_reader.py` skips the I2C bus, etc. That is a smell, two ways:

- **It's on the actors.** An actor should never know it's simulated.
  Sim-ness is a property of the *device* (the layout's `MakeModel`); the
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

Proof gates *consequential real-world action* (acquiring a deed, binding
contracts on the real broker, claiming a real terminal asset), not internal
mechanics — real and sim scada run the same actor code. And the
make-imaginary wand is the enforcement: a layout it produces has a fresh,
unregistered identity, so it is *structurally unable to prove realness* —
simulated by construction. Cross-ref the TaDeed / sim-real boundary rider in
`executor/scada-ltn-link-state.md`.

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
  device boundary via a `Sim*` `MakeModel`, the plant pushes, one flat
  branch in the actor, no driver hierarchy. The first increment may still
  start with an `is_simulated` branch and graduate to a `Sim*` MakeModel as
  the sema word lands.
- Whether the relay-state reporting in (2) is the same change that
  un-comments the House0 FsmAtomicReport path (probably adjacent, not
  identical).
