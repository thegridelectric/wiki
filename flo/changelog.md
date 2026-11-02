# FLO changelog

Status: Accepted · Pass 0 · Updated 2026-11-01

> What this is: one entry per code-repo commit in the FLO domain
> (`optimal-flexibility` for the bruce optimizer; the FLO service repo when
> it exists). Git is the what; this file is the why.

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
