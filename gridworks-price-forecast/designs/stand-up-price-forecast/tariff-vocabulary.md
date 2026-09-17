# Tariff and price vocabulary (spoke)

Status: Draft · Pass 0 · Updated 2026-09-16

> What this is: the brainstorm for the words that carry a delivery
> tariff and a price signal, and the first small word we want now so
> the scada and the LTN stop hard-coding the tariff. The first word's
> shape is agreed (2026-09-16), pending the sema-spec authoring step;
> the rest is questions for this design's real session.

## Where the tariff lives today

The homes are on Versant Rate A-1, "Home Eco Rate with Bonus Meter"
(Time-of-Use); the schedule and $/kWh are recorded in
`wiki/regulatory/versant/tariffs.md` "Rate A-1" (weekday peak 7 to 12
and 16 to 20, shoulder 12 to 16, off-peak 20 to 7; weekends and
holidays have no peak; DST-bracketing schedule). The code carries it in
five places, none of them a word:

- `gw.house0.operational.params` / `gw.nolan.operational.params`
  `OnPeakWindows` (`gw.tou.window` list): the one configured form. The
  scada's control clock (`actors/hydronic/shared.py`) reads it.
- `derived_generator.py` energy planning and `ltn/contract_handler.py`
  fuel substitution: two inline copies of the weekday-hours table.
- `gridworks-ps/basic_api/price_forecast.csv`: the tariff as a
  hand-built hourly series in USD/MWh (487.63 weekday 7 to 11 and 16 to
  19; 54.98 shoulder and weekend day; 50.13 night), extended by hand
  two weeks at a time and expired in May 2025. The LTN's "real-time"
  price is this forecast read back ("WE ARE NOT USING THE REAL-TIME
  PRICE YET", `ltn.py`), sent to itself by an in-process fake market
  maker.
- `gridworks-web-backend` `backend_api.py`: the same three USD/MWh
  figures as a plotting fallback.
- `gridworks-marketmaker` enum `DistributionTariff`
  (`VersantA1StorageHeatTariff`) and the `gridworks-ps` 8760 alias
  `gw.me.versant.a1.res.ets`: two names for the tariff, neither in sema.

Who uses prices versus hours: the scada's control code (local control,
leaf ally, hydronic) uses only the on-peak clock; no $ figure reaches a
control decision. The LTN uses prices: the forecast's dist plus LMP
series is the FLO's edge cost and the bid curve, and the cleared price
against the bid sets the hour's contract quantity. The one tariff-shaped
threshold in the LTN is `fuel_sub_usd_per_mwh = 490`, a settings value
sitting just above the on-peak delivery figure.

## The first word: `gw.tou.tariff`

The smallest word that names the tariff and carries its schedule, so
the scada and the LTN read one thing. On-peak and off-peak only; the
shoulder is deliberately not modelled yet (control treats it as
off-peak, as today). Fields:

- `Alias` (LeftRightDot): the tariff's stable machine name, e.g.
  `versant.a1.home.eco.bonus`. One alias per published tariff; the
  price-forecast word will carry the same alias so consumers can check
  they are on the same tariff.
- `DisplayName`: the utility's own name, `Home Eco Rate with Bonus
  Meter`.
- `TimeZone` (IANA name): the wall clock the windows are in. Today it
  is the scada's `timezone_str` setting, which the windows silently
  assume.
- `OnPeakWindows`: list of `gw.tou.window`, the field the ops words
  already carry, moved inside the tariff. Same non-overlap axiom.

No prices in this word. The delivery price series is the forecast
service's output (the `dist` column today), and the control code never
reads a $ figure; adding prices now would put a second copy of the
tariff's rates beside the forecast. When the price-forecast word
exists it carries `TariffAlias`, and the rate table becomes that
service's input, not the scada's.

Consumers on this word:

- The two ops words replace `OnPeakWindows` with `Tariff:
  gw.tou.tariff` (both are `staging`, so edited in place). The scada's
  `in_onpeak_window` reads `ops.Tariff.OnPeakWindows`, and the two
  inline tables (`derived_generator.py`, `contract_handler.py`) read
  the same method, closing the three-clocks state the historical
  write-up records (`wiki/gridworks-scada/historical-executor/
  on-peak-clock.md`).

**Consistency between scada and LTN.** The guarantee is structural,
not by intention: both read the tariff from the same instance. While
the LTN runs in the scada process it reads the scada's ops word. Once
the LTN is its own service, the scada's `LayoutLite` carries the
tariff (it already carries the ops-derived modes), and the
price-forecast word carries `TariffAlias`; the LTN asserts the two
aliases match on receipt and treats a mismatch as a fault, not a
warning. No consumer keeps its own copy of the windows.

## Brainstorm for the dynamic tariff (open)

Questions the real design session resolves before `vocabulary.md`:

- **Two kinds of dynamic delivery signal.** (a) High-priced hours set
  day-ahead: a dated schedule, not a recurring one, so the word is a
  list of dated windows with a price or a tier per window, published
  once a day with a validity window. (b) A real-time override from the
  utility: is it a price (a new number for the next hour) or a
  requirement (curtail, or hold a load off, regardless of price)? A
  requirement is not a price and should not be encoded as one; it is a
  dispatch instruction with an authority and a duration, closer to the
  MarketMaker's contract than to a forecast.
- **Who faces the price.** Distinguish prices the homeowner is billed
  (the delivery tariff on the bonus meter, the standard-offer supply)
  from prices only the aggregator faces (the LMP, regulation, capacity).
  The homeowner-facing set is what the FLO must respect for the bill;
  the aggregator-facing set is what the bid must respect for the
  market. One series with both summed (today's `total_price_forecast`)
  loses the distinction; the word should carry them as named components
  and let the consumer sum.
- **Aggregator versus energy supplier.** Probably not distinguished by
  the forecast service: both see the same wholesale series; the
  difference is the retail contract, which is a tariff fact, not a
  forecast fact. Confirm.
- **Sub-costs.** Energy versus delivery at least (the LTN already
  separates `dist` and `lmp`); within delivery, the A-1 distribution
  energy charge versus the rest of delivery only matters if a component
  becomes dynamic on its own. Model the components the forecast can
  vary independently; leave the rest as one number.
- **Holidays.** A-1 has no peak on ten named holidays and
  `gw.tou.window` binds days of the week only; the first word treats a
  holiday as its weekday. A `Holidays` list on the tariff, or a
  `gw.tou.calendar`, comes with the dynamic tariff.
- **Recurring versus dated.** The recurring `gw.tou.window` shape
  serves the static tariff; the dynamic signal is dated. Both can coexist
  as the tariff's base schedule plus a dated override list with
  precedence rules (dated over recurring; requirement over price).
- **Observed versus forecast.** A cleared or settled price is an
  observation; the day-ahead schedule is a forecast with a firmness
  (utility-published is firm; an LMP forecast is not). Carry firmness
  on the word rather than in the source's name.
- **What retires.** The hand-extended `price_forecast.csv`, the price
  editor UI path, the in-process fake market maker's `latest.price`
  self-send, the `backend_api.py` fallback table, and the two inline
  clock tables. Each names the word that replaces it when the word
  exists.
