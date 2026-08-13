# Spruce un-limbo (hub)

Status: Accepted · Pass 1 · Updated 2026-08-11 · Linear: OPS-392

**EDD: yes** bench (honeysuckle) and box harness runs are the verification;
spokes reach Verified only when an experiment runs against the real bus or a
real broker.

**▶ Active spoke: [`summer-local-control.md`](summer-local-control.md)**

> What this is: the hub for un-limboing the spruce scada integration —
> getting the branch that runs Matt Polstein's house (the Nolan layout)
> out of limbo and onto a path that merges to main without breaking the
> House0 fleet. Grew out of Jessica's 2026-06-09 seed; the seed's
> *Reported* items have now been verified or corrected (below).

## Spokes

- `gw108-board.md` — schematic-verified board facts: zone signal
  chain, expander map, DAC/EEPROM (living reference)
- `spruce-relay-control.md` — chunk A record: reader→bus verified;
  code-survey pins, relay roster (layout side complete 2026-08-11),
  bench/boot reproducers, window safety arrangement
- **`summer-local-control.md` — the scada takes over the summer
  hack: TOU cooling + behavioral glitches (the actor build) (active)**
- `zone-relays-and-thermostat-model.md` — the zone / circuit /
  thermostat model (settled; vocabulary + layout landed 2026-08-11)
- `operational-params-cleanup.md` — `gw.nolan.operational.params` +
  slimming the house0 word (GNodes, Lat/Long out)
- `admin-for-nolan.md` — admin UI sees and operates a Nolan house
- `hello-world.md` — LTN ↔ SCADA over dev rabbit, consumed by a dev JK
- `gleanings.md` — residual live content from closed spokes
  (both-cases survey · layout-augments carry/skip · gw.nolan.layout
  closing)

The simulated-actors spoke moved to the simulated-test-environment
design (2026-06-11, harness elevated to the top); the merge gate's
"testing green for BOTH" rides that harness.

## The commitment (the deadline driver)

**Air conditioning at Matt Polstein's, with pride in the scada code**
(committed for July 15). As of 2026-07-15 the **monobloc heat pump is
providing the air conditioning**; the remaining bar — the near-term goal —
is the **scada controlling spruce's i2c relays**, so the promised shape
runs under scada control: AC off-peak, plus pre-cooling the room a bit
during the afternoon shoulder. Constraints:

- Cooling uses the **fan coil units directly from the heat pump**. NOT the
  radiant floor and NOT the store tanks (that would require reversing water
  flow).
- Suspicion to validate: **long cooling bouts** are more efficient.
- Later option, eyes open: use the thermal store for cooling accepting that
  the water mixes — no stratification, very limited capacity.

## The merge gate (Jessica, 2026-06-10 — Open, Draft)

The working branch merges to main only when **both cases work**:

- two layout instances — **`house0.layout` and `gw.nolan.layout`** (the
  latter already drafted as a Sema type) — and
- **scada operations, layout generation, and testing green for BOTH.**

Rationale: with one layout type, per-house special cases hide in
hand-coded generators (tlayouts today: nine `gen_<house>.py` scripts).
Two layouts is the minimum that forces control code to be parameterized
by layout rather than forked per house — the meta-goal's first proof.

**Merge gate ≠ July-15 gate.** Spruce already runs an unmerged branch;
the AC commitment rides the branch line while both-cases convergence
happens. The dual-layout work needs its own honest timeline so "after
July 15" doesn't become "never."

## Branch state (verified 2026-06-10)

- **What runs on spruce: `td/orig-pred-set`** (Thomas's branch; tip
  `3c100867`, 2026-05-26). It **contains `jm/spruce`** as an ancestor —
  all the i2c work (i2c bus actor, relay board, thermistor reader, Gw108
  components) is already in it — and it merged dev on 2026-05-26
  (`b4c3d65f`), so it sits only ~10 commits behind dev, 32 ahead.
  Textually it merges clean with dev; the real blocker is semantic
  (House0 relay actuation disabled — next section).
- **`jm/spruce-unlimbo`** — created 2026-06-10 off `td/orig-pred-set`:
  the working branch for this design.
- **Gleaned from `jm/spruce-new`:** exactly 2 commits, cherry-picked
  onto `jm/spruce-unlimbo`: `62bc7218` (scada.py docstring), `2b603cc0`
  (ChannelConfigBase + RelayActorConfig / I2cThermistorChannelConfig
  version bumps + named-type tests).
