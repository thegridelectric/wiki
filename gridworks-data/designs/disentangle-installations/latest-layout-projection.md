# latest-layout-projection — one current layout row per house

Status: Accepted · Pass 1 · Updated 2026-10-20 · Linear: OPS-473

> What this is: the third spoke of the disentangle-installations hub. gjk
> keeps the current layout of every terminal asset in one journaldb
> table, `layouts`, written the way it writes the `g_nodes` projection
> from the registry's forest broadcasts. A reader asks "what is this
> house's layout" with a key lookup and never scans the `messages`
> hypertable. The scada's `layout.lite` fills the row today; a new
> bundle word, the layout twin of `g.node.forest`, is the shape the
> terminalasset registry (OPS-471) fills it with later. Decided in a
> grill session 2026-10-20.

## The problem

A scada sends `layout.lite` once per run, when its upstream link first
activates (`gw_spaceheat/actors/scada.py:1384` on `main`,
`:1189` on `legacy`), and otherwise only on a `send.layout` request. A
healthy house can run for months between sends, so there is no time
window a reader may safely put on the query.

Every reader today scans for it. The v2 summaries endpoint
(`gridworks-web-backend/api/v2/routers/installation_summaries.py:96`)
window-partitions `gridworks.messages` by sender and type ordered by
`timestamp` and takes row one; the hypertable's composite index
(`gw_data/db/models/message.py:37`) is on sender, type and
`persisted_at`, so it narrows the scan without serving the ordering.
The realtime gateway keeps its layout in memory and after a restart has
no layout for a house until that scada reconnects. The v2 visualizer
port (OPS-611) needs the same lookup and asked, on 2026-10-20, for the
longest gap it may assume so it can bound the query by time. A time
bound fails on exactly the healthy houses; a current-state table answers
the question without one.

## The pattern: the registry's forest, applied to layouts

The grid-node registry sets the pattern this spoke follows
(`wiki/grid-node-registry/executor/primary.md` "A projection mirrors
truth"). One reusable payload word, `g.node.forest`, with the content,
a `SendTimeMs` and an optional `Proof`, is used three ways: a delta
broadcast after every applied change, a periodic snapshot broadcast
chunked so no message is unbounded, and the response to a request word.
A projection consumes only that interface, holds no authority, upserts
on immutable ids, is healed by the snapshot, and can be deleted and
rebuilt at any time.

Layouts get the same word shape and the same projection discipline. The
registry's half of the pattern (the delta and snapshot broadcasts, the
request word, the read API) belongs to OPS-471. This spoke mints the
bundle word and builds the table and its writer.

## The bundle word

`layout.bundle`, staging, version 000:

- `Layouts`: a list whose items are `oneOf`, by `$ref`, the `layout.lite`
  versions the deployed fleet sends: 011 (`legacy`) and 012
  (`actual-spruce`). `main` sends 013, staging today; it
  joins the `oneOf` once it is finalized and published.
- `SendTimeMs`: the sender's clock when the bundle is assembled, the
  sender-time standard, exactly as on the forest. One bundle-level send
  time serves the guard for every row the bundle writes.
- `Proof`: optional placeholder, as on the forest.
- `TypeName`, `Version`.

No `MessageId`; gjk derives the message id from sender, type and send
time, as it does for the forest. No per-layout time or id inside the
bundle: the layout's own TerminalAsset `GNodeId` is its key and the
bundle's send time is its clock. A second clock or a second key would
have to be reconciled with the first.

The layout words themselves have no clock and no sender field, which is
right: the same instance is sent by the registry and confirmed by the
scada at different times and compares equal.

**The next version** of the bundle widens the `oneOf` to the full layout
words (`gw.house0.layout`, `gw.nolan.layout`, and their successors) when
those are ready to publish, which is after the scada's layouts stop
mutating. The registry and, as its confirmation, the scada send that
version. The bundle stays staging until then.

## The table

`gridworks.layouts` in `gw_data`, one row per terminal asset:

- `ta_g_node_id` (primary key): the TerminalAsset `GNodeId`, the one
  link to a house in this hub, the key the roles table and the registry
  use.
- `terminal_asset_alias`: the alias at the time of the write, the key
  `reading_channels` uses.
- `from_alias`: the sender of the message the payload came from, in the
  form `messages.from_alias` uses. This is how the row remembers whether
  the registry or a scada wrote it.
- `type_name`: the word the payload is an instance of.
- `version`: that word's version.
- `payload` (JSONB): the instance verbatim. Readers decode it through
  their codec exactly as they decode a `messages` row and handle every
  version the bundle's `oneOf` admits.
- `message_id`: the journaled `messages` row it came from.
- `sent_at`: the sender's clock, the do-not-regress guard's memory, as
  on `g_nodes`.
- `persisted_at`.

## The writer

`LayoutLitePersistor` already runs a per-message fan-out (the
reading-channel sync); the upsert is one more step in it, with
`fanout_on_import = False` so persistent-store backfills never touch the
row. The raw message is journaled either way; history stays in
`messages`. Two message shapes write the row:

