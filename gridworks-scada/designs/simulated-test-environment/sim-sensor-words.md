# Sim-sensor words — the vocabulary for simulated sensor data

Status: Draft · Pass 0 · Updated 2026-06-11

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
