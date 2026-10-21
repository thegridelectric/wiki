# port-v1-visualizer-to-v2

Status: Draft · Pass 0 · Updated 2026-10-20 · Linear: [OPS-611](https://linear.app/gridworks/issue/OPS-611)

**EDD: no** verified by the repo suite plus one test per ported plot
that builds the plot payload from journaled rows, and by the v2 page
drawing each plot for oak over a window with a real FLO run in it.

> What this is: the v1 visualizer routes in `api/backend_api.py`
> (`get_plots` with `get_data` and the eleven `plot_*` builders,
> `get_flo`, `get_csv`, `get_messages`) are ported to v2 routers that
> read the Timescale journal through `gw_data`'s models and decode
> through the vendored sema snapshot, and the v1 code is deleted. The
> price plot is rebuilt from the journaled `flo.params.house0` rows,
> per house, with a gap for every hour no FLO run covers.

**Parked (2026-10-20).** Not scheduled until the real price service
(OPS-437) exists and LTNs publish FLO params again. See "Why".

## Why

The production page calls only the v2 routes (`summaries`, `messages`,
`synced.readings.bundle`); the web-api2 request log over a day shows
nothing else. The v1 routes are still registered in the same process,
but their engine connects to a Postgres named `journaldb` on
`localhost`, and web-api2 runs no Postgres. Every v1 call fails at
connect. `plot_prices`, `get_flo` and the whole of `get_data` are dead
code on the box, and the old visualizer that called them
(`gridworks-web-frontend`, pointed at `web-backend.electricity.works`)
is a different box and a different page.

A price plot drawn from FLO params is still the right design for the
price panel: every FLO run publishes the exact prices the house
optimized against, the journalkeeper captures `flo.params.house0`
(v000 to v007) into `gridworks.messages`, and the v2 `flo.download`
router already makes the per-house query against it. But it needs a v2
route and a plot slot in the v2 page, and today there is nothing to
plot: no LTN has published params since the spring. Oak's LTN gets its
forecast from the stopgap price service and then stops before the FLO
("Not enough tank temperatures available", 2026-10-20 09:41 ET); the
other LTNs never reach the forecast fetch today (maple's forecast file is from 2026-03-31; its log shows the layout step each cycle and nothing after). The
journal's last rows are from 2026-03-31 (maple) to 2026-06-01 (elm,
fir).

Porting all of v1 rather than one plot is the honest unit: the plots
share `get_data` and its hand-read `report.event` state lists, which
is the OPS-542 cleanup, and a single ported plot would leave the dead
engine and the other ten builders in place for the next design to
trip on.

## The rule

- **Source for prices.** `gridworks.messages` rows of type
  `flo.params.house0` from the house's LTN alias, over the plot window
  extended 48 h back so a run before the window start can cover its
  first hours. The query the v2 `flo.download` router makes.
- **Stitching.** For each hour in the window, take the most recent row
  whose `ParamsGeneratedS` is at or before that hour and whose horizon
  from `StartUnixS` covers it, and read `LmpForecast[i]` and
  `DistPriceForecast[i]` at that hour's index. This is the price the
  house believed going into the hour. Each run leaves two rows with
  the same `FloParamsUid` (graph minute and bid minute) and the same
  prices, so latest row per hour is correct without dedupe.
- **Gaps are explicit.** An hour no row covers is `null`, drawn as a
  break. A house with no rows in the window gets the plot with a note
  "no FLO ran in this window", which is the signal that the house was
  not in LTN mode.
- **Units.** `PriceUnit` on the row, through the enum, into the axis
  label.
- **Sema at the boundary.** `flo.params.house0` and its closure join
  the API seed and are decoded through `api/sema`'s codec with an
  `isinstance` narrow, in place of the gridflo class built from a raw
  dict. Interior series records are typed structures with a note
  naming the missing word.

## Out

- A settled-price series beside the as-seen series: a word for OPS-437.
- Any change to the LTN, the scada or the stopgap service.
- The `web-backend.electricity.works` instance: whether it is up and
  what to do with it is an infra question, raised separately.

## Open

- Which repo holds the v2 page, and whether it has a plot slot per
  installation today.
- Whether the v2 shape is one route per plot or one bundle, as the
  readings bundle is.
- The first gw-wrapped `flo.params.house0` row to reach the journal
  live: every stored row predates the 2026-06-09 LTN change, and the
  path is proven only by the LTN glitches that take it. Confirm with
  one query before relying on it.

## Plan

Open until unparked. The price plot alone was sized at 1.5 h against
v1; the port is larger and sized when the v2 page is in hand.
