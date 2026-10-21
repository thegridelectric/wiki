# retire-installations — the tables leave journaldb

Status: Accepted · Pass 1 · Updated 2026-10-21 · Linear: OPS-473

> What this is: the second spoke of the disentangle-installations hub.
> `installations`, `customers` and `installers` are dropped from
> journaldb outright; roles re-key to the TA GNodeId; web-backend and
> the frontend keep working with the Address and Contact sections dark
> until OPS-600.

## Do this next

The dev run passed (dev-run spoke, 2026-10-21); step 8 of it, the
dashboard by a person, is the one check left. Then the commits, in this
order: web-backend `jm/retire-installations` (the summaries through the
codec as `gw.house.summary`, the api snapshot regenerated from sema
`65f489b` with `--allow-staged`, `BACKEND_API_PORT` and
`BACKEND_RABBIT_TLS`); the frontend branch (its first commit, then the
`gw.house.summary` and `gw.house.operating.status` mirrors and the
Status column); the experiments folder. The merges wait on sema
promoting `gw.house.summary`, `gw.dashboard.role`,
`gw.house.operating.status` and `layout.bundle` (the published-only
tests fail `main` on a staging word), and the operating-status word on
the scada needs the `CreatedMs` rename in the scada's snapshot before
the scada-sent path is live. Open decision: whether gjk's weather
persistors move to what gwwf sends now (channel and bundle 002,
forecast, location and observation 001, four new words) as its own
commit on the gjk branch or its own issue; the seed pins the weather
words until then.

Done so far: gridworks-data merged to `main` (migrations `e5a1c2d3f4b6`
and `d4a7c9e1b2f3`, `gw_data` 0.7.0 on PyPI); gjk `b49c94e` on
`jm/house-status-projection` with the lock at 0.7.0. web-backend `jm/retire-installations`:
`ddeee35` (the four query paths joining the `g_nodes` projection, the
first test suite), `5de2bc3` and `7507f42` (both snapshots
published-only from sema `1c52df0`), `a174a79` (the summaries join on
`layouts`, the gateway seed; recorded in the latest-layout-projection
spoke). Before cutover: Joe has agreed `jds/tsdb_api` and `jds/v2_apis`
merge to `main` at deploy time; the TA rows' `display_name` in gnr
reads "Beech TerminalAsset", so rename in gnr or shorten in the
frontend. The sema checkout on the laptop is moved between branches by
other sessions; a regen here runs against `dev` and says which commit
it used.

## The summary word

Decided 2026-10-21 in a grill on the backend–frontend boundary; this is
the build to do next, in this order.

The dashboard is a GitHub Pages app and the backend a service on a
box, so every response is bytes from one app to another and sema is
mandatory there. The summaries endpoint returns instances of a new
word, and the frontend reads them by the word's field names. The
concept of a system mode is retired with layout.lite 013, so
`SystemMode` and `MainAutoState` leave the summary and the frontend;
the one state field is the house's operating status.

1. **sema.** `gw.dashboard.role` enum, PascalCase values from the roles
   table (`Admin`, `Owner`, `Viewer`).
   `gw.house.operating.status` 000 is staging: rename `UnixMs` to
   `CreatedMs` in place (it records a state change and may later be
   stored and re-sent); it is published when the scada on
   `jm/spruce-unlimbo` also sends it upstream. `gw.house.summary/000`,
   owner `gridworks-energy`: `Role`, `TaGNodeId` (`uuid4.str`),
   `GNodeAlias`, `DisplayName` (nullable), `Layout` (a `oneOf` over
   `layout.lite/011` and `/012`, widened by a version bump as layout
   words arrive; the reader branches on the instance's own `TypeName`
   and `Version`), `OperatingStatus` (`gw.house.operating.status`,
   nullable until the projection has a row), `LatestSnapshotTime`
   (nullable; null means not reporting in the last day),
   `LongestRunningZoneName`, `LongestRunningZoneStartTime` (nullable
   pair from the heat-call readings of the last day), `SendTimeMs`
   (the response is reassembled per request), `TypeName`, `Version`.
   Nothing about a person. `gw.dashboard.role` is a versioned enum,
   `Admin`, `Owner`, `Viewer`, default `Viewer` so an unknown role grants
   the least. Both new words and the status rename are sema `f8a5e50` on
   `jm/house-summary` off `jm/layout-bundle`; promotion follows the dev
   run.
2. **gw_data.** A `house_operating_status` projection table, one row per
   house keyed by the TA GNodeId, with the payload, `created_at` and a
   `source` column (`scada` or `derived`) for operators.
