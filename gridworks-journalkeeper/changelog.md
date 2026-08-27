# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-journalkeeper` code repo**. The matching git commit (in
`gridworks-journalkeeper`) holds the WHAT (the diff). Each entry's
date and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-08-25 — bulk load driver and flo.params replay as repo scripts

`1342d23`, on `main` at `9f5664f`. `scripts/s3_bulk_load.sh` drives the eventstore back-fill from a box in the
bucket's region: layouts first over the whole span (so every channel era
exists before a report is read), then every other type forward, each type's
range ending the day before its earliest row already in the DB (queried, not
hand-kept — id-less types are not idempotent across the rabbit and S3
paths). `gridworks.event.problem` is never back-filled (its pre-2026 volume is
a device-fault flap) and `gw.weather.*` is skipped (nothing older than the
weather service). `scripts/replay_flo_params.py` re-derives the
`flo.params.house0` v004–006 pseudo-readings for rows the default path
stored before those persistors existed. Both live in the repo because a
deployed box runs committed code only.

## 2026-08-25 — batched commits for the bulk import

`8a26e9e`, branch `jm/ops-498-load`. A 300-message probe from the laptop put the DB at ~9.5 ms per message with
one commit each — as much as the S3 GET — and a `report.event` persist is
three or four round trips, so against Timescale Cloud the database would be
the whole cost of the prod load. `SemaMessagePersistor.persist_messages`
persists a batch in one transaction (`--batch-size`, default 500, in the
importer); a batch that raises is rolled back and replayed one message at a
time so a single bad payload costs only itself. Channel rows are cached on
the session (`db.info`) for the batch and forgotten after a layout sync,
so a run of reports for one house reads `reading_channels` once. The live
path is unchanged: `persist_message` is one message, one transaction.

## 2026-08-26 — go in parallel

`96c832e` on `main` (bulk load: PASS2_END so several drivers can share the
span). Pass 2a runs at ~14 msg/s on the box with the CPU idle: the cost is the
database's insert work per message, not the network (the journal DB is in
the same region). Weeks are independent, so the lever is running several
drivers at once, each on a disjoint span. `PASS2_END` caps pass 2a (and
skips 2b unless the cap reaches the common floor) so a driver can own,
say, one quarter.

## 2026-08-26 — Merge branch 'jm/ops-498-importer-test-fakes'

`38bd6e5` on `main` (importer test fakes learn the receipt-time-keyed set). `be04325` landed with four importer tests red: the fake persistors in
`test_s3_message_importer.py` predate `dedupable_message_types` /
`RECEIPT_TIME_KEYED_TYPES`, and one test still expected the default type
set to be every known type. Fakes and expectation brought in line; no
code change.

## 2026-08-26 — better de-dupe

`be04325` (message ids from the payload's created time; S3 import refuses
receipt-time-keyed types). The `messages` key is `(timestamp, id)`. A message loaded by the S3 import
dedupes against the row the live path wrote only when both halves come
from the payload. `default_message_id` now derives the uuid5 from the
payload's created time (not the receipt time), so every type with a
created time — `snapshot.spaceheat`, `ticklist.*`, `flo.params.house0`,
`weather.forecast`, `glitch`, `heating.forecast`, `energy.instruction`,
`new.command.tree`, `gw.weather.forecast` — is now path-independent like
`layout.lite` and `report.event`. Types with no created time
(`RECEIPT_TIME_KEYED_TYPES`, pinned by a static test) cannot be made
dedupable by the persistor, so the S3 importer refuses them; the live
path still journals them. Also `--alias-prefix` (driver default `hw1.`)
keeps dev-universe traffic out of the back-fill. Rule for the vocabulary:
a word that wants a dedupable journal row or a safe ack MUST carry a
created time.

## 2026-08-26 — Another walkback MISM

`77c5ef6`, on `main` at `77c5ef6` (vendor sema pico.tank union; PASS2_START for the
driver). Snapshot regenerated from sema with the `pico.tank.module.component.gt`
010/011 union on `layout.lite` 005 and 006 (third load-time mismatch: 14
Dec 11–12 2025 layouts from beech, elm, maple). The driver takes
`PASS2_START` so pass 1 can resume from a later day while pass 2 still
starts at the population start; each mismatch stop no longer costs an
hour of re-listing layouts.

## 2026-08-25 — woops

`fb68393`, on `main` at `1c57bd4` (bulk load: floors from a recorded file, not the
live DB). The driver derived each type's floor (the day before its earliest row) from
the DB at every start. After the first pass had loaded 2024–2025 layouts,
the earliest `layout.lite` row was Dec 2024, so a restart computed a floor
of 2024-11-30 and skipped pass 1 entirely, starting pass 2a with half the
layout eras missing. The floors are a property of the live era, captured
once before any back-fill; `FLOORS=<file>` feeds that capture to every
later run, and the DB query is only used (with a warning) when no file is
given.

## 2026-08-25 — vendor sema 371514d: load-time layout.lite mismatches

`5e10955`, on `main` at `9bc5f19`. Snapshot regenerated from sema `371514d` so the bulk load decodes the two
within-version wire shapes it found on its first pass (`ha1.params:000`
with `MaxEwtF`; `relay.actor.config:002` without `StateType`). The two
real payloads are kept as fixtures with a decode test, since the
one-sample-per-version scan is what let them through. The load driver
takes `START` so a pass can resume from a later day after a fix.

## 2026-08-25 — prepping for data backfill

`7ce2a55`, branch `jm/ops-498-load`. Makes the persistors and the S3
importer safe to run over 2024–2025 windows against a prod DB that already
holds the current era.

**Why the sync guard and era rows.** `ReadingChannelSyncProcess` was
last-writer: every active channel absent from the layout being processed got
deactivated, so a 2024 layout loaded into prod would have retired a house's
live channels and dropped its live readings until the next live layout
re-created them. Now a layout older than the newest `layout.lite` in
`messages` for its TA syncs add-only: nothing active is touched, and every
definition it carries that is not the active one becomes an era row —
`deactivated_date` = the earliest newer layout's time. Channel definitions
do change under one name (`buffer-depth1`, `tank*-depth*`: data channel
`WaterTempCTimes1000` through 2025, derived `FahrenheitX100` from 2026), and
the front end scales by `reading_channels.unit`, so readings must land on the
row with their era's unit. `reading_channel_eras.channel_ids_at` does that
lookup (earliest `deactivated_date` after the report time, else the active
row) and `ReportEventPersistor` uses it.

