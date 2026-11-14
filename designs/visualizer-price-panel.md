# Visualizer price panel

Status: Accepted · Pass 1 · Updated 2026-11-13 · Linear: OPS-666

**EDD: yes** the panel on the visualizer page draws, for a window that
spans a day-ahead publication, the price forecast the house's FLO ran on
at the window start, from the journal alone, against the backend on
`tsdb_tap`; and the price forecast id in a journaled `flo.params` names a
journaled forecast whose prices equal the lists in that `flo.params`.

> What this is: the dashboard's price panel shows the LMP forecast a
> house's FLO actually optimized against, as of the start of the window,
> on the same time axis as every other panel, with the tariff's on-peak
> hours shaded. To make that possible the price-forecast service changes
> from a pull-on-request builder to a publication-driven emitter whose
> forecasts reach the journal with a stable id, the LTN names that id in
> `flo.params`, and the new forecast word states prices the way every
> other market word does: integers scaled by 1000 with a declared unit.

## Why

Today the panel draws whatever the stopgap price service holds at the
moment the page loads: the next 48 hours from now, the same for every
house, as three series (LMP, delivery, total) on two axes. For a window in
the past it draws nothing. None of that is what the viewer wants to know,
which is the price the house was planning against.

The service builds a fresh forecast whenever an HTTP request arrives in a
new hour. It mints a new `PriceUid` on every rebuild, so one day's
published prices get about 24 different ids, and the id reaches nothing:
the LTN decodes the response as a dict and copies the two lists into
`flo.params`, which has a `WeatherForecastId` and no price forecast id
(the retired `flo.params.house0` had a `PriceForecastUid`). The service
has no broker side, so no forecast is journaled; the journal has the
`latest.price` words from the MarketMaker and the price lists inside each
hour's `flo.params`, and nothing else about price.

The published prices arrive once a day. ISO-NE posts the next operating
day's day-ahead hourly LMP between about 12:40 and 13:30 ET, with rare
days hours later ("Findings" below). Everything between publications is
the same forecast with its past hours trimmed, so one forecast per
publication is the natural unit, and the day-ahead prices change little
enough that the panel needs no layered forecast like the weather panel's.

## Decisions (2026-11-11)

- **The series shown is the forecast a FLO used.** The price service
  broadcasts each forecast; the journalkeeper journals it; the LTN names
  the forecast's id in `flo.params`; the backend joins the two. When the
  chosen heater has no `flo.params` for the hour, the panel falls back to
  the service's forecast in force at that hour. The service is improved
  exactly as far as that fallback needs: a forecast provably exists for
  every hour.
- **One forecast per window.** The panel draws the forecast in force at
  the window start. No layering.
- **One trace, one vertical axis.** The panel draws the forecast price,
  which is the full price the LTN expects to face. The tariff's on-peak
  hours are indicated by light pink blocks over those times.
- **A forecast is one price per slot for one product (2026-11-12).** The
  FLO optimizes against the sum and makes no decision on how the price
  divides, so the forecast word has one price list and no parts, and
  `flo.params` has one price list. The parts stay in `latest.price`,
  the actual price, whose recipe the MarketMaker owns. What went into a
  forecast is a question asked after the fact and is under "Open".
- **The time axis is the page's.** The price panel's x range is the
  window's range, as on every other panel.
- **Prices are integers with a declared unit.** The forecast word states
  each hour's price as `...X1000` integers with a `PriceUnit` from
  `market.price.unit`, the spelling of `price.quantity.unitless` 001 and
  the bid words; `latest.price` 001 and `price.component` take it too
  (2026-11-13). `flo.params` keeps its
  per-step lists as floats in USD/MWh, as its other lists are.
- **`latest.price` is the full price the LTN faces.** It is the price
  that determines the contract between the LTN and the MarketMaker, so
  it includes every sub-stream the LTN faces at its node. A
  wholesale-only meaning for it was proposed and rejected. The
  MarketMaker's job is to become, piece by piece, a DSO: an external
  market structure (ISO-NE) may price differently from what the
  MarketMaker's own market faces, and turning the one into the other is
  the MarketMaker's work. How the parts stay separable inside that one
  price is under "Open".
