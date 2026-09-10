# Spruce settled (hub)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: [OPS-532](https://linear.app/gridworks/issue/OPS-532)

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

## Related work

- The admin session and the admin process behind it (a dead admin link
  noticed by both sides, one admin at a time, `heartbeat.a` both ways)
  is the admin domain's
  [OPS-529](https://linear.app/gridworks/issue/OPS-529); it goes onto
  the deployed line in this design's window.
