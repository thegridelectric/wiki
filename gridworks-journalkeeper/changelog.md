# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Format:

```
## YYYY-MM-DD — <commit subject line>

**Why:** <the motivation — what problem, constraint, or decision drove
this change; what alternatives were considered; what this unblocks>
```

Newest at the top.

---

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
  [`wiki/gridworks-base/designs/support-non-gnode-actors/service-settings.md`](../gridworks-base/designs/support-non-gnode-actors/service-settings.md)
  lands the `ServiceSettings` split. A `_note` field in the JSON itself
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