- **The parts of a price are named by one enum, with coincident peak in
  it from the first version.** Members: wholesale energy, wholesale
  congestion, wholesale loss, delivery, `CoincidentPeakTransmission`
  (the monthly peak) and `CoincidentPeakCapacity` (the annual peak). A
  coincident-peak part's price in a slot is assigned from a probability
  assessment that the slot is a coincident peak. That monthly allocates
  transmission and annual allocates capacity in ISO-NE is unverified.
- **One MarketMaker identity per priced node.** A MarketMaker exists
  wherever a distinct price forms: an ISO-NE PNode, and later a
  distribution constraint below one. A market is then named fully by
  its MarketMaker's alias and its product, and the upstream pricing
  point a MarketMaker faces is a fact about that MarketMaker. Whether
  one application hosts several MarketMaker identities is a deployment
  choice the words do not depend on, since they address a MarketMaker
  by its alias.
- **The forecast word is `gw.price.forecast`.**
- **The tariff is a property of the market.** A market declares one
  tariff, and its price is the full price for every bidder on it.
- **The enum of price parts is `price.component.name`**, with no `gw.`
  segment.
- **The on-peak hours reach the browser in the layout (2026-11-13).**
  Both panels shade the tariff's on-peak hours, and the FLO plot loses
  the implicit signal when `flo.params` 002 folds the delivery list
  into one price. The scada states its tariff in `layout.lite` 014,
  copied from its ops word, and the house summary names that version,
  so the browser reads the tariff off the installation it already has.
  Considered and declined: a `Tariff` in `flo.params` (a plotting fact
  in the optimizer's request word, permanent once 002 publishes, and
  copied into every hourly request); journaling the ops word (the right
  source later, but it will change rapidly for a month and is not
  publishable); a house-and-time route over the hand-kept fleet
  constant (correct only once the ops word is journaled). The ops
  word's `Tariff` prose is corrected at the same time: when the LTN is
  the boss, local control is dormant and the tariff's windows are
  nothing to it beyond the price.

## The market, as claimed and as run (2026-11-13)

**Decision: the Keene market's product is `rt60gate1`.** Real-time
energy, 60-minute slots, gate closing 60 s before the slot. The value is
added in `gw.market.product.name` 001 (staging), and the two words that
name a product, `gw.price.forecast` and `gw.operational.params`, take
that version. The MarketMaker's `market_product`, the price service's
`product_name` and every house's `MarketProductName` in tlayouts move to
it. The slot names change with the product, so the Keene `latest.price`
series under `rt60gate5` ends and a new one begins under `rt60gate1`;
the backend's real-time route takes the market prefix as a parameter
and follows it.

**Why.** Both services claimed `rt60gate5`, a gate closing 300 s before
the slot, and `market.product` 000 spells the same numbers out as
`SlotDurationMinutes` and `GateClosingSeconds`. The LTN asks the FLO
`bid_lead_s` = 180 s before the slot and sends its `bid` off the answer;
the FLO answers in about 10 s (oak, 2026-11-11: `flo.params` at
18:57:07Z, `flo.recommendation` at 18:57:17Z). Bids therefore reach the
maker about 170 s before the slot, after the gate the name claimed.
Moving the practice to a 300 s gate (a 420 s lead) was weighed and
declined: it changes the LTN's timing for no gain, since clearing today
takes the price from ISO-NE and the tariff and a book-reading engine
would also finish in milliseconds. A 60 s gate leaves the bid about
110 s of slack against a FLO stall, the same budget the other option
had. The maker today receives bids and drops them; booking and acking
them, with the gate enforced on dequeue, is OPS-431's work.

## The price service, reshaped

The service's job becomes: notice a publication, build one forecast from
it, emit it once, and serve views of it until the next publication.

