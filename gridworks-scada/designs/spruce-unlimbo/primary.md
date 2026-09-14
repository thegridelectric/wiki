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

Three layout families, six houses:

- **spruce** — `gw.nolan.layout`; runs `jm/spruce-unlimbo` today.
- **maple, beech** — `gw.house0.layout` (siegenthaler loop).
- **fir, elm, oak** — House0 with no sieg loop, `gw.house0.no.sieg`;
  the word and gens are a launch item (`house0-no-sieg-layout.md`).

## Spokes

In priority order. Launch items are the ones the six-box deploy cannot
go without.

1. ✅ DONE krida-retirement (est 6h → ≈15h) —
   House0 relays onto per-relay components against the Krida board record,
   one I2C actuation path, the relay multiplexer retired; witnessed on beech
   2026-09-11
2. ✅ DONE house0-zero-ten-outputs (est 3h → 4.0h) — House0's three 0-10V
   outputs onto per-output components against the board record, one actor arm
   for both chips, the power-on level in the ops words, the DFR multiplexer
   actor retired; witnessed on beech 2026-09-13; in
   `executor/hardware-layout.md` "The 0-10V output actuator"
3. ✅ DONE dac-output (est ?? → ≈9h) — the 0-10V output on the
   relay pattern; in `executor/hardware-layout.md` "The 0-10V output
   actuator" and `executor/running.md` "Experiment window on a deployed box"
4. ✅ DONE pico-cycler-command (est 4h → 9.6h; five-v-boss est 5h → 2.5h) —
   the cycler under a command interface with the ack pair, the per-pico state
   roster on the deployed line, the sim pico source, the panel rows, plus
   five-v-boss (the 5 V hold above it); in `executor/control-hierarchy.md`
   "The pico-cycler command" and "five-v-boss: the 5 V hold",
   `executor/testing.md` "Pico liveness in-process"
5. ✅ DONE sh-node-actor-partition (est ?? → ??) — the
   five-strata split of the god base class (A infra · B command-tree · C+D
   hydronic per family · E zone-TOU) and the role-first directory shape; in
   `executor/control-hierarchy.md` "The node-actor partition". The
   hydronic-file reviews and H0N/H0CN retirement it surfaced carry on in
   `correct-house0.md` rung 5
6. `correct-house0.md` (OPS-539, per-rung) — House0 made right: the fixture
   pair from the sema-native gen and `sema validate` green, the H0N/H0CN
   retirement carried through the hydronic file reviews, the House0 word's
   requirement axioms to the Nolan shape
7. `operational-params-cleanup.md` — the ops words per family and the
   coherence cleanup after the HydronicLayout collapse
8. `nolan-local-control.md` — the loop that runs a Nolan house through a
   heating season; opens after the partition rope
9. `control-strategy-selection.md` — the LTN and the scada select the
   correct control strategy per house; ops chooses the machine, the
   machine owns its state; the LTN side still to design
10. `layout-word-axioms.md` — the staging axiom reshape of both layout
    words + fixture/generator moves
11. `house0-no-sieg-layout.md` — the `gw.house0.no.sieg` word (House0 with
    the sieg surface deleted) and the oak / fir / elm generators; three of
    the six boxes are this family
12. `extra-pico-channels.md` — fancoil / floor1 / pipes1: which of their
    channels and deriveds the Nolan layout word requires vs tracks
13. `relay-actor-enforcement.md` — the relay actor keeps every relay reliable
    on the new code: assert-then-verify with I2C self-heal, confirmed state
    from pin-readback, honest boot; the two relay-test gaps that witness it
    pulled forward to launch. The zone-call / thermostat control model on top
    is post-launch (OPS-532)
14. `refactor-sieg.md` — the sieg loop's first exercise on the new code;
    the House0 rows of the hp-boss live test uncommented; before maple
    and beech take the branch
15. `command-tree-matrix.md` (est 3h) — the sender rule for five nodes (built),
    the state-transition tree matrix on `command_node.py`, the relay's full
    report to the journal
16. `odds-and-ends.md` — small launch items, one problem / change / test
    each (the panel's unobserved row offers every command; hp-boss
    reports its state at start; the LTN Dst-routing test)
17. `main-changes.md` — the commits `main` took after the branch point,
    each carried or dismissed before the branch becomes `main`
18. `finalize-layout-lite-13.md` — `layout.lite/013` and its closure from
    staging to published so spruce can send it on the production broker;
    `gw.nolan.layout` closes with the same promote
19. `deployment.md` — the fleet rollout to all six boxes as `main`:
    precondition gates, per-family order and verification, rollback to the
    prior SHA, and the post-launch tlayouts loop for updating a deployed
    layout or ops

Testing green for every layout family rides the simulated-test-environment
design's harness.

## The invariant: layouts carry three axes

Every layout word carries three axes explicitly, and control states speak
only the first:

1. **Capability set** — what intents exist at a house. The vocabulary is
   **per-layout subsetted**, not universal (OPS-394 defines it).
2. **Capability → mechanism binding** — what an intent means on this
   plumbing (a "charge buffer" is different valve/pump choreography on
   different manifolds).
3. **Hardware realization** — which device executes it. One relay actor,
   layout-bound: the same code drives a Krida panel relay at House0 and a
   gw108 relay at Nolan because the relay's component selects the board.

## Open

- The capability-set / binding / hardware model needs a worked draft
  against both layouts (joint with OPS-394's capability list); plant
  and store capabilities remain after the zone slice.
- gwsproto axiom burn-down ([OPS-513](https://linear.app/gridworks/issue/OPS-513)):
  after the simulated Nolan scada runs in dev, before the merge.
- Executor write-up as spokes verify: layout-strategy routing, relay
  actuation paths, test-layout selection.

## Related work

- The upstream data-side once-over — gridworks-data, web-backend, and
  web-frontend ingesting the three layout families without per-house
  channel-name specials — is its own cross-cutting design,
  [OPS-542](https://linear.app/gridworks/issue/OPS-542). It runs downstream:
  this launch produces the layouts, that design makes the data pipeline read
  them.
