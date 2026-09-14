# Spruce un-limbo (hub)

Status: Accepted · Pass 1 · Updated 2026-09-14 · Linear: OPS-392

**EDD: yes** bench (honeysuckle) and box harness runs are the verification;
spokes reach Verified only when an experiment runs against the real bus or a
real broker.

**▶ Active spoke: [`correct-house0.md`](correct-house0.md)**

> What this is: the hub for getting `jm/spruce-unlimbo`, the branch that
> runs the Nolan layout at spruce, onto the whole fleet as `main` before
> the heating season without breaking the House0 houses. Everything a
> launch needs is a spoke here; what makes the deployed line good over
> the season is `../spruce-settled/`.

## Spokes

In priority order. Launch items are the ones the six-box deploy cannot
go without.

- ✅ DONE krida-retirement — House0 relays onto per-relay components
  against the Krida board record, one I2C actuation path, the relay
  multiplexer retired; witnessed on beech 2026-09-11
- ✅ DONE house0-zero-ten-outputs — House0's three 0-10V outputs onto
  per-output components against the board record, one actor arm for
  both chips, the power-on level in the ops words, the DFR multiplexer
  actor retired; witnessed on beech 2026-09-13; in
  `executor/hardware-layout.md` "The 0-10V output actuator"
- ✅ DONE dac-output — the 0-10V output on the relay pattern; in
  `executor/hardware-layout.md` "The 0-10V output actuator" and
  `executor/running.md` "Experiment window on a deployed box"
- ✅ DONE pico-cycler-command — the cycler under a command interface
  with the ack pair, the per-pico state roster on the deployed line,
  the sim pico source, the panel rows; est. 4h (2–8), actual 9.6h; with
  five-v-boss, the 5 V hold above it, est. 5h (3–10), actual 2.5h; in
  `executor/control-hierarchy.md` "The pico-cycler command" and
  "five-v-boss: the 5 V hold", `executor/testing.md` "Pico liveness
  in-process"
- `correct-house0.md` — House0 made right: the fixture pair from the
  sema-native gen and `sema validate` green, the H0N/H0CN retirement
  carried through the hydronic file reviews, the House0 word's
  requirement axioms to the Nolan shape
- `sh-node-actor-partition.md` — the five-strata split of the god base
  class: tiers, role-first dirs, names decisions, the rope's Done
  ledger with estimate against actual per chunk; to retire: distill
  into the executor, then delete (recipe in its "Do this next")
- `command-tree-matrix.md` — the sender rule for five nodes (built), the
  state-transition tree matrix on `command_node.py`, the relay's full
  report to the journal
- `zone-relays-and-thermostat-model.md` — the zone / circuit /
  thermostat model in the layout, the relay actor's confirmed state, the
  thermostat chunk (sim thermostat, setpoint discovery, first
  Hubitat/Honeywell tests)
- `operational-params-cleanup.md` — the ops words per family and the
  coherence cleanup after the HydronicLayout collapse
- `layout-word-axioms.md` — the staging axiom reshape of both layout
  words + fixture/generator moves
- `extra-pico-channels.md` — fancoil / floor1 / pipes1: which of their
  channels and deriveds the Nolan layout word requires vs tracks
- `control-strategy-selection.md` — the LTN and the scada select the
  correct control strategy per house; ops chooses the machine, the
  machine owns its state; the LTN side still to design
- `nolan-local-control.md` — the loop that runs a Nolan house through a
  heating season; opens after the partition rope
- `refactor-sieg.md` — the sieg loop's first exercise on the new code;
  the House0 rows of the hp-boss live test uncommented; before maple
  and beech take the branch
- `main-changes.md` — the commits `main` took after the branch point,
  each carried or dismissed before the branch becomes `main`
- `odds-and-ends.md` — small launch items, one problem / change / test
  each (the panel's unobserved row offers every command; hp-boss
  reports its state at start; the LTN Dst-routing test)
- `finalize-layout-lite-13.md` — `layout.lite/013` and its closure from
  staging to published so spruce can send it on the production broker;
  `gw.nolan.layout` closes with the same promote

Testing green for every layout family rides the simulated-test-environment
design's harness.

## The deadline driver

**Deploy the new code on the whole fleet before the heating season.**
Three layout families, six houses:

- **spruce** — `gw.nolan.layout`; runs `jm/spruce-unlimbo` today.
- **maple, beech** — `gw.house0.layout` (siegenthaler loop).
- **fir, elm, oak** — House0 with no sieg loop, `gw.house0.no.sieg`;
  not built yet (`../spruce-settled/fall-layouts.md`).

Spruce's summer cooling runs on the box's summer hack (the monobloc heat
pump cools through the fan coils; cooling never uses the radiant floor or
the store tanks); the scada's takeover of it is the Nolan local control
work.

## The conceptual model (the design's center of gravity)

Three things the code conflated and the layouts separate:

1. **Capability set** — *what intents exist at a house.* Differs per
   scheme: Nolan has capabilities House0 lacks (resistive backup
   elements, fan coils, heat-exchanger pump) and lacks ones House0 has
   (store charge/discharge across three tanks, Honeywell setpoint
   reading via Hubitat; reading only, no setpoint write path exists).
   The capability-protocol-and-verify design
   ([OPS-394](https://linear.app/gridworks/issue/OPS-394)) defines the
   vocabulary; this design adds that the vocabulary is **per-layout
   subsetted**, not universal.
2. **Capability → mechanism binding** — *what an intent means on this
   plumbing* (OPS-394 principle 2). "Charge buffer" is different
   valve/pump choreography on different manifolds.
3. **Hardware realization** — *which physical device executes the
   mechanism.* Differs even where the capability is identical: the pico
   cycler relay exists in both schemes, on a Krida panel relay at House0
   and a gw108 relay at Nolan. This axis lives in the layout (the relay's
   component selects the board), so the relay actor is one body of code
   with layout-bound actuation.

The layout words carry all three axes explicitly; control states speak
only axis 1. The zone slice of the capability surface is settled in
`zone-relays-and-thermostat-model.md`; plant and store capabilities are
open.

## The meta-goal (why this is vision-grade, not a chore)

We are still finding the best designs for different scenarios: new-build
green homes vs old median homes in northern Maine. At least five different
heat pumps go in this fall, thermal stores under evaluation range from
store-under-floor to oxygenated 350-gallon basement tanks, and the flow
control manifolds and sensing keep changing.

The system must let us **reason like this brain-dump and adjust on the
fly to new configurations**: control schemes parameterized by layout
(layouts as complex sema types), not hand-coded per house. Spruce is the
first proof.

## Open

- The capability-set / binding / hardware model needs a worked draft
  against both layouts (joint with OPS-394's capability list); plant
  and store capabilities remain after the zone slice.
- gwsproto axiom burn-down ([OPS-513](https://linear.app/gridworks/issue/OPS-513)):
  after the simulated Nolan scada runs in dev, before the merge.
- Executor write-up as spokes verify: layout-strategy routing, relay
  actuation paths, test-layout selection.
