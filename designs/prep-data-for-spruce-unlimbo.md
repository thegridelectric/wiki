# Prep data for spruce-unlimbo

Status: Draft · Pass 0 · Updated 2026-10-15 · Linear: OPS-542

**EDD: yes** the day of fleet data from the spruce-unlimbo first data catch
is the verification; a claim reaches Verified only when that data reads the
whole way up (journal, façade, visualizer) by layout lookup alone, against
real services (`experiments/`).

> What this is: the data-side cleanup that follows the spruce-unlimbo launch
> (OPS-392): JournalKeeper, the web-backend and the web-frontend stop
> deciding meaning by channel-name strings and read it from the layout
> word. Kept out of spruce-unlimbo because it is a different set of repos
> with its own verification; the launch's deployment spoke points here by
> Linear id.

## Sequence

1. **The first data catch** (OPS-392, `deployment.md` "The first data
   catch"): `layout.lite/013` published, gjk creating its channels, the
   heat-call guard on gjk, three boxes on `jm/spruce-unlimbo` on the
   production broker for a day, readings landing.
2. **Boxes to `main`, maybe.** After that day the launch decides whether the
   boxes move to `main`. This design does not wait on that call; it needs
   the caught data, not the swap.
3. **This design: the string cleanup**, against the caught data.

## The three repos

The fleet emits, JournalKeeper writes the journal DB, the web-backend reads a
façade over it, the web-frontend visualizes. The cleanup is on:

- **gridworks-journalkeeper** — every place a persistor decides what a
  channel is from its name: the hand-kept `STATE_CHANNELS` map, the
  heat-call synthesis keyed on `*-whitewire-pwr`, and the rest of the
  string matching in the persistors
  (`gridworks-journalkeeper/executor/persistor.md` "Open"). Pseudo-channels
  stay; what changes is that gjk derives them from the layout it receives
  rather than from literals in code. One goes away outright: the
  `buffer-available-kwh` pseudo channel in `flo_params_house0_persistor.py`
  stores the LTN's `BufferAvailableKwh`, which the LTN computes from a
  hard-coded four-layer buffer and returns as 0 whenever `KeepBufferFull`
  is true (every deployed House0 house). No layout has that buffer any
  more, so the channel is removed rather than re-derived; the journal's
  existing rows stay, a rebuild from scratch will not have them. It is the
  only live emitter of the `KilowattHoursX1000` unit value, which stays in
  `gw1.unit` because 002 is published.
- **gridworks-web-backend** — the public read-only façade: the API returns
  the channels and layout/params shape for every family from the layout
  word, with no per-house channel-name table.
- **gridworks-web-frontend** — the visualizer: it renders each family from
  the layout, including the families with no buffer tank or iso valve and
  the one with no water store tanks at all.

## Functional names

The data services decide what a channel is from its name because the
layout gives them nothing else to look up: the functional names
(`hp-lwt`, `dist-swt`, `primary-flow`, the zone whitewire and heat-call
channels, the state-machine handles) live in python in
`gwsproto.names`, and in sema only as literals inside the axioms of the
staging full-layout words. tlayouts has the same problem from the other
side: `jm/spruce` imports `gwsproto.names` from gridworks-scada to spell
the names it writes. One fix serves both: the names become sema.

The cleanup goes in two stages:

1. **Staging `layout.lite` 013 states what the database needs.** Edited
   in place while it is staging: the state machines (handle, state enum
   word, version), the zone-call circuits (whitewire channel, heat-call
   channel, threshold), the heat-call DerivedChannels so gjk stops
   synthesizing them, and the store and buffer depth channel lists. This
   retires `STATE_CHANNELS`, the handle remaps, the heat-call synthesis
   and the per-house thresholds.
2. **Role bindings wait for the full layouts.** Picking a channel by
   role (the heat-pump and distribution plot lists, zone grouping by
   name prefix) needs a sema vocabulary of functional roles, which the
   staging `gw.house0.layout`, `gw.nolan.layout` and `gw.hydronic` words
   point toward. It is published with them.

The vocabulary comes before the bindings: tlayouts writes the bindings,
so it needs the role names first. Its full exit from `gwsproto.names`
also needs what is not a channel role:

- **Core actor node names** (`s`, `lc`, `auto`, `derived-generator`,
  `power-meter`), which also build hierarchy names
  (`f"{Core.primary_scada}.{name}"`, tlayouts `layout_gen.py:705`). A
  node-role vocabulary sits beside the channel-role one. The web-frontend
  needs it too: it parses the command trees and state machines in full
  only when it knows which core actor each node is.
- **Per-family name sets** (House0, Nolan, Hydronic), which suggests the
  vocabulary belongs with each full-layout word rather than in one flat
  enum.
- **`DeviceType`** (tlayouts `device_types/__init__.py:15`, already "the
  local name for gw1.device.type") moves to the vendored sema enum now;
  it does not wait.

tlayouts drops its gridworks-scada import once the node and channel role
vocabulary is published.

## No per-house specials

The three layout families (`gw.nolan.layout`, `gw.house0.layout` with the
sieg loop, `gw.house0.no.sieg`) must ingest and display by their
layout-sema declaration, not by hand-mapped channel names (the standing
team rule: data analysis never slows the production system, and hard-coded
channel-name strings in data services are the named enemy). The tell that
vocabulary is missing or unused is code that scrapes instead of looking up.

## The experiment (the EDD bar)

Read the caught day through the whole pipeline, asserting:

1. **Channels arrive.** Every channel each box's layout declares is in the
   journal DB, none dropped and none silently renamed, with no gjk code
   naming a channel.
2. **Hourly data parses.** The hourly rollup the web-backend serves parses
   for each family, with no decode error on a family-specific channel.
3. **The visualizer works.** The web-frontend renders each house's page from
   its layout: the channels present, nothing assuming a tank or valve the
   family lacks.

The harness is a re-runnable reproducer; findings distill into scoped
Verified claims once it is green.

## Rename `reading_channels.terminal_asset_alias` here

`reading_channels.terminal_asset_alias` becomes `about_g_node_alias`,
nullable: a channel is about a GNode, and a channel of aggregated power
across every terminal asset in Millinocket is about none in particular
(decided 2026-10-15 under OPS-473, deferred here because every consumer
binds the column by name and this design is where they are all rewritten).
What the rename touches, from a read of the live journaldb and the
repos on 2026-10-15:

- **gridworks-data:** `ReadingChannelSql.terminal_asset_alias` and the
  unique constraint on (alias, name, deactivated_date), which stays with
  `NULLS NOT DISTINCT`. The index named `terminal_asset_alias` is on
  `name`, a misnomer to fix in the same migration. The three SQL
  functions under `scripts/misc` (`retrieve_readings_1s`,
  `calc_energy_1hr`, `calc_hourly_data`) read the column by name in text
  bodies and must be recreated; the `readings_1hr` continuous aggregate
  and `cached_hourly_data` carry an output column of the old name, which
  is dropped and recreated if the name is to go through. The aggregate
  follows a rename of the underlying column by attribute number, but
  prove that on a local timescaledb-ha container before journaldb.
- **gridworks-journalkeeper:** creates channel rows through the gw_data
  model and loads them by alias (`reading_channel_eras.load_channel_rows`,
  the report-event, layout-lite and weather-bundle persistors). Breaks on
  the first insert after the rename unless deployed in the same window.
- **gridworks-web-backend:** raw SQL naming the column in
  `hourly_data_download`, `installation_summaries`, `readings_csv`,
  `hourly_electricity`; model references in `readings_csv` and
  `synced_readings_bundle`. The `terminal_asset_alias` strings in its
  sema types are the sema word's field, untouched.
- **gridworks-alerts:** reads the column through the model in
  `alert_generator.py` and derives the house alias from it.

One window: gw_data release, then journalkeeper, web-backend and alerts
deployed with the migration.

## Open

- The dashboard's Parameters page opens on hard-coded defaults in the
  frontend model (DD power 12 kW, DD RSWT 180 F, intermediate RSWT
  130 F) while the house's `layout.lite` row has the scada's own
  `Ha1Params` (cedar in the dev run: 9 kW, 160 F, 100 F). The page has
  the layout since OPS-473 and could read them from it; Ha1Params is
  itself on its way out, so the fix waits for whatever replaces it.
- Which families the three catch boxes cover; a family not among them needs
  a simulated asset (or a later box) to meet the bar.
- Whether the stage 1 additions to `layout.lite` 013 belong in its
  finalize spoke under OPS-392 or here.
- Whether the simulated fourth fall layout (OPS-532) is exercised here too.
- The exact web-frontend and web-backend seams that still read channel
  names by string rather than the layout word.
- The state enums the journal fans out versus the registry. Sema deleted
  `gw1.local.control.standby.top.state` on 2026-10-06 (`f234cfd`,
  `replaced_by: gw2.lc.top.state`) while the enum was still vendored in
  JournalKeeper's snapshot and bound to the `local-control-standby-state`
  pseudo channel; the 2026-10-15 gjk regen had to drop both to build.
  Deleting a published enum a consumer vendors is the pattern to look at
  here: which `gw1.*` state enums the gjk pseudo channels still name,
  which the scada on `jm/spruce-unlimbo` reports, and how a replaced enum
  reaches the journal without a hole (readings for that machine stop at
  the deletion; none in the 60 days before it).
