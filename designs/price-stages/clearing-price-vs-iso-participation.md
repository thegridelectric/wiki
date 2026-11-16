# The clearing price and ISO-NE participation

Status: Draft · Pass 0 · Updated 2026-11-16 · Linear: OPS-684

> What this is: the difference between the MarketMaker's clearing price,
> the price it states to its own aggregation, and the MarketMaker's
> participation in ISO-NE's markets on that aggregation's behalf. The
> two are easy to run together because today one number feeds the other.

## The clearing price

The clearing price is the maker's statement to its bidders of what a
slot's energy costs, in two stages of the maker's own commitment
(`price.stage` 000, on `latest.price` 002): `Provisional` at the slot's
open, `Final` when the maker binds. Today the maker builds it from two
outside sources it has no part in setting: ISO-NE's five-minute
locational marginal price at Keene Rd and the Versant A-1 delivery
tariff. The stage names the maker's commitment and says nothing about
where the number came from.

## Participation on the aggregation's behalf

Open. When the aggregation is a market participant in ISO-NE's markets
(a dispatchable asset related demand, DARD, inside a composite settlement
facility), the maker receives a Desired Dispatch Point before each
five-minute interval and settles with ISO-NE at the interval's verified
price (`regulatory/isone/real-time-dispatch/primary.md`). Two things
change and one does not: the Provisional's source becomes the price the
dispatch implies, under the same stage name; the maker's settlement with
ISO-NE becomes a real cash flow it owes or is owed; and the clearing
price stays the maker's statement to its houses, with the stages, the
contract and the terms unchanged. ISO-NE's verified price is the maker's
settlement upstream and is not a stage of this market's price.

## What a house sees

Open. A house sees the clearing price and its contract only. It does not
see, and does not need, the maker's position with ISO-NE.
