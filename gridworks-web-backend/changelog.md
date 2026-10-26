# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-backend` code repo**. The matching git commit (in
`gridworks-web-backend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-25 — price forecast route for the visualizer (`cd793d3`, OPS-623)

**What:** `GET /api/v2/price-forecast/latest`, behind the login dependency,
reads the stopgap price service's latest-forecast route at
`BACKEND_PRICE_FORECAST_URL` (a required setting), decodes
`gw.stopgap.price.forecast` through the vendored snapshot and answers the
word's dict form; a service that answers anything but 200, or cannot be
reached, is a 503. The word joins the api seed. Four route tests with the
fetch stubbed.

**Why:** the visualizer's price panel called the old price service's
visualizer path from the browser, and that path went with the PriceDb box;
the stopgap serves one word on two paths and the browser's call failed as a
NetworkError. The backend serves the word so the browser reads a sema word
from one place, in the plot slot OPS-611 later fills with the as-seen
series from FLO params. The route and the stopgap word retire together with
OPS-437.

## 2026-10-25 — bundle and messages answer in wire form (`f543829`, OPS-542)

**What:** the readings bundle route returns `SyncedReadingsBundle.to_dict()`
and the messages route returns each decoded word's `to_dict()`, so both
answer in sema wire form.

**Why:** the model objects were handed to FastAPI's encoder, which wrote a
null field as `null` where the wire form leaves it out; the browser reads
the words the way every consumer does (OPS-542).

## 2026-10-25 — readers: pick state rows by channel kind (`c4e7ced`, OPS-542)

**What:** the api snapshot vendors `gw.channel.kind`; `ChannelUnit` takes
the row's `channel_type` as `kind` (`ChannelUnit.from_row`), and the csv,
the bundle's series and the bundle's state sequences take a row as a state
machine when its kind is `StateMachine`. `UNIT_VOCABULARIES` goes.

**Why:** a state row was told by its unit type falling outside the two
unit vocabularies, an inference from a column that names something else.
The journal now writes every row's kind from the enum, so the readers read
it. Against `tsdb_tap` (renamed rows), the eight recipe windows answer 200
with the same series, oak's 013 era 32 machines and spruce 04:30–07:30 38,
as before the change, and the csv gives state symbols beside the numeric
columns (OPS-542).

## 2026-10-25 — readings bundle: state sequences from every state row, by enum version (`3ab988b`, OPS-542)

**What:** the bundle's `OperatingStateSequenceList` is built from every
state-machine row of the house with readings in the window, picked by a
unit type outside the unit vocabularies, and each stored position resolves
to its symbol through the row's (enum, version) with `Enum` resolving
through the newest vendored version (`readings_units.state_value`, the
csv's rule). The rows of one name feed one sequence; a change is detected
on the symbol; a row whose enum the snapshot does not vendor, or a position
outside its enum, gives no point. Times are `UtcIso8601Millis`, and a
second change at the same millisecond replaces the first. The enum lookup
by name alone (`SEMA_ENUM_LOOKUP`) goes. The bundle test covers a machine
whose rows span the `Enum` stamp and a version, changing state twice in
one second.

**Why:** the query took rows with `unit = 'Enum'` only, the stamp the
journalkeeper gave state channels before 013; a 013 layout declares each
machine's enum version and the journalkeeper writes it as the row's unit,
so every 013-era state reading was invisible to the browser's state strip
and the heat-pump-on highlights, and a position was read through whatever
version the snapshot vendored newest rather than the row's. Second-level
times failed the word's strictly-increasing axiom on spruce's boot, where
`hp-watch-state` changed twice inside one second. Against `tsdb_tap`,
oak's 013 era answers 32 machines where it answered one, spruce's window
38 (OPS-542).

## 2026-10-24 — readings bundle: knit a channel's rows into one series (`64eef54`, OPS-542)

**What:** the visualizer's bundle (`synced.readings.bundle`) is one series
per channel lineage, as the csv is one column: the `reading_channels` rows
that share a name or a layout channel Id form one series in the newest
row's unit, with every older row's values converted into it. The lineage
and conversion rules move to `api/v2/readings_units.py`, shared by both
routers (the csv's `select_columns` goes there too); each conversion is an
affine map (`Affine`), and the bundle's query joins the readings to a
VALUES table of (row, series, slope, intercept) so a reading is converted
before TimescaleDB's time-weighted average and a lineage's rows average
together. The request picks series by any name a lineage has had, in the
request's order, which replaces the post-query regex match. A state row is
no series: the bundle word labels a series with a unit vocabulary, so a
requested state channel is left out. `tests/test_synced_readings_bundle.py`
covers the flip, a window inside the new era, a rename, a state row and
irreconcilable units; the test app gains the bundle router and the
`timescaledb_toolkit` extension.

**Why:** the bundle grouped by (name, unit, unit type), so a window within
thirty minutes of a unit change (the query reaches back that far for the
average's starting value) got two series of one name and failed the
word's `ChannelDefinitionBijection` axiom with a 500. On the night of
2026-10-23 the three houses each changed unit and changed back, and the
visualizer page erred on every window touching those hours. Run against
`tsdb_tap` with oak's and spruce's readings for that night, all eight
recipe windows answer 200 with one series per name (OPS-542).

## 2026-10-23 — readings csv: use state machine enums, knit together . (`5767309`, PR #22, OPS-618)

**What:** a csv column is one channel across its layout changes: the
`reading_channels` rows that share a name, or share a layout channel Id
(`channel_id`), form one column (`api/v2/readings_units.py`, `lineages`).
A unit change mints a new Id under the same name, a rename keeps the Id
under a new name, and a state-machine pseudo row with no Id joins by name,
so each is one column rather than two: oak's `vdc-relay1` and `vdc-relay`
are one column headed `vdc-relay`. The column is headed by its newest row's
name and in that row's unit, the unit the house sends now, and every older
row's values convert into it (temperatures and flows convert pairwise
through a reference unit; anything else converts only to itself), so
hp-lwt in WaterTempCTimes1000, then CelsiusTimes100, is one column in one
scale. A state channel's cell is the state's symbol, resolved through the
row's (enum name, version); a row stamped "Enum" resolves through the
newest vendored version. A bucket takes the mean of numeric readings and
the last state. A request names a column by any name it has had;
`all-data` is every column. The channel query takes every row of the house
with a reading in the window and the request then picks columns, so a
column asked for by one name comes whole; the readings stream is filtered
by row id. Rows of one column whose units do not reconcile, or a state enum
the snapshot lacks, refuse the request (422) with the pair named. Rows with
telemetry Unknown are left out. The api snapshot vendors every state enum,
all versions. The first-bucket arithmetic uses the signed offset, so a
look-back reading before the requested start stays out of the first row.
`gw-data` 0.8.0 for the `channel_id` column.

**Why:** OPS-618 section 3. layout.lite 013 renames units and channels and
the fleet is flipping between 012 and 013; the csv joined by name and never
read `unit`, so a column across the flip mixed two scales and a rename was
two columns. With `reading_channels.channel_id` the layout's Id is a column,
so the rename's rows are knit by it rather than by a hash of the Id and the
definition.

## 2026-10-22 — api snapshot carries the published synced-readings words; both services import under test (`45739eb`, OPS-473)

The synced-readings router reads `synced.readings.bundle` and
`operating.state.sequence`; both were staging, so the published-only
regen in `a53414d` left them out and the API failed to import on
web-api2 at the retire-installations deploy. The two words are published
(sema `2272873`) and the snapshot is regenerated from that commit. A
new test imports both service entry modules, so a snapshot missing a
word a router names fails the suite rather than the box.

## 2026-10-22 — summaries are gw.house.summary instances through the codec; layouts 011 through 013; published-only snapshots (`3d8a14f`, OPS-473)

The v2 summaries endpoint returns `gw.house.summary` instances in the
word's dict form, in place of a pydantic model of its own: the dashboard
is one app and the backend another, so the boundary is sema. Each house
joins its `house_operating_status` row, nested as `OperatingStatus`, the
word verbatim; `Layout` is the `layouts` row decoded without upgrade and
accepted when it is one of the versions the summary names (011 through
013), else logged and left null. The gateway reads the same three
versions; its status message's `system_mode` is null for a 013 house,
since 013 retires the system mode. Both snapshots are published-only from
sema `36dd41c`. `SystemMode` and `MainAutoState` leave the
response; the one state is the operating status. `Role` is the
`gw.dashboard.role` enum from the roles table, an unknown value granting
`Viewer`. `gw-data` pins
0.7.0 for the status table. Two settings for a laptop run:
`BACKEND_API_PORT` (8000 stays the scada's) and `BACKEND_RABBIT_TLS`
(the dev broker speaks plain AMQP). Verified by the dev run,
`experiments/2026-10-21-disentangle-dev-run/`.

## 2026-10-20 — summaries read the layout from the layouts projection; the gateway seeds it once at start (OPS-473, `a174a79` on `jm/retire-installations`)

The v2 summaries endpoint takes each house's layout from
`gridworks.layouts`, a left join on the TerminalAsset GNodeId, in place
of the window over `messages` that ranked every `layout.lite` ever
journaled. The snapshot half of that window stays and is bounded to the
last day: a snapshot arrives every few minutes, so an older one means the
house is not reporting and `LatestSnapshotTime` is null. `LayoutLite` and
`SystemMode` are null for a house with no layouts row yet, which keeps
the house in the list. The gateway reads every layouts row once at start
through the API's read-only journaldb URL (`BACKEND_TSDB_URL`, now in
`template.env` and the README; the API already required it) and seeds
each house's layout keyed by the row's `from_alias`, the scada alias a
live message's header names, with no message counted; a read failure is
logged and the live `layout.lite` fills the house in later. `gw_data` is
pinned `>=0.6.0`, the version with `LayoutSql`. Tests: the fixture seeds
a layouts row per house, oak's saying Standby against a Heating
`layout.lite` in `messages` and beech's with no `layout.lite` in
`messages` at all, and one test each proves the summaries and the
gateway read the row.

## 2026-10-20 — retiring installations / retiring installations continued (OPS-473, `5de2bc3` + `7507f42` on `jm/retire-installations`): sema snapshots published-only, the API seed beside its snapshot, a test that main ships no staging word

The regen script builds both vendored snapshots, `api/sema` and
`gateway/sema`, from their own seeds (`<package>/sema_seed_request.yaml`,
per sema's template; the API seed moves from the repo root, where
nothing regenerated it) and no longer passes `--allow-staged`: the sema
spec says a staging snapshot runs only against dev brokers, and web-api2
is production. A new test reads each snapshot's own
`definitions/registry.yaml`, where every word and version it ships has a
status, and fails on `main` when one is not published; off `main` it
reports them and skips. Nothing outside the repo is read, so it runs the
same on GitHub, where a pull request is judged by its target branch. Both snapshots are
regenerated from sema `1c52df0`: `layout.lite` 013 and its staging
closure leave (the gateway seed pins 011 and 012; the API seed's
`include_all_versions` skips staging on its own), and the API seed
drops `gw1.local.control.standby.top.state`, an enum sema withdrew on
2026-10-06 that nothing here reads. With 012 the latest published
version, the versionless `LayoutLite` class is 012 in both packages, so
the summaries' and the gateway's layout unions are `LayoutLite |
LayoutLite011`, and the gateway's system-mode read has no 013 case.

## 2026-10-15 — retire installations: the house list is the TerminalAsset rows of g_nodes; no contact, address or params in any response (OPS-473, `ddeee35` on `jm/retire-installations`)

The `installations`, `customers` and `installers` tables leave journaldb
(gridworks-data migration `e5a1c2d3f4b6`, `gw_data` 0.5.0) and roles
re-key to the TerminalAsset GNodeId. Every query that joined
`installations` for the house list now joins the `g_nodes` projection:
the data-access check and the hourly-electricity query resolve the URL's
house alias to the TA row (`<alias>.ta`) and match it against the role's
`ta_g_node_id` (null still means every house); the session's sys-admin
test reads the same column. The v2 summaries endpoint keys each house by
its TA GNodeId beside the alias, takes `display_name` from the TA row
(gnr owns it), and stops returning `address`, `primary_contact`,
`secondary_contact`, `hardware_layout` and `spaceheat_parameters`; the
layout is the latest `layout.lite` from the journal, decoded through the
codec. Operational params are not on the bus (`scada.params` last seen
2026-03), so the Status section loses that field. The household is in the
private customer store; this database hands out read credentials and
must hold nothing about a person. `gw-data` 0.5.0.

## 2026-10-11 — Realtame gateway goes to tap broker (not prod); decoding through its sema snapshot (OPS-586, `817933c`)

The gateway was the last password client on the prod broker, and it
spoke plaintext: AMQP to `hw1-1:5672` as the default login, so the
password and the whole fleet stream crossed the internet unencrypted. It
now connects to the analytics tap over TLS (`amqps://`, port 5671), a
scheme fixed in code so no `.env` can turn it back to plaintext, and the
tap has no plaintext listener anyway. The tap's Let's Encrypt
certificate verifies against the system CA bundle, so the gateway knows
the encrypted session is with the real tap, with no GridWorks CA file or
client certificate to install. It logs in as `web.gateway`, binds `gw.#`
on `ear_tx` with an exclusive `web.gateway.<uuid>` queue, and decodes
every message it keeps through a
vendored sema snapshot (`gw`, `report.event` 002–004, `layout.lite`
011–013, `snapshot.spaceheat` 003) instead of reading dicts. Every payload
decodes at the version it was sent in, so houses on `layout.lite` 011 and
012 keep their `SystemMode`; a box sending 013 shows none until OPS-542
picks up `gw.house.operating.status`. The password has no default any more, and
the user, host, port and vhost come from `.env`. With the gateway off
prod, OPS-578 can close 5672.
