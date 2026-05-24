# Refactor: gridworks-journalkeeper → gridworks-base 0.4.2

Status: Draft · Pass 0 · Updated 2026-05-23

Pre-spec plan capturing the *why* and intended shape of the
journalkeeper-on-base-0.4.2 refactor. The executor spec
(`../executor/primary.md` + sub-specs) is bootstrapped as part of Stage 4
of this plan and will eventually supersede this note.

## Context

`gridworks-journalkeeper` duplicates work now owned elsewhere:

- **Named types** in `src/gjk/named_types/` (45 files) are vestigial: the
  canonical codec is **Sema** and `src/gjk/sema/` already has it. Joe's
  `src/gjk/s3_message_importer.py:197-236` already parses with
  `SemaCodec.from_dict(...)` and persists via `SemaMessagePersistor`. The
  live AMQP path in `journal_keeper.py` (pika-based, since `gwbase` is
  pika-native — the scada side is the MQTT side, via the rabbit MQTT
  plugin) still uses the old per-type-name if/elif over `gjk.named_types`.
  The live path must mirror the import path.
- **DB models** in `src/gjk/models/` are superseded by
  `gw_data.db.models.MessageSql` (Joe's persistor at
  `sema_message_persistor.py:6` already imports from there).
- **Weather:** the legacy `Weather` type
  (`gjk/named_types/weather.py`, `weather_service.py`, `run_weather.py`)
  is **dead code**. `WeatherForecast` and `HeatingForecast` ARE
  Sema-registered (`sema/definitions/registry.yaml`,
  `gjk/sema/types/weather_forecast.py`), but scada **self-generates** them
  via NWS in `gw_spaceheat/actors/derived_generator.py:814-896` and sends
  them to its LTN — no broadcast consumer exists. The
  "weather forecast service" (one Rabbit broadcast channel per channel
  type) is a future design, not an extraction of current code.
