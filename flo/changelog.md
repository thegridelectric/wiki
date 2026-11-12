# FLO changelog

Status: Accepted · Pass 0 · Updated 2026-11-06

> What this is: one entry per code-repo commit in the FLO domain
> (`optimal-flexibility` for the bruce optimizer; the FLO service repo when
> it exists). Git is the what; this file is the why.

## 2026-11-11 · gridworks-flo · clean up README (`c51e85b`, merged to main in `33ca934`, OPS-514)

The README now follows the repo README pattern, so the executor's
Domain Summary can be copied from it: a plain summary first (what the
FLO works out for a house and where it sits between the bidder and the
market), then what the service speaks, the two ways in, builds and
memory, and deploy, with install, tests and CI last. Three kinds of
sentence went: claims about what the LTN does with an answer, which
belong to the LTN's own docs; transition wording about the LTN leaving
gridworks-scada; and "logged as lost" for a killed build, which the
service answers with a `BuildLost` refusal. `./ci.sh` green.

## 2026-11-09 · gridworks-flo · The FLO service speaks flo.recommendation 001 (`c7945d2`, jm/flo-plot-words, OPS-665)

Snapshot at sema `58a55b4`, the published flo plot words: the seed pins
`flo.recommendation` 001, which brings `flo.tank.store.path` 000 (the
layer count, the three band temperatures and two thermoclines per step,
`EmptyStoreWh`, `FullStoreWh`) and `flo.path.penalties.bruce` 000 (the
three penalty series, the terminal cost, `TerminalCostEmptyStoreUsd`,
`PathCostUsd`) through the closure. bruce fills the fields in its own
repo; the service calls `recommend_bytes` and decodes the reply through
this snapshot (`flos.py`), so no service code names them. alice answers
bare paths; bruce's annotations pass through as bytes.
`scripts/regen_sema_snapshot.sh` builds published-only. OPS-665: the
dashboard draws the store state and the penalties from the journal
instead of re-solving. `./ci.sh` green.

## 2026-11-09 · optimal-flexibility · bruce states the tank store and its penalties beside each path (`d77c29a`, jm/flo-plot-words, OPS-665)

The recommendation moves to `flo.recommendation` 001 (sema `58a55b4`,
published). Beside each path bruce fills a `flo.tank.store.path` and a
`flo.path.penalties.bruce` from one walk of the chosen path
(`path_words`), so the three share the path's step count by
construction. The store word: the tuning's layer count and, per step,
the three band temperatures and the two thermoclines of the state the
step ends in, plus `EmptyStoreWh` and `FullStoreWh`, `compute_energy`
for the whole store at 70 F and at `max_tank_temp_f`, the reference
every state's energy uses. The penalties word: the RSWT, stability and
short-cycle penalties the step's edge was charged, the terminal cost of
the last state, `TerminalCostEmptyStoreUsd` from `terminal_cost_full()`,
and `PathCostUsd`, the sum of the walked edges' costs (electricity at
the request's prices plus the three penalties) plus the last state's
terminal cost. The dashboard had been running two of bruce's formulas in
the browser for the state of charge and the terminal bar's share, and
had no source for the title's total cost; now it reads them.
`test_recommend.py` asserts the path's store energies sit between the two
bounds, the terminal cost is at most the empty-store cost, and the path
cost is at least the penalties plus the terminal cost.
`scripts/regen_sema_snapshot.sh` builds published-only. pytest 12 passed.

## 2026-11-06 — log in local time (`d33e7b1`, jm/log-tz, PR 4, OPS-514)

gridworks-base 0.7.3 renders log timestamps in the service's `log_tz`
with the UTC offset on every line; the flo pins it and its `.env`
template sets `GWFLO_LOG_TZ=America/New_York`, since the people reading
the flo box's logs are in Maine. The stdout stream (journald) takes the
same gwbase line format and zone as the actor's file log, so the two
agree on the hour.

## 2026-11-06 — The FLO answers a request it cannot serve with flo.refusal (`eeaecf6`, jm/subprocess-per-build, PR 3, OPS-514)