**Why the tallies.** The importer's summary showed decode outcomes only; a
reading whose channel had no row was a silent `continue`. `RunSummary` now
carries dropped readings per `(TA, channel)`, enum values that hit the sha256
fallback, era rows added, and per-day `(from_alias, type, version)` outcome
counts; `--summary-json` writes it for post-load reconciliation. The S3
client takes `settings.aws.region_name` (an instance-role box has no default
region) and `--workers` prefetches GETs on a thread pool.

Tests: `test_channel_eras_backfill.py` replays real beech samples (2026
layout, 2025 layout, reports from 2024/2025/2026) against a TimescaleDB
container and asserts the active set is untouched, the era row exists, and
each report's readings sit on the row with its unit; hermetic tests cover
`channel_ids_at`, the dropped-readings tally and `RunSummary`.

## 2026-08-25 — Type walk-balk to Oct 13 2024

One squashed commit (on `f6e98ed`) for the whole gjk side of the OPS-498
walk-back: the vendored sema snapshot at sema `134a1b1`, the `version_scan`
dispositions, and persistors for every back-filled version.

**Snapshot.** The seed now lists `layout.lite` 001–012 and `report.event`
000/002/003 explicitly, with `scada.params`, `snapshot.spaceheat`, `report`,
`atn.bid`, `flo.params.house0` via `include_all_versions`, so every accepted
`(type, version)` the S3 eventstore carries from 2024-10-13 — the start of
database population, the first full day of the `report.event` era — to the
2026-01-09 floor decodes.

**version_scan.** `IGNORED_TYPE_NAMES` (the proactor event/ping/ack family,
listed explicitly so authored siblings stay visible) keeps the deferred track
out of the `need` list. `REJECTED_TYPE_VERSIONS` is pair-scoped: the
pre-versioning `gridworks.event.problem <no-version>` shape (`TimeNS`, 21 msgs,
one `ng` house) and `snapshot.spaceheat 000` (11 msgs in one week of Sept–Oct
2024, the pre-channel nested `telemetry.snapshot.spaceheat` with hex enum
symbols and dashed aliases; below the population start, where readings ride
`gt.sh.status`, which JK does not accept). Both surface as `rej`, never
authored.

**Persistors.** `persist_vNNN` for every back-filled version, so readings are
extracted rather than falling to the message-only default path:
`report.event 000` (its `report:001` carries `FsmActionList`, no `StateList`,
so machine-state readings are skipped), `layout.lite 001–006` (all synth-era;
`SynthEraLayout` / `DerivedEraLayout` aliases let the sync methods
type-narrow; v001 has no `SynthChannels`, v002's is optional; only the
reported synth channels `required-energy` / `usable-energy` get rows), and
`flo.params.house0 000–006` (v000 has no `BufferAvailableKwh`, v001 has it
optional — that reading is skipped when absent). The v004–v006 flo messages
already in the DB from Jan–Mar 2026 were stored without pseudo-readings; a
replay script in the loading session fixes that.

## 2026-08-23 — README: sema paragraph in canonical language (`f6e98ed`)

The README's Sema note is rewritten in the sema README's own words —
vocabulary registry, boundary contracts, mechanically verifiable — and adds
the scoping sentence (Sema applies only at system boundaries; it does not
prescribe internals). Converging on sema's self-description instead of a
per-repo paraphrase; same text lands in every snapshot-consuming repo. The vendored snapshot is refreshed so its generated README carries the
same scoping sentence (README-only snapshot diff).

## 2026-08-22 — persist layout.lite v006 (`05d1be6`)

(Also carries the version_scan failure-classification below — squashed in.)

The S3 backfill's first incompatible version, layout.lite v006 (Dec 2025 –
mid-Jan 2026 wire), now exists in sema — this teaches JK to load it. Snapshot
regenerated against sema dev (picks up `LayoutLite006` and the new snapshot
README). v006 stays v006: its forward upgrade is context-dependent (007
redesigned the derived layer), so rather than upgrade, `persist_v006`
handles it natively. The channel sync dispatches on a synth-era version set
(`SYNTH_ERA_LAYOUTS`) rather than pinning v006 — earlier versions (v005,
v004, …) also carry SynthChannels and append there as the backfill walks
earlier. Of a layout's synth channels, only the two that ever appear in
report.event readings — `required-energy` and `usable-energy`
(`REPORTED_SYNTH_CHANNELS`) — get `reading_channels` rows, as
`synth.channel.gt`; the other 12 are unreported intermediates whose rows
would never carry data. The two are present from the beginning of the
archive, so their synth-era readings link from the first load; when a
forward load reaches a 007+ layout the standard mismatch step retires the
synth row and creates the derived one, recording the era transition. Also:
the top-level README gains the standard pointer to the vendored snapshot
and the sema repo.

version_scan grows failure classification + `--save-samples`. A version
that fails to decode means one of two different things: the codec does not
know the version (author a new sema word version) or it does and the real
payload still fails (the sema definition mistranslates the wire — a bug to
raise, not a version to add). The summary conflated them as one NO; it now
reports `need` vs `MISM` (with the decode error) so it states directly which
new versions the backfill needs and raises any known version that stops
translating. `--save-samples <dir>` writes each (type, version)'s first
payload as `<type.name>-<version>.json`, the wire evidence the authoring
step works from.

## 2026-08-22 — add s3 version_scan discovery tool (`1b8cbcf`)

Backfilling the S3 event store back to Sept 2024 needs a map of *which
message versions appear when* before any loading — a version outside the
current sema registry decodes degraded and cannot be stored, so it has to be
authored first. Downloading every object to find out is untenable: the
loader's GETs are sequential and cross-region, ~hours per day. `version_scan`
answers the question cheaply instead. The version lives in the JSON envelope
(`Payload.Version`), so it is read with a plain parse, no codec. Because a
type's version is piecewise-constant in time, per `(type, from_alias)` the
scan **downloads all** objects only when a bucket has fewer than 100 in the
span, and otherwise **bisects** to find the version-change boundaries in
`O(log n)` GETs. It reports a `(type_name, version)` timeline — first/last
seen, count, houses — and decodes one sample of each through the codec to
flag the versions that still need a new sema word version authored.

