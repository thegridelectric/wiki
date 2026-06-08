# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-journalkeeper` code repo**. The matching git commit (in
`gridworks-journalkeeper`) holds the WHAT (the diff). Each entry's
date and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

<!-- pending commit -->
## 2026-06-07 — Resolve gw_data from PyPI instead of local path source

**What:** Remove the `[tool.uv.sources] gw_data = { path =
"../gridworks-data/" }` override from `pyproject.toml` and relock so
`uv.lock` pins `gw-data 0.3.0` from the PyPI registry. (Branch
`jm/gw-data-from-pypi`.)

**Why:** The local path source resolved gw_data from a sibling checkout,
which works on a dev machine but breaks CI: `tests.yml` runs `uv sync
--all-extras --all-groups --locked`, and in CI only this repo is checked
out — there is no `../gridworks-data`, so the locked sync failed before
tests could run. Now that gw_data is published
(https://pypi.org/project/gw-data/, 0.3.0), the dependency
`gw_data>=0.3.0` resolves from PyPI in both CI and local installs.
Verified: `uv sync --locked` resolves and `pytest tests/` → 13 passed.

## 2026-06-07 — custom persistors: deterministic (uuid5) message ids (`fa08423`, merged `af06ef0` / PR #160)

**What:** Route the `flo.params.house0` and `weather.forecast` custom
persistors through a shared `default_message_id(from_alias, type_name,
time_received)` helper (new, in `message_persistence_info.py`) instead of
`uuid.uuid4()`. Thread `time_received` through the dispatch seam
(`SemaMessagePersistor.persist_message` → `custom_fn(from_alias,
time_received, payload)`) and update both persistors' `persist_vNNN`
signatures accordingly. Adds `tests/test_custom_persistor_idempotency.py`
(hermetic: id determinism per persistor + a dispatch-seam regression guard).

**Why:** `57f5340` added the two custom persistors minting `messages.id`
with `uuid4()`, which dodges the `(timestamp, id)` dedupe and **duplicates
the `messages` row** on any re-import — re-introducing for these two types
the exact bug `7308766` fixed for the default path. The custom persistors
couldn't compute the deterministic id because the dispatch never passed them
`time_received`, hence the seam change. The shared helper means a future
third custom persistor can't reintroduce the gap. No schema/model change, no
sema version bump; the `reading.message_id → messages.id` provenance link is
preserved and now deterministic. See
[`designs/custom-persistor-idempotency.md`](designs/custom-persistor-idempotency.md).

## 2026-06-05 — merge jm idempotent-msg-id + importer-robustness PRs (`0e51f9d`, `968216a`)

**What:** PR #157 (`jm/idempotent-msg-id`) and PR #158
(`jm/importer-robustness`) merged onto the integration branch. No new
source beyond the already-logged feature commits — #157 carries `7308766`
(deterministic uuid5 ids) + `4c437ae` (its test); #158 carries `56d2455`
(empty-date guard + log-and-continue).

**Why:** Recorded here only so the branch HEAD (`968216a`) resolves to a
changelog entry. The substance lives in the three feature-commit entries
below; these are the PR merge bubbles, no behaviour change of their own.

## 2026-06-05 — flo.params.house0 + weather.forecast use the pseudo-channel pattern (`e45f197`)

**What:** Reworked `flo_params_house0_persistor.py` and
`weather_forecast_persistor.py` so both follow one division of labour with
`pseudo_channels.py`: **`LayoutLitePersistor` syncs the registered
pseudo-channels into the DB; every other persistor queries the
pseudo-channels back out of the DB and writes readings against them**
(comment in `pseudo_channels.py` rewritten to state this). Also comments
out `new.command.tree` in `MSG_CREATED_AT_FIELDS_MS` until that type
decodes correctly in SEMA.

**Why:** `57f5340` introduced the two custom persistors but each managed
its own pseudo-channel registration inline, duplicating the channel-sync
logic LayoutLite already owns and risking divergent channel rows. Routing
all registration through LayoutLite and making the readings-persistors
read-only consumers of the channel table makes pseudo-channel identity
single-sourced. `new.command.tree` was emitting under a broken SEMA shape,
so it's parked rather than persisted half-formed.

## 2026-06-05 — Fixed a bad SEMA merge (`95d3b89`)

**What:** Removed two stray lines from `src/gjk/sema/enums/__init__.py`.

**Why:** The sema-snapshot merge folded into `57f5340` left a duplicated /
dangling enum re-export in the generated `__init__.py`. Trimmed by hand to
restore a clean import surface; self-corrects on the next `sema snapshot
build`.

## 2026-06-05 — Custom persistence for flo.params.house0 and weather.forecast (`57f5340`)

**What:** Adds `FloParamsHouse0Persistor` and `WeatherForecastPersistor`
and registers them in `SemaMessagePersistor.custom_persistor_lookup`
(keyed by `target_message_type`), joining `LayoutLitePersistor` and
`ReportEventPersistor`. Both new persistors declare their own
`PseudoChannel`s (e.g. `forecast-ws`, `forecast-oat`) and fan their
payloads out into `gw_data` `readings`. Carries a sema-snapshot regen
(drops the `weather` v000 type, `non.empty.string` / `positive.int.as.str`
formats, and the `market.type.name` enum; adds `gw1.unit/002`) plus an s3
importer date-range widening (`2026-01-09 → 2026-06-01`).

**Why:** `flo.params.house0` and `weather.forecast` carry telemetry that
belongs in `readings` keyed by channel, not as opaque JSON blobs in
`messages` — the default persistor can't shape that, so each needs a custom
handler the way `report.event` already has one. Registering them in
`custom_persistor_lookup` means `all_known_message_types()` now binds and
decodes them automatically. The snapshot regen is the vocabulary catching
up to the types these persistors decode. (The pseudo-channel ownership in
this commit is then cleaned up in `e45f197` above.)

## 2026-05-29 — test deterministic uuid5 message ids (`4c437ae`)

**What:** Add `tests/test_uuid5_message_id.py` + a `tests/data/` fixture (a real
captured `gridworks.ack` S3 object). Asserts `persist_message_default` mints a
deterministic `uuid5` — same `from_alias|type|persisted_ms` → same id (matches
the explicit formula), and a different `persisted_ms` → a different id. Hermetic
(no DB/AWS; persistor built via `__new__`).

**Why:** locks in the idempotency guarantee from `7308766` so a re-imported date
stays a true no-op.

## 2026-05-29 — s3 importer: empty-date guard + log-and-continue (`56d2455`)

**What:** `s3_message_importer.py` — (A) `page.get("Contents", [])` so an
empty/missing date folder no longer `KeyError`s; (B) the per-message failure
path `continue`s instead of `return`ing, so one bad object no longer aborts the
whole run.

**Why:** a `Feb 1 → present` backfill will hit empty days (A) and the occasional
undecodable object (B) — either currently kills the importer mid-run. Lifted from
`jm/s3_hack` as a standalone PR for Joe; the C/E/F items and the
`s3_analytics_import` wrapper are intentionally **not** included.

Adds hermetic `tests/test_s3_message_importer.py` (no AWS/DB): A — a page with
no `Contents` yields nothing (no `KeyError`) + a positive parse; B — driving
`main()` with fakes where every download fails, asserting **both** messages are
attempted (the loop `continue`s rather than `return`ing; pre-fix this would be 1).

## 2026-05-29 — deterministic uuid5 message ids for idempotent re-import (`7308766`)

**What:** In `sema_message_persistor.py`, `persist_message_default` now derives
the message `id` as `uuid5(MESSAGE_ID_NAMESPACE, "{from_alias}|{type}|{persisted_ms}")`
instead of `uuid4()` when there is no `MSG_ID_FIELDS` id; `time_received` is
threaded into the default persistor and the `persist_message` dispatch is
restructured; drop the now-unused `Callable` import.

**Why:** `uuid4()` made re-importing a date **duplicate** rows for any type
without a deterministic id (most types) — the `(id, timestamp)` PK +
`on_conflict_do_nothing` can't dedupe a random id. The S3 filename triple is
unique per object, so `uuid5` over it makes re-import a true no-op. No
schema/model change. Lifted from `jm/s3_hack` as a standalone PR for Joe — the
importer A–F changes and the `s3_analytics_import` wrapper are intentionally
**not** included here.

## 2026-05-29 — fix bug (`b19e8c6`) — export MarketTypeName from sema enums __init__

**What:** Add `from gjk.sema.enums.market_type_name import MarketTypeName` and
`"MarketTypeName"` to `__all__` in `src/gjk/sema/enums/__init__.py`.

**Why:** `49c7cb3` vendored `market_type_name.py` and pointed
`property_format.py`'s lazy import at `gjk.sema.enums`, but the generated
`__init__.py` re-export was dropped during the snapshot restore — so
`from gjk.sema.enums import MarketTypeName` raised `ImportError` the moment a
`market.slot.name` value (e.g. inside an `atn.bid`) was validated. Adding the
re-export unblocks decoding `atn.bid` / any `market.slot.name`. Self-corrects on
a clean `sema snapshot build` (the generator emits the export).

## 2026-05-29 — Add market type name (`49c7cb3`)

**What:** Vendor the `market.type.name` enum into the gjk sema snapshot —
`definitions/enums/market.type.name/000.yaml` + generated
`sema/enums/market_type_name.py` — and point `property_format.py`'s
`_market_type_name_enum()` lazy import at `gjk.sema.enums` (was the un-vendored
`sema.runtime.enums`).

**Why:** The `market.slot.name` format's validator (`is_market_name`) needs the
`MarketTypeName` enum, but that's an axiom/validator dependency the `$ref`
closure can't see (formats can't reference vocabulary), so `sema snapshot
prepare` never pulled it — leaving the snapshot importing a non-existent
`sema.runtime` and crashing the importer (`ModuleNotFoundError`) the moment an
`atn.bid` / `latest.price` (both `$ref` `market.slot.name`) is decoded. Seeding
the enum + fixing the import lets those types decode. Deeper fixes — threading
`import_root` through the format generator, and whether a format may reference an
enum at all — are tracked separately. (An earlier two-mode CLI / uuid5 /
take-everything exploration was reverted and is not part of this commit.)