- **A bare `layout.lite` from a scada**, the whole fleet today. `sent_at`
  is `MessageCreatedMs`. The TA `GNodeId` is looked up in the `g_nodes`
  projection by `<scada alias with .scada replaced by .ta>`; a scada
  whose terminal asset has no `g_nodes` row is logged and skipped, which
  is the right behavior for a projection of registered assets.
- **A `layout.bundle`**, one row per layout it holds, `sent_at` from
  `SendTimeMs`, gated to the registry alias exactly as the forest
  persistor is gated by `registry_alias`. gjk ships published words only
  (`tests/test_sema_snapshot_published.py` fails `main` on a staging
  word), so this writer comes with the bundle's publication; the
  registry-provides rule below is in the projection already, with the
  registry alias unset until then.

The rules the writer applies:

- **The guard compares `sent_at` only.** A write with an older send time
  than the row's is skipped and logged. A lower word version with a
  later send time overwrites a higher one: a house that runs
  `main` for a window and goes back to `actual-spruce`
  sends 013 then 012, and the row follows the house. A version-ordered
  guard would freeze a house at its newest ever version during exactly
  those windows.
- **The registry provides, the scada confirms.** A row the registry
  wrote (`from_alias` is the registry) is never overwritten by a scada
  message; a scada message whose payload differs from that row is logged
  as a mismatch glitch. This is the Open item in the registry design
  about what a scada's confirmation does on a mismatch, answered in the
  journal. Until the registry sends, every row is scada-written and the
  rule has nothing to do.

**Rebuild.** `rebuild-layouts`, a gjk script: the latest-per-sender query
over `messages` for `layout.lite`, upserted through the same persistor
path. Run once after the migration, so the table is full before any
scada reconnects, and again whenever the table is suspect. It is the
registry executor's "a projection can be deleted and rebuilt at any
time", with the journal standing in for the snapshot broadcast until the
registry sends one.

**Precondition for unlimbo houses on the production broker.** gjk's
vendored snapshot has `layout.lite` 001 through 012. The journal keeper
logs a codec failure and drops a message it cannot decode
(`journal_keeper.py:205`), so a 013 send is not journaled and the row
stays at the house's last 011 or 012. The order is: finalize 013,
publish it, regenerate gjk's snapshot, then connect `main`
houses to the production broker.

## Readers

- **The v2 summaries endpoint** joins `layouts` on the TA `GNodeId` and
  drops the `layout.lite` half of its window query. `snapshot.spaceheat`
  keeps a bounded scan: it arrives every few minutes, so a bound is
  honest there, and a latest-snapshot row would be rewritten every few
  minutes for every house with no reader that needs it.
- **The gateway** reads `layouts` once at start through web-backend's
  read-only role, then keeps consuming the live message. The gateway has
  no database connection today; this adds one read at start. The
  alternative, the gateway sending `send.layout` to a scada when a
  snapshot arrives for a house with no layout, would make a dashboard
  process a sender of requests at scadas, the wrong direction for the
  control hierarchy.
- **The v2 visualizer** reads the row by key with no time bound, and
  keeps the lookup behind one function so the registry read API can
  replace it later without touching the plots.

## Build status

Done 2026-10-20, each committed on its own `jm/` branch, suites green:

1. **sema** `jm/layout-bundle` (`c997534`): `layout.bundle/000`, staging, with its
   axiom template and mutation tests.
2. **gw_data** `jm/layouts-projection` (`0b938ca`, merged to `main` by PR): `LayoutSql`, migration
   `b7d2e4f6a8c1`, migration tests, version 0.6.0.
3. **gjk** `jm/layouts-projection` (`d435ff0`): `layouts_projection.py`, the
   `live_only_db_operations` seam on `MessagePersistenceInfo`, the
   persistor hook, `python -m gjk.rebuild_layouts`, eight tests, the pin
   `gw_data>=0.6.0` locked from PyPI. Ready to merge.
4. **web-backend** `jm/retire-installations` (`a174a79`): the summaries
   `LEFT OUTER JOIN layouts` on the TA GNodeId, so `LayoutLite` and
   `SystemMode` are null for a house with no row; the snapshot scan is
   bounded to the last 24 h; the gateway's seed at start
   (`gateway/layouts.py`, `BACKEND_TSDB_URL`, keyed by `from_alias`,
   counted as no message), a test each; `gw_data>=0.6.0`. `main` is
   merged into the branch (`98df82a`); suite green (13 tests), pyright
   clean on the merged tree. Not yet pushed.
5. **web-frontend** `jm/retire-installations` off `jds/v2_apis`,
   uncommitted: the summary type as the API returns it, `LayoutLite`
   typed to the fields read, the Location column gone, Address and
   Contact "Not shown here", Status from the snapshot facts, Hardware
   from the layout, the sieg default from the `sieg-flow` channel, the
   Parameters page on defaults, the gateway key from `GNodeAlias`; the
   `HardwareLayout`, `InstallationContact` and `SpaceheatParameters`
   types deleted. Build green.

## Do this next

1. The dev run (dev-run spoke) passes; then merge the sema, gjk and
   web-backend branches.
2. Deploy: migrate journaldb, run `python -m gjk.rebuild_layouts`, record
   both in the gjk executor as the deploy steps for this migration.

## Open

- None.