3. **journalkeeper.** The latest-status projection: a house that sends
   the word gets the word; a house whose latest layout is 012 or earlier
   gets a row deduced from `layout.lite` and the latest snapshot
   (`Standby` and `StandbyPosture` from `SystemMode`,
   `SeasonalStorageMode` from the layout, `ServiceMode` Heating,
   `TopState` and `LtnDispatching` from the snapshot's `top.state` and
   `gw1.main.auto.state`, `AcceptsDispatch` true in Auto and not
   Standby, `ScadaBlind` false since main checks no freshness,
   `ValidationState` `UnValidated`, since no deed is in the journal and
   the enum names that as the scada's own value before any deed).
   Retiring main deletes the deduction. Built on gjk
   `jm/house-status-projection` off `jm/layouts-projection`, snapshot
   from sema `f8a5e50` with `--allow-staged`; gw_data table on
   `jm/house-operating-status` (migration `d4a7c9e1b2f3`, 0.7.0). With it, the sema message persistor reads `CreatedMs`,
   else `SendTimeMs`, from any payload before its per-type table (the
   sender-time design, step 3).
4. **web-backend.** The summaries endpoint builds `gw.house.summary`
   instances through the codec, reading the status projection; the
   pydantic model goes.
5. **frontend.** `src/sema/` mirrors `gw.house.summary` and
   `gw.house.operating.status` by hand until the sema TypeScript target
   exists (its own design in `wiki/sema/designs/`); the Houses table and
   the Status section read `Standby`, `ServiceMode` and `TopState` in
   place of the system mode; times are read as `CreatedMs` and
   `SendTimeMs` and nothing else.

The dev run covers the result. The gateway websocket messages (status,
the snapshot envelope, the zone series) stay hand-built dicts for now;
same gap, a later item.

## What survives, and where each field goes

- **The house list** is the TerminalAsset rows of the `g_nodes`
  projection; `display_name` comes from gnr, which owns it as mutable
  presentation. The endpoint keys each house by its TA GNodeId, the
  same id the roles table and the customer store use; the frontend keeps
  routing by alias.
- **Roles** key on the TA GNodeId as a plain column, no foreign key; a
  null still means every house. Forced into this spoke by the foreign
  key to `installations.id`. The table itself moves to web-backend's
  identity database under OPS-600.
- **The Hardware section** reads the latest `layout.lite` from the
  journal messages through the codec. Operational params are not on the
  bus (`scada.params` last journaled 2026-03), so the Status section
  loses its params field.
- **address, customers, installers** are in gridworks-pii (pii-store),
  seeded before this spoke drops them; latitude and longitude are
  deleted.
- **hardware_layout, house_parameters, representation_status,
  alert_status, scada_ip_address, scada_git_commit** are deleted, not
  migrated. The words in the journal are the truth for the first two;
  the fleet drift check already knows the commit every box runs; alert
  state belongs to the alerting rework.

## Web-backend

The URL names a house by its alias; the role names it by its TerminalAsset
GNodeId, the `g_nodes` row at `<alias>.ta`; a null role is every house.
The data-access check and the hourly-electricity query resolve the alias
to that row; the session's sys-admin test is an admin role with a null
`ta_g_node_id`. The v2 summaries endpoint returns, per house: `Role`,
`TaGNodeId`, `GNodeAlias` (the house alias), `DisplayName` (the TA row's,
gnr owns it), `SystemMode`, `MainAutoState`, `LatestSnapshotTime`, the
longest-running zone, and `LayoutLite` (the latest `layout.lite` from the
journal, decoded through the codec). No address, contact, hardware layout
or params field. The v1 `/login` is untouched. The test suite
(`tests/`) seeds two houses and three logins on a testcontainers
TimescaleDB built from the `gw_data` models.

## Frontend

The live dashboard is the `jds/v2_apis` branch, deployed to GitHub Pages
by a hand-run workflow (`main` stops at the v1 routes and a retired
host); it logs in through `/api/v2/sessions`, keys every house by
`GNodeAlias`, and takes the house list from the summaries. The branch
base and merge target is `jds/v2_apis`. What the field change touches
(checked 2026-10-16): the Installations table's Location column
(`Address` city and state) goes; the Information page keeps its four
sections, Address and Contact render "not shown" until OPS-600, Hardware
shows `LayoutLite`, Status keeps the snapshot facts; the Real-time
page's default sieg loop is on when the layout has a `sieg-flow` data
channel (`Strategy` is the house family, `House0` or `Nolan`, and does
not say sieg); the Parameters page starts from its defaults, since
`SpaceheatParameters` is gone and operational params are not on the
bus. `TaGNodeId` joins the `InstallationSummary` type; routes and
pickers stay on `GNodeAlias`; the real-time page's gateway key is the
last segment of `GNodeAlias`, not the display name, so the registry's
display names can read however gnr likes.

Built on web-frontend `jm/retire-installations` off `jds/v2_apis`:
build green, lint unchanged from the branch base.

## Cutover

1. pii-store is seeded and verified (six customers, labels, no
   coordinates).
2. gridworks-data migration applied to journaldb; web-backend and
   frontend deployed from `main` in the same window, after the dev run
   passes and the branches merge (`jds/tsdb_api` is in `main` as of PR
   #18; `jds/v2_apis` merges with the frontend branch).
3. Row-level check: the dashboard lists six houses, every Status and
   Hardware section renders, no endpoint returns a contact or address.
4. Operators look customers up with the CLI from here until
   OPS-600.

## Open

- The summaries take `SystemMode` from `layout.lite`, and the real-time
  page its sieg default; both snapshots here are published-only, so 013
  (staging, with neither `SystemMode` nor a sieg handle) enters only
  when it is promoted. Raised on the spruce-unlimbo layout-lite spoke;
  the summaries code follows whichever way 013 is finalized.
- Side effect of this spoke, 2026-10-17: the same published-only test
  now guards the vendored snapshot in gwbase, journalkeeper,
  fleet-index-service, grid-node-registry (test written, not yet
  committed, on `jm/published-only-snapshot-test`), terminalasset and
  tlayouts; experiments reverted it, since harnesses may ship staging
  words. terminalasset's snapshot fails the test on `dev` with 63
  words, 5 of them withdrawn from sema: that regen is its own issue.