## 2026-08-19 — add summary log to S3 loader (`efb24a9`)

The S3 backfill's real deliverable when reaching back through history is
*which message versions appear* — the codec decodes today's versions and
returns a degraded object for any it doesn't know, so an old version is
invisible except as one warning line per message. Buried in a multi-GB day
that is unusable. The importer now tallies every message by
`(type_name, version)` — decoded-ok / degraded / parse-failed — and prints a
sorted summary at the end, with the degraded versions called out explicitly
as the ones needing new sema word versions authored before they can load.

## 2026-08-13 — production login is `gjk`, not `ubuntu` (`4764f4a`)

The Hetzner migration (gjk moving off AWS onto its own cpx11) is the
moment to retire the AWS-stock-image `ubuntu` login the unit file
carried forward from journalmaker/journalkeeper's original bring-up.
`service/journalkeeper.service` and the README now say `User=gjk` /
`/home/gjk/gridworks-journalkeeper`, matching the box's own name and
the `gjk aliases` decision below (aliases already read `gjk`, not
`jk`) — one short name for the box, the login, and what people type.

## 2026-08-13 — gjk aliases (`3d3e636`)

The box aliases follow the service's real name: `jkstart`/`jkstop`/
`jkrestart`/`jkstatus`/`jklog` become `gjk*` — the box is gjk, the
fingers type gjk. Spelling only; the box picks them up on its next
pull (the login's `~/.bashrc` sources the repo file).

## 2026-08-13 — tracks weather (`3e5f4b9`)

The weather service's vocabulary is in the journal from its FIRST
broadcast (stand-up-weather-forecast, the JK MVP that gates
populate): the nine `gw.weather.*` words — the two stream words
(observation, forecast), the four record words, and the
create-command round (create.cmd + ack/nack twins) — vendor into the
snapshot and join `all_known_message_types()`, all default-path:
messages-table only, no readings projection yet (that rides the
pseudo-channel word-gate and the table-shape conversation). The
forecast's created_at maps from MessageCreatedMs; the four records
use their own uuid as the message id (a record replayed through the
bus dedupes); the observation and the command round ride the basic
path (the observation carries a claim time, not a message-created
time, by design; CommandHash is sha256, not a uuid). The command
round is journaled deliberately — the journal DB carries every
minting act, not only the eventstore. The S3 importer's type list
gains the same nine for backfill parity.

**Observed-series pseudo-channels on bundle creation.** A
`gw.weather.forecast.bundle.gt` record broadcast is the sign its
embedded observation channels are about to flow (gwwf emits per
bundle), so THAT is when gjk ensures each observed series has its
reading channel: a custom persistor (the bundle leaves
`MSG_ID_FIELDS` — its uuid still becomes the message id) whose
post-insert hook creates one `reading_channels` row per embedded
OBSERVATION channel if absent — name = the dash-rendering of the
channel's LRD Name, display name and unit from the record,
`channel_type = gjk.pseudo`. Forecast channels get no reading
channel: readings stay current-weather-only. The series is
fleet-scoped — it belongs to no terminal asset — so on today's
NOT-NULL table shape `terminal_asset_alias` carries the broadcasting
weather GNode's alias (`hw1.weather`), the owning source, matching
the messages rows' from_alias (the rename that name now begs is
OPS-494; reader migration off the per-TA legacy forecast-oat/-ws
rows stays with the JK table-shape conversation). Idempotent for S3
re-import: create-if-absent; a mismatch on an existing row is
logged, never silently mutated.

Two things surfaced by the work, fixed in the same cluster:

- **Narrowing moves from broker bindings to dispatch.** The per-type
  binding (`#.<type>`) assumed the type token is terminal — wrong
  for radio-channeled broadcasts (radio tail follows the type) and
  direct keys (to-class.to-alias follows it): none of the nine would
  ever have reached gjk's queue. The root cause was routing-key
  grammar re-derived locally as binding strings, so gjk stops doing
  broker-side type narrowing entirely: the queue binds `#` (gjk is a
  tap on the full bus — ~37k msgs/day at present, measured 2026-08-11)
  and the capture set applies at dispatch, read off the PARSED
  envelope gwbase hands it — from_alias, type_name, category, radio
  channel all come from the one object that owns the grammar. A
  post-decode gate covers the legacy `broadcast.*` salvage path
  (decodable ≠ captured: the snapshot deliberately holds vocabulary
  gjk does not persist). The `#` bind also delivers the legacy keys
  the salvage recovers — previously they arrived only by accident of
  the type-terminal match. A second live-AMQP test witnesses both
  real shapes — a radio-tailed observation broadcast and a
  direct-key create command — landing as messages rows with their
  senders' aliases intact. Accepted trade: JK downtime now backlogs
  the whole torrent (bounded later by a queue cap policy if needed —
  safe, because the S3 backfill is the designed recovery path).
- **The snapshot regenerates publication-grade.** The previous
  vendored snapshot contained staging versions; the regen gate now
  refuses them, and gjk is a prod service, so the seed pins
  `layout.lite` to its published set (007–012; 013–015 are staging)
  and `new.command.tree` to 000–001. The journal DB confirms prod
  traffic carries only layout.lite 011/012 — nothing live is
  dropped. `persist_v013` retires with its class; regen rebinding
  makes 012 the current `LayoutLite`.

Also deletes `run_weather.py`, a dead remnant of the spun-out legacy
weather service (it imported a module that no longer exists).

## 2026-08-07 — latest gwbase + service-template mechanisms (aliases, logging) (`6635434`, main via PR #175 `eafe946`)

