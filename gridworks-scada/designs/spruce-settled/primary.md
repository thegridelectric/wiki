# Spruce settled (hub)

Status: Draft · Pass 0 · Updated 2026-09-29 · Linear: [OPS-532](https://linear.app/gridworks/issue/OPS-532)

**EDD: yes** the deployed spruce line and the simulated houses are the
verification; a spoke reaches Verified only when a run against one of
them exercises it (`experiments/`).

> What this is: the work that comes AFTER `jm/spruce-unlimbo` is
> deployed on spruce. Everything a launch needs stays in
> `../spruce-unlimbo/`; what makes the deployed line good over the
> season collects here. Opened 2026-09-10 to receive the first such
> item. These spokes are the work to complete BEFORE the layouts and
> the operational params publish and the fleet goes onto the hw1
> rmqbot (`publish-layouts-and-operational-params.md` is that step).

**▶ Active spoke:** none until the launch.

## Spokes

- `hp-unit-sensor.md` — a first sensed machine of what the heat pump
  unit is doing, per-unit rules in their own files; practice, heuristic,
  written to be replaced
- `scada-startup-report.md` — a `scada.startup.report` word sent once per
  run: when the run started, when the report was sent, the commit the box
  runs
- `admin-tests-house0.md` — admin coverage on the House0 fixture pair,
  the twin of the Nolan admin tests
- `five-v-restore-liveness.md` — the extra 5 V cycle on TurnOn: the
  liveness clock runs through the hold; restart it at power-on
- `pico-cycler-coverage.md` — the five in-process tests the cycler
  command work still owes (overlap, sim-pico loop, journal path, GPIO
  commit order, admin ack)
- `command-tree-diagrams.md` — the graphic command-tree diagrams the
  control-hierarchy executor asks for
- `publish-layouts-and-operational-params.md` — the layout closure and
  the operational-params pair from staging to published once the fleet
  runs them, and the wire words that still have no sema word minted
- `misc-tests.md` — small tests that fixes have earned and not yet got
- `pump-doctors-functional.md` — the dist and store pump doctors end to
  end on a plant that answers; the in-process suite pins the monitors
  and the attempt bookkeeping until the simulated houses run
- `relay-tests.md` — what the hp-boss witness left unexercised, ten
  gaps each with its test; gap 1 (the sieg leg) is owned before the
  launch by spruce-unlimbo's basic-sieg spoke
- `pump-device-type.md` — a device-type word per pump model (control
  kind, curve, stop machine); carries the measured Grundfos UPMS 20-78 F
- `hp-device-type-records.md` — a vendored `hp.device.type.gt` record for
  every fleet heat pump (LG and Mitsubishi still missing) so a house gen
  binds its hp-odu/hp-idu to nameplate facts, not a bare DeviceType string
- `hp-twin.md` — the heat pump's digital twin under hp-boss: sema
  command events in, modbus out; waits on the modbus work
- `ltns-ready.md` — a maple LTN and a spruce LTN running on the new
  code, each with its FLO and parameters; then what the LTN takes from
  the scada, transferred from spruce-unlimbo's `layout.lite/013` work
- `thermostat-and-zone-control.md` — the zone / circuit / thermostat
  control model deferred out of the launch: the circuit FSM, the
  governance machine, setpoint belief, and the thermostat chunk (sim
  thermostat, setpoint discovery, Hubitat/Honeywell); the launch-side
  relay-actor enforcement is OPS-392
- HOLD `command-node-vocabulary.md` — "command node" is used with
  inconsistent meanings across the sema words and code (commander /
  actuator / ack-replier); the Commanding–Commandable–Actuator taxonomy is
  parked until its command-node sitting
- `five-minute-energy.md` — the scada produces Wh per five-minute
  interval at the transactive boundary, integrated by the power meter at
  its clock, so no consumer has to integrate a change-driven power series
- `fall-layouts.md` — the four layouts arriving fall 2026 (one sim,
  three Millinocket installs); what each removes/adds
- `gw108-board.md` — schematic-verified board facts: zone signal
  chain, expander map, DAC/EEPROM (living reference)
- `simple-sim-n3.md` — `gw1.simple.sim.layout` loadability as the N=3
  stress test of the family tiers
- `multi-bus-layouts.md` — a board with two I²C buses or a second board
  expressible in the layout words and driven by the scada: the bus as a
  board-resident component, the decided shape and build inventory

## Related work

- The admin session and the admin process behind it (a dead admin link
  noticed by both sides, one admin at a time, `heartbeat.a` both ways)
  is the admin domain's
  [OPS-529](https://linear.app/gridworks/issue/OPS-529); it goes onto
  the deployed line in this design's window.
