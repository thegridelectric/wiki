# Spruce un-limbo (hub)

Status: Accepted · Pass 1 · Updated 2026-09-13 · Linear: OPS-392

**EDD: yes** bench (honeysuckle) and box harness runs are the verification;
spokes reach Verified only when an experiment runs against the real bus or a
real broker.

**▶ Active spoke: [`sh-node-actor-partition/primary.md`](sh-node-actor-partition/primary.md)**

> **When you get around to re-organizing this hub** (a fresh session,
> after the "do this now" queue is clear), in this order. First, roll the
> OPS-392 rows under "Active hours — scratch" in `admin/jess-estimates.md`
> into the Actual of their `r:sim-green` rope chunks, so the calibration
> question can be answered: do estimates made after a layer is open hold,
> where estimates made from outside blew up? Second, sort the eighteen
> spokes into three piles: done (distill into `executor/`, delete), live,
> parked. Third, rewrite this hub in present tense. The work since June
> came in four layers, each visible only
> once the one above was open (what runs; layouts and mirrors; the
> hardware bus; the vocabulary); eight spokes were born on 2026-09-02
> alone, and fifteen of eighteen are Draft Pass 0. The sort needs the
> queue clear so it knows which spokes are actually finished.

> What this is: the hub for un-limboing the spruce scada integration —
> getting the branch that runs Matt Polstein's house (the Nolan layout)
> out of limbo and onto a path that merges to main without breaking the
> House0 fleet. Grew out of Jessica's 2026-06-09 seed; the seed's
> *Reported* items have now been verified or corrected (below).

## Spokes

The order is roughly the priority order.

- ✅ DONE krida-retirement — House0 relays onto per-relay components
  against the Krida board record, one I2C actuation path, the relay
  multiplexer retired; witnessed on beech 2026-09-11
- `house0-zero-ten-outputs.md` — House0's three 0-10V outputs onto
  per-output components, the DFR multiplexer actor retired; after the
  relay decommission
- `correct-house0.md` — House0 made right: the fixture pair
  from the sema-native gen and `sema validate` green, the H0N/H0CN
  retirement carried through the hydronic file reviews, the House0
  word's requirement axioms to the Nolan shape; after the 0-10V shift
- `gw108-board.md` — schematic-verified board facts: zone signal
  chain, expander map, DAC/EEPROM (living reference)
- `spruce-admin-rig.md` — the standing admin-panel rig on the real house
  (tmux scada off the dev broker, shared with the person on site).
- `spruce-relay-control.md` — chunk A record: reader→bus verified;
  code-survey pins, relay roster (layout side complete 2026-08-11),
  bench/boot reproducers, window safety arrangement
- `summer-local-control.md` — the scada takes over the summer
  hack: TOU cooling + behavioral glitches (the actor build)
- `zone-relays-and-thermostat-model.md` — the zone / circuit /
  thermostat model (settled; vocabulary + layout landed 2026-08-11)
- `operational-params-cleanup.md` — ops words + the coherence
  cleanup after the HydronicLayout collapse
- **`sh-node-actor-partition/` — the five-strata split of the god
  base class; tiers, role-first dirs, `hydronic/` family files (active)**
- `sieg-command-tree.md` — the Siegenthaler loop's tier and command
  surface (admin included); `SiegLoop` sits on `House0Hydronic` until
  then; opens with the fall layouts
- `nolan-local-control/` — the loop that runs a Nolan house through a
  heating season; gathers the scattered LC pieces; opens after the
  partition rope
- `control-strategy-selection.md` — ops chooses the machine, the
  machine owns its state; what replaces `SeasonalStorageMode`
- `extra-pico-channels.md` — fancoil / floor1 / pipes1 (re-energized
  2026-09): which of their channels and deriveds the Nolan layout word
  requires vs tracks; before launch
- `fall-layouts.md` — the four layouts arriving fall 2026 (one sim,
  three Millinocket installs); what each removes/adds
- ✅ DONE dac-output — the 0-10V output on the relay pattern, distilled
  into `executor/hardware-layout.md` "The 0-10V output actuator" and
  `executor/running.md` "Experiment window on a deployed box"
- `layout-word-axioms.md` — the staging axiom reshape of both layout
  words + fixture/generator moves
- `hello-world.md` — LTN ↔ SCADA over dev rabbit, consumed by a dev JK
- `unsorted/` — drop-box for surfaced-but-not-yet-thought-through
  items (CT measurement chain, …)
- `finalize-layout-lite-13.md` — take `layout.lite/013` and its closure
  from staging to published so spruce can send it on the production
  broker; a before-merge item

Not in the list: `gleanings.md` holds residual content from spokes
closed in August (both-cases survey, layout-augments carry/skip,
gw.nolan.layout closing). It is a parking file, not a workstream; the
sort into done / live / parked decides what of it survives.

