# Gleanings — sim-test-environment notes parked off the build path

Status: Draft · Pass 0 · Updated 2026-06-13 · Linear: OPS-40

> What this is: the simulated-test-environment spoke that holds **gleanings** —
> groundwork, calibration questions, reusable patterns, and deferred/queued
> items — so `build-plant.md` stays a lean, lead-with-the-plan construction
> spoke. Nothing here is on today's critical path; it is the reservoir the
> active spoke draws from. Sema words awaiting Jessica's review have their own
> spoke: `new-sema-words-to-review.md`.

## Sim-sensor words — groundwork + the `sim.plant.flux` decision

Folded here from the former `sim-sensor-words.md` spoke (the joint-session
groundwork is settled; the durable distillate is the `sim.plant.flux` decision
below). Verified against gridworks-scada 2026-06-11.

### How scada sensors receive information today — two paths

1. **Driver poll path.** An actor polls its hardware driver
   (`read_telemetry_values(channels) → DriverOutcome[dict[name, int]]`,
   `drivers/multipurpose_sensor/…:15-32`), buffers latest values, and reports on
   sync period or async threshold by sending `synced.readings` to the primary
   scada (`actors/multipurpose_sensor.py:208-228`). The existing sim driver
   (`GridworksSimPm1`) hardcodes return values — no message feed.
2. **API path (the precedent for message-fed sensors).** Picos POST typed
   payloads over HTTP — `microvolts` (HwUid, AboutNodeNameList, MicroVoltsList;
   `api_tank_module.py:189-263`) and `multichannel.snapshot` (HwUid,
   ChannelNameList, MeasurementList, UnitList; `api_btu_meter.py:209-262`) — and
   the receiving actor converts (beta formula, unit scaling) then emits
   `synced.readings`. Sensor values arriving *as messages* is already a
   first-class scada pattern; the simulated source extends it from
   HTTP-from-picos to broker-from-terminal-asset.

**Internal lingua franca:** everything converges on `synced.readings`
(ChannelNameList · ValueList · ScadaReadTimeUnixMs; equal-length axiom) or
`single.reading`, with scaled-int values typed by the `TelemetryName` enum
(`WaterTempCTimes1000`, `GpmTimes100`, …) and channel names bound to the
layout's `DataChannel`s.

### Async-first hypothesis (Jessica, 2026-06-11)

The whole sim stack might be faster if the readings arrive **async** —
event-driven, not cadence-bound. Sharpened: a snapshot-every-N-seconds model
bakes wall-clock pacing into the simulation. If sim time is ever to outrun wall
clock (run a winter's heating in an hour — the hybrid fleet and
experiment-at-scale cases), emission has to scale with **event density, not
elapsed time**: the sim emits a reading when something *happens* (a relay flips,
a temperature crosses a threshold, a heat-call edge), and the consuming side
reacts immediately. The scada's own `AsyncCaptureDelta` machinery exists because
the interesting things are edges; sync snapshots are the bandwidth-saving
aggregate, not the signal. Current lean: async single readings are the spine; a
snapshot bundle exists for bootstrap/resync (a late-joining scada needs current
state once), inverting the original snapshot-first lean.

### Decision points (with the leans that were taken)

1. **Altitude.** Telemetry-level (channel + scaled value + telemetry name), not
   device-level mimicry — the terminal asset models the house, not the silicon;
   device mimicry is a later, separate target for driver-path testing.
