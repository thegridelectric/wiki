# Sim-sensor words — the vocabulary for simulated sensor data

Status: Accepted · Pass 1 · Updated 2026-06-12 · Linear: OPS-40

> What this is: simulated-test-environment spoke — choosing the initial
> sema words a simulated terminal asset uses to report simulated sensor
> data. A **joint design session**: the groundwork and decision points
> are here (verified against gridworks-scada 2026-06-11); the decisions
> stay blank until made together. Minting goes through
> `/make-sema-word` (read `sema/CLAUDE.md` first). Moved here from the
> hello-world design (gridworks-terminalasset) at its 2026-06-11
> close-out — sim vocabulary is simulation work and consolidates here.

## How scada sensors receive information today — two paths

1. **Driver poll path.** An actor polls its hardware driver
   (`read_telemetry_values(channels) → DriverOutcome[dict[name, int]]`,
   `drivers/multipurpose_sensor/…:15-32`), buffers latest values, and
   reports on sync period or async threshold by sending
   `synced.readings` to the primary scada
   (`actors/multipurpose_sensor.py:208-228`). The existing sim driver
   (`GridworksSimPm1`) hardcodes return values — no message feed.
2. **API path (the precedent for message-fed sensors).** Picos POST
   typed payloads over HTTP — `microvolts` (HwUid, AboutNodeNameList,
   MicroVoltsList; `api_tank_module.py:189-263`) and
   `multichannel.snapshot` (HwUid, ChannelNameList, MeasurementList,
   UnitList; `api_btu_meter.py:209-262`) — and the receiving actor
   converts (beta formula, unit scaling) then emits `synced.readings`.
   Sensor values arriving *as messages* is already a first-class scada
   pattern; the simulated source extends it from HTTP-from-picos to
   broker-from-terminal-asset.

**Internal lingua franca:** everything converges on `synced.readings`
(ChannelNameList · ValueList · ScadaReadTimeUnixMs; equal-length axiom)
or `single.reading`, with scaled-int values typed by the
`TelemetryName` enum (`WaterTempCTimes1000`, `GpmTimes100`, …) and
channel names bound to the layout's `DataChannel`s.

## Async-first hypothesis (Jessica, 2026-06-11)

The whole sim stack might be faster if the readings arrive **async** —
event-driven, not cadence-bound. Sharpened: a snapshot-every-N-seconds
model bakes wall-clock pacing into the simulation. If sim time is ever
to outrun wall clock (run a winter's heating in an hour — the hybrid
fleet and experiment-at-scale cases), emission has to scale with
**event density, not elapsed time**: the sim emits a reading when
something *happens* (a relay flips, a temperature crosses a threshold,
a heat-call edge), and the consuming side reacts immediately. The
scada's own `AsyncCaptureDelta` machinery exists because the
interesting things are edges; sync snapshots are the bandwidth-saving
aggregate, not the signal. Current lean: async single readings are the
spine; a snapshot bundle exists for bootstrap/resync (a late-joining
scada needs current state once), inverting the original
snapshot-first lean below.

## Decision points for the joint session (with current leans)

1. **Altitude.** Device-level mimicry (microvolts-style — the sim
   pretends to be hardware, exercising conversion code) vs
   telemetry-level (channel + scaled value + telemetry name). Lean:
   telemetry-level — the terminal asset models the house, not the
   silicon; device mimicry is a later, separate target for
   driver-path testing.