- **`jm/layout-augments`** — chunk B's glean source (pushed to origin
  2026-06-10): the `gwsproto/names/` progression (core / house0 /
  hydronic_spaceheat / nolan node+channel names), preliminary nolan
  layout gen, derived-channel axioms — 12 unique commits, forked before
  Thomas's May work, so absorbing it is a reconciliation job. The branch
  tests skip `test_layout_gen.py` pointing at this rework.
- **Deleted 2026-06-10:** `jm/pico` (TankModule3Params prep — regenerate
  later), `jm/pred-set`, `jm/maple-hack`, `jm/spruce`, `jm/spruce-new`
  (fully gleaned), `jm/scada-control` (capability-type sketch mined into
  the capability-protocol-and-verify design first).
- **tlayouts** rides a lock-step `jm/spruce` branch (sema-native,
  pushed to origin since 2026-08-03); its `main` pairs with House0-era
  scada, its `jm/spruce` pairs with the spruce line. Coupling details
  in `gleanings.md`. The gens are dev-laptop tooling and run in the
  **sibling scada checkout's venv** (that venv's python with
  `PYTHONPATH="src:<scada>/gw_spaceheat"`; tlayouts' own uv env has no
  gwsproto, deliberately) because `names` and the board device-type
  records still import from gwsproto. Temporary: chunk B moves both
  into sema, after which the gens run self-contained and the
  venv/branch pairing dissolves into ordinary snapshot versioning.
- Sema `jm/nolan` holds the draft `gw.nolan.layout` type (2 commits ahead
  of sema dev).

## Test state by commit — RESOLVED (2026-06-11, commit `b3cf2c4b`)

The "merge `bb4f6294` is the suspect" hypothesis was a **red herring** — not
a branch regression at all. Two independent causes, both fixed in `b3cf2c4b`
("Green the test suite: House0 AsyncCaptureDelta + local test dotenv wiring"):

- **The 10 s link timeout** (`test_auto_state_home_alone_to_ltn` and the
  scada↔LTN link tests) was **local environment, not code**: the test dotenv
  that turns TLS off for the plain local broker never loaded — `conftest.py`
  declared dead dotenv constants while `gwproactor_test` reads a different
  name (`GWPROACTOR_TEST_DOTENV_PATH` / `tests/.env-gwproactor-test`). So the
  LTN broker defaulted `tls.use_tls=True` and hung against plain mosquitto.
  Fixed: conftest now wires the dotenv var, and the local rig is committed
  (un-gitignored).
- **CI's two failures** were the `AsyncCaptureDelta` axiom: the
  `RelayActorConfig` v003 bump (`dab55d20`) enforces "AsyncCapture ⇒
  AsyncCaptureDelta" but only `nolan-layout.json` got the values;
  `house0-layout.json`'s 14 relays were left without it. Fixed: backfilled
  `AsyncCaptureDelta: 1`.

Both ride entirely on `td/orig-pred-set` — the merge and the sim-time bridge
were innocent. The full debugging is an EDD worked example in
`experiments/logbook.md`. Tests green on `jm/spruce-unlimbo`.

## Why the branch can't run House0 (verified disable points)

Jessica: "I have disabled the meaning of turning on and off relays."
Confirmed in code on the branch:

- `gw_spaceheat/actors/relay.py` — `process_message`'s dispatch of
  `FsmAtomicReport` from the relay multiplexer is **commented out**, so
  the legacy Krida-multiplexer actuation round-trip never completes; and
  `relay.py:88` looks up `H0N.relay_multiplexer` unconditionally, which
  the Nolan layout doesn't have. The refactor split actuation into a
  Gw108 direct-GPIO path (`_actuate_and_report`) and the legacy
  multiplexer path (`_actuate_and_defer_report`, round-trip dead).
- `tests/conftest.py` hardcodes `nolan-layout.json` — House0 tests never
  run on CI on this branch.
- tlayouts `jm/spruce` drops `add_relays()` from House0 generators and
  switches tank calibration constants to 100×-scaled values — it cannot
  generate correct House0 layouts.

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
   **pico cycler relay** exists in both schemes, but is a Krida
   i2c-multiplexer relay on House0 and a Gw108 GPIO relay on Nolan.
   Today this axis leaks into actor code as the two hard-coded paths in
   `relay.py`; it belongs in the layout (component/actor selection), so
   the relay actor is one body of code with layout-bound actuation.

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
  settled in `zone-relays-and-thermostat-model.md`. [OPS-219](https://linear.app/gridworks/issue/OPS-219) lives here.
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
- Executor write-up: the durable architecture facts found here
  (layout-strategy routing, relay actuation paths, test-layout
  selection) belong in `wiki/gridworks-scada/executor/` as they verify.