2. **Source identity.** Identity is the terminal asset's GNode alias carried by
   the transport (the wrapper's `From`), not faked in the payload; the sim layout
   generator is the single source of channel names, writing the same names into
   the scada layout and the terminal asset's config.
3. **One word or two.** Settled at **plant source word → synced readings** (the
   actor converts), not the async-single spine the earlier hypothesis leaned
   toward. See the `sim.plant.flux` decision below.
4. **Timestamps.** The word carries source time (which can be sim-time, decoupled
   from wall clock); the scada stamps read-time at conversion. Both kept, never
   conflated.
5. **Units.** `TelemetryName` semantics (canonical scaled-int conventions), not
   `multichannel.snapshot`-style loose `UnitList` strings.
6. **Where the words live and cross.** The sema word IS the wire format —
   gwbase-world words (left.right.dot TypeNames) on the AMQP fabric; the
   scada-side sim actor consumes the word directly over the MQTT bridge and
   converts to `synced.readings` inside the actor (exactly `api_tank_module`'s
   shape today). One canonical word; gwsproto stays internal to the scada.

The thread through all six: the simulated source should look like a **very honest
pico** — the same reception pattern the scada already trusts, minus the hardware
fictions.

### Decided 2026-06-12: `sim.plant.flux`

**The plant emits; the sensor reads.** Two roles, two words: the plant *is* the
physical world (gwta physics) and radiates its own state; a **sensor** (the
scada-side SimSensorActor) reads that and reports **`synced.readings`** to the
ShNodes, exactly as a real sensor reads a thermistor. **Nothing is a "reading"
until something has read it** — so the plant's word is explicitly *not*
`sim.synced.readings`. (At full fidelity the plant emits *physics* — a depth at
48.5 °C — and the sensor converts it to a channel + scaled-int; in the MVP the two
collapse, but the role names keep the seam where it belongs.)

**The word: `sim.plant.flux`.** Flux is never something a body *has* — it is always
flux *through* a surface, defined by the coupling between what's radiated and the
aperture it crosses. That builds the perceiver↔emitter exchange into the word: the
reading is the flux the **sensor's aperture** couples to (its channels, its
`AsyncCaptureDelta` — the surface it holds up to the plant). It avoids privileging
one side the way "truth" would, and it dodges scada's overloaded FSM "state."
Magnetic, relational, quantizable — and a deliberate **Tesla** nod. The
chosen-over alternative, `sim.plant.state`, was easy but one-sided and collides
with machine-state naming. **The sema `description` SHALL carry this rationale (the
flux-is-coupling reasoning + the Tesla call-out)** so the word teaches itself when
stared at.

Shape (settled):

- `ChannelNameList`, `ValueList`, `ScadaReadTimeUnixMs` — `ScadaReadTimeUnixMs`
  (unix ms) is the **sim time**, the source's truth-time, passing straight into
  `synced.readings.ScadaReadTimeUnixMs` downstream;
- **plus `ActualTimeUtc`** — the wall-clock time it crossed the wire, in
  **human-readable ISO 8601, millisecond precision** (`utc.iso8601.millis`, Joe's
  format). Provenance for a human reading a sped-up-time CSV, not consumed by the
  conversion — so it reads as a timestamp, not a number;
- equal-length axiom (`len(ChannelNameList) == len(ValueList)`);
- **No `Simulates*` fields** — the plant's raw emission must not presume its
  destination; the **reader interprets** the flux.

**Why both times.** Under sped-up coordinator time the sim clock outruns the wall
clock, so the emission carries two honest timestamps: the sim time it represents
and the real time it crossed the wire. The scada never sees the split: the
**SimSensorActor ingests the word, keeps `ActualTimeUtc` for the log/CSV, and
re-emits plain `synced.readings`** (`ScadaReadTimeUnixMs` = sim time) to the
ShNodes — the real ingestion path untouched.

**The word lives in both snapshots.** Baked into **both** the gwta snapshot (to
encode/emit) **and** the scada's gwsproto snapshot (to decode/read). A
sim-**boundary** word carried by both carriers; what stays internal to the scada's
ShNodes is `synced.readings`, not the source word.

## Questions about the real system's behavior (for DB access)

Obvious things to confirm against real per-room data (the best-guess parameters in
`build-plant.md` "The room thermal model" stand in until then; add questions as
they arise):

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

## Pattern: the cross-carrier sema round-trip harness

A reusable pattern for any sema-vocabulary sweep where scada (or another carrier)
authors the JSON and sema must decode it. Set it up at the **start** of the sweep —
the cost is minor next to the multi-depth untangles it prevents.

**The harness:** `sim-time-experiment/layout_roundtrip_check.py`. Given a real
scada-format layout JSON, it pulls every instance by `TypeName` and decodes each
through the sema runtime (`sema.runtime.codec.default_codec.from_dict`). A clean
decode is the cross-carrier guarantee that scada's wire form conforms to the new
sema type. Run from the sema repo so `sema` imports resolve:

