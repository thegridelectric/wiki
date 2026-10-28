# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-frontend` code repo**. The matching git commit (in
`gridworks-web-frontend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-26 — visualizer hooks above the guard; temperature axes autoscale (`992e798`, OPS-588)

**What:** the auto-refresh hook and the house-change effect in
`VisualizerPage.tsx` move above the session guard with the other hooks.
The heat pump and secondary loop panels' temperature axes take the
offset range form the Storage panel uses (20 °F either side of the data,
clamped to 0 to 260) in place of a fixed 0 to 260.

**Why:** the two hooks were the last below an early return, which the
rules-of-hooks lint flags and React does not define. The fixed range was
the OPS-568 and OPS-593 stopgap for data that fell off the old 30 to 70
axis; autoscaling fits whichever house is plotted.

## 2026-10-26 — front-end fixes from the OPS-588 sweep (`4038ca7`, OPS-588)

**What:** Thomas's `td/dev` branch squash-merged as PR #14 (the title is
GitHub's default, "Td/dev (#14)"); the branch keeps the fourteen commits.
Deployed to GitHub Pages by the `main` push. Per sub-issue:

- OPS-591 "Network Error": the API interceptor surfaces the server's
  `detail` string, or the HTTP status, where axios said only "Network
  Error". The request timeout goes from 5 s to 10 s so a slow login is
  not cut off.
- OPS-562 / OPS-625 auto-refresh: the button works again, keeps the
  user's start time and advances only the end time to now, every 30 s.
  The hook reads its callbacks through refs so a re-render does not
  restart the timer, which was the once-a-second refresh.
- OPS-593 secondary loop panel: the fixed temperature range widens to
  0 to 260 F so spruce's secondary temperatures are on the axis. A fixed
  range; autoscale is the open item.
- OPS-568 heat pump panel: same range change on the heat pump panel.
- OPS-604 / OPS-567 sieg flow: with a sieg loop in the layout, primary
  flow is `sieg-send` at or above 0.5 gpm, not `primary-flow`; buffer
  water no longer animates when only the sieg loop runs.
- OPS-627 maple heat pump animation: heat pump power is the sum of the
  indoor and outdoor units with a missing reading read as zero, so one
  missing channel no longer hides the animation.
- OPS-560 spruce real-time: a secondary pump row in the flow table and
  a split heat pump header whose secondary leg animates toward the store
  or the buffer by the charge relay. Keyed on the house being spruce;
  the layout-keyed version waits for elm (OPS-622 "The real-time page").
- OPS-626 gw-temp zones: thermostat names ending `-gw` are filtered in
  the browser. The gateway derives them from channel names while every
  layout since 011 has `ZoneList`; the gateway fix is the durable one.
- OPS-624 secondary EWT/LWT on the visualizer: Thomas's sub-issue closed
  with a data check and no code change here.
- Real-time header shows "Connecting..." until the first status message
  for the selected house arrives, instead of the previous house's data.
- The five `useRef` calls in `VisualizerPage.tsx` move above the session
  guard, with the other hooks; a hook below an early return trips the
  rules-of-hooks lint and is undefined behaviour in React when the guard
  flips. The auto-refresh hook and one effect below the guard predate
  this branch and wait for a change that hoists the functions they close
  over.

**Why:** the first pass over the operations issues George filed against
the web app since September, taken as one hot fix so the fleet has it for
the elm bring-up. The per-house and name-matching patterns it adds are
recorded in OPS-622 for the comb-through rather than cleaned here.

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