**What:** on `jm/gwbase-template-update` (off dev — deliberately not the
review-gated pii branch). `gridworks-base>=0.5.8` (0.5.7/0.5.8 are
broker-definitions-only — gnr_ear_tx, debug queue — no API delta).
JournalKeeper stops overwriting the ActorBase-built XDG file logger with
a bare module logger — the actor now logs to
`~/.local/state/gridworks/journalkeeper/log/<alias>.log` in the
bijective gwbase format (an injected logger remains an override seam for
harness scripts). `service/` conforms to the ear/gnr template: one
`bash_aliases` (jkstart/jkstop/jkrestart/jkstatus/jklog — pure spelling,
no logic) replaces the six per-verb scripts + install/uninstall; the
unit keeps its box facts and gains the repo-root-CWD env convention. The
15-minute `journalkeeper-restart` timer pair is retired: it re-started
deliberately stopped services, which fights operator intent — the
ear/gnr posture (Restart=always covers crashes; a manual stop stays
stopped).

**Why:** the gwbase/template increment of the integrate-gwbase-sema
thread (OPS-386): gjk was the last gwbase service on the pre-template
service mechanics, and its actor log went to a logger nobody wired to a
sink.

## 2026-08-06 — registry projection into gw_data: fan-out + bootstrap on 006/002, do-not-regress guard; opaque position ids only (`7edf504`)

One commit on `jm/remove-position-point-pii`, squashed/amended from
seven working commits (2026-07-28 → 2026-08-06); the sub-entries keep
the working narrative, their hashes died in the squashes. Dev-rig
verified end to end on current code (all four legs PASS, `created_at ==
SendTimeMs` exact, ear slice capture; reproducer
`experiments/2026-08-05-registry-projection-rig/`). Paired with
gridworks-data 0.4.0's position_points drop + sent_at — the same-named
branch there; reviewed together. Awaiting that review before merge.

### do-not-regress guard on the forest projection (2026-08-06)

**What:** `project_forest` derives
the forest's send time and passes it through the row upserts: a node or
edge write whose send time is older than the row's stored `sent_at` is
skipped (equal passes — replays stay idempotent); rows written with a
send time record it. Forests without one (000-era) write as before and
leave `sent_at` untouched. Requires gw_data's `sent_at` columns (same
branch there).

**Why:** an out-of-order write can no longer regress the projection —
the concrete race being the one-time bootstrap response landing after a
newer live broadcast. Until now only snapshot anti-entropy healed this;
the guard prevents it. (OPS-386 item 5 precondition #2; sender-time's
"order-aware projection" consumer.)

### position-point lifecycle: consume g.node.gt/006 + forest/002 (2026-08-06)

**What:** Vendored snapshot regen picks up
`g.node.gt/006`, `g.node.forest/002`, `g.node.create.cmd/001`,
`g.node.reparent.cmd/002`; the forest persistor gains `persist_v002`
(SendTimeMs is required in 002, so `created_at` is always the sender's
clock — no None branch). 001 moves to `old_versions`; archives still
decode, and a 001 without a SendTimeMs deliberately cannot auto-upgrade
(`UpgradeRequiresContext` — a send time is never fabricated), landing on
the degraded path rather than acquiring an invented timestamp.

Paired with gridworks-data 0.4.0 (position_points table + FK dropped
there): the fan-out stores the registry's opaque `position_point_id`
**verbatim** — the resolve-against-local-table check and its NULL-out go,
`PositionPointSql` leaves the imports, and the pin bumps to
`gw_data>=0.4.0` (local runs use an editable install until 0.4.0
publishes; `uv run --no-sync`).

**Why:** the gjk consumer strand of the position-point-lifecycle design
(OPS-488) — gw_data's projection reads the same forest the registry now
emits, and holds no position content: plaintext never (no PII in the
analytics database), ciphertext deliberately not either; authority is
evident in the gnr → gjk broadcast and code, and the audit trail lives in
the persistent store.

### forest bootstrap: pull the registry forest via the read API (2026-08-05)

**What:** New `src/gjk/forest_bootstrap.py` — one
`g.node.forest.request` per requested root against gnr's read API
(`POST <api-base>/gnr/g-node-forest-request`); each response decodes
through `SemaCodec` (a 000 forest auto-upgrades) and projects through the
same fan-out live broadcasts use — `GNodeForestPersistor.project_forest`,
the fan-out's now-public seam. Projection only, no `messages` row: message
rows witness bus traffic, and an API pull is not bus traffic. `--api-base`
is required (no default aims a projection at the wrong universe's
registry).

**Why:** strand-1 step 3 of the registry-projection design (OPS-443) —
bootstrap/resync populates the `gw_data` projection before the first
broadcast arrives; the periodic snapshot broadcast remains the ongoing
anti-entropy.

### hack script: re-id January-seeded g_nodes to registry GNodeIds (2026-07-30)

**What:** `scripts/hack_reid_g_nodes.py` —
temporary (delete after it runs in prod). The six old→new id pairs are
hardcoded in the script — the mapping IS the reviewable plan (pairs
verified against the live registry read API 2026-07-30). One transaction
re-points `installations.g_node_id`,
`connectivity_edges.from/to_g_node_id`, and the `g_nodes` primary key.
Dry-run by default; `--execute` applies; refuses if the database does not
match the plan (alias check per row; already-applied rows skip
idempotently). DB from `GJK_DB_URL`.

