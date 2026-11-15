# Visualizer price panel

Status: Accepted · Pass 1 · Updated 2026-11-15 · Linear: OPS-666

**EDD: yes** the panel on the visualizer page draws, for a window that
spans a day-ahead publication, the price forecast the house's FLO ran on
at the window start, from the journal alone, against the backend on
`tsdb_tap`; and the price forecast id in a journaled `flo.params` names a
journaled forecast whose prices equal the lists in that `flo.params`
(met 2026-11-14, "Verified"); and, for the remainder, the MarketMaker
publishes a `latest.price` 001 whose parts sum to the price, the Keene
series restarts under `rt60gate1` with every service on the new name,
and the panel draws that real-time price beside the day-ahead forecast
for a window that spans the cutover.

> What this is: the dashboard's price panel shows the forecast a house's
> FLO actually optimized against, as of the start of the window, on the
> page's time axis, with the tariff's on-peak hours shaded. The chain
> that makes it possible shipped on 2026-11-14 and is now stated where
> it lives: the service in `gridworks-price-forecast/executor/` (its tables),
> the LTN's request in `gridworks-ltn/executor/flo-boundary.md`, the
> route and the panel in `gridworks-web-backend/executor/visualizer.md`
> "Price forecast". What remains here is the market-side remainder:
> the product name, the actual price with its parts, the real-time
> trace, and the scada's tariff in its layout. The design closes when
> those ship and are distilled the same way.

## Verified (2026-11-14)

The price service's first broadcast (`f89aaeee…`, 18:29 EST) is
journaled; oak's and beech's 18:57 `flo.params` 002 name it, and the 48
prices in beech's request equal the forecast's `PriceX1000List` at the
same slots divided by 1000. The backend route and the panel were checked
on the page against the dev backend on `tsdb_tap` and, after the
2026-11-14 deploy of backend #33, on the production page.

## Decisions standing for the remainder

- **The Keene market's product is `rt60gate1`** (2026-11-13): real-time
  energy, 60-minute slots, gate closing 60 s before the slot. Both
  services claimed `rt60gate5`, a 300 s gate, while the LTN asks the FLO
  180 s before the slot and the FLO answers in about 10 s, so bids reach
  the maker about 170 s before the slot, after the gate the name claimed.
  A 300 s gate (a 420 s lead) was weighed and declined: it changes the
  LTN's timing for no gain, since clearing takes milliseconds. A 60 s
  gate leaves the bid about 110 s of slack against a FLO stall. The value
  is in `gw.market.product.name` 001, published. Booking and acking bids
  with the gate enforced on dequeue is OPS-431's.
- **`latest.price` is the full price the LTN faces.** It determines the
  contract between the LTN and the MarketMaker, so it includes every
  sub-stream the LTN faces at its node; a wholesale-only meaning was
  rejected. The MarketMaker's job is to become, piece by piece, a DSO:
  turning what the external market prices into what its own market
  faces is its work.
- **The parts of a price are named by one enum, `price.component.name`**
  (published, 000): `Unknown`, `WholesaleEnergy`, `WholesaleCongestion`,
  `WholesaleLoss`, `Delivery`, `CoincidentPeakTransmission` (the monthly
  peak), `CoincidentPeakCapacity` (the annual peak). A coincident-peak
  part's price in a slot is assigned from a probability that the slot is
  the peak; that monthly allocates transmission and annual allocates
  capacity in ISO-NE is unverified. `latest.price` 001 (published) has
  the parts, a `TariffAlias` present exactly when a `Delivery` part is,
  and axioms that the parts sum to the price.
- **The market's real-time hourly price is the hour's first 5-minute
  LMP** (2026-11-15): the interval that begins as the slot opens, so
  the maker asks ISO-NE every second from the top of the hour and
  publishes the moment the interval is posted, about 25 s in (ISO-NE
  posted the 09:45 and 09:50 intervals 23.5 s after they began,
  measured 2026-11-15), and no longer the :55 sample fetched 20 s
  before the hour. A
  check against ISO-NE's posted prices for 2026-11-15 found every
  published wholesale part equal to the :55 sample and the first hour
  20 USD/MWh under ISO-NE's hourly price. The LTN clears a bid only on
  a `latest.price` heard within 5 s of the slot's start
  (`gridworks-ltn/src/gwltn/market.py` `LATEST_PRICE_WINDOW_S`), so
  the LTN's window widens past the maker's `fetch_deadline_s` (240 s)
  in the same cutover, or every house aborts its clearing.
- **One MarketMaker identity per priced node.** A MarketMaker exists
  wherever a distinct price forms: an ISO-NE PNode, later a distribution
  constraint below one. A market is named by its MarketMaker's alias and
  its product; whether one application hosts several identities is a
  deployment choice the words do not depend on.
- **The tariff is a property of the market.** A market declares one
  tariff, and its price is the full price for every bidder on it.

## Plan

**Do this next:** step 8, the product name cutover, then the verifying
clause: the panel drawing the real-time price beside the forecast for a
window that spans the cutover, against `tsdb_tap`.

4. **MarketMaker** shipped: `latest.price` 001 with its parts (maker
   #80): the LMP's energy, congestion and loss parts from ISO-NE, the
   `Delivery` part from the A-1 table at the Seventeenth Revision with a
   note naming the tariff word that retires the table, `TariffAlias` set.
   The LTN reads 001 on scada `main` once its branch merges; the maker
   deploys after the LTN houses roll.
7. **The real-time price on the panel** shipped (backend #34, frontend
   #25, 2026-11-15): the backend's latest-prices route serves a market's
   `latest.price` rows over a window at 001, and the panel draws
   "Real-time" beside "Day-ahead forecast", the market taken from the
   forecast word's `MarketMakerAlias` and `ProductName`, so no fleet
   constant is needed.
8. **The product name cutover.** The product is a fact of the
   `gw.operational.params` word (`MarketProductName`, with
   `MarketMakerAlias`), set per house in `tlayouts/<house>_gen.py`; the
   MarketMaker's `market_product` and the price service's `product_name`
   settings name the same product. All three move to `rt60gate1` in one
   cutover, every house rolled by `roll.sh`, so no service names a
   product the others do not. The slot names change with the product, so
   the Keene `latest.price` series under `rt60gate5` ends and a new one
   begins; the real-time route follows its prefix parameter.
   Prerequisite: the tlayouts snapshot vendors `gw.market.product.name`
   000, which lacks `rt60gate1`; it regenerates at 001 first. The scada's
   gwsproto, the journalkeeper, the backend, the frontend and the price
   service already vendor 001; the maker takes the product as a bare
   name. The FLO's hard-coded `rt60gate5` in its `BidRecommendation` slot
   name is unused (the LTN builds the bid's slot name from the ops word)
   and is a cleanup, not a blocker.
9. **The tariff in the layout** shipped: the scada's `layout.lite` 014
   states its tariff (scada #623); the journalkeeper, backend and
   frontend parts shipped with 014 and `gw.house.summary` 003. The
   browser's fleet-tariff fallback retires when every house runs 014.

Related work by issue: OPS-437 owns the price service's standing as a
gwbase GNode and the tariff vocabulary, including the tariff-tracking
recommendation; OPS-431 owns the gate and the ack; OPS-665 is the
pattern (the browser draws the published word).
