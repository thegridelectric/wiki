# Self-faking device actors — local smoke test (no plant, no broker)

Status: Draft · Pass 0 · Updated 2026-06-15 · Linear: OPS-40

**EDD: yes** the verification is the smoke-test experiment — boot the full-sim House0 layout
locally and watch every device actor run its **real** code path on self-generated input with
zero crashes and zero dead coroutines.

> What this is: a simulated-test-environment spoke. The **component-faithful** sim pattern (the
> real device actors run, fed synthesized hardware input) completed for **all** the pico device
> actors and run in a **self-generating** mode — no plant, no broker, no coherent physics — so a
> fully-sema-compliant House0 sim layout exercises every device code path (microvolt→temp,
> tick→Hz→Gpm, BTU math, affine calibration, async-capture, emission) without crashing. The cheap
> precursor to the coherent plant.

## The objective (Jessica, 2026-06-15)

We want the ability to **"fake out with random numbers"** enough of a fake plant — *embedded in
the sim actors themselves* — that a fully-sema-compliant House0 layout runs and **all the code it
uses runs without crashing**. The sim actors can be run with an option where they **self-generate
fictitious data instead of listening for a gwta over the dev broker**. This initial test is what
can be accomplished **locally, without an actual coherent plant model**, and still exercise the
various code bits. It **comes before** building a terminalasset simple sim plant. The
`sim.pico.tank.module.component.gt` pattern (which exercises `api_tank_module.py`) needs to
**replicate for `api_btu_meter.py` and `api_flow_module.py`** before we can really do this.

## Where this sits among the sim approaches (don't conflate)

Three sim paths live in this design; this spoke is the third:

1. **`SimSensorActor` baseline** (`simulated-actors.md`, `build-plant.md`) — the *generic
   plant-seam*. The real device actors are **absent**; a `SimSensorActor` publishes synthetic
   channels and a gwta plant pushes `sim.plant.flux` over the broker. Tests **comms**, not device
   code.
2. **Component-faithful sim** — the real device actors **run**, fed synthesized input through their
   real inbound path. Kept as the "fidelity dial" because *testing the real pico code under
   simulation is worth it*. `sim.pico.tank.module.component.gt` exists for exactly this — but its
   actor side "is only partly worked through."
3. **This spoke** — path 2 in its simplest **local, self-generating** mode: the device actor
   generates its *own* raw input on a timer, no plant and no broker. The device-level "garbage
   values first," *before* the plant even exists.

This spoke does not replace the `SimSensorActor` baseline; it builds out the complementary
component-faithful path that the design deliberately preserved.

## The pattern — self-generate at the real POST input seam

Every pico device actor takes raw device data through an HTTP **POST seam** and runs it through the
**real** processing path. Self-fake mode: when the actor's component is a sim variant (a `Sim*`
`DeviceType`), the actor **synthesizes that raw data on a timer** and feeds the *same* real path —
so all the conversion / calibration / capture / emission code runs untouched. Grounded in the code:

| Actor | Real input seam | Real processing (exercised) | Self-fake feeds |
| --- | --- | --- | --- |
| `ApiTankModule` | `_handle_microvolts_post` → `_process_microvolts` | microvolts → `simple_beta` → temp; then `derived_generator` affine calibration | synth microvolts → `_process_microvolts` |
| `ApiBtuMeter` | `_handle_multichannel_snapshot_post` → `_process_multichannel_snapshot` | flow + hot/cold temps → BTU/flow channels | synth `MultichannelSnapshot` |
| `ApiFlowModule` | `_handle_ticklist_{hall,reed}_post` | ticklist → Hz → Gpm (`GpmFromHzMethod`) | synth ticklist |

Synthesized values can be trivial — **constant / random / sawtooth**. The point is that the code
*runs*, not that the physics is right (physics is the coherent plant's job, later). Built as a
**seam**: the self-generator is one source; a broker-listen / plant-push source slots into the same
seam when the plant lands.

## DeviceType, not MakeModel

Sim is declared at the **device boundary via an open `pascal.case` `Sim*` `DeviceType`** (a
`gw1.device.type` value) — **not** a MakeModel. MakeModel was **retired** this cycle (the
device-type model; see `executor/components.md` and the hardware-layout-pass-one work). `gw1.device.type`
already carries `GridworksSimSensor`, `GridworksSimRelayBank`, `GridworksSimPowerMeter` (one
annotated "was MakeModel GRIDWORKS__SIMPM1"). **Stale-language note:** `primary.md` and
`simulated-actors.md` still say "`Sim*` MakeModel" throughout — that should be swept to
"`Sim*` DeviceType" (small follow-up).

## The work

1. **New sema words** (`/make-sema-word`): `sim.pico.btu.meter.component.gt` and
   `sim.pico.flow.module.component.gt`, mirroring the real components via `SimulatesTypeName` /
   `SimulatesVersion` consts (exactly like `sim.pico.tank.module.component.gt → pico.tank.module.component.gt/012`).
   Each carries the real component's config plus any synth params. (`sim.pico.tank.module.component.gt`
   already exists.)
2. **Actor self-generate mode** for `ApiTankModule` (finish the partly-worked-through sim path),
   `ApiBtuMeter`, and `ApiFlowModule`: a self-generating loop, **keyed off the sim component /
   `DeviceType`** (not a global `is_simulated` flag — that's the smell `simulated-actors.md` calls
   out; the sim component *is* the trigger, layout-driven), that synthesizes raw input on a timer
   and feeds the real POST-processing path. Likely a shared helper/mixin rather than three copies.
3. **A fully-sim House0 layout** — all device components swapped to their sim variants (buffer +
   store tanks, the BTU meter(s), the flow module(s)), via the make-imaginary wand
   (`make_imaginary_layout.py`) + the sim component swaps. Runs locally, no broker, no plant.
4. **The smoke-test experiment (the EDD bar)** — boot it, advance N steps, and assert: zero
   crashes, zero dead actor coroutines, a plausible reading on every device channel, and
   `derived_generator` computing (affine tank calibration end-to-end — currently untested with
   non-zero B — and the `sum` primary-flow strategy once it lands).

## Why this matters for hardware-layout-pass-one

The hardware-layout-pass-one design left a **`primary-flow` behavior test** as a deferred
deliverable that explicitly *needs simulated plants* (`sum` derived strategy across the three
Siegenthaler configs; the affine tank-calibration path). **This spoke is the minimal plant that
deliverable runs against** — the self-faking `ApiBtuMeter` + `ApiFlowModule` feeding
`derived_generator` is exactly the harness it specified. So this spoke unblocks that test.

## Sequencing

Precedes `build-plant.md`'s coherent plant ("comes before building a terminalasset simple sim
plant"). It is the device-level smoke test; the coherent plant adds physics + the broker loop on
top, reusing the same actor seams. **Candidate to become the active spoke** — Jessica's call.

## Open questions

- **`Sim*` `DeviceType` values for btu/flow** — reuse `GridworksSimSensor`, or mint
  `GridworksSimBtuMeter` / `GridworksSimFlowModule` (a `gw1.device.type` addition)?
- **Self-generate cadence** — wall-clock timer first; coordinator `sim.timestep` later (`sim-time.md`).
- **Synthesis shape** — constant / random / sawtooth first; design the seam for scripted scenarios.
- **Where the self-fake loop lives** — a shared mixin/helper across the three actors vs per-actor.
- **Implementation gate** — no scada/sema edits until this spoke reaches Accepted (Pass ≥ 1).
