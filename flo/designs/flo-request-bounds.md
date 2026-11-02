# FLO request bounds

Status: Draft · Pass 0 · Updated 2026-11-02 · Linear: [OPS-653](https://linear.app/gridworks/issue/OPS-653)

**EDD: yes** the layer question is settled by reading oak's bids and
cleared paths over its first weeks on the bruce FLO; the price-bounds half
is build-out, verified by the suite and the LTN's request test.

> What this is: two bounds the LTN's FLO request takes from outside the
> plant, both hand-set today, and where each one's authority goes. The
> market's price bounds are two constants in
> `gridworks-scada/gw_spaceheat/actors/ltn/flo_request.py`; the store's
> layer resolution is fixed by the layout's sensor count.

## The price bounds

The request's `PriceMaxUsdMwh` and `PriceMinUsdMwh` are module constants
(2000 and -100 USD/MWh). They bound the price axis the FLO bids over, so
they are the market's facts, not the plant's. The ops word names the
product the house bids into (`MarketProductName`), and sema's
`market.product` word describes a product by its name token, slot
duration, gate closing and quantity unit; it says nothing about price.

The bounds belong on the product: a `market.product` revision with a
price ceiling and floor and the price unit, so every bidder into the
product reads the same axis. How the LTN obtains the product instance
(from the MarketMaker on the broker, or the registry) is a MarketMaker
launch question; until the word says it, the constants stay, with
their note in place.

## The store's layer resolution

The FLO's layer unit is the sensor layer: `TanksModeled` times
`TempSensorsPerTank`. Oak's BufferOnly model is therefore 3 layers, a
transition matrix of 461 actions by 252 states built in 16 s. The LTN it
replaced modeled the same buffer as 9 layers over a far larger state
space.

Whether 3 layers resolves enough of the store for the plan is a FLO
question, answered from oak's bids: do the cleared paths charge and
discharge the buffer in steps the plant can follow, and does the bid
quantity track what the buffer then takes? If 3 is too coarse the layer
count becomes a `flo.tuning.bruce` knob, since it is a modeling choice,
not a tank fact. Each new shape needs its transition matrix generated and
placed on the ltn box before the first run (ltn instance-README "Non-repo
box state"); the first oak run on jm/flo-tuning-ops (2026-11-02 02:28)
failed on the missing 3-layer matrix.

## Plan

1. Read oak's bids and cleared paths for a week; decide the layer
   question and record it in `executor/bruce-flo.md` "The store".
2. If a knob is needed: `flo.tuning.bruce` 001 with the layer count,
   the LTN passes it through, the matrix recipe moves with it.
3. Propose the `market.product` price fields in sema; the LTN reads
   them from the product instance once a path to it exists; delete the
   two constants in the same change.

## Open

- Where the LTN gets its `market.product` instance.
- What zero `StoreWhList` is measured from. Oak's first cleared path
  (2026-11-02 03:00) reports the one 120 gal buffer at 174 kWh rising to
  a flat 181 kWh: the 7 kWh of headroom is a plausible buffer, the
  absolute is not water above any floor a buffer has. The word says
  "expected energy", so either the FLO's floor is far below the coldest
  allowed state or the response is in another unit; settle it before
  anyone reads the path for the store.