## 2026-05-28 — add back accidentally deleted s3 message importer

**Why:** `src/gjk/s3_message_importer.py` (Joe's S3 event-store → `gw_data`
backfill importer) was lost when `6f93126` ("drop the legacy named_types
cluster") removed it; it survived on `jds/db_v2`. Restored **verbatim** onto
`jm/db_v2` so it's present in jm's PR in working form *before* any change —
the APIs it depends on (`gjk.sema.SemaCodec`/`SemaType`,
`SemaMessagePersistor.all_known_message_types()` / `persist_message()`) still
resolve on this branch. Deliberately unmodified: a two-mode CLI variant
(explicit date-range + rolling N-day-delayed) will be added as a *separate*
module so Joe's original stays his.

## 2026-05-27 — get ci tests working

**Why:** Stage 2 deleted `Makefile`, but `.github/workflows/tests.yml`
still called `make venv` / `make dev` / `make test` — CI broke on the
first push with `make: *** No rule to make target 'venv'`. Replaced
with `uv sync --all-extras --all-groups --locked` + `uv run pytest`.
The `--all-extras` is load-bearing: gjk's pyproject splits dev deps
across `[project.optional-dependencies]` (where pytest lives) and
`[dependency-groups]`; `--all-groups` alone doesn't pull pytest.
Matches gwwf's working pattern; switched `Install uv` to the official
`astral-sh/setup-uv@v6` action while at it.

## 2026-05-27 — minor script added (point_at_prod_observe.py)

**Why:** Companion to `point_at_dev_hack.py`, narrower scope: bind
catch-all on prod broker, count distinct `type_name`s seen over a
fixed window, exit. Used to take an inventory of what journalkeeper
actually receives on prod — the data behind the
"What gjk stores (and doesn't)" section of
`wiki/gridworks-journalkeeper/executor/primary.md` (3-tier breakdown:
stored / degraded / routing-key-rejected). Same temporary-scaffolding
shape as the dev runner; both promote to a library helper when the
test harness lands (see findings F-005). Generic regex-based
password redaction in the URL log line — never hardcode the secret
as a literal even for masking purposes.

## 2026-05-26 — dev-rabbit integration scaffolding

**Why:** Closing out the Stage 1 refactor surfaced a few discrete
chunks that travel together as "post-port polish + a working dev-test
runner":

- **README + template.env rewrite, Makefile delete.** The old
  README/Makefile assumed pre-0.4.0 gwbase + the in-tree
  `weather_service.py`; the env template pointed at the wrong
  postgres port and used `<PASSWORD>` placeholders inconsistently.
  The new README documents the gw-data-pg + dev-rabbit recipe; the
  env template aligns with gridworks-data's port-5433 default and the
  gw_writer role.
- **`scripts/point_at_dev_hack.py`** — the catch-all dev consumer
  used to verify the 2026-05-26 gwwf→gjk weather flow on dev rabbit.
  Binds catch-all on `_consume_exchange`, wraps `dispatch_message` to
  log + capture each body, try/excepts around persistence so receipt
  stays visible if the persistor breaks. Companion to gwwf's
  hack-fictitious mode (now reverted there; F-002 in
  `research/findings.md`). Promote to a library helper
  (`gjk.testing.catchall_runner`) when the harness lands.
- **`g_node.json`** — synthesized dev identity (`d1.journal.dev.…`).
  Transient: gjk is **not** a GNode actor, so this file exists only
  because gwbase 0.4.x's `ActorBase.__init__` requires GNode identity
  fields on disk. Removed once
  [`wiki/gridworks-base/executor/actors.md`](../gridworks-base/executor/actors.md) §5.5
  lands the `ServiceSettings` split (gwbase 0.5.0). A `_note` field in the JSON itself
  captures the same reason for anyone who finds the file before
  reading the wiki.
- **`sema_seed_request.yaml` → `src/gjk/sema_seed_request.yaml`.**
  Same move as gwwf's: snapshot-adjacent in the package, outside the
  regen-managed directory. Proposed sema-wide convention so consumers
  don't litter their repo roots.
- **`journal_keeper.py` + `tests/test_journal_keeper.py` micro-tweaks**
  — small polish that fell out of the integration test (no behaviour
  change to the live AMQP path).

The integration test that motivated this scaffolding (22 weather
messages flowing gwwf → weathermic_tx → ear_tx → JournalKeeper →
`messages` table) is captured in detail at
`wiki/gridworks-journalkeeper/research/findings.md` (F-001 through
F-007) — including the harness recipe this `point_at_dev_hack` is a
template for.

## 2026-05-26 — drop the legacy named_types cluster (Stage 2)

**Why:** Stage 1 ported `journal_keeper.py` onto `SemaCodec +
SemaMessagePersistor`, which made the entire `gjk.named_types` /
`gjk.old_types` / hand-rolled SQLAlchemy `gjk.models` cluster
unreferenced by the live path. The live path now goes
`journal_keeper → sema_message_persistor → {layout_lite_persistor,
report_event_persistor} → gw_data.db.models (sibling) + gjk.sema.*
(snapshot) + gjk.pseudo_channels + gjk.message_persistence_info +
gjk.config`. Everything else in `src/gjk/` was dead weight — a
mutually-dependent legacy island the live path doesn't touch.

Specifically removed: `codec.py`, `property_format.py`, `utils.py`,
`weather_service.py` (ported to gridworks-weather-forecast),
`journal_keeper_hack.py`, `s3_message_importer.py`, `named_types/`,
`old_types/`, `type_helpers/`, `first_season/`, `models/`, `enums/`.
The sema snapshot under `gjk/sema/` stays — that's the live decode
+ DB-shape vocabulary.

This closes the divergence between the live AMQP path and the
backfill path that Stage 1 started to converge: now both go through
the same sema runtime + sibling-repo SQLAlchemy models, and there's
no second copy of message decoding floating in the codebase.

## 2026-05-25 — Add weather (sema snapshot refresh: weather v000)

**Why:** gjk consumes types via
`SemaMessagePersistor.all_known_message_types()`, so a type doesn't
become consumable here until it lands in gjk's local sema snapshot.
With `weather` v000 in the sema repo (alongside two new format words
`non.empty.string` and `positive.int.as.str`), the snapshot needed
regenerating here so the live AMQP bind picks up `weather` and the
persistor knows how to decode + store it. The incidental changes to
`channel.readings/002`, `gw1.tank.temp.calibration.map/000`, and
`relay.actor.config/002+003` are the regen reaching coherence with
the new format words — sema's reverse-dependency closure refreshes
those so existing types stop hand-rolling what the format word now
expresses. Removing `types/gw1_tank_temp_calibration_map.py`
(hand-impl) was part of the same coherence pass; the regenerated form
supersedes it. No live-path code changed — the actor binds the new
type automatically.

## 2026-05-23 — drop obsolete tests; add JournalKeeper smoke tests

**Why:** Most of the existing test suite (`tests/types/`,
`tests/old_types/`, `tests/enums/`, `tests/test_utils.py`) mirrored
modules that the next stage of this refactor deletes. Keeping them
green would have meant either rewriting them against gridworks-base
0.4.0 (wasted effort, since the source files go shortly) or excluding
them with sentinel markers (noise that has to be cleaned up later).
`src/gjk/sema/tests/test_property_format.py` came out for a different
reason: it's a vendored copy of canonical sema's own format-validation
tests; tests for type definitions belong with the type definitions in
`sema/`, not duplicated in every consumer. `src/gjk/__main__.py` +
`tests/test_main.py` were an empty click stub plus a test that
confirmed the stub exited 0 — neither carries any real contract; a
real actor entry point will land with Stage 5's dev-stack smoke. The
new `tests/test_journal_keeper.py` covers the actually-load-bearing
contract — that `dispatch_message` decodes JSON, routes well-formed
SemaTypes to the persistor, swallows malformed JSON without raising
(the live actor must keep running), and skips degraded SemaTypes.

## 2026-05-23 — port journal_keeper.py to SemaCodec + SemaMessagePersistor

**Why:** The live AMQP path and the S3 backfill path were diverged.
The live path used a hand-maintained 18-handler `if/elif` over
`gjk.named_types`; the backfill path (Joe's `s3_message_importer.py`)
already used `SemaCodec.from_dict` + `SemaMessagePersistor`.
Converging both onto the single parse + persist path eliminates the
divergence, lets new types flow through with zero code edits here
(the persistor's `all_known_message_types()` becomes the only source
of truth for what gets bound and persisted), and matches the
construction shape Joe already established. `ActorBase` rather than
`GridworksActor` is the correct base by definition: journalkeeper is
not a GNode actor on the grid — it doesn't participate in
heartbeat/time-coordinator semantics, just persists what crosses the
broker. The in-file S3 utilities went away because
`s3_message_importer.py` does that job; keeping two copies is the
divergence problem in miniature.

## 2026-05-23 — align pyproject with gridworks-base 0.4.0

**Why:** Foundation for the journal_keeper port. The new pika-native
`ActorBase` / `RoutingEnvelope` shape this refactor consumes ships in
gridworks-base 0.4.0; pinning that here was the prerequisite to
landing the port. 0.4.1 / 0.4.2 are failed CI publish attempts with
no functional change — 0.4.0 is what's actually on PyPI. The
hatchling + py3.12-3.14 + classifier choices mirror what
gridworks-base itself uses, so the two repos compose without
toolchain surprises. Lint / style config changes were intentionally
kept out of this commit so the diff is the minimal functional change
needed to consume the new base.