- **Publication-driven fetch.** ISO-NE's `hourlylmp/da/final/info`
  endpoint returns `LatestBeginDate` and `CreationDate` for the latest
  posted day, so one cheap call tells the service whether tomorrow is
  posted and exactly when it was. From 12:30 ET the service polls `/info`
  every few minutes until `LatestBeginDate` reaches tomorrow, then fetches
  the day; before 12:30 and after a successful fetch it checks hourly, so
  a day posted at 20:00 is still caught. A day not posted by 13:30 is
  treated as late; the service keeps polling and raises nothing.
- **One forecast per publication, stable id.** The forecast document is
  the whole published horizon from the next hour: today's remaining hours
  and tomorrow's, extended beyond the last published day by hour-of-day
  repeat as now. Its id is minted once. The hourly view the LTN pulls is
  cut from the kept forecast and names the same id; a new id appears only
  when ISO-NE publishes (or the service starts with nothing kept).
- **Broadcast.** Each new forecast is published onto the hw1 broker as the
  weather service publishes its forecasts; the journalkeeper journals it.
  The service grows a rabbit side; its auth posture is the OPS-437 hub's
  open question and this design takes the weather service's answer until
  that hub decides otherwise. The HTTP routes stay for the LTN's pull.
- **As built.** The kept document is 72 hours from the next hour and
  the view is its next 48; a new document is also built when the kept
  one can no longer fill a 48-hour view. The word does not say which
  ISO-NE posting a forecast came from, so the service keeps that beside
  the document in a small basis file (the posting time and the count of
  hours ISO-NE itself published). The basis word in "Open" retires the
  file.

## Vocabulary

Governed by `sema-CLAUDE.md`: spec first, read-receipt, registry rules.
Shapes here are confirmed (2026-11-11) and are what the sema change
starts from. New words are
authored `staging`, exercised on the dev broker, and promoted before
anything on `hw1` sends them.

- **`price.component.name`**, a versioned string enum, 000. It names the
  parts of a price. Values, in order: `Unknown` (the default: a part
  this version cannot name, whose price still counts in the total),
  `WholesaleEnergy`, `WholesaleCongestion`, `WholesaleLoss`, `Delivery`
  (what the utility bills for delivery under the tariff),
  `CoincidentPeakTransmission`, `CoincidentPeakCapacity`. The name
  follows `market.type.name` and `gw.market.product.name`; it has no
  `gw.` segment because `latest.price` refers to it and that word is
  uniform across makers. A maker with another part appends a value.
- **`price.component`**, a type, 000: `Name` (the enum) and
  `PriceX1000` (integer), one part of one price.
- **`latest.price` 001** (000 is published, so this is a new version).
  `PriceX1000` is the full price the bidder faces and the price of the
  contract; 000 spells it `PriceTimes1000`, and the bid words'
  `price.quantity.unitless` 001 spelling is the one every price word
  converges on. Added: `Components`, a list of `price.component`;
  `TariffAlias` (`left.right.dot`), the tariff the `Delivery` part is
  computed under; `CreatedMs`. Axioms: the components' prices sum to
  `PriceX1000`; no `Name` other than `Unknown` appears twice;
  `TariffAlias` is present exactly when a `Delivery` part is. The
  upgrade from 000 assigns one `Unknown` component with the whole
  price, since a 000 instance does not say how its price divides.
- **`gw.price.forecast`**, a type, 000, replacing
  `gw.stopgap.price.forecast`. It forecasts the price a MarketMaker
  will publish in `latest.price` for one market, slot by slot. Fields:
  `FromGNodeAlias`; `MarketMakerAlias` and `ProductName`
  (`gw.market.product.name`), which with a slot start give that slot's
  `MarketSlotName`; `ForecastUid` (uuid4, the name `gw.weather.forecast`
  gives its own id); `CreatedMs`; `SlotStartS` (`utc.seconds`);
  `PriceUnit` (`market.price.unit`); `PriceX1000List`. Axioms:
  `SlotStartS` is non-empty, strictly ascending and on the 300-second
  grid; one price per slot. Slot starts in UTC seconds leave nothing
  for the word to say about the 23-hour and 25-hour days.
