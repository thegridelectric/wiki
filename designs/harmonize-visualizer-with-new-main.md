# Harmonize the visualizer with the new main

Status: Draft · Pass 0 · Updated 2026-10-25 · Linear: OPS-542

**EDD: yes** the day of fleet data from the spruce-unlimbo first data catch
is the verification; a claim reaches Verified only when that data reads the
whole way up (journal, façade, visualizer) by layout lookup alone, against
real services (`experiments/`).

> What this is: the data side of the spruce-unlimbo launch (OPS-392): the
> readers (JournalKeeper, the web-backend, the web-frontend) work across
> layout eras on the data the fleet now produces, with the gate for
> merging `jm/spruce-unlimbo` into `main`: no errors on the visualizer
> page over any window, and George happy with the time series. Kept out
> of spruce-unlimbo because it is a different set of repos with its own
> verification; the launch's deployment spoke points here by Linear id.
> The string cleanup that follows (the three repos reading meaning from
> the layout word, the seam a word on both sides) is a separate design.

## Do this next

The fleet's night of 2026-10-23 is the dataset: oak on 013 from 01:42:45
to 01:57:23 and from 03:07:29 to 03:17:46 ET, maple from 03:12:00 to
03:23:10 and from 09:48:24 to 09:57:52, spruce from 00:57:45 to 03:18:52,
each house on its old line otherwise (the `layout.lite` arrivals in the
journal). Every reader fault shows against it.

**▶ Do this next.**

1. The dataset folder `experiments/013-cutover-windows/`: the era table,
   a harness that runs the bundle, csv and hourly readers per era and per
   spanning window, one verdict per claim. Suspected and unverified: the
   bundle's LOCF fill copies a retired row's last value forward across
   the rest of the window; three spruce rows went stale at its rollback
   (forecast-oat, forecast-ws, vdc-relay). A harness item for the house0
   renames: whether the journalkeeper, the hourly calculation
   (`cached_hourly_data`, filled by a gridworks-data job not yet read) and
   the downloads still read right at spruce, whose 013 rows are retired
   under names the browser does not know (`n-state`, `s-state`,
   `*-relay-state`). The 013-era temperatures oak and maple journaled ten
   times too large are explained: those boxes ran 013 without the scaling
   code spruce had, and spruce's 013 points read right, so the readers are
   right going forward. What remains for those hours is a one-off
   correction of the journaled points, or leaving them. Also to check:
   spruce's five 013 heat-call series plot nothing in its 013 window
   (no zone calling, or empty derived rows); spruce's reports write no
   HeatCallSynth readings where the other houses' do; and the eight
   `gw1.local.control.standby.top.state` rows, an enum sema does not
   have, so those machines give no state sequence.
2. The gate, then the merge (the launch's deployment spoke). The first
   clause, no error on the page over any window, held on production on
   2026-10-25 for spruce through the present on its `jm/spruce-unlimbo`
   data; the second is George's read of the time series.

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

## Landed

Short pointers; the durable facts live where they point.

- The journalkeeper checks every report's rows against the layout in
  force and journals a daily Warning glitch on a drifted `channel_id`;
  every row's `channel_type` is a `gw.channel.kind` value; observed
  weather readings are written to their rows (gridworks-journalkeeper
  executor `persistor.md`).
- The csv and the bundle read a channel's lineage across layout eras in
  the newest row's unit; the bundle's state sequences read every state
  row by (enum, version); state rows are picked by kind; the bundle and
  messages routes answer in wire form (gridworks-web-backend executor
  `primary.md` "The readings csv and bundle"; changelog 2026-10-23 to
  2026-10-25).
- The frontend's bundle types match the words and are named by them
  (gridworks-web-frontend changelog 2026-10-25).
- `gw.channel.kind` and `gw.house.control.mode` are published (sema
  `7b9fe15`); the production rows were relabelled 2026-10-25
  (gridworks-infra `databases/journaldb.md` "Data changes run by hand").
- Backend `a2733fd` on web-api2 and frontend `ec8934c` on Pages since
  2026-10-25 22:12 UTC; the two 013 windows (oak 04:00–08:00 UTC, spruce
  04:30–07:30) plot from `tsdb_tap` with no page error, and spruce's
  live page reads through the present.

## Open

- Which families the three catch boxes cover; a family not among them needs
  a simulated asset (or a later box) to meet the bar.