2. **Source identity.** The API types use `HwUid`; a simulated stream's
   natural identity is the terminal asset's GNode alias, carried by the
   transport (the wrapper's `From`), not faked in the payload. The real
   binding question is channel names — lean: the sim layout generator
   is the single source, writing the same channel names into the scada
   layout and the terminal asset's config.
3. **One word or two.** Original lean was snapshot-bundle first; the
   async-first hypothesis inverts it — async single reading as the
   primary word, snapshot for bootstrap/resync. To settle together,
   including whether both get minted in one session (increment 2's
   scriptable heat-call is edge-shaped and forces the async word
   anyway).
4. **Timestamps.** Existing types carry `ScadaReadTimeUnixMs`; a
   simulated source has its own truth-time. Lean: the word carries
   source time (which can be sim-time, decoupled from wall clock —
   required for faster-than-real-time runs and deterministic
   capture/replay); the scada stamps read-time at conversion. Both
   kept, never conflated.
5. **Units.** Lean: `TelemetryName` semantics (canonical scaled-int
   conventions), not `multichannel.snapshot`-style loose `UnitList`
   strings — those exist because hardware reports native units; a sim
   has none. Pre-session check: what telemetry vocabulary sema already
   has, so we don't mint a parallel enum.
6. **Where the words live and cross.** Lean: the sema word IS the wire
   format — gwbase-world words (left.right.dot TypeNames) on the AMQP
   fabric; the scada-side sim driver in broker mode consumes the word
   directly over the MQTT bridge and converts to `synced.readings`
   inside the actor (exactly `api_tank_module`'s shape today). One
   canonical word; gwsproto stays internal to the scada.

The thread through all six: the simulated source should look like a
**very honest pico** — the same reception pattern the scada already
trusts, minus the hardware fictions.

## Decided 2026-06-12: `sim.plant.flux`

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
one side the way "truth" would (the plant has truth, the sensor degrades it), and
it dodges scada's overloaded FSM "state." Magnetic, relational, quantizable — and
a deliberate **Tesla** nod (he was onto something). The chosen-over alternative,
`sim.plant.state`, was easy but one-sided and collides with machine-state naming.
**The sema `description` SHALL carry this rationale (the flux-is-coupling reasoning
+ the Tesla call-out)** so the word teaches itself when stared at.

It is the terminal asset's native **source word** — paralleling the source words a
real pico emits (`microvolts`, `multichannel.snapshot`) that the receiving actor
*converts* into `synced.readings` (decision point 6, "a very honest pico"). Shape
(settled):

- `ChannelNameList`, `ValueList`, `ScadaReadTimeUnixMs` — `ScadaReadTimeUnixMs`
  (unix ms) is the **sim time**, the source's truth-time, passing straight into
  `synced.readings.ScadaReadTimeUnixMs` downstream;
- **plus `ActualTimeUtc`** — the wall-clock time it crossed the wire, in
  **human-readable ISO 8601, millisecond precision** (`utc.iso8601.millis`, Joe's
  format). It is provenance for a human reading a sped-up-time CSV, not consumed
  by the conversion — so it reads as a timestamp, not a number;
- equal-length axiom (`len(ChannelNameList) == len(ValueList)`);
- **No `Simulates*` fields.** An earlier draft pinned the word to
  `synced.readings` via `SimulatesTypeName`/`SimulatesVersion` consts; dropped
  (Jessica, 2026-06-12) — the plant's raw emission must not presume its
  destination. The **reader interprets** the flux (into `synced.readings` now,
  electrical and other derived signals later).

**Why both times.** Under sped-up coordinator time the sim clock outruns the wall
clock, so the emission has two honest timestamps: the sim time it represents and the
real time it crossed the wire. Keeping both at the sim boundary is what lets a CSV
produced under sped-up time be reordered/latency-checked against reality (the
fidelity-ladder north star). The scada never sees the split: the **SimSensorActor
ingests the word, keeps `ActualTimeUtc` for the log/CSV, and re-emits plain
`synced.readings`** (`ScadaReadTimeUnixMs` = sim time) to the ShNodes — the real
ingestion path untouched.

**The word lives in both snapshots.** Because the scada's SimSensorActor must
*decode* it to read it, the word is baked into **both** the gwta snapshot (to
encode/emit) **and** the scada's gwsproto snapshot (to decode/read). It is a
sim-**boundary** word carried by both carriers; what stays internal to the scada's
ShNodes is `synced.readings`, not the source word.

This settles decision point 4 (Timestamps — both kept, never conflated) and points
"one word or two" at **plant source word → synced readings** (the actor converts),
rather than the async-single spine the earlier hypothesis leaned toward. Minting
runs through `/make-sema-word` (read `sema/CLAUDE.md` first); it lands in `sema/`,
a separate claim from this session.