Snapshot regenerated from sema `cb422c1` with `flo.refusal` 000 in the
seed. The worker answers `NoTuning` when the Tuning names no optimizer
it runs (or the optimizer is not installed) and `NoMatrix` when bruce
has no cached matrix for the plant shape, matching bruce's plain
`RuntimeError` by text until bruce types it. The actor refuses
`BuildFailed` with the last line of the worker's stderr, `BuildLost`
for a worker killed or timed out, and `PastDeadline` for a
recommendation built later than the reply deadline, which until now
was dropped in silence; a worker's own refusal is passed on. Every
answer goes in the kind the request came, discriminated by TypeName.
Tests: the worker's two refusals (the NoMatrix one real, against the
laptop's missing oak matrix), the actor's five answers with the send
captured, and a refusal round trip over the dev broker's MQTT door.

## 2026-11-06 — One subprocess per build, no process pool (`86a8e6c`, jm/subprocess-per-build, OPS-514)

The build pool is a thread pool that runs each build as `python -m
gwflo.build`, the request on stdin and the reply on stdout; the worker
shares nothing with the service but its pipes. `ProcessPoolExecutor` is
gone. Why: oak's first request to `hw1.flo` (2026-11-06 11:25 ET) was
lost because the pool's POSIX semaphores under `/dev/shm` had been
removed by logind's `RemoveIPC` when the `flo` ssh session that
restarted the unit ended, a failure a laptop run and a box check made
from inside the session never see. The design's "one process per build
that exits" was met by the executor's `max_tasks_per_child` switch,
which still left shared kernel objects behind; a plain subprocess meets
it with none, in a unit or in a container. A worker that exits nonzero
is a refused build logged with its stderr (`BuildRefused`); one killed
by a signal, or still running at `GWFLO_REPLY_DEADLINE_S` and killed
for it, is a lost build (`BuildLost`). The worker claims the stdout
pipe at the descriptor level, so a write to descriptor 1 from Python or
a C library goes to stderr and only the reply reaches the pipe. Tests:
a build answers over the pipes, a raising build is refused with its
stderr, a SIGKILLed worker is lost, a hung worker is killed at the
timeout and lost, only the reply reaches stdout.

## 2026-11-04 · gridworks-flo · The FLO hears flo.params direct over the edge and wrapped on amq.topic, answering in kind (`2a48ef9`)

**Why.** The LTN on gwbase sends `flo.params` as a direct message over
the class fabric and wants the `flo.recommendation` back the same way;
gridworks-base 0.7.2 declares the LeafTransactiveNode and Flo edge pair.
The LTN inside gridworks-scada is still an MQTT client and reaches the
FLO wrapped on `amq.topic`, and the fleet runs that LTN until the move
is complete, so the FLO answers both.

**What.** `FloActor.process_message` notes whether the request came
wrapped (a header) or direct, and `reply` answers in kind: direct over
the Flo-to-LeafTransactiveNode edge to the bidder's alias, or wrapped
across the MQTT seam as before. The `amq.topic` binding stays and its
docstring says it goes once the LTN has fully moved out of
gridworks-scada. The broker test gains the direct round trip: an alice
request published on `ltnmic_tx` with the direct key comes back on the
LTN's class queue with the direct key; the MQTT round trip stays. The
pin moves to gridworks-base 0.7.2, whose definitions have the edges.

## 2026-11-04 · gridworks-flo · the FLO is a GNode; ci.sh is the one gate (`dd2c579`)

**Why.** The LTN finds its optimizer the way it finds its clock: by
walking the registry forest from itself up to the universe root, the
first node with a Flo child names it, else `<universe>.flo`. That needs
the FLO to be a registry row with a durable GNodeId, and it is the same
row the FIS principal binds to. A Service principal with a hand-chosen
`amq.topic` wildcard has no place in the forest.

**What.** `GwfloSettings` subclasses `GNodeSettings` and `FloActor`
subclasses `GridworksActor`, so the actor loads and validates its
`g.node.gt.json` at boot, declares `GwGNodeClass.Flo` and claims it at
connect; its transport class follows from that (gridworks-base 0.7.1). The
tests write a dev identity file; the README and `template.env` describe
the identity and the cert whose CN is the GNodeId. The hw1 cutover is
separate: a `hw1.flo` row in the registry, a GNode principal and cert
minted for it, the box moved to them, the Service principal suspended.
The gate follows sema and gjk: `ci.sh` owns the steps, the workflow is
checkout, uv, the sibling clone and `./ci.sh` with the dev-rabbit
service; `ruff check` runs with `--no-fix` so a lint error fails instead
of being auto-fixed on the runner.