The simulated-actors spoke moved to the simulated-test-environment
design (2026-06-11, harness elevated to the top); testing green for
every layout family rides that harness.

## The deadline driver

**Deploy the new code on the whole fleet before the heating season.**
Three layout families, six houses:

- **spruce** — `gw.nolan.layout`; runs `jm/spruce-unlimbo` today.
- **maple, beech** — `gw.house0.layout` (siegenthaler loop).
- **fir, elm, oak** — House0 with no sieg loop, `gw.house0.no.sieg`;
  not built yet (`fall-layouts.md`).

The July air-conditioning commitment at spruce is met (the monobloc
heat pump cools through the fan coils; cooling never uses the radiant
floor or the store tanks). Its scada takeover is `summer-local-control.md`.

## The conceptual model to build (the design's center of gravity)

Three things are currently conflated and must be separated cleanly
(Jessica, 2026-06-10):

1. **Capability set** — *what intents exist at a house.* Differs per
   scheme: Nolan has capabilities House0 lacks (resistive backup
   elements, fan coils, heat-exchanger pump) and lacks ones House0 has
   (store charge/discharge across three tanks, Honeywell setpoint
   reading via Hubitat — reading only; no setpoint write path has ever
   existed, verified 2026-08-11). The capability-protocol-and-verify
   design ([OPS-394](https://linear.app/gridworks/issue/OPS-394)) defines
   the vocabulary; this design adds: the vocabulary is **per-layout
   subsetted**, not universal.
2. **Capability → mechanism binding** — *what an intent means on this
   plumbing* ([OPS-394](https://linear.app/gridworks/issue/OPS-394) principle 2). E.g. "charge buffer" means different
   valve/pump choreography on different manifolds.
3. **Hardware realization** — *which physical device executes the
   mechanism.* Differs even where the capability is identical: the
   **pico cycler relay** exists in both schemes, but is a Krida panel
   relay on House0 and a Gw108 GPIO relay on Nolan. This axis lives in
   the layout (the relay's component selects the board and the
   mechanism), so the relay actor is one body of code with layout-bound
   actuation.

The layout types (`house0.layout`, `gw.nolan.layout`) should carry all
three axes explicitly; control states speak only axis 1.

## Chunks (revised from the seed)

- **A — i2c relays:** the reader→bus path is window-verified
  (2026-08-11); what remains is the relay path riding the bus
  (`spruce-relay-control.md`: five gaps + roster), restoring the
  House0 path, and making the path choice layout-driven (axis 3).
- **B — layout pipeline:** `gw.nolan.layout` + `house0.layout` as Sema
  types; retire tlayouts' lock-step branching; fold in the
  `jm/layout-augments` rework (carry/skip judgment + the
  `gw.nolan.layout` closing plan: `gleanings.md`). [OPS-334](https://linear.app/gridworks/issue/OPS-334) ("80% done") lives here.
- **C — branch reconciliation:** `jm/spruce-new` gleaned; remaining:
  fold `jm/layout-augments`, merge dev forward regularly.
- **D — Nolan local control:** today observation-only (SetpointPhase
  learning, heat-call sensing). The control loop that *uses* predicted
  setpoints is unwritten; written against the [OPS-394](https://linear.app/gridworks/issue/OPS-394)
  capability surface from day one — the zone slice of that surface is
  settled in `zone-relays-and-thermostat-model.md`. [OPS-219](https://linear.app/gridworks/issue/OPS-219) lives here;
  the gathered plan is `nolan-local-control/`.
- **E — minimal AC path (was: by July 15):** resolved as the summer
  hack on the box; its scada takeover is `summer-local-control.md`.

## The meta-goal (why this is vision-grade, not a chore)

We are still finding the best designs for different scenarios — new-build
green homes (Matt) vs old median homes in northern Maine. We will be
testing out at least 5 different heat pumps this fall, and are examining
various thermal stores (store-under-floor, 350-gallon tanks that can be
assembled in the basement BUT are oxygenated) and also continuing to
experiment with flow control manifolds and additional sensors.

The system must let us **reason like this brain-dump and adjust on the
fly to new configurations**: control schemes parameterized by layout
(layouts-as-complex-Sema-types), not hand-coded per house. Spruce is the
first proof.

## Open

- Fold `jm/layout-augments` (carry/skip judgment in `gleanings.md`).
- The capability-set / binding / hardware model above needs a worked
  draft against both layouts (joint with [OPS-394](https://linear.app/gridworks/issue/OPS-394)'s capability list) —
  the zone slice is drafted (`zone-relays-and-thermostat-model.md`);
  plant and store capabilities remain.
- gwsproto axiom burn-down ([OPS-513](https://linear.app/gridworks/issue/OPS-513)):
  after the simulated Nolan scada runs in dev, before the merge.
- Executor write-up: the durable architecture facts found here
  (layout-strategy routing, relay actuation paths, test-layout
  selection) belong in `wiki/gridworks-scada/executor/` as they verify.
