# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-backend` code repo**. The matching git commit (in
`gridworks-web-backend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-11-24 — The FLO routes serve flo.params 005 and take flo.rerun.request 003 (`f8ca616`, jm/flo-params-005, PR 41)

**Why:** the LTNs send `flo.params` 005, the lift COP model, since its promotion (sema `df68501`), and `flo.rerun.request` 002 cannot hold a 005 params. The api seed names its versions, so the regen adds 005 and 003 only through the seed. 004 and 002 join the versions the routes accept, and the tests serve oak's hour at 005 and solve a 005 hour with bruce.

## 2026-11-24 — The seeds state the snapshots' staging policy; ci.sh checks both vendored snapshots and keeps staging off main (`3d80456`, jm/snapshot-staging-policy, OPS-702)

**Why.** Whether a snapshot could hold staging words was an `ALLOW_STAGED=1`
on the regen command, and nothing checked `main` but a hand-written test
that read each snapshot's registry (OPS-702). The committed api snapshot was
in fact a staging one: its marker listed `flo.params` 004,
`flo.recommendation` 003, `flo.rerun.request` 002, `flo.tuning.bruce` 003
and `flo.path.penalties.bruce` 002, all published since. Each seed now
states its policy, no `staging` block, so both snapshots are published-only,
with `package_name` and `vendor_dir`; the script is one `sema snapshot
regen` per package. Each snapshot ships its own `check_staging.py`, and the
new `ci.sh` (the repo had none) runs both checks under `python -P` and then
pytest; the hand-written main-only test goes. Both snapshots are
regenerated from sema `ac40b4b`: the api build passes over the staging
`gw.channel.kind` 001 and says so, and the staging marker is gone.

One squashed commit. `ci.sh` runs each snapshot's shipped `check_staging.py` with `--deploy-branch main`, so a pull request into main fails while either snapshot holds a staging word; both snapshots sit at the published `flo.params` 004.

## 2026-11-20 — The FLO routes serve the Experimental tuning versions (`e2d8b2c`, #39, jm/flo-tuning-experimental, OPS-696)

**Why.** `flo.tuning.bruce` 003 and `flo.path.penalties.bruce` 002 move the two unmet-load knobs and their penalty series into an open `Experimental` dict, so a knob under tuning changes bruce and nothing else (OPS-696). The words that nest them follow: `flo.params` 004, `flo.rerun.request` 002, `flo.recommendation` 003, `gw.operational.params` 000 repointed in place. All five are staging in sema (`c8cc461`), so the snapshot is a dev-only staged one until they promote. The seed vendors the new versions beside the journaled
ones; the FLO route and the price-forecast route add the versions they
serve; the re-run route takes a `flo.rerun.request` at 001 or 002 and hands
it to bruce, which lifts a journaled 002 or 003 params to 004.

## 2026-11-18 — minor README update (`a79b943`, jm/ops-683-review, OPS-683)

Merged to main with the entry below as `7001d27` (#38), 2026-11-19.

The paragraph under "The FLO re-run on a laptop" still told a reader to
install a local optimal-flexibility "over the pinned one" and to move
the lock with `uv lock --upgrade-package`. With bruce an editable path
source, neither applies: the sibling checkout is what solves, and a pull
or branch switch there needs no re-sync. The paragraph now says that,
and that a version mismatch answers 422 with bruce's own reason.

## 2026-11-18 — bruce is the sibling checkout, and the re-run's 422 says what bruce said (`d236bc3`, jm/ops-683-review, OPS-683)

**Why.** The lock pinned bruce at a commit that predates bruce's own
`FloRerunRequest`, so the route imported a class the installed package
lacked and every re-run answered 500. Production has no bruce, and on a
laptop bruce is the sibling checkout being worked on, so a commit pin was
the wrong shape: the `rerun` group now sources `bruce-energy` from
`../optimal-flexibility`, editable, and `uv sync --group rerun` installs
whatever is checked out there. In the route, the wrapper no longer
rewrites every decode error as a version mismatch: a word bruce cannot
read answers with bruce's reason, and bruce itself names both versions
for a `flo.params` it reads but does not solve. The `isinstance` check on
the inner params goes, since the wrapper's type already states it.

## 2026-11-17 — Add FLO rerun request (`69a9b82`, OPS-683)

**Why.** The re-run could edit bruce's penalty tuning but not force heat
pump steps on or off, which bruce's optimizer already accepts and no
word stated. The route's body becomes `flo.rerun.request` 000, published
to the registry first: it wraps a `flo.params` with the forced-on and
forced-off step lists, and its two axioms (steps inside the grid, no
step in both lists) are validators in the vendored class. The snapshot
takes the word and its sample; the tests send the wrapper. The lock
stays at bruce `6632ea5`, which predates bruce's own `FloRerunRequest`,
so the route's import fails until bruce is sourced from the sibling
checkout in a following change.

## 2026-11-15 — The re-run solves with bruce at flo.params 002 (`c260b4a`, OPS-665)

**Why.** The LTNs moved to `flo.params` 002 the evening of 2026-11-14 and
bruce's main followed, while the re-run route's lock still pinned bruce at
the 001 commit, so every current hour would have failed to solve. The lock
moves to bruce main (`6632ea5`), and a body at a version bruce no longer
reads (the journal's 001 hours, which name no forecasts and cannot lift to
002) answers 422 naming both versions instead of a 500 from bruce's own
decode error. The re-run is a developer tool, so the mount now refuses
to start an API that is not running locally (`BACKEND_RUNNING_LOCALLY`,
false on the web box) with the setting on: the only-on-a-laptop rule is in
the code, not just in which box sets which variable.

## 2026-11-15 — The latest-prices route: a market's cleared prices over a window, every row at latest.price 001 (#34) (`7e8fc3a`, jm/realtime-price, OPS-666)

**Why:** the price panel draws the price the market cleared at beside the
forecast, and the journal holds the maker's `latest.price` rows at 000
(the price alone) and, from the 2026-11-14 maker deploy, at 001 (the
price in its parts). `GET /api/v2/markets/{market}/latest-prices?start&end`
serves the rows of one market, named by its slot-name prefix
`<commodity>.<product>.<maker alias>`, for the slots that start from one
slot before the window through its end, oldest first; the codec upgrades
a 000 row to 001 with its whole price as one `Unknown` part, so the
browser reads one version. The snapshot seeds `latest.price` at both
versions. The slot length is a module constant with a note naming the
product-name fact that retires it. A login is the only gate: a market
price is not house data.

## 2026-11-14 — The price panel's forecast for a house and hour, from the journal (#33) (`37eedbf`, jm/price-forecast-word, OPS-666)

**Why:** the price panel draws the stopgap service's live forecast, which
has no past, so the default window shows nothing. The journal now takes
`gw.price.forecast` (one per ISO-NE posting, under a stable `ForecastUid`)
and `flo.params` 002 names the forecast the LTN read its prices from. A
new route `GET /api/v2/installations/{alias}/price-forecast?time=` answers
with the forecast word for the market slot `time` falls in: the one the
house's own `flo.params` for that slot names, else the newest the service
had published by `time`, else 404. Which rule chose it is not in the
response; a sema enum for it waits on the registry reopening. The api
seed takes `gw.price.forecast` and both `flo.params` versions (001 rows
from oak have two price lists and no forecast id), and the FLO route
decodes 001 rows at their own version. The snapshot is regenerated with
staging words admitted (`ALLOW_STAGED=1`, a switch the regen script now
has), which also moved `gw.house.summary` to 003 and `layout.lite` to
014: the summaries route decodes 013 and 014 layout rows and emits
summary 003, and the fleet tariff route's prose names the 014 `Tariff`
that retires it. The branch is cut from `jm/flo-plot-words` (OPS-665,
which already drops the `gridworks-flo` dependency) rebased on `main`.
Staging words run on dev only, so the branch merges after promotion.
Tests seed two service forecasts and an oak `flo.params` 002 naming the
earlier one; 58 passed.


**Also in this squash:** the api snapshot regenerated from sema `dev` at `bba18bc`, where the
price panel's words are published, so the build is published-only and
the `staging.yaml` index goes. The re-run route decoded its body at the
snapshot's current `flo.params`, 002, and the codec refuses to upgrade a
001 body (no forecast id to invent), yet the journal's rows before
tonight are 001; the route now accepts either journaled version and
lets bruce say what it can solve.

## 2026-11-14 — The FLO re-run route: a flo.params in, bruce's flo.recommendation out, on a laptop only (`9bac6f7`, OPS-665)

**Why.** The optimizer author's inspection tool is to solve an hour again
with the penalty tuning changed and look at the plot. The web box has no
optimizer, so the route lives behind a setting (`BACKEND_FLO_RERUN=in-process`)
and a dependency group (`rerun`, the bruce package from
optimal-flexibility `main`, a git source so a box's `uv sync` needs no
sibling checkout) that only a laptop sets and installs. The
seam is sema both ways: the body is the hour's `flo.params` with its
Tuning edited, the answer is the `flo.recommendation` 001 bruce gives,
so the visualizer draws it with the plot it already has. bruce needs
newer numpy and pandas than the lock held, so the lock moves both for
every install.

## 2026-11-14 — Merge pull request #31 from thegridelectric/jm/flo-plot-words (`1eb7fb6`, OPS-665)

**Why.** The backend reads the FLO's recommendation, it does not solve
it. `api/v2/routers/flo_recommendation.py` serves the journaled
`flo.recommendation` at 000 or 001 by bidder and slot through the codec,
and `/flo.params?time=` serves the LTN's request for the slot by the same
lookup. The side quests no longer import gridflo, so the web box has
no optimizer and no `bruce-energy`. Both snapshots (`api`, `gateway`) are
regenerated from sema `dev` at `b5064f9`, which also brings
`layout.lite` 013. The merge of main keeps the `tou_tariff` router of
PR #29 beside the new one in `tests/conftest.py`. web-api2 pulls `main`
and restarts `gridworks-api` and `gridworks-gateway`.

## 2026-11-14 — Stop printing every SQL command (`206b926`, jm/no-sql-echo, cherry-pick of Thomas's `4dcd5d4a`)

**Why:** the api service's async engine was created with `echo=True`, so
every SQL statement went to the journal on web-api2, about 6,600 lines an
hour on a box with a 6.8 GB root disk. One line in
`api/v2/dependencies.py` drops the flag. Lifted on its own from the
`td/bruce-flo` branch so it ships ahead of the FLO-plot merge order.

## 2026-11-11 — The fleet's time-of-use tariff as a gw.tou.tariff word for the price panel's on-peak shading (`ada1c7f`, jm/price-panel-lmp, OPS-666)

**Why:** the price panel shades the tariff's on-peak hours, and the browser
is not allowed to know what on-peak means. The on-peak windows are a
sema fact, `gw.tou.tariff` 000 with `gw.tou.window` 000, published for
this (sema `ae2b2ac`). The api seed takes the tariff word and the
snapshot is regenerated; a new route `GET /api/v2/tou-tariff/current`
answers the fleet's Versant A-1 tariff as a `TouTariff` instance in wire
form. When houses journal `gw.operational.params`, the route serves the
house's own `Tariff`. A test checks the shape against the word's formats
and that the route needs a login.

## 2026-11-10 — side_quests no longer import gridflo (`458fbc7`, jm/flo-plot-words, OPS-665)

**Why:** three one-off analysis scripts under `side_quests/house_energy_use/`
imported `gridflo`, the last reference in the repo to the private
`gridworks-innovations` checkout the branch stops depending on. The
scripts stay for reference with their `gridflo` imports commented out and
a note saying why; the rest of each script is untouched. The folder is
not installed code.

## 2026-11-10 — Snapshot at the flo plot words with the store's bounds and the path cost (`fdb8bd0`, jm/flo-plot-words, OPS-665)

The commit is the whole FLO route under a snapshot title: the route serves the recommendation word from the journal, and the optimizer and the xlsx go.

**What:** `api/v2/routers/flo_recommendation.py`: `GET
/api/v2/installations/{installation_id}/flo.recommendation?time` answers
the newest `flo.recommendation` the journal holds whose `BidderAlias` is
the house and whose paths start at the market slot `time` falls in, in
the word's dict form through the vendored snapshot, behind the same
data-access check as the readings routes; a 404 `No FLO was run in this
hour` when no row matches. The seed pins the word at 000 and 001, since
the journal holds the fleet's 000 rows and 001 adds the store state and
the penalties as optional lists with no upgrade path from 000, so each
row is served at its own version; the closure brings the path, the two
annotation words, the pair and the two market enums. The snapshot is at
sema `58a55b4`, the published flo plot words, built published-only by
`scripts/regen_sema_snapshot.sh` for both packages (`api`, `gateway`);
`test_sema_snapshots_published` passes. `flo.tank.store.path` states the
store's empty and full energy and `flo.path.penalties.bruce` the
empty-store terminal cost and the path cost; the route serves a 001 row
that has them and answers 500 on a 001 row written before them.

The same module serves `GET .../flo.params?time` the same way: the newest
`flo.params` whose `GNodeAlias` is the house and whose `StartUnixS` is the
slot start, for the FLO view's load and price traces; the seed pins the
word at 001, which brings `flo.tuning.alice` 000 and `flo.tuning.bruce`
001. A test seeds beech's request for the 001 slot and asserts the slot
before, which has a recommendation but no request, is a 404.

**Gone:** `flo_download.py` (re-solve the hour's `flo.params.house0`
with the optimizer and return `result.xlsx`), the legacy `POST /flo` in
`backend_api.py` that did the same, and the `gridworks-flo` editable path
dependency on the private `gridworks-innovations` checkout, so the web
box runs no optimizer and depends on nothing outside the public repos.
The `side_quests/` scripts that import `gridflo` are untouched; they are
not installed code.

**Why:** the FLO service already publishes the answer; re-solving on the
web box made a plot depend on which commit a sibling checkout sat at and
ran a second optimizer against production data. The dashboard reads what
was published. Tests seed the registry's 001 and 000 examples re-addressed
to beech for two slots and oak's for one, and cover the word returned at
each version, the slot with no run, the alias filter and the viewer gate.
pytest 51 passed.

## 2026-11-01 — The weather routes serve a bundle's record and its journaled forecasts (`cddefbe`, OPS-622)

**What:** `api/v2/routers/weather_forecast.py`: `GET
/api/v2/weather/bundles/{bundle_name}` answers the newest
`gw.weather.forecast.bundle.gt` record the journal holds under that name,
and `GET /api/v2/weather/bundles/{bundle_name}/forecasts?start&end` the
bundle's `gw.weather.forecast` emissions received in the window, oldest
first; both in the words' dict form through the vendored snapshot, which
the seed extends with the two words (the closure brings the series, the
channel records and the fidelity enum). The forecast is vendored at 001
and 002, since the journal holds the service's fortnight of 001 rows and
its 002 rows from 2026-11-01 17:01Z, and 001 has no upgrade path to 002
(no ForecastUid to mint), so each emission is served at its own
version. Tests seed a bundle record and three re-timed registry-example
emissions, two at 001 and one at 002, and cover the window, the bundle
filter, the ordering, the 404 and the login.

The api seed also declares `local_names: strip_prefixes: [gw]`, so the
vendored snapshot renders `gw.weather.channel.gt` as `WeatherChannelGt`,
`gw.house.summary` as `HouseSummary` and so on for every `gw.` word and
enum (wire TypeNames untouched; `gw1.` words keep their prefix), matching
the names the frontend's vendored `.d.ts` already uses. The legacy
`weather.forecast` word leaves the seed: no backend code read it, and
its local name collided with `gw.weather.forecast`.

**Why:** the visualizer's weather plot read the per-house
`weather.forecast` message the scada's derived generator emitted on the
`legacy` line; on `main` the scada consumes the weather service's
`gw.weather.forecast` and emits nothing, so the plot went blank house by
house as the fleet rolled to `main` on 2026-10-29. The service's word is
about a bundle, not a house, and its values are scaled per the bundle's
channel records, so the browser needs the record beside the emissions.
Verified against production rows copied into `tsdb_tap`: bobcat answers
its record and 63 emissions over three days; moose and raccoon answer
their records and no emissions, because the journalkeeper's default
message id (sender, type, created time) collides across the three
bundles the service emits in the same millisecond and keeps only the
first, bobcat. That journalkeeper fault is open; the routes are right
once it journals every bundle.

## 2026-10-29 — the house summary states the scada's commit and where it stands against main (`6c877d2`, OPS-622)

**What:** the summaries query joins the newest `gw.scada.commit` each
house's scada announced and the route fills `ScadaCommit` on
`gw.house.summary` 002, plus `ScadaCommitStanding`: GitHub's compare of
`main...<commit>` on `BACKEND_SCADA_REPO` (a required setting), as
`gw.commit.standing`. `-dirty` is Dirty without asking; identical is
OnMainHead, behind is BehindMain, ahead or diverged is OffMain; a 404 or
an unreachable GitHub is Unknown. One call per distinct commit across the
fleet, cached five minutes in the process. A scada that announced none
leaves both fields out. The api snapshot takes 002 and the enum, both
published. Tests: beech announces twice and the
newer hash wins with its standing; oak announces none; the resolver's
mapping, Unknown on outage, and the cache across requests.

**Why:** the dashboard's Houses card shows a green check for a scada on
main's head and the short hash otherwise, so the fleet's running code is
read off the page rather than off each box. The browser renders the
standing the backend derived; it does not compare hashes itself.

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
