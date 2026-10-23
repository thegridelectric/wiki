# Channel identity across layouts

Status: Accepted · Pass 1 · Updated 2026-10-23 · Linear: OPS-618

**EDD: yes** the verification is a toggle run on the dev stack: one scada
publishes layout.lite 012, then 013, then 012 again while JournalKeeper
journals its reports, and the readings csv for `hp-lwt` comes back as one
column in one scale. The harness stays as the reproducer.

> What this is: the rule for what a `reading_channels` row is, applied
> before the fleet publishes layout.lite 013 (OPS-392). A channel whose
> telemetry changes is a different channel; a state machine whose enum
> version changes is a different channel; the csv endpoint stitches rows
> that share a name. Three repos: gridworks-journalkeeper bears the change,
> gridworks-web-backend gets the stitching, tlayouts supplies the Id rule.

## Why now

The fleet is about to move between 011/012 and 013 layouts, possibly more
than once per house, and 013 renames units and declares every state
machine with its enum and version. Today a `reading_channels` row is
identified by `(terminal_asset_alias, name)`; each row's `id` is a fresh
uuid4 minted by the layout persistor
(`gridworks-journalkeeper/src/gjk/layout_lite_persistor.py:162`), and a
unit change under the same name is modeled as a time era, split by
`deactivated_date` (`reading_channel_eras.py`). Three live flips give
`hp-lwt` four rows and two ids for the same CelsiusTimes100 channel. The
state-machine rows do not record the enum version at all, so a version
bump silently changes what the stored integer means.

## The rule

A reading channel is identified by what it measures and how it is
expressed. Two channels with the same name and different units are two
channels. The layout is the authority:

- A `data.channel.gt` or `derived.channel.gt` Id names one (name,
  telemetry) pair. tlayouts mints a new Id when a channel's TelemetryName
  or OutputUnit changes and keeps the Id across every other regeneration.
  That rule is stated in the layout word, so every emitter follows it.
- A state-machine channel is one (hosting node, enum name, enum version).
- A name is reused only for the same quantity. `hp-lwt` is a temperature
  in every layout that declares it. tlayouts owns this rule; this design
  depends on it and does not enforce it.

## 1. `reading_channels.id` is the layout's channel Id

**Rows.** For data and derived channels the row's `id` is the layout's
channel `Id`. A layout that declares an Id already in the table reuses the
row: the sync sets `deactivated_date` to NULL if it was retired, and
retires any other active row of the same name at the layout's time in the
same flush, which keeps the unique constraint on
`(terminal_asset_alias, name, deactivated_date)` satisfied.
`deactivated_date` means one thing: absent from the current layout.

**Pseudo channels** have no layout Id. Their `id` is a uuid5 over a fixed
namespace and `(terminal_asset_alias, name, unit_type, unit)`, so a flip
reuses the row too. The namespace constant sits beside
`MESSAGE_ID_NAMESPACE` in `message_persistence_info.py`.

**Readings resolve through the layout in force.** A report at time t maps
each ChannelName to a row through the newest layout.lite from that scada
at or before t (`messages` has every layout with its timestamp and
payload). The map is built once per layout message and cached on the
session like `load_channel_rows` is today. The reading word
(channel.readings 002) names the channel only, so this lookup is the whole
routing; the row's unit is not consulted.

**What stays, keyed by Id.** The add-only path for a layout older than
the newest persisted keeps its job on back-fill: a channel it declares
with no row of its own gets a row retired at the earliest newer layout's
time, so that era's readings have a row with the right unit. The
"same definition already present" check it had is the Id match now.
`channel_ids_at` stays as the fallback for rows minted before the cutover
and goes with the rekey.

**Ids reused in history.** The fleet's current layouts have 558 channels
with 558 distinct Ids and no Id shared across houses, but the layout
history reuses an Id within a house for another definition in 22 cases:
renames (oak's `zone1-iving-rm` typos, beech's `-device` suffixes), synth
channels become derived (beech `usable-energy`), a unit change (fir `oat`
AirTempCTimes1000 to WaterTempCTimes1000) and spruce's data channels
become synth. The row of a later definition under an Id a row already
holds is keyed by the uuid5 of the Id and the definition (name, unit,
unit type, channel type), in `channel_resolver.row_id_for`, and both the
sync and the resolver go through it.

