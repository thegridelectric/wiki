# Minimal House0 sim-run — the safety net (spoke — done)

Status: Accepted · Pass 1 · Updated 2026-07-04 · Linear: OPS-407

> What this is: the cheapest high-value move in pass one. Before the layout rewrite touches ~76
> call-sites, stand up a test we don't have today — the scada **boots a House0 layout and runs every
> device code path** with self-faking device actors on the **dev rabbit broker** (no LTN, no plant).
> Build it against the **existing** fixtures first, so it is a regression net the rewrite verifies
> *through*. The richer coherent plant + LTN stay sim-test-environment work
> ([OPS-40](https://linear.app/gridworks/issue/OPS-40)).

## Why this is first

We have no good way to test the existing scada code — only real hardware (slow, one house at a time)
or partial unit tests. Pass one rewrites how layouts are built (sema-authored, `sema_to_dc`) and will
move ~76 call-sites onto `self.hydronic.*`. Doing that blind is the risk. A House0-replicating sim-run
makes the change **behaviorally verifiable**: if the scada boots House0 and every device actor's code
path executes without crashing, the rewrite is safe to be un-fussy about static fixture equality.

So the order is: **net first, rewrite under it.** Build the boot against today's fixtures (proves it
works on known-good layouts), then re-run it after each rewrite step.

## Scope — minimal, not the coherent plant

Borrow the sim-test-env **self-faking-actors** model (the cheap precursor to the plant): the real
device actors (`ApiTankModule` / `ApiBtuMeter` / `ApiFlowModule`, the poller) self-generate fictitious
input on a timer — no plant process — and the scada runs on the **dev rabbit broker** (the Rabbit MQTT
plugin, `localhost:1885`, exactly as a real house connects), with **no LTN** so it sits in LocalControl.

**On the broker, not in-process (decided 2026-06-28).** A no-broker in-process harness is the backdoor
transport EDD calls necessary-but-insufficient — it shares a fake transport + wall clock and goes green
while real comms behavior stays invisible. Running on `gw-dev-rabbit` exercises the real MQTT wiring and
is the **reusable seed for the OPS-40 rig**, not a throwaway. Durable harness facts live in
[`../../executor/testing.md`](../../executor/testing.md); this spoke scopes only the **House0-boot** slice.

**The sim layout — `gw1.simple.sim.layout` (decided 2026-06-27).** The simulated stand-in for House0 is
authored as its **own word, `gw1.simple.sim.layout`** — **NOT** shoehorned into `gw.house0.layout`. It
replicates House0's device code paths for testing without claiming to be a House0 layout, so
`gw.house0.layout` keeps its real shape (buffer required). Shape: **no buffer tank, a single storage
tank**, **relays (and what they do) left out** initially — the smallest hydronic shape that still runs
the temperature / flow / power device paths. Build most of it now; layer the relay paths in after the
boot works.

**In scope (pass one):**
- The simplified sim House0 layout loads and the scada actor tree starts on `gw-dev-rabbit`.
- Each non-relay device actor runs its read/derive path on self-faked input without crashing, publishing
  its channels over MQTT (no consumer needed).
- A single witnessed "House0 booted + ran N device cycles" assertion — the behavioral gate.

**Out of scope (stays OPS-40):** the coherent `sim.plant.flux` plant, the **LTN** + the dispatch contract,
sim-time coordinator stepping, the multi-house hybrid rig, chaos/poison levers; and (initially) the relay
actuation paths.

## LocalControl + "turn on the heat pump" — a documented fake first

The *meaningful* test of control is "can LocalControl turn on the heat pump." In the real code that is a
**relay actuation**: `actors/hp_boss.py` closes `hp-scada-ops-relay` (House0 relay6) to turn the heat
pump on (and opens it to turn off); `actors/sh_node_actor.py` exposes the relay accessors
(`hp_scada_ops_relay`, `hp_failsafe_relay`, `store_charge_discharge_relay`); `actors/local_control/` is
the coordinating actor. So a real control test needs the relay path — which the minimal boot defers.

**Decided (2026-06-27) — fake-first.** Rather than wire the full relay-actuation path now, **add a fake
into LocalControl that does very little (or nothing)** — just enough to start the actor tree and let us
iterate — **with a docstring saying exactly that** (a sim placeholder; the real relay-actuation control
lands by iteration). This honors "err simpler, leave a question": the boot is unblocked, and the
heat-pump-control behavior is grown incrementally against a running rig rather than built up-front.

**Deferred to iteration (not boot blockers):** the relay actuation path; the LocalControl→`hp_boss`→
`hp-scada-ops-relay` "turn on the heat pump" capability; and the **layout axiom names** that bind it —
e.g. a House0 axiom guaranteeing the heat-pump-control relays exist with the right `WiringConfig`,
mirroring nolan's `VdcRelaySemantics` / `ElementRelaySemantics` / zone failsafe-ops relay-semantics
axioms (the stub-existence pattern, [`axioms.md`](axioms.md)). Decide those names when the relay path
is iterated in, not for the boot.

## Boot-seam scout (done 2026-06-28)

- **Boot path (corrected 2026-06-29):** the live entry is `cli.py run` → **`ScadaApp.main()`** (the
  proactor `App` subclass in `scada_app.py`). `Scada` is now a `PrimeActor` whose
  `__init__(self, name, services)` takes a `ScadaAppInterface` — so the App is **required**, not optional
  (approach (B) brings up `ScadaApp` standalone). `ScadaApp.get_settings(env_file=...)` builds
  `ScadaSettings` from `.env`; `ScadaApp._load_hardware_layout` does `House0Layout.load(path)`. The older
  `command_line_utils.get_scada` / `run_scada.py` path is **stale** — it still builds
  `Scada(settings=, hardware_layout=, actor_nodes=)`, which no longer matches the PrimeActor signature;
  don't use it.
- **Actor-factory seam:** the proactor host's `_load_actors` (`gwproactor/app.py:270–281`) →
  `ActorInterface.load(node.Name, node.actor_class_str, services, actors_module=actors)` — looks the
  `ActorClass` string up in `actors/__init__.py` and calls `Class(name, services)`. This is where a
  sim/self-fake branch slots in.
- **`is_simulated=True` already handles ACTUATION.** I2cBus / Relay / I2cRelayMultiplexer /
  MultipurposeSensor / PowerMeter already skip hardware (`SimulatedPin`, skip smbus2/GPIO) under
  `is_simulated`; there's even a `GridworksSimPowerMeter` driver. **The gap is SENSOR INPUT:** the
  device actors get readings *pushed* — tank/flow/BTU via **HTTP POST** from picos
  (`api_tank_module._process_microvolts`, `api_flow_module._handle_ticklist_*`,
  `api_btu_meter._handle_multichannel_snapshot_post`), the thermostat poller via **REST**
  (`hubitat_poller._make_request`). Self-faking = inject readings at those points on a timer. **No
  existing self-fake for sensor readings** — this is the new bit (the sim-test-env self-faking-actors
  slice).
- **`ScadaLiveTest` is heavier than we want:** it builds on `TreeLiveTest` + a parent `LtnApp`
  (`tests/utils/scada_live_test_helper.py:16–25`) — the full proactor multi-App stack (no *real* broker,
  in-process transport). Reusable: the `is_simulated=True` settings pattern.
- **Things to stub/avoid:** don't start `SimTimeListener` (needs `gridworks_mqtt`); stub
  `services.send_threadsafe` / `publish_message` / `add_web_route` / `add_task` to no-ops; `PicoCycler`
  no-ops gracefully with no picos.

## Shipped

All three milestones landed 2026-06-29 (detail in `wiki/gridworks-scada/changelog.md`):

- **`b4623fe1`** — `gw_spaceheat/sim_boot.py`: boots the real `ScadaApp` standalone (approach (B)) on
  `gw-dev-rabbit` (MQTT 1885), `is_simulated=True`, no LTN → LocalControl, bounded run, reports how
  many channel values populated. Proven on `maple.json`.
- **`d8ce5570`** — generic `SimSensorActor` (self-generating `SyncedReadings`, no pico / no faked HTTP)
  + `sim_layout.py` (swaps the pico-fed sensor actors for `SimSensorActor`s → the simulated house0
  layout; 55 of 92 channels populate vs 20 with real pico actors).
- **`822b150c`** — the universe guardrail ([`universe-guardrail.md`](universe-guardrail.md)), with
  `sim_layout.py` dev-ifying aliases so the sim layout is coherent with the dev broker.

## Still open

- Coordinate with sim-test-environment's `self-faking-actors` work so the two don't duplicate the seam
  — the minimal slice here should be a subset that the fuller spoke later subsumes.
- The relay-actuation / LocalControl→`hp_boss` "turn on the heat pump" path stays iteration work (the
  documented fake, above), grown against the running rig.