- **`flo.params` 002** has one `PriceUsdMwhList` where 001 had
  `LmpUsdMwhList` and `DistUsdMwhList`, and gains `PriceForecastId`
  (uuid4), the `ForecastUid` of the `gw.price.forecast` the list was
  read from, required as `WeatherForecastId` is. It is in the first
  sema change, because the panel finds its forecast through this id.
  The upgrade from 001 refuses for want of context: a 001 instance does
  not say which forecast its prices came from. The one list reaches the
  optimizer, which reads the two lists and adds them today.
- **The journalkeeper's seed** takes `gw.price.forecast` and
  `latest.price` 001 so both are journaled.
- **`layout.lite` 014** adds `Tariff` (`gw.tou.tariff` 000), required:
  the time-of-use tariff the home is billed on, as the running scada's
  operational params state it. The 013 upgrade refuses for want of
  context. 013 gains the example a superseded version must have.
  **`gw.house.summary` 003** accepts 014 in `Layout`. Both staging.
- **`gw.operational.params` 000** (staging, in place): `Tariff` and
  `UsesBackupWhenCold` state their own meaning. The old prose said the
  heat pump is held off during on-peak hours, which is local control's
  behavior when it is in charge and not the tariff's meaning.

Until a tariff word with prices exists ("Open", the tariff tracking
item), the MarketMaker and the price service each compute the
delivery price from a hand-kept copy of the A-1 table, corrected to the
Seventeenth Revision, with a note beside each naming the missing word.
The MarketMaker states it as the `Delivery` part of `latest.price`; the
price service adds it into the forecast price.

Known tension, undecided: the tariff's delivery charge includes retail
transmission as a flat amount per kWh, and `CoincidentPeakTransmission`
prices the same upstream cost by its peak. A price with both counts
transmission twice unless the recipe nets one against the other. No
coincident-peak part is priced until that recipe is decided.

## LTN

The LTN decodes the forecast through its vendored snapshot instead of
`data["LmpList"]`, keeps the decoded word, and writes its price list
and its id (`PriceForecastId`) into every `flo.params` it builds from
it. The optimizer reads the one list. The
hand-kept `price_forecast.csv` goes with the dict.

## Backend

One route answers "the price forecast for this house at this hour":

1. The `flo.params` journaled for the house at the window's first hour
   names a `PriceForecastId`; return that journaled forecast.
2. Otherwise the journaled forecast with the greatest `CreatedMs`
   at or before the window start; the stopgap's live route is the fallback
   only until forecasts are journaled.
3. Otherwise nothing, and the panel says so.

The response is the forecast word, with a note of which rule chose it (a
small sema enum, derived here, sent as data). The on-peak hours are a
fact of the tariff and reach the browser inside the house summary: the
summaries route serves the house's latest layout row, and a
`layout.lite` 014 row states the house's `Tariff`. The fleet's one
tariff at `GET /api/v2/tou-tariff/current` is the fallback for a house
whose latest layout is older than 014, with a note naming the version
that retires it.

## Frontend

`PriceForecastPlot.tsx` draws one trace, the forecast price in USD/MWh
(divide the integers by 1000 at render), on one y axis; light pink rectangles over
the on-peak spans the browser lays from the tariff word over the window's
range; the x axis range set from the window like the other panels. The
vendored `.d.ts` for the new word types the response. The tariff word
is the installation's `Layout.Tariff` when the layout is 014, else the
fallback route's. `FloPlot.tsx` (OPS-665) lays the same spans over its
horizon from the same tariff, which replaces the on-peak signal the
delivery list gave before 002.

## Plan

**Do this next:** step 5, the web backend's forecast-for-house-and-hour
route (rule 1, then rule 2), with the `gridworks-flo` dependency
removal. The service and both LTNs deploy in one cutover after the
words are promoted: the service's legacy route serves the new word, so
an LTN on the old code breaks the moment the service ships, and an LTN
on the new code has nothing to read until it does.

**Where the build stands (2026-11-13).** Steps 1, 2 and 3 are done on
branches.

