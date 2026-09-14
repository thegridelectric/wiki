# Spruce settled (hub)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: [OPS-532](https://linear.app/gridworks/issue/OPS-532)

**EDD: yes** the deployed spruce line and the simulated houses are the
verification; a spoke reaches Verified only when a run against one of
them exercises it (`experiments/`).

> What this is: the work that comes AFTER `jm/spruce-unlimbo` is
> deployed on spruce. Everything a launch needs stays in
> `../spruce-unlimbo/`; what makes the deployed line good over the
> season collects here. Opened 2026-09-10 to receive the first such
> item.

**▶ Active spoke:** none until the launch. First in line:
[`report-all-machine-states.md`](report-all-machine-states.md).

## Spokes

- `report-all-machine-states.md` — every command node's machine state
  becomes a journal channel by one rule; which state and channel
  changes earn an asynchronous report
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
- `relay-tests.md` — what the hp-boss witness left unexercised, ten
  gaps each with its test; gap 1 (the sieg leg) is owned before the
  launch by spruce-unlimbo's refactor-sieg spoke
- `pump-device-type.md` — a device-type word per pump model (control
  kind, curve, stop machine); carries the measured Grundfos UPMS 20-78 F
- `hp-twin.md` — the heat pump's digital twin under hp-boss: sema
  command events in, modbus out; waits on the modbus work
- `sieg-command-tree.md` — the Siegenthaler loop's tier and command
  surface (admin included); `SiegLoop` sits on `House0Hydronic` until
  then; opens with the fall layouts
- `fall-layouts.md` — the four layouts arriving fall 2026 (one sim,
  three Millinocket installs); what each removes/adds
- `gw108-board.md` — schematic-verified board facts: zone signal
  chain, expander map, DAC/EEPROM (living reference)
- `simple-sim-n3.md` — `gw1.simple.sim.layout` loadability as the N=3
  stress test of the family tiers

## Related work

- The admin session and the admin process behind it (a dead admin link
  noticed by both sides, one admin at a time, `heartbeat.a` both ways)
  is the admin domain's
  [OPS-529](https://linear.app/gridworks/issue/OPS-529); it goes onto
  the deployed line in this design's window.