## 2026-11-03 · gridworks-flo · bruce from the sibling checkout, words at 001 (`9be3a85`)

**Why.** The service pinned `bruce-energy` to a tag on the GridWorks fork
of optimal-flexibility while the LTN boxes moved to the editable sibling
checkout of `thdfw/optimal-flexibility` tracking `main` (scada PR #603).
One pattern for every box that runs bruce, and the fork can go.

**What.** `pyproject.toml` sources `bruce-energy` from
`../optimal-flexibility`, editable; the lock resolves only with the
sibling present, so the CI workflow clones it before `uv sync`. The
seed moves to `flo.params/001`, the snapshot regenerates
(`flo.tuning.bruce/001` in the closure) and the test fixtures read the
001 samples: bruce `main` speaks 001 and the service's 000 snapshot
rejected its own broker test's request. gridworks-infra:
`tools/box-deploy.sh flo` pulls the sibling and syncs with the bruce
extra (a plain `uv sync --frozen` drops the extra); the flo box README
records the sibling and the 9-layer oak matrix
(`heat_pump_water_tank_268a5f12`) now beside the 3-layer one.

## 2026-11-02 · optimal-flexibility · the previous plan lines up from the path's second step (`6b0ae89`, fork PR #1, tag `v0.1.0+gw2`)

**Why.** `PreviousOptimalPath` starts at the slot that cleared and the
request that hands it on starts at the slot after, so the path's step 0
is behind the request. `params_from_request` fed the whole path as the
previous plan, and the stability penalty compared the request's first
step against the hour that had already run.

**What.** The previous plan is the path from step 1 on; the store
expected now stays the store at the end of step 0. `test_recommend.py`
pins the alignment on a three-step path.

## 2026-11-02 · gridworks-flo · no deploy key needed (`f747a49`)

The `bruce-energy` git source changes scheme from `ssh://` to `https://`,
same fork, same tag `v0.1.0+gw1`. Both the fork and the upstream
`thdfw/optimal-flexibility` are public, so an anonymous https fetch
installs the extra on any box with no key of any kind.

Why: the ssh scheme forced a deploy key onto every box that installs bruce;
a public repository needs none, and a box with no GitHub key is the norm.

## 2026-11-02 · gridworks-flo · pyright passes without the bruce extra (`c1dc396`)

The five optional `bruce` imports (the dispatch in `flos.py`, the matrix
check in `tests/conftest.py`) take `# pyright: ignore[reportMissingImports]`.
The lint job installs no extras, so bruce is absent there by design and
pyright reported each import unresolved; the tests jobs were already green
on both Pythons. Reproduced in a scratch sync without extras before the
change.

Why: the first green CI run on the branch is the proof the lock resolves
with no sibling checkouts, which the box relies on.

## 2026-11-01 · gridworks-flo · bruce pinned to a tag on the GridWorks fork (`1f5c454`)

`bruce-energy` becomes a git source, `thegridelectric/optimal-flexibility`
at tag `v0.1.0+gw1` (`68029d7`, the service callable; the upstream version
plus a GridWorks suffix, as scada pins the proactor), in place of the
sibling-path source.
uv validates every path source in the lock even when its extra is not
selected, which is how the second CI run died ("Distribution not found at
.../optimal-flexibility"); a git source pinned to a commit resolves without
a fetch until the extra is installed, verified by a sync with ssh disabled.
The README gains the one line for working against a local bruce checkout.

Why: the lock resolves on the runner and on the box alike, and a deploy
installs one exact optimizer. The fork exists because the upstream repo
takes no pushes from GridWorks; branches go to the fork and reach upstream
by pull request.

## 2026-11-01 · gridworks-flo · CI installs gridworks-base from PyPI; published-only snapshot on main (`fbead94`)

`gridworks-base` loses its sibling-path source: 0.6.2 is on PyPI and the
lock pins it there, so the runner's `uv sync --locked` resolves (the first
CI run on main died at that step, "Distribution not found at
.../gridworks-base"). `bruce-energy` keeps the sibling path until the
service callable is on optimal-flexibility main. Adds
`tests/test_sema_snapshot_published.py`, the weather-forecast test with
two paths changed: every word in the vendored snapshot's expanded seed is
looked up in the sema registry and a non-published one fails on `main`,
is reported off it, and skips without a registry; `pyyaml` joins the dev
group for it.

Why: CI green is the gate for a push, and a deploy from `main` must ship
only published vocabulary.

## 2026-11-01 · gridworks-flo · bruce round trip over the dev broker (`a8f52a7`)

The broker test gains the real optimizer: `test_bruce_request_over_mqtt_is_answered`
publishes the sample request at oak's live plant shape (one tank, nine
sensors, 120 gallons; the `heat_pump_water_tank_2b6a76e0` matrix) on the
MQTT door and checks the `flo.recommendation` that comes back has bruce's
name, a first pair at the request's price ceiling, one path per pair and
pairs descending in price. It self-skips without the bruce extra or
without a cached matrix for that shape, so CI stays alice-only. The two
MQTT tests share one `round_trip` helper; `conftest.bruce_can_build`
crosses into bruce as bytes, since the packages share vocabulary and no
Python types.

Why: everything the service does for an LTN is now witnessed on the
laptop's dev broker, alice and bruce both, before the service touches the
prod broker.

## 2026-11-01 · gridworks-flo · The FLO service (`5804378`)

The first commit of `gridworks-flo`: a gwbase Orchestrator of class `Flo`
(`gwflo rabbit`, one unit) whose queue binds `amq.topic` on
`gw.*.to.flo.flo-params`, decodes the request through its own vendored
snapshot (seed: `flo.params` 000, `flo.recommendation` 000), hands the
bytes to a bounded pool of spawn-per-build worker processes
(`GWFLO_WORKERS`), and publishes the reply wrapped on
`gw.<flo>.to.ltn.flo-recommendation`; a reply older than
`GWFLO_REPLY_DEADLINE_S` is dropped. Dispatch is one table keyed by the
Tuning TypeName: alice in the repo (one pair at the ceiling, zero
quantity, a zero-power path), bruce through `bruce.service.recommend`
behind an optional extra so CI and an alice-only deploy install no
optimizer. Tests: alice's axioms, the dispatch table, and the EDD harness
that publishes a request over the dev broker's MQTT door and reads the
recommendation back on the LTN's topic. The unit caps the whole pool
(`MemoryMax=6G`) rather than each worker.

Why: FLO memory leaves the LTN boxes for one measured place, and the LTN's
one callable changes transport only.

## 2026-11-01 · optimal-flexibility · bruce.service.recommend: the FLO boundary callable (`68029d7`)

`bruce.service.recommend(FloParams) -> FloRecommendation` is the one thing
a caller imports from bruce. It spells the request as
`HeatPumpWaterTankParams` (layers = tanks × sensors, gallons = tanks ×
gallons per tank, the tuning word's knobs, the previous path as the
stability penalty's inputs), builds and solves the graph without trimming
it, sweeps the bid with `generate_bid`, and for each pair re-selects the
first-step edge at that pair's price and walks the shortest path onward
for the plan beside it (watts and end-of-step store watt-hours per step).
The first pair sits at the request's own `PriceMaxUsdMwh`; the commit it
reports is the installer's VCS pin, else the checkout's HEAD.
`recommend_bytes` is the same call as bytes in and bytes out, the form
the LTN's child process and the service both use.
`tests/test_recommend.py` checks the round trip and axioms 1 to 5 on the
cached oak matrix.

## 2026-11-01 · optimal-flexibility · Vendor the sema snapshot for the FLO boundary (`4cc9b74`)

Adds bruce's vendored Sema snapshot at `src/bruce/sema`, seeded by
`src/bruce/sema_seed_request.yaml` and regenerated by
`scripts/regen_sema_snapshot.sh`, both instances of sema's two templates in
the gridworks-weather-forecast layout. The seed pins the two words on the
FLO boundary, `flo.params/000` and `flo.recommendation/000`; the closure
brings `flo.optimal.path/000`, `flo.tuning.alice/000`,
`flo.tuning.bruce/000`, `price.quantity.unitless/001`, three enums and ten
formats. Generated from sema `jm/flo-words` at `03a949d`, which drops `MarketSlotName` and `InjectionIsPositive` from the reply: the FLO states no market facts.

Why: the LTN hands the optimizer one serialized sema word and gets one
back, and the optimizer must decode and encode those through sema's
generated classes rather than its own pydantic models, so the same bytes
work when the callable's transport becomes the FLO service's broker
round-trip (OPS-514). This step vendors the vocabulary; the callable that
uses it is OPS-392's PRs to the same repo. No optimizer code changes.
