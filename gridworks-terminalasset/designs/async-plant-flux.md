# Async plant flux

Status: Draft · Pass 0 · Updated 2026-11-12 · Linear: OPS-672

**EDD: yes** Verified when a compose run of a simulated house shows a
power change reported within two seconds of the relay actuation that
caused it, and a stopped plant noticed by the scada within the heartbeat
window.

> What this is: the plan to move the simulated terminal asset from a
> steady whole flux every 5 seconds to a flux that reports a channel
> when it changes, the way a real house's sensors do. It follows the
> first merge of the plant (gridworks-terminalasset PRs 3 to 6 and
> gridworks-scada PR 618) and does not gate it.

## Why

A real house reports a channel when its value crosses the channel's
`AsyncCaptureDelta`, and otherwise once per capture period. Power is the
clearest case: the LTN and the market act on it, so the report follows
the change within about a second.

The first plant sends every channel every 5 seconds. That has two
costs:

- A power change shows up to 5 seconds after the relay that caused it,
  so a simulated house misreports the timing of every dispatch.
- Tank depths and other slow channels are reported twelve times a
  minute, so report volume from a simulated house is nothing like a real
  one's.

## Decisions

1. **The delta is applied on both sides.** The plant emits a channel
   when it crosses its `AsyncCaptureDelta`. `SimSensorActor` also
   applies the delta to what it is handed.
2. **Power is the requirement, flow the likely second.** Both must be
   fast in simulation.
3. **The plant sends a heartbeat.** A plant that emits on change is
   quiet when nothing changes, so the scada cannot read silence as a
   dead plant.
4. **The clock stays wall time.** Coordinator timesteps are a later
   change (OPS-40).

## What changes

### Plant (gridworks-terminalasset)

- **Step loop.** The model advances on its own period of about one
  second, and once more on each `sim.plant.actuation` it hears. Today it
  advances only when the flux timer fires (`plant.py` `emit_flux`).
- **Emit rule.** After each step the plant compares every channel with
  the value it last sent. A channel goes into the flux when the change
  reaches its `AsyncCaptureDelta`, or when its `CapturePeriodS` has
  passed since it was last sent. A step with nothing to send sends
  nothing.
- **Capture tuning as an input.** `AsyncCaptureDelta` and
  `CapturePeriodS` are in the house's `gw.operational.params`
  (`capture.tuning`). The plant reads only the layout today. It takes
  the operational params file as a second argument and adds the word to
  its seed request.
- **Heartbeat.** A `sim.plant.flux` with empty lists, sent on a fixed
  short period. The word allows it: the lists have no minimum length and
  the one axiom is that they are the same length.

### Scada (gridworks-scada)

- **Plant link merges.** Each flux updates the latest value of the
  channels it names. Today a flux replaces the whole table
  (`plant_link.py:152`), which would drop every channel a partial flux
  leaves out.
- **Silence counts heartbeats.** The 15-second rule
  (`PLANT_SILENT_AFTER_S`) stays, measured from the last flux of any
  kind, empty ones included.
- **`SimSensorActor` applies the delta.** It keeps the last value it
  reported per channel and reports on a delta crossing or at the capture
  period.
- **No change** to `PowerMeter` and `I2cThermistorReader`, which already
  poll and apply the delta, or to the sim tank modules and BTU meters,
  which then see what a real pico would post.

## Open

- **Heartbeat period.** A few seconds, well under the 15-second window.
- **Model step rate.** Whether the FMUs run comfortably at a one-second
  step, and whether power wants a shorter one.
- **Tank module delta.** A real tank pico compares microvolts against a
  threshold the scada computes from the depth channels' delta
  (`api_tank_module.py` `micro_volt_capture_delta`). The plant needs the
  same number for the `-micro-v` channels.
- **Sim-specific code in the scada.** The heartbeat and the silence rule
  are in the plant link. If picos and the power meter are later fed over
  their real network paths, the link serves only the on-board devices.
  That is a separate decision.

## Size

About two days for someone who knows the code: half a day each for the
plant's step loop and emit rule, the operational params input, the scada
side, and the tests with a rerun of the compose experiment
(`experiments/2026-11-11-beech-sim-compose/`).
