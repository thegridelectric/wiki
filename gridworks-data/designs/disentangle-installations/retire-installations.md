# retire-installations — the tables leave journaldb

Status: Accepted · Pass 1 · Updated 2026-10-17 · Linear: OPS-473

> What this is: the second spoke of the disentangle-installations hub.
> `installations`, `customers` and `installers` are dropped from
> journaldb outright; roles re-key to the TA GNodeId; web-backend and
> the frontend keep working with the Address and Contact sections dark
> until OPS-600.

## Do this next

gridworks-data is merged to `main` (migration `e5a1c2d3f4b6`, `gw_data`
0.5.0 on PyPI). web-backend is on branch `jm/retire-installations` off
`jds/tsdb_api`: `ddeee35` has the four query paths joining the `g_nodes`
projection and the repo's first test suite. **Uncommitted on that branch,
suite green (11 tests), pyright clean, ready to commit as one cluster**
(its changelog entry is written): both snapshots regenerated published-only
from sema `1c52df0`; the gateway seed pinned to `layout.lite` 011 and 012
and the API seed rid of a withdrawn enum; 013 out of both layout unions
(`LayoutLite | LayoutLite011`, versionless = 012) and the gateway's 013
system-mode case gone; the API seed beside its snapshot (the root
`sema_seed_request.yaml` is removed from the index); the regen script
without `--allow-staged`; `tests/test_sema_snapshots_published.py`, which
reads each snapshot's own registry and fails on `main` on any
non-published word. Stage `api/sema`, `gateway/sema`, the two seeds, the
regen script, the test, `api/v2/routers/installation_summaries.py`,
`gateway/state.py`, `pyproject.toml` and `uv.lock`; title: "sema
snapshots: published-only regen for both packages, the API seed beside
its snapshot, and a test that main ships no staging word".

Then the frontend ("Frontend" below), branched off `jds/v2_apis`. Before
cutover: Joe has agreed `jds/tsdb_api` and `jds/v2_apis` merge to `main`
at deploy time; and the TA rows' `display_name` in gnr reads "Beech
TerminalAsset", so rename in gnr or shorten in the frontend. The sema
checkout on the laptop is moved between branches by other sessions; a
regen here runs against `dev` and says which commit it used.

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
page's default sieg loop comes from `LayoutLite.Strategy` instead of
`HardwareLayout.sieg`; the Parameters page starts from its defaults,
since `SpaceheatParameters` is gone and operational params are not on
the bus. `TaGNodeId` joins the `InstallationSummary` type; routes and
pickers stay on `GNodeAlias`.

## Cutover

1. pii-store is seeded and verified (six customers, labels, no
   coordinates).
2. gridworks-data migration applied to journaldb; web-backend and
   frontend deployed from the branches in the same window. web-api2
   deploys web-backend from `jds/tsdb_api`, so that is the branch base
   and the merge target; whether it becomes `main` is decided then.
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