- **Build:** pyproject still uses `setuptools.build_meta`, pins
  `gridworks-base>=0.3.5`. Move to hatchling + `uv` and bump to
  `gridworks-base>=0.4.2` (matches base's own toolchain).
- **No `CLAUDE.md`, no `wiki/gridworks-journalkeeper/`** — umbrella
  living-spec convention not bootstrapped here yet (this note starts it).
- **No multi-actor dev orchestration exists** anywhere. The smoke target
  is a scada actor in simulated mode against dev-rabbit; that recipe
  needs writing down and a wiki home.

Outcome: a small, focused journalkeeper that (a) inherits transport from
`gwbase.ActorBase`, (b) parses inbound with `SemaCodec.from_dict(...)`,
(c) persists through `SemaMessagePersistor` into `gw_data`. Plus a
wiki-level dev-stack guide so we can stand up `dev-rabbit +
scada(simulated) + journalkeeper + postgres` with a reusable recipe that
extends toward hundreds-of-actors experiments later.

## User-confirmed choices

- New weather repo will be `gridworks-weather-forecast/` (sibling, package
  `gwwf`), but **spin-out is deferred** — this plan only deletes the
  dead `weather_service.py`/`Weather` legacy code. The real
  WeatherForecastService is green-field (broadcast-per-channel) and gets
  its own plan.
- Branch: continue on `jm/db_v2` (clean, last commit aligned).
- Stage order: **port `journal_keeper.py` first**, then delete cruft only
  if unreferenced, then pyproject, then CLAUDE.md + wiki. 4 commits in
  the repo, plus the wiki bootstrap.
- Auto mode up to (but not including) commits — user lands commits.

## Stage 0 — Set up postgres per `gridworks-data` README (prerequisite)

Before touching journalkeeper code, walk the `gridworks-data/README.md`
setup end-to-end on this machine so Stage 5's smoke test has a schema to
write into. Then suggest README improvements based on the walk-through.

Steps (per `gridworks-data/README.md:1-71`):

1. Pull `timescale/timescaledb-ha:pg18-ts2.25`; run with `5432:5432` (or
   `5433:5432`) and `POSTGRES_PASSWORD`.
2. `psql ... -f src/gw_data/db/scripts/0_server_init.sql` (creates
   `gw_admin`).
3. `cp template.env .env`; fill `GW_DATA_DB_URL`.
4. `uv sync && uv run alembic upgrade head`.
5. `uv run python ./src/gw_data/db/scripts/1_db_seed.py`.
6. **Verify with `psql` which tables exist** — this is the contract Stage 2
   needs (resolves cross-stage open item #1: does `gw_data` cover
   `DataChannelSql` / `NodalHourlyEnergySql` / `ScadaSql` analogues?).

Suggestions for `gridworks-data/README.md` (refine after the actual
walk-through):

- L35, L50: typo `127.0.01` → `127.0.0.1`.
- §1: include a concrete `docker run` example so first-time readers
  don't bounce out to tigerdata's docs for the basics. Keep the link.
- §2: name `template.env`'s location (repo root) explicitly.
- §3: heading is `## 3` while §1, §2 use `###` — make consistent.
- §3: add a "verify" step (`psql -c "\dt"` should show these N tables).
- §3: list what `1_db_seed.py` seeds.
- Consider a top-level "Prerequisites" block (Python ≥ 3.12, Docker,
  psql ≥ 18) — currently scattered across §1 and §2.

Land README edits on a `jm/readme` branch of `gridworks-data`,
separate from the journalkeeper refactor on `jm/db_v2`. Make the
edits directly on the branch; user lands the commit.

## Stage 1 — Port `journal_keeper.py`

Goal: the live AMQP path mirrors the S3 import path. (Both pika/Rabbit-side;
the MQTT-side scada actor produces, journalkeeper consumes off the broker
via AMQP.)

Pattern: `src/gjk/s3_message_importer.py:197-236` (dispatch shape) +
`src/gjk/sema_message_persistor.py:124-168` (persistor handoff).

Shape:

- `JournalKeeper(ActorBase)` keeps inheriting `gwbase.actor_base.ActorBase`.
  Journalkeeper is **not** a GridWorks actor (no GNode role, no
  heartbeat/time participation), so `GridworksActor` is the wrong base —
  `ActorBase` is correct by definition, not a deferred choice.
- `__init__(settings, codec: SemaCodec, logger)` constructs
  `SemaMessagePersistor(settings, codec, logger)` and stashes both. Reuse
  the same `SemaCodec` factory as `s3_message_importer`.
- `local_rabbit_startup()`: replace 18 hard-coded bindings with a loop
  over `self.persistor.all_known_message_types()`
  (`sema_message_persistor.py:80`). New types added to the persistor's
  table flow through automatically.
- Inbound handler: drop the giant if/elif; do
  `payload = self.codec.from_dict(payload_dict, auto_upgrade=False,
  mode="degraded")` then
  `self.persistor.persist_message(from_alias, time_received, payload)`.
  Errors log + continue (live path differs from the importer, which
  halts).
- Delete S3-import utilities in `journal_keeper.py` (≈ lines 481-546) —
  superseded by `s3_message_importer.py`.

Touched: `src/gjk/journal_keeper.py` (heavy rewrite), `src/gjk/__main__.py`
(verify wiring).

## Stage 2 — Delete cruft (only what's now unreferenced)

After Stage 1, sweep with `grep` + `ruff --select F401`. Delete only
modules with zero remaining importers:

- `src/gjk/named_types/` — all 45 files.
- `src/gjk/old_types/` — confirmed legacy.
- `src/gjk/models/` — `MessageSql` superseded; **verify `gw_data` covers
  `DataChannelSql` / `NodalHourlyEnergySql` / `ScadaSql`** before
  deleting (flag any gap).
- `src/gjk/codec.py` (`pyd_to_sql`) — deletes with old models.
- `src/gjk/weather_service.py`, `run_weather.py`, weather tests — delete
  outright; commit message records why (deferred spin-out + dead path).
- `gjk/named_types/weather.py` — legacy `Weather` not in Sema, unused;
  deletes with `named_types/`.
- `alembic/` + `alembic.ini` — **ASK before deletion**; DB now owned by
  `gridworks-data`.
- Tests under `tests/types/`, `tests/old_types/`, `tests/enums/` — drop
  those covering deleted modules; keep enum tests if `src/gjk/enums/`
  survives (likely referenced by `sema/types/`).

Verify: `ruff`, `mypy --strict`, `pytest` green; `uv sync` clean;
`import gjk` from a scratch venv only loads survivors.

## Stage order revision (2026-05-23)

User reordered: tooling alignment + a green-tests baseline come before
deletion. **New order: 3 → 1 → 3b → 2 → 4 → 5 → 6.** Stage 1 (the
journal_keeper port) has to land before Stage 3b can be meaningfully
green, because the current `journal_keeper.py` imports `named_types/`
and `models/` — surviving-code green isn't reachable until those
imports go away. Stage 3b's job is then to verify the survivors are
actually green before Stage 2 starts deleting; deletion lands as a
no-op against the test suite.

## Stage 3 — Pyproject + tooling alignment

- `[build-system]` → `hatchling.build`.
- `requires-python = ">=3.12,<3.14"` (matches base).
- Bump `gridworks-base>=0.4.0`. (0.4.1 / 0.4.2 were failed CI publish
  attempts with no functional change; 0.4.0 is what's on PyPI.)
- `gw_data` dep: stay on local path during umbrella dev; confirm before
  pinning a published version.
- `[tool.mypy] strict = true`, `[tool.ruff]` mirroring base.
- Update `.pre-commit-config.yaml` to match base.
- Regenerate `uv.lock`.
- Drop deps that go with deleted modules (`psycopg2-binary`, `requests`,
  `pytz` if only used by deletions).
- `.github/workflows/` mirrors base CI: ruff + mypy + pytest on py3.12
  and py3.13 with `ghcr.io/thegridelectric/dev-rabbit:latest`.

Verify: `uv sync && uv run pytest && uv run mypy --strict src && uv run
ruff check`. Push branch, watch CI.

## Stage 3b — Pytest running

Goal: pytest collects and the survivor tests pass. Mypy and ruff
cleanup are deliberately deferred to **after** Stage 2 — strict-mypy on
code that's about to be deleted is wasted effort, and trying to lint
green inside doomed modules has the same problem.

Survivor scope (the only thing that needs to import cleanly + test
green right now):

- `src/gjk/`: `__init__.py`, `__main__.py`, `config.py`, `journal_keeper.py`
  (post-Stage-1 shape), `layout_lite_persistor.py`,
  `message_persistence_info.py`, `property_format.py`,
  `report_event_persistor.py`, `s3_message_importer.py`,
  `sema_message_persistor.py`, `utils.py`, `sema/**`, `enums/**`.
- `tests/`: `test_main.py`, `test_utils.py`, `tests/enums/**` (keep if
  `src/gjk/enums/` survives).

Targets:

- `uv run pytest` → collects without errors and the surviving tests
  pass.

If the doomed tests under `tests/types/` and `tests/old_types/` block
collection (they import doomed `gjk.named_types`/`gjk.old_types` modules
that may temporarily break post-Stage-1), point pytest at the survivor
set via `[tool.pytest.ini_options] testpaths = [...]` rather than fixing
the doomed tests. Stage 2 then deletes both the doomed source and the
doomed test dirs together.

**Mypy and ruff** are run post-Stage-2 (or in a new Stage 3c) once the
doomed paths are gone and there's nothing distorting the picture.

## Stage 4 — CLAUDE.md + wiki bootstrap for journalkeeper

Repo `CLAUDE.md`: one-paragraph "what this is"; pointers to
gridworks-base (transport), gw_data (schema), `src/gjk/sema/` (codec);
working-with-Claude protocol pointer to `wiki/gridworks-journalkeeper/`
and umbrella `wiki/GridWorks_CLAUDE.md`.

`wiki/gridworks-journalkeeper/` at acceptable-minimum:

- `executor/primary.md` — overview, invariants ("persistence boundary is
  `gw_data.db.models.MessageSql`"; "inbound parsing is `SemaCodec` — no
  hand-dispatch"), glossary, TOC. Status: Draft · Pass 0.
- `executor/journal-keeper.md` — sub-spec of the actor: routing table
  from `persistor.all_known_message_types()`, dispatch via
  `codec.from_dict`, persistor handoff.
- `executor/s3-import.md` — sub-spec for Joe's importer.
- `research/refactor-to-base-0.4.2.md` — **this file**, preserved as the
  pre-spec rationale.
- `changelog.md` — first entries seeded with `<!-- pending commit -->`
  markers.

## Stage 5 — Production-broker integration test (reframed 2026-05-24)

**Reframed:** the primary integration check is **pointing
journalkeeper at the production rabbit broker** and seeing if it just
works — real volume, real type variety, real edge cases. The old
"spin up scada-simulated locally" recipe is the fallback for
offline development, not the primary smoke target.

### 5a observations (2026-05-24)

- **Connected cleanly** to `amqp://hw1-1.electricity.works:5672/hw1__1`
  with prod creds. Queue auto-deletes on Ctrl-C as expected.
- **Across two runs (40s + 5min):** 120 raw bytes captured, 81
  persisted to local `messages`. Type breakdown: snapshot.spaceheat
  ×66, report.event ×6, gridworks.event.problem ×6, power.watts ×2.
  Degraded (not persisted, not Sema-registered): gridworks.ack ×22+,
  slow.contract.heartbeat ×10+.
- **All captures from `*.scada` aliases.** No LTN-aliased captures
  even though the broker has an `amq.topic → ear_tx` exchange-binding
  (routing key `#`) — the LTN publishes on `amq.topic` and the binding
  should fan to ear_tx. Either LTN was quiet in the window, or LTN
  traffic uses routing classes that ActorBase drops (see F-007 below).
- **Zero weather messages caught** despite the operator-reported
  10-minute cadence and runs spanning the expected window. Root cause
  surfaced (and filed as F-007 in
  `../../gridworks-base/research/findings.md`): ActorBase's
  `RoutingClass` enum lacks the short forms production actually uses
  (`ws`, `s`); every `rjb.hw1-isone-ws.ws.weather` and
  `gw.<scada>.to.s.*` message is dropped at parse. 48 such drops in
  the 5-minute window.
- **Other broker observations:** production already has a journalkeeper
  running (`hw1.isone.journal-F6c6`) with narrow bindings
  (`#.atn-bid`, `#.energy-instruction`, …), not `#`. We did not
  conflict — fan-out gives each consumer its own copy. The broker
  fabric is richer than expected: 11 `<class>_tx` exchanges (plus
  `_mic` siblings) all bound `#` → `ear_tx`, plus `amq.topic` → `ear_tx`.
  ear_tx really is the union audit tap.

### 5a — Point at prod (next action)

- One-off untracked `scripts/point_at_prod.py` in the journalkeeper
  repo. Constructs `Settings()` + `SemaCodec()` +
  `JournalKeeper(settings, codec, logger)`, then
  **monkey-patches `local_rabbit_startup`** to bind a single narrow
  routing key (`#.report-event` first) and **monkey-patches
  `dispatch_message`** to also dump each consumed `body: bytes`
  into `./captured/` as a free fixture seed.
- `.env` (gitignored) supplies `GJK_RABBIT__URL` (prod creds, plain
  `amqp://` — prod is not TLS per beech scada's config) and
  `GJK_DB_URL` pointing at local `gw-data-pg`.
- `g_node.json` (gitignored) holds a synthesized journalkeeper
  identity — broker auth is via URL creds, not GNode identity.
- Queue is auto-delete (`actor_base.py:361`), so Ctrl-C cleans up;
  abnormal exit doesn't leave a queue accumulating prod traffic.
- Start narrow, widen as it proves out
  (`#.report-event` → `#.snapshot-spaceheat` → `#.power-watts` → `#.*`).

### 5b — Design a repeatable test from observation

Two paths, pick after we've seen real traffic:

- **Sample replay** — feed captured bytes through `dispatch_message`,
  assert parse + persist. Fast, deterministic, CI-friendly. Likely
  sufficient: journalkeeper is a pure consumer with no time-ordered
  or stateful behavior, so a representative byte snapshot covers the
  contract. Risk: snapshot ages as new types appear.
- **Spin up scada in test** — boots dev-rabbit + scada-simulated +
  journalkeeper, asserts messages flow. Catches integration drift
  but heavy (3 containers), slow, prone to flake. Defer unless 5a
  reveals behavior-over-time matters (ordering, batching,
  idempotency under bursts).

The captured fixtures from 5a are the input either way — for replay
they ARE the test, for scada-in-test they're a known-good comparison
set.

### 5c — Dev-stack guide (still wanted, in parallel)

The cross-repo "how to run things locally" story still belongs in a
new `wiki/dev-stack/` domain — broker recipes, MQTT plugin nuance,
scada-simulated as the offline alternative. Doesn't gate on 5a.

The original scada-simulated recipe (was 5a, now 5c) as a fallback:

1. Boot dev-rabbit: `gridworks-base/arm.sh` — single broker from
   `for_docker/{arch}.yml`.
2. Enable MQTT plugin (one-time; scada uses MQTT, broker is AMQP by
   default): `docker exec gw-dev-rabbit rabbitmq-plugins enable
   rabbitmq_mqtt && docker exec gw-dev-rabbit rabbitmqctl restart_app`.
3. Boot postgres for `gw_data`.
4. Terminal A: journalkeeper against the dev broker.
5. Terminal B: `SCADA_IS_SIMULATED=true gws run` (after
   `./tools/mkenv.sh`).
6. Watch journalkeeper logs; assert rows in `messages`.

Living artifact: a new wiki domain `wiki/dev-stack/`, because the
orchestration is cross-repo and the umbrella convention forbids repo
READMEs from referencing the wiki.

`wiki/dev-stack/`:

- `primary.md` — dev stack topology (one broker, N actors, optional
  postgres), one-broker-many-actors invariant, MQTT-vs-AMQP plugin
  nuance, layout conventions.
- `recipes/single-broker.md` — extracted from `for_docker/`.
- `recipes/scada-simulated.md` — the recipe above.
- `recipes/journalkeeper-persisting.md` — counterpart.
- `recipes/smoke-test.md` — combined three-way smoke.
- `research/scale-strategy.md` — see Stage 6.

`wiki/README.md` domain table: add `dev-stack`.

Repo READMEs: touched only to ensure self-contained "run me" sections
name the right entry points; do not reference the wiki.

## Stage 6 — Scale strategy (1 → 10 → 100s of actors)

Don't build for hundreds now; do write the trajectory down so we don't
accumulate dev-stack debt that has to be undone.
`wiki/dev-stack/research/scale-strategy.md` records:

- **Today (1-3 actors):** terminals + venvs + `gws run --is-simulated`.
  No orchestration. Sufficient for the journalkeeper refactor smoke.
- **Tier 1 (1-10 actors, near-term):** extend `for_docker/{arch}.yml`
  to multi-service compose: rabbit + postgres + scada(s) +
  journalkeeper. Wrap with Makefile/script. Each actor still a full
  venv process.
- **Tier 2 (10-50 actors, mid-term):** container per actor type,
  parameterised by layout file + identity env vars. Validate
  dev-rabbit memory; consider non-baked broker.
- **Tier 3 (100s of actors, far-term):** open question. Candidates:
  (a) k3s/k8s + rabbit cluster; (b) Nomad; (c) custom Python supervisor
  pool with process-per-actor. Resurrect or discard
  `gridworks-infra/`'s dormant Terraform skeleton. Decision deferred —
  the doc records candidates + criteria (process isolation needs,
  broker fan-out limits, experiment reproducibility).

This stage produces only a doc, not infrastructure. Build Tier 1 only
when the journalkeeper refactor needs it (it doesn't, today).

## Cross-stage open items

1. `gw_data` schema coverage for `DataChannelSql` / `NodalHourlyEnergySql`
   / `ScadaSql` analogues.
2. `SemaCodec` type discovery mechanism (entry-points vs startup
   register) — read `src/gjk/sema/codec.py` before Stage 1.
3. `alembic/` ownership — confirm with user before deletion.
4. Whether `src/gjk/enums/` stays (likely yes, referenced by
   `sema/types/`).

## End-to-end verification

1. `uv sync` clean in journalkeeper, gridworks-data, gridworks-scada,
   gridworks-base.
2. Run the Stage 5 recipe; observe persistence end-to-end.
3. `pytest && mypy --strict && ruff check` in journalkeeper.
4. `s3_message_importer` still works against a small date window.
5. Stage 4's wiki passes umbrella conventions (status stamps, ≤1000
   lines/doc, no repo README references the wiki).