```
cd ~/GridWorks/sema && uv run python \
  ~/GridWorks/sim-time-experiment/layout_roundtrip_check.py <layout.json> [TypeName ...]
```

**Fixtures (real data):** `~/GridWorks/oak.generated.json` (the original real oak —
richest; has egauge etc.) and `gridworks-scada/tests/config/house0-layout.json`
(current versions: CACs `:001`, `relay.actor.config:003`, …). NOT
`nolan-layout.json` (not a good-enough fixture). The decoded instance doubles as
the type's natural example.

**Per-word recipe (leaf-first):**
1. Author the flat sema schema from the gwsproto runtime class; add the registry
   entry; regen (`build_indexes.sh` + `regenerate_runtime.py`); `pytest` green.
2. Run the harness against oak/house0 for that `TypeName` — must be `0 FAIL`.
3. Commit title-only on `jm/sim-vocab`; add the `wiki/sema/changelog.md` entry;
   update `new-sema-words-to-review.md`.

**Gotcha that makes this worth doing first:** a declared axiom generates a runtime
template that **raises `NotImplementedError` until implemented**, so any real decode
throws. Either implement the axiom (sema convention — 59/61 are) or, when the axiom
encodes deployment policy rather than a cross-system contract (e.g. the CAC
`MakeModel↔id` table), drop it and keep the type structural-only. The harness
catches this on word 1 instead of after a dozen words.

**Validate sema AGAINST scada (EDD).** The scada hand-maintains its gwsproto types
(PascalCase) *separately* from the sema canon, so they can drift. Close the loop:
have the scada EMIT an instance of a type and guarantee it passes the sema runtime
check — feed scada-produced JSON (a `SyncedReadings`, a layout's `spaceheat.node.gt`,
later `sim.plant.flux` / `sim.plant.actuation`) through `default_codec.from_dict()`
and assert it decodes clean. A green decode is a *guarantee* the two carriers agree.

## Deferred / queued

- **gwsproto stops serializing `None`/`null` fields.** Surfaced by the live
  round-trip — sema tolerates it but it shouldn't be emitted. Worth its own design
  when picked up.
- **A simulated weather-forecast service** so the harness gets weather the way prod
  does (the Phase-A fixture is a static secret weather file for now).
- **DB backfill of real `gw.house0.layout`s respecting uniqueness** — the wand
  (`make_imaginary_layout.py`) is the seed tooling (instance ids unique, device-type
  ids canonical/shared).
- **Deferred canonization (NOT before the harness works):** add one or two lines to
  `GridWorks_CLAUDE.md` defining **Verified as run against the test harness**, with a
  longer document about what full test-harness runs mean. Canonize only after the
  sprint finishes.

## Opportunities for improvement

- **Move operational config out of the hardware layout (incl. the web server).** The
  hardware layout should be hardware *truth* — what exists, how it's wired, what it
  measures — not operational/service config (`executor/components.md` "What belongs in
  the hardware layout"). The **web server** is the clearest case: its host/port is
  service config, not a device. The `AbstractWebServer` device type (added this sprint)
  keeps hardware-layout-pass-one uniform — every component carries a `DeviceType` — but
  the real endpoint is lifting service config *out* of the layout into scada settings.
  The web server **stays** as a thing; it just shouldn't be a hardware-layout component.
  (Pass-two / its own cleanup, beyond hardware-layout-pass-one.)
- **Hubitat is not going forward; Home Assistant is uncertain — don't over-invest in the
  current poller/hubitat model.** Andrew's pollers + the Hubitat hub component exist to
  support the **5 initial House0 homes**. We do **not** plan to keep supporting Hubitat,
  and may not adopt Home Assistant either. If we do take on a hub going forward it will
  likely be **Home Assistant**, with a large refactor that probably **re-architects the
  pollers**. So treat the current poller/hubitat layer as legacy-supporting-the-five, not
  a pattern to extend or model carefully in the device-type work. (The web server is the
  exception — it stays, per the note above.)