- **sema**: on `dev` at `115aea2` (the price words in `ebbc627`); the
  earlier `jm/price-forecast-one-list` at `95a63bc` (its title is
  "squash"; it wants a real title when the branch is squashed). All the
  new words are `staging`. Its parent `eba7ece` is on local `dev` and
  not pushed.
- **price service**, `jm/price-components` at `92d04c4` plus the regen below.
  It was exercised on the dev broker: one `gw.price.forecast` broadcast
  per ISO-NE posting, 72 slots, and a 48-slot view under the same id on
  both HTTP routes. Its snapshot is vendored with `--allow-staged` at
  the renamed field.
- **FLO**: `gridworks-flo` `0ff6a75` and `optimal-flexibility`
  `ec2675a` on `jm/price-forecast-word`; the optimizer reads the one
  list.
- **LTN**, both copies on `jm/price-forecast-word`: the live one in
  `gridworks-scada/gw_spaceheat/actors/ltn/` and the gwbase port in
  `gridworks-ltn`. Each decodes `gw.price.forecast` from the service's
  route, keeps the word's bytes in its data dir as the copy it reads
  when the service is unreachable, and builds `flo.params` 002 from the
  forecast's slots starting at the request's own; a forecast without
  that slot refuses the request. The scada's protocol twins moved with
  its snapshot (`FloParams` 002, `PriceForecast`, the product name
  enum 001). The scada's commit is `a9f6ba88`; the port's is pending.
- **journalkeeper**, `jm/price-forecast-word`: the seed takes
  `gw.price.forecast` (journaled on its own id and clock) and
  `layout.lite` 014; 013 moves to the old versions and the 014 row is
  projected like a 013 row. Gate green, commit pending.
- Everything stays off `hw1` until the words are promoted. The price
  service does not merge to `main` before then.

Gaps left in the price service: the actor has no test in CI (it needs
a broker), and CI does not run mypy. A gap left in the LTN: the request
does not check that the forecast's `MarketMakerAlias` and `ProductName`
are the LTN's own market; the LTN has one market today and the check
belongs with the word that names it.

