# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-frontend` code repo**. The matching git commit (in
`gridworks-web-frontend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-25 — price plot axis reaches the forecast (`0af0813`, OPS-623)

**What:** the price plot's x-axis range ends 48 hours past the window end,
where the forecast hours are.

**Why:** the default plot layout fixes the x range to the window, so the
forecast hours kept past the window end drew outside the visible axis and
the plot came up empty.

## 2026-10-25 — price panel draws 48 hours past the window (`86d29f0`, OPS-623)

**What:** the panel keeps the forecast hours from the window start to 48
hours past its end, as the v1 panel did, and the empty note says "near this
window".

**Why:** the stopgap's forecast begins at the next full hour, so a window
ending at now, the page default, had no forecast hour in it and the panel
showed only the note. Drawing the forecast ahead of the window is what the
panel is for until a price series over the window exists.

## 2026-10-25 — price panel reads the backend's forecast (`866d79f`, OPS-623)

**What:** `src/sema/StopgapPriceForecast.d.ts` types `gw.stopgap.price.forecast`
000; `pricing-api.ts` fetches `/api/v2/price-forecast/latest` through the
session client, keeps the forecast hours inside the chosen window and adds
Total as a browser-side sum of LMP and delivery. The panel says "No price
forecast for this window" when no forecast hour falls in it. The direct
POST to the retired price service path is gone, and the panel no longer
takes an installation.

**Why:** the price service's visualizer path went with the PriceDb box, so
every plot showed "Pricing request failed: NetworkError". The browser reads
a sema word the backend serves, per the seam rule; the forecast covers the
next 48 hours, so a window in the past gets the note rather than an error.

## 2026-10-25 — the bundle types are the words (`fbb6794`, OPS-542)

**What:** `src/sema/SyncedReadingsBundle.d.ts`, `ChannelReadingsListItem.d.ts`
and `OperatingStateSequence.d.ts` match `synced.readings.bundle` 003 and its
items field for field (TypeName, Version, AboutGNodeAlias, UnitType, null
grid points in a ValueList), named by the word; the visualizer imports them
under those names.

**Why:** the hand-kept types had drifted from the words the backend serves
(fields missing, nulls typed away), and a type named for an API response
hides that it is a word. Checked on the page against `tsdb_tap` for the
013 cutover windows (OPS-542).

## 2026-10-22 — houses keyed by TaGNodeId; summaries as gw.house.summary; layouts 011 through 013 (`3d514bb`, PR #8, OPS-473)

`src/sema/` mirrors `gw.house.summary` and `gw.house.operating.status`
by hand until the sema TypeScript target exists; the summary type is
`HouseSummary`, with the word's `TypeName`, `Version` and `SendTimeMs`,
and a field the word allows to be null is optional, since the dict form
omits it. The Houses table's Mode column becomes Status, read from the
operating status as Standby or the service mode, then the top state;
the Information page's Status section shows Standby (with the posture),
service mode, top state and the status's own time. The role checks
compare against the enum's `Admin` and `Owner`. The layout field is
`Layout`. Verified by the dev run,
`experiments/2026-10-21-disentangle-dev-run/`.

## 2026-10-21 — retire installations: the summary as the API returns it; Address and Contact not shown; Hardware and the sieg default from the layout (folded into `3d514bb`, PR #8, OPS-473)

The dashboard follows the web-backend summaries once the `installations`,
`customers` and `installers` tables leave journaldb. The summary type is
retyped to the fields the API returns: `TaGNodeId` joins, `DisplayName`,
`SystemMode`, `MainAutoState`, the snapshot facts and `LayoutLite` are
nullable, and the `HardwareLayout`, `InstallationContact` and
`SpaceheatParameters` types go, since no endpoint returns them. The
Installations table drops its Location column, filter and sort. The
Information page keeps its four sections: Address and Contact read "Not
shown here" until the customer store has a read path (OPS-600), Status
comes from the snapshot facts, Hardware from `LayoutLite`. The real-time
page's default sieg loop is on when the layout has a `sieg-flow` data
channel, and its gateway key is the last segment of `GNodeAlias`, so the
registry's display names can read however gnr likes. The Parameters page
starts from its defaults, since operational params are not on the bus.
`LayoutLite` and the sieg check are typed in `src/sema/` by hand, to the
fields read; a generated snapshot is the open gap at this boundary.
