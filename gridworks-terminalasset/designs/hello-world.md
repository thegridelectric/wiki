# Hello-world gwbase uv project

Status: Accepted · Pass 1 · Updated 2026-06-11 · Linear: OPS-404

> What this is: a bite-size design — set up the freshly created
> `gridworks-terminalasset` repo as a working uv project on
> gridworks-base, with a hello-world actor that connects to the dev
> rabbit broker and emits a heartbeat. The stop line is explicit:
> **no new Sema types** — those come later, inside the simulation work
> (the scada simulated-test-environment design, where this repo's
> simulated terminal assets are increment one).

## Scope

1. **uv scaffold.** `pyproject.toml` (Python 3.12+), `src/` layout,
   pytest, ruff; dependency on `gridworks-base`. (Resolved 2026-06-11:
   no pin needed — gwbase 0.5.2 is published on PyPI and its `dev`
   branch matches the tag exactly, so a plain `gridworks-base>=0.5.2`
   dependency is correct.)
2. **Hello-world actor.** A `GridworksActor`-based GNode that connects
   to `gw-dev-rabbit` and emits a heartbeat at a fixed cadence, using
   **existing** gwbase/Sema message types only. Config via the standard
   gwbase settings pattern (broker coordinates from env).
3. **Smoke tests.** App constructs and settings load without a broker;
   one live-marked test (skipped by default) that connects to dev
   rabbit and sees its own heartbeat.
4. **Done when:** one command (e.g. `uv run ta-hello`) connects to the
   dev broker and a catch-all observer sees the heartbeat arriving on
   the routing fabric.

## Explicitly out of scope

- New Sema types (sim component types, `GRIDWORKS__SIM*` MakeModels,
  synthetic-telemetry words) — deferred to the simulation design.
- Any physics, even synthetic channels — this is plumbing proof only.
- CI beyond a minimal ruff + pytest action (optional; may ride a later
  commit).

## Designing the simulated-sensor sema words — together (added 2026-06-11)

The next part of this design is a **joint session**: choose the initial
sema words a simulated terminal asset uses to report simulated sensor
data. This section holds the groundwork (verified against
gridworks-scada 2026-06-11) and the decision points; the decisions are
deliberately blank until we make them together. Minting happens later,
via `/make-sema-word` (read `sema/CLAUDE.md` first), inside the
simulation work — the hello-world code keeps its no-new-types stop line.

**How scada sensors receive information today — two paths:**

1. **Driver poll path.** An actor polls its hardware driver
   (`read_telemetry_values(channels) → DriverOutcome[dict[name, int]]`,
   `drivers/multipurpose_sensor/…:15-32`), buffers latest values, and
   reports on sync period or async threshold by sending
   `synced.readings` to the primary scada
   (`actors/multipurpose_sensor.py:208-228`). The existing sim driver
   (`GridworksSimPm1`) just hardcodes return values — no message feed.
2. **API path (the precedent for message-fed sensors).** Picos POST
   typed payloads over HTTP — `microvolts` (HwUid, AboutNodeNameList,
   MicroVoltsList, `api_tank_module.py:189-263`) and
   `multichannel.snapshot` (HwUid, ChannelNameList, MeasurementList,
   UnitList, `api_btu_meter.py:209-262`) — and the receiving actor
   converts (beta formula, unit scaling) then emits `synced.readings`.
   Sensor values arriving *as messages* is already a first-class scada
   pattern; the simulated source extends it from HTTP-from-picos to
   broker-from-terminal-asset.

**Internal lingua franca:** everything converges on `synced.readings`
(ChannelNameList · ValueList · ScadaReadTimeUnixMs; equal-length axiom)
or `single.reading`, with scaled-int values typed by the
`TelemetryName` enum (`WaterTempCTimes1000`, `GpmTimes100`, …) and
channel names bound to the layout's `DataChannel`s.

**Decision points for the joint session:**

1. **Altitude.** Device-level mimicry (microvolts-style — the sim
   pretends to be hardware, exercising conversion code) vs
   telemetry-level (channel + scaled value + telemetry name — skips
   device quirks)? Telemetry-level looks right for the terminal asset;
   device-level mimicry could come later for driver-path testing.
2. **Source identity.** The API types use `HwUid`; a simulated stream's
   natural identity is the terminal asset's GNode alias. What binds a
   sim stream to the layout's channel names?
3. **One word or two.** A periodic snapshot bundle, an async
   single-reading word, or both (mirroring the synced/single pair)?
4. **Timestamps.** Existing types carry `ScadaReadTimeUnixMs` — but a
   simulated source has its own truth-time. The word likely carries
   source time; the scada stamps read-time on conversion.
5. **Units.** `TelemetryName` enum semantics vs
   `multichannel.snapshot`-style loose `UnitList` strings.
6. **Where the words live and cross.** They are gwbase-world words
   (left.right.dot TypeNames) crossing the AMQP fabric; does the
   scada-side actor consume the sema word directly over the MQTT
   bridge, or translate at a gwsproto named-type boundary?

## Open

- Whether the hello actor's GNode identity is a throwaway dev alias
  (what the code does today — `ensure_g_node_json` self-mints) or the
  first real `TerminalAsset`-class GNode in the dev registry.
- (Resolved 2026-06-11: module `gwta`, console script `ta-hello`,
  following the gridworks-base → `gwbase` naming precedent.)