**`channel_id` is a column of its own (Draft, 2026-10-23).** The row's
primary key `id` is a surrogate with no meaning; readings point at it and
nothing else reads it. A new nullable column `channel_id` is the layout's
channel Id verbatim, set on every row that comes from a declared data or
derived channel and NULL on a state-machine pseudo row, with an index. The
unique constraint on `(terminal_asset_alias, name, deactivated_date)`
stays, so a renamed channel (oak's `vdc-relay1` becomes `vdc-relay` in 013
under the same Id) is two rows with two names and one `channel_id`: the
old name survives for the readers that key on it, and the lineage is a
column rather than a hash. The uuid5-of-Id-and-definition key above
retires with this: the sync finds a declared channel's row by `(asset,
name)` among active rows, compares the definition, and writes
`channel_id` from the layout; a changed definition under a name is a new
row as before.

*Why not the Id as primary key.* The first cut made `id` the layout Id and
hashed when an Id was already held under another definition. That loses
the Id for the second row (`row_id_for` is a one-way uuid5), and the rekey
of history then has to rewrite `readings.channel_id` across the readings
hypertable. What the column buys:

- *The rekey is cheap.* It becomes a backfill of ~1,700 reading_channels
  rows; no reading ever moves, so no window over the hypertable.
- *The unique constraint stays.* `(terminal_asset_alias, name,
  deactivated_date)` is unchanged, every old name keeps its row, and the
  readers that key on names see nothing move.
- *The resolver simplifies.* A declared channel's row is found by
  `(asset, name)` among active rows and compared by definition; the
  Id-is-held branch and the uuid5 derivation go away.

*Backfill, once, in reading_channels only (1,817 rows, no readings
touched).* The key is (terminal asset, name, unit); the row's `id` is not
consulted. tlayouts is the source of truth: a pair declared in a tlayouts
output layout gets that layout's Id, `jm/spruce` (the 013 layouts) before
`main` (the layouts the House0 boxes run). A pair no branch declares (a
retired name or unit, elm, the dev universes) gets the Id of the newest
layout.lite in `messages` that declares it; where both sources declare a
pair they agree on every one. A `gjk.pseudo` row gets NULL. Where history
gave one Id to two units and the newest layout keeps it (fir `oat` air
versus water temp, spruce's three opto inputs BinaryState versus Unknown)
the rows in the unit tlayouts does not declare get NULL, so NULL means
"no layout Id names this name and unit". The map is built by a script
from the live table and the two branches, written as a csv beside the
migration, and regenerated right before the migration runs; the
migration updates by row id and fails loud on any non-pseudo row the csv
does not cover. The uuid5 derivation goes with the column. The era rule
(`channel_ids_at`) stays: it picks among the rows of one name and
definition, and is the whole routing for a report from before the first
layout the journal has from its scada (the 2024 beech, fir and oak
archive, and a report that precedes its own layout by days). The model and the alembic
migration live in gridworks-data (`gw_data.db.models.ReadingChannelSql`);
the writer is gjk's `channel_resolver`; the csv endpoint may group by
`channel_id` to knit a rename when a reader wants lineage rather than
names.

*Until the column exists* the current rule stands: `id` is the layout Id
where that Id is free, the uuid5 where it is held, and the sync reuses the
same rows on every flip.

**Schema.** One added column, `reading_channels.channel_id uuid NULL` with
an index; the primary key, the unit columns and the unique constraint are
unchanged. `deactivated_date` means one thing: absent from the current
layout.

## 2. State-machine channels track the enum version

Today (`report_event_persistor.py:41`) a state channel's `unit_type` is
the enum name and its `unit` is the literal "Enum". The layout's
`StateEnumVersion` is read and ignored. The stored value is the state's
position in the vendored enum's value list, and a value the snapshot
lacks is stored as a sha256 integer with a warning.

**Rows.** `unit_type` stays the enum name; `unit` becomes the enum version
from the layout's StateMachines entry. A version bump is then a unit
change, and the layout sync treats it like any other: a new row, the old
one retired. The pseudo-channel uuid5 includes the version through `unit`.

**Values.** The stored integer is the state's position in the declared
version's value list. `ENUMS_BY_NAME` becomes a map keyed by (enum name,
version) over the vendored current and `old_versions` enums.

**Refusal.** A declared (enum, version) the snapshot does not vendor gets
no channel and no readings; the sha256 fallback goes. The miss is counted
in a tally the run summary and the live log surface, keyed by
`(terminal_asset_alias, enum, version)`, so the fix is visible: re-vendor
the snapshot. machine.states 000 names the enum without a version; the
version comes from the layout in force, the same lookup as section 1.

**Names.** Unchanged: the continued names for the legacy machines,
`<node>-state` otherwise, `<node>-pico-state` for picos.

## 3. The csv endpoint stitches rows by name

To do in gridworks-web-backend, after sections 1 and 2 are journaling.

`readings_csv.py:243` already joins readings to `reading_channels` by name
and emits one column per name, so rows that share a name interleave by
timestamp. It never reads `unit`, so across a flip the `hp-lwt` column
mixes WaterTempCTimes1000 and CelsiusTimes100 values.

- Select `unit` and `unit_type` with the name.
- Convert each value to one canonical unit per quantity before emitting,
  from a conversion table keyed by (from unit, to unit).
  WaterTempCTimes1000 to CelsiusTimes100 divides by ten. A pair the table
  lacks makes the response an error, so a raw value never reaches the file silently.
- State channels emit the state's symbol, resolved through (enum name,
  version) from the row, so a column reads the same across versions.

A column is a channel's lineage: the rows joined by a shared name (a unit
change mints a new Id under the name) or a shared `channel_id` (a rename
keeps the Id under a new name), headed by the newest row's name. A request
names a column by any name its lineage has had. Rows of one lineage never
overlap in time, so the union sorted by timestamp is unambiguous. The one
assumption is the name-reuse rule above.

## The experiment

On the dev stack (`experiments/dev-stack-recipe.md` first): a simulated
scada on `jm/spruce-unlimbo` publishes 013, is swapped to a 012 build,
then back, each with a few reports between. Assert:

1. `reading_channels` has exactly two `hp-lwt` rows for the asset, ids
   equal to the two layout Ids, and the 013 row is active at the end.
2. Every `hp-lwt` reading is attached to the row whose layout was in force
   at its time.
3. Each declared state machine has one row per (enum, version) seen, and
   no reading on a state channel is a sha256 fallback.
4. The csv for `hp-lwt` over the whole run is one column in CelsiusTimes100.

## Plan

1. tlayouts: the Id rule (under OPS-392; this design depends on it).
2. ✅ gjk: section 1 rows and routing, on `jm/channel-identity-v013`.
3. ✅ gjk: section 2, same branch.
4. ✅ The toggle experiment is `tests/test_channel_identity_toggle.py`
   against real TimescaleDB; `executor/persistor.md` and `s3-backfill.md`
   state the rule.
5. ✅ web-backend: section 3 (`api/v2/readings_units.py`,
   `tests/test_readings_csv.py`). Rows with telemetry Unknown (spruce's
   opto inputs, 2026-01-28 to 03-31) are left out of the csv. With the
   column, a csv column is a lineage: rows joined by a shared name or a
   shared `channel_id`, headed by the newest row's name, so a rename is
   one column and a request by any of its names gets it (`jm/csv-stitch-units`,
   `gw-data` 0.8.0).
6. ✅ gridworks-data: the `channel_id` column, migration `f7c3d1a2b4e5`
   with the csv its data step applies, `scripts/channel_id_backfill_map.py`
   (on `jm/channel-id`, `gw_data` 0.8.0); gjk: the sync keys rows by name
   and definition, writes `channel_id`, the uuid5 derivation is gone, the
   toggle test takes a rename (on `jm/channel-id-column`).
7. ✅ journaldb is at `f7c3d1a2b4e5` (2026-10-23): the regenerated csv
   matched the committed one byte for byte, 1465 rows got a `channel_id`,
   348 pseudo rows and the 4 scale-conflict rows are NULL. Still to do:
   deploy gjk on `gw_data` 0.8.0.

Effort: 4 h, 90% interval 2–10 (agreed 2026-10-22). The lines below are the first-pass breakdown that quoted higher; the agreed figure stands.

| line | point | low | high |
|---|---|---|---|
| authoring (resolver, uuid5 ids, version-keyed enums, tests) | 5 | 2 | 8 |
| discovery (persistors, eras, importer, csv endpoint) | 3 | 2 | 10 |
| decision (history, refusal surfacing, canonical units) | 2 | 1 | 5 |
| spec beat | 1 | 0.5 | 2 |
| **sum** | **11** | **5.5** | **25** |

The rekey migration is outside these lines: 3 (2–8) on its own.

## Open

- Whether the name-reuse rule (same name, same quantity) is checked in
  tlayouts or stated in the layout word's axioms.
- OPS-542 lists the state enums the journal fans out versus the registry
  as open; section 2's refusal tally answers the "how does a replaced enum
  reach the journal" half, and the rest stays there.