**Why:** step 1 of the disentangle-installations design (OPS-473) and a
deployment precondition of the forest projection (OPS-386 item #5): the
six January-seeded rows carry the right aliases under wrong ids, and the
first live broadcast would collide on the alias unique constraint.
**Verified:** dry run against the live journaldb shows the six intended
re-ids and no unknowns.

### bind all three transport grammars; pin forest projection to the registry (2026-07-30)

Also: the forest persistor takes a required `registry_alias`
(derived at registration from the service alias — `<universe>.gnr`, one
convention, no second literal) and projects only forests from that
sender; anything else is witnessed into `messages` with a warning, never
projected. from_alias is self-asserted in the routing key until the
broker enforces publish-time alias pinning (the mtls-fis-auth design's
new section); the app-side pin is correct now and harmless then.

**What:** on `jm/forest-snapshot`. `bind_queue` binds each known type
exactly once per gwbase transport grammar: `gw.*.to.*.<token>` (wrapped,
type last), `rjb.*.*.<token>.#` (broadcast — the radio channel keeps its
dots, so it is a multi-segment tail and the type sits mid-key; `#`
matches zero segments, covering channel-less broadcasts too), and
six-segment `rj.*.*.<token>.*.*` (direct). The old single `#.<token>`
binding missed both non-type-last grammars — every channel-keyed
broadcast and every rj direct of a known type sailed past the queue
unbound — while over-matching anything type-last. Spec-exact now: keys
outside the three grammars are the ear's to witness, not jk's to
consume, and the S3 import path replays history without touching live
bindings (pre-OPS-387 `broadcast.*` strays included — the parse-error
hack stays for that path).

**Why:** found live, first try of the dev rig — gnr's forest snapshot
broadcast (radio channel = the forest root) never reached d1.journal;
zero rows, zero messages. The in-code tests could not see this: they
publish with type-last keys. The rig is the experiment the projection
needed before any box deploy.
**Verified:** dev rig end-to-end — snapshot broadcast → gjk projects
nodes + edge into gw_data with SendTimeMs as created_at; suite green.

### g.node.forest fan-out into gw_data: live-only projection, persist_v001 send time (2026-07-29)

**What:** New `g_node_forest_persistor.py`
registered in `custom_persistor_lookup` (`g.node.forest` leaves
`BASIC_MSG_TYPES` — the custom path owns it now): upserts forest nodes
into `gridworks.g_nodes` and edges into `gridworks.connectivity_edges`
via the `additional_db_operations` seam, so raw message + projection
commit in one transaction. Keyed on immutable ids; nodes flush before
edges (FK order). Pure upsert converges: gnr's reparent never touches
edge rows (the tree is the alias prefix) and the alias ledger makes
cross-node alias collisions impossible. Missing-endpoint edges skip with
a warning; edge ids are immutable per (from,to) pair, so a new id
claiming an existing pair is an anomaly — skipped with a warning, never
absorbed; an unresolvable `position_point_id` stores NULL with a warning (the
forest carries the reference, not the point — known gap until a
position-point source exists). Tests: hermetic id-determinism +
registration, plus a live-Timescale scenario (project, replay-idempotent,
alias update, endpoint skip, pair supersede). And the live/replay seam:
`persist_message` takes a required `live` keyword (actor True, S3
importer False); each custom persistor declares `fanout_on_import` —
True on the four history fan-outs, False on the forest projection — so
a persistent-store backfill can never regress the current-state
projection (the raw message is stored either way). Replays welcome
everywhere else. Snapshot regenerated for `g.node.forest/001`
(sender-time first adopter): versionless `GNodeForest` rebinds to 001,
000 moves to `old_versions` (archives still decode), and `persist_v001`
turns `SendTimeMs` — the registry's clock at forest assembly — into the
message's `created_at`.

**Why:** OPS-443 strand 1 step 2 — gw_data's registry projection comes
alive, so analytics and the fleet's consumers read GNodes and wiring from
the same store as everything else.
**Verified:** suite 26 passed (incl. ephemeral-TimescaleDB integration);
ruff check clean.

### updated sema snapshot: adding g.node.forest + g.node.forest.request (2026-07-28)

**What:** Seed
gains `g.node.forest` and `g.node.forest.request` (include_all_versions —
closure pulls `g.node.gt/005`, `connectivity.edge.gt`, the
`base.g.node.class`/`g.node.status` enums, and samples); `layout.lite`
pinned to published `["007","012"]`. Snapshot regenerated from sema `dev`
via `scripts/regen_sema_snapshot.sh`. With 012 now the snapshot's latest,
`LayoutLite` rebinds to it: `layout_lite_012` old-version imports drop from
`pseudo_channels.py` and `layout_lite_persistor.py` (persist_v012 takes
`LayoutLite`; dead `persist_v013` deleted — dispatch is
`getattr(f"persist_v{version}")`). `g.node.forest` joins
`BASIC_MSG_TYPES` (no id/created fields), so gjk binds and persists the
broadcast; `g.node.forest.request` is vendored but deliberately not
registered — it is gjk's outbound bootstrap call, not a captured message.
(The sema snapshot CLI now guards its own checkout — clean-tree refusal
and no repo-tree writes live there, not in this repo's regen script.)

**Why:** first step of the registry-projection strand — gjk can decode the
registry's `g.node.forest` broadcast, and `g.node.forest.request` covers
the bootstrap/resync call against gnr's read API. The layout.lite pin: the
sema staging tier (OPS-445) makes published-only snapshots the default, and
the June snapshot had silently vendored what are now staging words
(layout.lite/013 + staging component versions). Nothing live sends 013 —
prod scada emits 011, spruce's running commit 012; 013 exists only on an
unlanded WIP branch. Widen the pin when 013+ promote.
**Verified:** suite 23 passed; ruff check + format --check clean.

## 2026-08-05 — minor; remove wiki references (`3bfc97b`)

**Why:** Repo files stand alone — `scripts/point_at_dev_hack.py` and
`scripts/point_at_prod_observe.py` cited `wiki/gridworks-journalkeeper`
paths a repo reader cannot follow. The docstrings keep their operative
content (what the hack is, when to remove it); only the private-wiki
pointers go.

## 2026-07-09 — ruff format sweep (`4511242`)

**What:** on `jm/heat-call-rollback`. `ruff format .` over the 13 files that
had drifted (persistors, config, importer, scripts, tests). No semantic
change.

**Why:** `ruff format --check` was failing repo-wide; kept as its own commit
so the reformat noise stays out of the semantic diffs either side of it.
**Verified:** ruff check + format --check clean; suite 23 passed.

## 2026-07-09 — remove unused sqlalchemy import; move heat-call pseudo channel into its own module (`c8927d3`)

**What:** on `jm/heat-call-rollback`. `flo_params_house0_persistor.py` drops
`from sqlalchemy import literal, select`, orphaned since the
pseudo-channel-pattern refactor (`e45f197`) deleted the CTE-based
`insert_reading_with_channel` helpers that used them. New
`zone_heat_call_pseudo_channel.py` holds `ZoneHeatCallPseudoChannel`, now a
working class that bakes in the heat-call channel construction
(`"Heat Call"`, `Gw1Unit.Unitless`) the persistor previously spelled out
inline; `report_event_persistor.get_pseudo_channels` uses it. The broken
original (`__init__` referencing undefined names — the F821s ruff flagged)
is gone.

**Why:** salvages the housekeeping from the reverted heat-call-removal
commit while keeping the working synthesis chain it also deleted: the
`whitewire-pwr` → `heat-call` pseudo channels + threshold derivation stay,
because only spruce reports heat-call natively today and the analytics crew
needs JK to synthesize the pseudo channels for the rest of the fleet until
spruce-unlimbo reaches it. Giving the class its own module keeps the
heat-call shim easy to find (and eventually retire) as one piece. dev was
rewritten: `b25e8a9` (PR #173 merge, carrying the removal as `9caf347`) →
`013aea2` + these two commits; the old tip stays reachable on
`jm/systemd-service`.
**Verified:** ruff check + format --check clean; suite 23 passed.

## 2026-07-09 — run journalkeeper under systemd (`013aea2`)

**What:** on `jm/systemd-service`. New `service/` dir mirroring
`gridworks-scada/service/`: `journalkeeper.service` (simple unit,
`Restart=always`, `ubuntu` @ `/home/ubuntu/gridworks-journalkeeper`,
`.venv` python), `journalkeeper-restart.service` + 15-min `.timer`
(catches manual-stop-and-forget), `install`/`uninstall` symlink scripts,
and `jk*` helper commands. New `run_journal_keeper.py` entrypoint at the
repo root (`start()` is non-blocking, so it joins the consuming thread to
hold the process open). README "Production notes" gains the install steps;
spec spoke: `wiki/gridworks-journalkeeper/executor/operational.md`.

**Why:** the new-line production journalkeeper should run under systemd
from day one rather than inheriting the old deployment's tmux habit
(the legacy-branch JK on journalmaker stays untouched as fallback of
record). **Verified:** `run_journal_keeper.py` ran locally against the
production broker for 90 s and persisted 17 messages (15
`snapshot.spaceheat`, 2 `gridworks.event.problem`) into a local gw_data
postgres; the auto-delete queue cleaned up on disconnect. The unit files
themselves await the production host.

## 2026-07-04 — CI trim: drop redundant cache + setup-python steps; prune dead dependabot watchers (`2aa9b74`)

**What:** `tests.yml` loses the manual `actions/cache` step
(`~/.cache/uv`) and the `actions/setup-python` step — `setup-uv` already owns
both (its `enable-cache: true` caches uv keyed on `uv.lock`; its
`python-version: "3.12"` installs Python), so the workflow was double-caching
and double-provisioning. `dependabot.yml` drops the pip watchers on
`/.github/workflows` and `/docs` — those constraint files don't exist
(hypermodern-cookiecutter legacy); the github-actions and root-pip watchers stay.

**Why:** the dependabot triage (PRs #166–#168) surfaced the redundancy — #166
wanted to bump the cache action, but bumping a redundant step is polishing dead
code; #166 closed, the step removed instead (same pattern as gwbase's
`tests.yml`, which runs on `setup-uv` alone). **Verified:** both YAMLs parse;
suite 23 passed locally; the real proof is the PR's own CI run (it exercises the
trimmed workflow).

## 2026-07-04 — PR #169 merged: import improvements (Joe) (`ec7d107`)

**What:** (Joe, `jds/import-improvements`, commits `cd33623`…`d5b5af0` + the
review-fix commits below) the s3 importer grows a real CLI — `--message-path`
(single message), `--start`/`--end` date ranges, `--message-types` include/`~`
exclude filters, `--dry-run`, `--abort-on-error`, `--db-echo`, `-v` — with
continue-past-failures as the default loop behavior. `report.event` `created_at`
/timestamp timezone fixes; weather-forecast unit scales corrected
(`forecast-oat` ×1000 → ×100, matching FahrenheitX100); zone **heat-call**
channels synthesized from `whitewire-pwr` readings (pseudo-channel + per-site
wattage thresholds); `snapshot.spaceheat`, `new.command.tree`, `atn.bid`
re-enabled for persistence; `layout.lite` 010/011 accept the `ha1.params`
versions the fleet actually shipped (paired with sema PR #32); `gw_data` → 0.3.1.

**Why:** the S3 archive backfill path — the journal ingests the historical
eventstore, including the mixed-version layouts real deployments produced.
Carried caveats: pre-fix `forecast-oat` rows remain ×10 (needs backfill —
`on_conflict_do_nothing` skips them on re-import); the heat-call synthesis has a
known interaction with spruce-unlimbo's layout-declared derived channels, parked
with its fix shape in the registry-projection-and-ear-capture design.
**Verified:** 23 passed on the merged state (gwbase 0.5.6 + gw_data 0.3.1 +
regen'd snapshot); CI green.

## 2026-07-04 — review fixes on PR #169 (`8c2ee05`, `338c295`, `fb9200b`)

Three commits on Joe's `jds/import-improvements` from the PR-169 review:

- **s3 importer: fix default type selection + testable CLI parsing** —
  (a) `str(args.message_types)` turned an omitted flag into the truthy "None", so
  the default date-range run selected `{"None"}` and silently imported nothing;
  now `args.message_types` is tested directly and the include-list strips
  whitespace (matching the `~` exclude branch). (b) `main()` → `main(argv=None)`
  + `parse_args(argv)` so pytest's own args can't leak into the parser (the PR's
  one failing test). Adds `test_omitted_message_types_defaults_to_all_known`,
  `test_message_types_include_list_strips_whitespace`; the continue-past-failure
  test passes explicit argv.
- **re-lock gw-data to registry 0.3.1** — the committed lock pinned
  `{ directory = "../gridworks-data" }` (only builds beside a sibling checkout;
  CI/fresh clones fail `uv sync`); `gw_data` 0.3.1 is on PyPI, so the lock now
  resolves from the registry with pinned hashes.
- **regen sema snapshot from jds/import-fixes** — adopts the regen output over
  the PR's hand-edits to generated `src/gjk/sema/` (2 lines: true
  `last_updated`/`generated_at` stamps). With sema PR #32 as source, the
  vendored widening now reproduces exactly under `scripts/regen_sema_snapshot.sh`
  — the "next regen reverts it" hazard is gone.

**Verified:** full gjk suite 22 passed after each step.

## 2026-07-04 — bump to gwbase 0.5.6 (`560035a`)

**What:** `pyproject.toml` `gridworks-base>=0.5.2` → `>=0.5.6`; relocked.

**Why:** stay on the current published gwbase. 0.5.6 adds the `gnrmic_tx → amq.topic`
broadcast bridge (registry `g.node.forest` broadcasts reach MQTT-native actors) and
renames the definitions artifact `prod_definitions.json` → `hybrid_definitions.json`
(vhost = `<universe>__<run>`); nothing in the 0.5.2→0.5.6 span changes this repo's
consumed API. **Verified:** full suite 21 passed on 0.5.6.

## 2026-06-12 — README: document the docker-gated integration test (`e9086c2`)

**What:** README "Run tests" — note the suite includes a Layer-2 liveness test
(`tests/test_live_amqp.py`) that stands up an ephemeral RabbitMQ + TimescaleDB
via `testcontainers`, boots a real JournalKeeper, and round-trips a message
through the broker into the DB; it needs docker and self-skips otherwise. Show
`uv run pytest -m integration` to run it alone.

**Why:** the README must stand alone for a contributor, and the new integration
test has a non-obvious docker prerequisite (and a self-skip) that the bare
`uv run pytest` line didn't convey.

## 2026-06-12 — Live AMQP liveness test: emitter → broker → JournalKeeper → DB (`603d8a9`)

**What:** Add a docker-backed integration test (`tests/test_live_amqp.py` +
`tests/conftest.py`) that stands up an ephemeral RabbitMQ **and** TimescaleDB
(via `testcontainers`), boots a real `JournalKeeper` actor against them, publishes
a `scada.params` sample to **`amq.topic`** (bridged to `ear_tx` by an
exchange-to-exchange binding), and asserts the message routes through the broker,
is consumed + decoded + persisted, and lands as a `gridworks.messages` row — then
tears both containers down. Adds `testcontainers` to dev deps and registers an
`integration` pytest marker; the fixtures self-skip when docker is unavailable.

**Why:** The unit suite deliberately skips `ActorBase.__init__` (constructs JK via
`__new__`), so nothing exercised the real boot → broker-consume → persist path —
the very path the `ServiceSettings` migration (`0b7c2e0`) changed, and where the
prod data-loss bugs lived. This is the first test that actually runs JournalKeeper
end-to-end against a real broker + real DB (Layer 2 of the layered-test-harness
design), and it doubles as the live verification of the tap-tier migration.
`scada.params` is the fixture because its row id (`message_id`) and timestamp
(`unix_time_ms`) are payload-fixed, so republish-until-landed is an idempotent
no-op (`on_conflict_do_nothing`), sidestepping the bind/consume race.

**What:** `src/gjk/config.py` — `Settings(GNodeSettings)` → `Settings(ServiceSettings)`.
Drop the GNode-only fields JK never used (`g_node_alias`, `g_node_id`,
`world_instance_alias`); make `service_alias: LeftRightDot = "d1.journal"`
first-class (overridable via `GJK_SERVICE_ALIAS`) and add
`service_name = "journalkeeper"` (the XDG path segment for logs/state). Scrub the
now-dead `GJK_G_NODE_PATH` plumbing from `template.env` (replaced with a
`GJK_SERVICE_ALIAS` comment) and from the local `.env`. Delete the tracked
`g_node.json` — a `ServiceSettings` tap has no GNode identity file to load.
Drive-by: fix a `test_journal_keeper.py` docstring that still claimed
`ActorBase.__init__` needs `g_node.json` on disk.

**Why:** JK is a *tap*, not a GNode — its actor was already `ActorBase`, but its
settings still inherited `GNodeSettings`, carrying GNode identity (and a
`g.node.gt.json` file) it never loads usefully. `ServiceSettings` is the gwbase
0.5.x tier for riding the rabbit + sema toolkit without GNode identity. This is
[OPS-386](https://linear.app/gridworks/issue/OPS-386) hub item #2 (`integrate-gwbase-sema-updates`, spoke
`gwbase-tier-migration`) — the last open remainder now that gwbase 0.5.2 is on
PyPI and the snapshot regen has landed. Sheds `g_node.json` entirely; logs land
under `state_dir("journalkeeper")`.

## 2026-06-11 — README: gwbase 0.5.2 + the vendored sema snapshot (`8a08ac8`)

**What:** README intro — note JK runs on `gridworks-base ≥ 0.5.2` and decodes
with a restricted, vendored Sema runtime at `src/gjk/sema`, generated from
`src/gjk/sema_seed_request.yaml` by the Sema snapshot toolchain (regenerate
via `scripts/regen_sema_snapshot.sh`); never hand-edit `src/gjk/sema`.

**Why:** the README predated the gwbase-0.5.x / sema-snapshot work
(`integrate-gwbase-sema-updates`, [OPS-386](https://linear.app/gridworks/issue/OPS-386)) — a new contributor had no pointer
to how JK gets its types or how to refresh them.

## 2026-06-10 — Snapshot: seed `bid` (current) alongside `atn.bid` (`d189ba7`)

**What:** Add `bid` to `src/gjk/sema_seed_request.yaml` and regenerate
`src/gjk/sema`. Pulls in `bid` + its dependency closure — notably the
`market_price_unit` / `market_quantity_unit` enums, **structurally via the bid
deps** (no `market.type.name` hand-patch). JK suite green (20 passed).

**Why:** the snapshot covered only the historical frozen `atn.bid`, so a current
`bid` message decoded as degraded. Seeding both keeps old S3 (`atn.bid`) and
current (`bid`) decoding strict. Per the [OPS-386](https://linear.app/gridworks/issue/OPS-386) design
(`integrate-gwbase-sema-updates`), which calls for both.

## 2026-06-10 — Update snapshot: new.command.tree effective-handle axiom (`fa27f1b`)

**What:** Re-run `scripts/regen_sema_snapshot.sh` against the now-current sema
dev. Tight 3-file delta — `new.command.tree/000.yaml`, the regenerated
`new_command_tree.py` (now enforcing `PrefixClosedHandles` over the effective
handle), and the seed index. Suite green at 20 passed.

**Why:** The prior snapshot regen (`d5d2fc7`) predated sema's
`new.command.tree/000` axiom rewrite (sema `668f00f`). This syncs JK to it so its
vendored copy matches sema dev. First real use of the new `regen_sema_snapshot.sh`
runbook — it worked end-to-end.

## 2026-06-10 — Regenerate sema snapshot from sema dev (`d5d2fc7`)

**What:** Rebuild `src/gjk/sema` cleanly via `sema snapshot prepare <seed>` →
`sema snapshot build --package-name gjk` from current sema dev (now carrying
`gw1.unit` **version 002**), replacing the hand-patched vendored snapshot. Drops
the vendored `tests/` (clears the long-standing `test_property_format.py`
failure), ships the round-trip gate + `samples/`, and removes the
`market.type.name` / `property_format.py` hand-patches. Broad diff (~67 files):
the snapshot was stale, so the regen also syncs JK to the [OPS-380](https://linear.app/gridworks/issue/OPS-380)
canonical-formatting landing, not just the 3 new units. Also adds
`scripts/regen_sema_snapshot.sh` (a one-command runbook wiring the gjk-specific
glue — seed path, `--package-name gjk`, the `output/sema` → `src/gjk/sema`
mirror — around the sema CLI) and a header pointer to it on the seed, so the
recipe isn't rediscovered by archaeology next time.

**Why:** First consumer of the merged sema snapshot-improvement ([OPS-380](https://linear.app/gridworks/issue/OPS-380) / PR
#21); part of [OPS-386](https://linear.app/gridworks/issue/OPS-386). The clean regen needed 3 `gw1.unit` members the persistors
hard-reference at class-definition time (`KilowattHoursX1000`, `DollarsX1000`,
`MilesPerHourX1000`), which had only ever been hand-patched into the old
snapshot. Those are now canonical in sema via the additive `gw1.unit/002`
(replays Joe's `jds/dollarsX1000` schema delta onto dev), so the regen carries
them honestly. **Green:** JK suite `17 passed`, round-trip OK on 35 samples.

## 2026-06-10 — Update gwbase (`828d0dc`)

**What:** Bump the `gridworks-base` dependency `>=0.4.0 → >=0.5.2` and `uv lock`.

**Why:** The `legacy_hack` (`2156a31`) overrides
`ActorBase.on_routing_key_parse_error`, a hook that exists only in gwbase 0.5.2.
Pinning 0.5.2 makes the override bind to the real base hook and lets the
previously-`skipif`-skipped fallback test run — JK suite now 8/8 green against
real gwbase 0.5.2. Independent of the JK sema-snapshot regen ([OPS-386](https://linear.app/gridworks/issue/OPS-386)), which is
deliberately not touched here.

## 2026-06-09 — JournalKeeper legacy_hack: persist pre-gwbase broadcast.* keys (`2156a31`)

**What:** Override `ActorBase.on_routing_key_parse_error` (the new gwbase
parse-error hook) so a routing key carrying a `broadcast` token — the
pre-gwbase LTN's `Dst="broadcast"` shape, which is not a valid GridWorks
envelope and which gwbase's parser raises on — is recognized and persisted
rather than dropped. The source alias comes from the wrapped body's
`Header.Src` (the legacy key has no from-alias slot), with a sentinel
fallback. Refactor the decode→persist path out of `dispatch_message` into a
shared `_persist_body(from_alias, body)` used by both the normal path and the
hack. Add unit tests for the broadcast path, the header-missing fallback, and
(skipped until the gwbase branch installs) the non-broadcast log+drop fallback.

**Why:** Live-testing against prod showed `broadcast.glitch` and
`broadcast.flo-next-hour-plans` silently dropped at the gwbase parse step — the
same data-loss class as the short-form `…to.s` keys, but one step earlier
(token[0] is not even a MessageCategory). The durable fix removes the hack at
the LTN source (scada design 'ltn-sends-gw-wrapped'); this `legacy_hack` is kept
**permanently** so historical and replayed `broadcast.*` data still loads.
Depends on the gridworks-base on_message parse-error hook (design
'must-accept-current-ltn-messages') and merges only once that publishes.

## 2026-06-09 — Fix report.event & layout.lite custom-persistor signatures (`3ac3749`, merged `5cd5199` / PR #162)

**What:** Add the `time_received: datetime` parameter to
`ReportEventPersistor.persist_v002/v003` and
`LayoutLitePersistor.persist_v007…v013` so their signatures match the
dispatch seam, which calls every custom persistor as
`persist_vNNN(from_alias, time_received, payload)`
(`sema_message_persistor.py:152`). The two persistors key their id off the
payload's `message_id`, so they accept `time_received` without using it. Add
a real-signature regression guard
(`test_every_custom_persist_method_accepts_time_received`) that asserts each
real custom persistor's `persist_vNNN` third positional param is
`time_received` (the existing seam test used a `MagicMock`, so it could not
catch un-migrated real signatures). Drive-by: ruff removed an unused
`from typing import List`.

**Why:** PR #160 (`fa08423`, 2026-06-07) threaded `time_received` through the
seam but migrated only the `flo.params.house0` and `weather.forecast`
persistors — `report.event` and `layout.lite` were missed. Every live
`report.event` therefore raised `TypeError: persist_vNNN() takes 3 positional
arguments but 4 were given` and was dropped; because `report.event`'s
`additional_db_operations` is what populates `readings`/`reading_channels`,
the telemetry write path has been broken on `dev` since 2026-06-07. Found by
live-testing the updated JournalKeeper against the production broker into a
fresh local `gw_data` DB. Verified: `pytest tests/` → 17 passed (the 4 new
guard cases fail without this fix).

## 2026-06-07 — Resolve gw_data from PyPI instead of local path source (`3631471`, merged `21e5895` / PR #161)

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
`designs/custom-persistor-idempotency.md` (design since shipped + removed).

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
