# gridworks-web-backend — rebuild spec

Status: Draft · Pass 0 · Updated 2026-10-24

> Faithful-rebuild hub for gridworks-web-backend: the two services behind
> the fleet web page, the read API over the journal DB and the realtime
> gateway from the fleet broker. Read this hub, then the spoke for the
> concern being touched.

## What the repo is

Two processes from one checkout, run as systemd units (`deploy/`) on the
web-api2 box (gridworks-infra `platform-inventory.md`), both behind nginx:

- **`api/`** (`python -m api`, port 8000): the public read-only façade
  over the journal DB, read as `gw_visualizer`. Hourly rollups, channel
  readings, installation summaries and the CSV export the web-frontend
  draws from.
- **`gateway/`** (`python -m gateway`, port 8100): the realtime WebSocket
  gateway, a very small part of the backend. Its one job is the live
  system graph on a house page, drawn from snapshots. One consumer on the
  fleet stream; each house's latest `layout.lite` and `snapshot.spaceheat`
  cached in memory and pushed to the browsers watching that house
  (`/realtime/{house_alias}`), with a whitewire series per zone and
  `/gateway/health`. `report.event` only stamps the house's last report
  time for health. A scada sends `layout.lite` only when its upstream
  link activates or on a `SendLayout` request, so after a gateway restart
  a house has snapshots but no layout until its scada next reconnects.

Both read their configuration from one `.env` with the `BACKEND_` prefix
(`template.env` names every variable).

## Cross-cutting invariants

- **Meaning comes from sema, not from the store or from channel names.**
  The journal DB holds facts; what a channel is comes from the layout
  word. Every message and record crosses the boundary through the
  vendored snapshot classes (`api/sema/`, `gateway/sema/`), never as
  hand-read dicts. Hard-coded channel-name strings in these services are
  the named enemy of the team rule that data analysis never slows
  production (OPS-542 is the cleanup).
- **Nothing in production depends on this repo.** It is outside the
  control plane: a house, an LTN and the market run unchanged when it is
  down. The alerter's dependence on the journal DB is the one exception,
  and OPS-545 removes it.
- **The gateway is a tap consumer.** It reads the fleet stream from the
  analytics tap broker (`hw1-tap.electricity.works`, AMQPS) as its own
  login (`web.gateway`; gridworks-infra `rmqtap/instance-README.md`
  "Broker logins"), binds `gw.#` on `ear_tx`, declares only exclusive
  queues named `web.gateway.<uuid>`, and publishes nowhere. A
  server-named `amq.gen-*` queue would fall outside the login's
  configure permission.
- **The browser contract is the sema wire form.** What the gateway pushes
  to a browser is the decoded word's `to_dict()`: PascalCase keys,
  `TypeName` and `Version` present.

## The readings csv and bundle

`/api/v2/installations/{id}/readings.download` (the csv) and
`/api/v2/installations/{id}/synced.readings.bundle` (the visualizer's
series) are one column or series per channel lineage: the
`reading_channels` rows joined by a shared name or a shared layout channel
Id (`api/v2/readings_units.py`). A name's rows differ in unit when a layout
changed how the quantity is expressed or a state machine's enum version
changed, so a lineage is in the unit of its newest row, the unit the house
sends now, with every older row's values converted into it (temperatures
and flows convert pairwise as affine maps on a reference unit; other units
only to themselves). A request names a lineage by any name it has had. Rows
of one lineage whose units do not reconcile refuse the request (422) rather
than mix scales; rows with telemetry Unknown are left out.

The csv converts in Python: a bucket is the mean of its numeric readings
and the last of its states, and a state cell is the state's symbol in the
row's enum version; a state enum the snapshot does not vendor refuses the
request. The bundle converts inside its query, before TimescaleDB's
time-weighted average, so the rows of a lineage average together whatever
the window; a state row is no series, since the bundle word labels a series
with a unit vocabulary (`synced.readings.bundle` axiom 5), and states reach
the browser through `OperatingStateSequenceList`: one sequence per state
channel name, built from every state row of the house (a unit type outside
the unit vocabularies), each position resolved to its symbol through the
row's (enum, version), a change detected on the symbol, times to the
millisecond.

## Glossary

- **api** — the read façade process.
- **gateway** — the realtime process.
- **house alias** — the house word of a scada GNode alias
  (`hw1.isone.me.versant.keene.beech.scada` → `beech`), the key browsers
  subscribe by.
- **snapshot** — here `snapshot.spaceheat`, the scada's latest readings
  and states; the vendored `sema/` tree is also called a snapshot, and
  context tells them apart.

## Spokes

None yet. Candidates: the API surface (routes and the readings and
rollup queries behind them) and the gateway (consumer, house state,
browser messages).

## Open

- The API spoke, from `api/backend_api.py`.
- `api/backend_api.py:1241` multiplies spruce's `-set` values by ten
  (`#TODO: remove this hack`); whether the layout or the ops params now
  make it unnecessary.
- The web-frontend's expectations of the gateway's message types
  (`status`, `mqtt_message`, `zone_whitewire_series`) are written down
  nowhere but the two codebases.