**Where the page stands (2026-11-11).** Both `jm/price-panel-lmp`
branches are merged and deployed: the backend's `gw.tou.tariff` route on
web-api2 and the panel on GitHub Pages. The panel has the final shape
(LMP alone on one axis, the page's time axis, the on-peak shading) and
keeps only the stopgap forecast's hours inside the window. The stopgap
has no past, so for the default window, which ends at now, the panel says
"No price forecast in this window". That stays until step 5 serves a
journaled forecast; a rollback was considered and declined. The lesson
for step 6: the frontend check is on the page with the default window.

**How the panel finds its forecast.** The panel looks first at the
`PriceForecastId` in the `flo.params` journaled for the house at the
window's first hour and draws the journaled forecast with that id
(the backend's rule 1). That needs the whole chain: the word, the
service journaling forecasts with a stable id, and the LTN naming the
id. Only oak journals `flo.params` today (since 2026-11-03); the other
five LTNs have journaled nothing since June 2026. A house with no
`flo.params` for the hour gets rule 2, the service's forecast in force
at that hour, so every house draws once the service ships.

Ordered by dependency; each step is a spoke if it outgrows a section.

1. **sema**: `price.component.name`, `price.component`, `latest.price`
   001, `gw.price.forecast`, `flo.params` 002, the journalkeeper seed.
2. **price service**: publication-driven fetch on `/info`, one forecast
   per publication with a stable id, the broadcast, the new word on both routes, the A-1 table at the
   Seventeenth Revision.
3. **LTN**: decode the word, write its price list and its id into
   `flo.params` 002; the optimizer in `gridworks-flo` reads the one
   list.
4. **MarketMaker**: `latest.price` 001 with its parts, the A-1 table at
   the Seventeenth Revision.
5. **web backend**: the forecast-for-house-and-hour route (rule 1, then
   rule 2), the `gridworks-flo` dependency removal in the same change
   (nothing imports it; it pins an editable checkout on web-api2 that
   is to be deleted).
6. **web frontend**: the panel reads that route; the stopgap fetch goes.
   Checked on the page with the default window before the PR.
7. **The real-time price.** The MarketMaker publishes a `latest.price`
   word at each hour's start for the Keene `rt60gate5` slot, sourced
   from ISO-NE's `fiveminutelmp/current` at location 43790 plus the A-1
   total delivery price for the hour, so each row is a summed retail
   price, with the five-minute LMP in force when the hour began as its
   energy part and no way to recover the parts from the word; the
   journal has them since 2026-10-22 with no gaps (477 rows for 477
   slots on 2026-11-11). `latest.price` 000 and `market.price.unit` 000
   are published. A backend route in the weather route's shape returns
   the window's rows for a market slot prefix; the browser draws a
   second step trace, "Real-time" beside "Day-ahead", the slot start
   from the last segment of the `MarketSlotName`. The market prefix is a
   route parameter; until a house's `flo.params` names its market the
   browser passes the fleet's one, with a note naming the word that
   retires the constant.

8. **The product name.** sema: `gw.market.product.name` 001 with
   `rt60gate1`, the two referrers on it, staging. Then the MarketMaker
   and price service config lines, and the tlayouts gen change rolled
   to every house by `roll.sh`, all in one cutover so no service names
   a product the others do not. The gate and the ack are OPS-431's.

9. **The tariff in the layout.** sema is done on `jm/flo-params-tariff`
   (layout.lite 014, gw.house.summary 003, the ops prose, the 013
   example). The rest waits until every consumer's sema snapshot is
   regenerated for the words above, then in dependency order:
   1. **scada**: the `layout_lite` property in `actors/scada.py` fills
      `Tariff` from `self.ops.Tariff`; the protocol snapshot takes 014.
   2. **journalkeeper**: done on `jm/price-forecast-word` (014 in the
      seed and the layout union; the layouts table stores the payload,
      so no schema change). `gw.house.summary` is the backend's word,
      not the journal's.
   3. **web backend**: snapshot takes 014 and summary 003; the summaries
      route decodes 013 and 014 rows and emits summary 003; the fleet
      tariff route gets its retiring note.
   4. **web frontend**: vendored zod for 014 and summary 003; the price
      panel and the FLO plot read `Layout.Tariff`, else the fallback
      route. Checked on the page against a 014 row.
   Promotion of 014 and summary 003 (and their staging closure) before
   any of this reaches `hw1`.

Related work by issue: OPS-437 owns the price service's standing as a
gwbase GNode and the tariff vocabulary; OPS-611's per-house price plot
from `flo.params.house0` is superseded for the new `flo.params` by this
design; OPS-665 is the pattern (the browser draws the published word).

## Open

- The service's broker auth posture (OPS-437's question).
- What went into a forecast. The forecast word states the price and
  nothing about its making: the ISO-NE posting it was built from, how
  many of its hours are ISO-NE's own and how many are repeats, the
  tariff revision behind the delivery price, and later a model's
  inputs. These do not sum to anything, so they are not parts of the
  price. The candidate is a separate basis word keyed by `ForecastUid`,
  journaled beside the forecast. Until it exists the journal tells a
  forecast built before tomorrow's posting from one built after it only
  by its `CreatedMs`.
- The 25-hour and 23-hour days at the DST changes: ISO-NE labels the
  repeated fall hour `02X` in its reports; how the Web Services API
  represents it is unverified.
- What the panel shows for windows before journaling began: the
  `flo.params` lists themselves, or nothing.
- Tracking the actual tariffs over time and historically, and where and
  how the auditable evidence backing the distribution prices is kept.
  Handled later, and before the move out of the hybrid `hw1` world into
  a `w` world that is used to exchange money. The standard is for data
  from its start onward and is not applied to old stale data. Today the
  record is prose (`wiki/regulatory/versant/tariffs.md`, with a
  prior-revisions table and source links) and two hand-kept code tables.
  Recommendation on file, a chain of three links that someone outside
  GridWorks can check:
  1. Each tariff revision is a journaled word with its effective date,
     revision number and docket, and its rates by part and period as
     integers. The sequence of these words in the journal is the
     history.
  2. The word names its evidence by content: the SHA-256 of the approved
     tariff sheet PDF, with the page and source link. The PDF is stored
     under that hash, because the utility's links change with each
     filing.
  3. The delivery part of each `latest.price` names the tariff revision
     it was computed from, so a contract price traces to a filed sheet.

  Two sub-questions: who publishes the tariff word (the MarketMaker
  declaring the tariff of its market, or a registry record), and where
  the PDFs are stored (the eventstore bucket, keyed by hash, is the
  candidate).

## Findings: ISO-NE day-ahead publication timing (2026-11-11)

Three independent sources, recorded as found.

### Web research (Opus subagent report, lightly trimmed)

Short answer: bids close at 10:30 ET, the tariff deadline for posting
results is 1:30 p.m. ET, and results usually post between about 12:40 and
1:10 p.m. On rare days they post hours later.

**(a) Scheduled time**

- Manual M-11 Rev 62 (effective 2025-02-28), §2.2.1 sets no clock time
  for posting: "10:30 a.m. — Day-Ahead Market submission period closes…",
  then "Upon Completion of the Day-Ahead Market — The Day-Ahead Market
  hourly schedules and Day-Ahead Prices are posted and the Re-Offer Period
  begins."
  https://www.iso-ne.com/static-assets/documents/100020/m_11_revision_62_effective_02_28_25.pdf
- The tariff deadline comes from Market Rule 1 §III.1.10.8(b), quoted in
  a 2020 filing: "[n]ot later than 1:30 p.m. of the day before each
  Operating Day . . . the ISO shall: … (ii) post the Day-Ahead Prices".
  https://www.iso-ne.com/static-assets/documents/2020/07/extend_0_to_30_da_em.pdf
- ISO Newswire says the 2020 change to a 10:30 close kept that deadline:
  "The ISO will still be required to clear the market and post results by
  1:30 p.m. each day." https://isonewswire.com/?p=3896
- The current tariff text could not be read (the download returned HTML
  instead of the PDF), so "1:30 p.m. is still in force" is unverified. The
  M-11 10:30 close is verified.

**(b) Observed timing and how late it runs**

- The 2020 filing says: "usually between 12:00 p.m. and 1:00 p.m." and
  "since the start of 2019, … posted day-ahead results within three hours
  [has] increased to 99.1%." Those figures predate the 10:30 close.
- The ISO Express listing for Oct 27 to Nov 10, 2026 shows 12:39 PM to
  1:31 PM, with most days between 12:45 and 1:10. Two rows: "11/02/2026
  12:39 PM EST" and "11/03/2026 01:31 PM EST".
  https://www.iso-ne.com/isoexpress/web/reports/pricing/-/tree/lmps-da-hourly
- The 1:30 deadline is not a hard limit. On Jan 26, 2026 a market notice
  was posted at 4:17 PM: "a technical issue that is preventing the
  completion of the Day Ahead Market process"
  (https://www.iso-ne.com/event-details?eventId=161852). Another followed
  at 6:02 PM: "approximately two hours to clear the DAM"
  (https://www.iso-ne.com/event-details?eventId=161853). Results that day
  therefore came around 8 PM.
- On DST: ISO-NE MIS reports label the extra fall-back hour "02X". How the
  Web Services API represents it was not verified, so expect a 25-row day
  in November and a 23-row day in March. Source: the ISO-NE DST notice as
  summarized in search results; the notice itself was not opened.

**(c) What the API exposes**

- The Web Services v1.1 docs list only `da/final` paths for day-ahead.
  They include `/hourlylmp/da/final/day/latest` and
  `/hourlylmp/da/final/info`. Preliminary paths exist only for real-time
  (`rt/prelim`). There is no `da/prelim`.
  https://webservices.iso-ne.com/docs/v1.1/
- No field was found in the HourlyLmp schema that records when the data
  was posted (unverified). The schema index on the docs page lists the
  type but not its fields.

**(d) Notifications**

- ISO-NE posts a Market Notice for each day: "Day Ahead Market Results for
  20260410 are now available", posted "Thu Apr 9, 2026 12:36PM".
  https://www.iso-ne.com/event-details?eventId=163043
- Ways to get those notices: email lists, one of which is for
  announcements of issues affecting the markets
  (https://www.iso-ne.com/participate/support/mailing-lists), and website
  subscriptions managed under "My Subscriptions", including web-feed
  options for customer notices (https://isonewswire.com/?p=3402).
- Whether a specific RSS or email channel sends the per-day "results
  available" notice was not confirmed. ISO-NE publishes no push
  notification for the API itself.

**Practitioners**

- gridstatus does not use the Web Services API for day-ahead hourly LMPs.
  It pulls the CSV
  `https://www.iso-ne.com/static-transform/csv/histRpts/da-lmp/WW_DALMP_ISO_{date}.csv`
  (gridstatus `isone.py`, line 555, on GitHub main).
- A search summary said gridstatus docs give "around 13:30 ET" for
  day-ahead availability. The page could not be opened (HTTP 403), so that
  is unverified.
- No forum or blog post was found comparing when data appears in the API
  versus ISO Express. The lag between them is unverified.

**What could catch out an hourly poller**

1. Results normally post between 12:40 and 1:10 ET. A poller that runs on
   the hour checks at 1:00 and gets an empty list on roughly half of days.
   The next check at 2:00 means tomorrow's prices can sit unseen for up to
   an hour. Polling every 5 to 10 minutes from 12:30 to 2:00 ET fixes
   this, with an hourly fallback until midnight.
2. Results can arrive as late as about 8 PM. Treat "no results by 1:30" as
   normal-but-late, not as an error.
3. The 1:30 p.m. deadline is in local Eastern time. If the service
   schedules in UTC, it has to follow EDT/EST changes.
4. `da/final` is the only day-ahead product. An empty list means "not yet
   posted", and nothing marks data as provisional.

### Live probe of the API with the service's account (2026-11-11, 09:xx ET)

```
GET hourlylmp/da/final/info
{"ServiceInfo":{"LatestBeginDate":"2026-11-11T23:00:00.000-05:00","CreationDate":"2026-11-10T13:10:05.000-05:00"}}

GET hourlylmp/da/final/day/latest/location/43790
ISO-NE error 500

GET hourlylmp/da/final/day/20261112/location/43790
{"HourlyLmps":{"HourlyLmp":[]}}
```

So `/info` gives the posting time of the latest published day directly
(operating day 2026-11-11 was posted 2026-11-10 at 13:10:05 ET), the
`/day/latest` path is broken, and an unpublished day is an empty list.

### Journal scan of the LTNs' hourly `flo.params` (2025-11-01 to 2026-11-11)

Method: for every journaled `flo.params` and `flo.params.house0`, compare
tomorrow's (ET) hourly LMPs with today's by hour of day; the first message
of a day where they differ bounds the publication time from above, with
the LTN's hourly fetch as the resolution. 153 days had messages; 148
showed a transition.

| first ET hour with real tomorrow prices | days |
|---|---|
| 11 | 2 |
| 12 | 66 |
| 13 | 71 |
| 15 | 2 |
| other (00, 20) | 7 |

The six days of the current service on oak (2026-11-05 to 11-10) split
three at 12:57 and three at 13:57, so publication fell on either side of
13:00 at the LTN's :57 fetch.

The two 11:xx days (Fridays 2025-11-14 11:24 and 2025-11-21 11:35) and
the 00:xx and 20:xx days are artifacts of the forecast pipeline of that
time and say nothing about ISO-NE posting early: on both Fridays the "tomorrow" values are the
same numbers (113.68, 207.86, 126.80 USD/MWh at 12:00, 13:00, 14:00) and
so are the "today" values, so the forecast then in use was a repeating
weekly template, and the hour at which it changed says nothing about
ISO-NE. In general an hour H in this table means the prices were in the
LTN's forecast at its fetch at H:mm and were not at its fetch an hour
earlier.

The scan script is `da_publish_scan.py` in this session's scratch; it
reads `gridworks.messages` through `DB_ANALYST_URL`.
