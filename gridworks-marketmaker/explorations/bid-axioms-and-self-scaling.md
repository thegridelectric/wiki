# Bid axioms & self-scaling

Status: Draft · Pass 0 · Updated 2026-06-22

> What this is: exploratory thinking on what a `bid` must satisfy for the same
> market maker to serve one house up to a large fleet without the algorithm
> degrading — a digest of an outside brainstorm, reframed into the wiki's
> vocabulary. **Not normative.** Companion to
> [`market-product-and-uniform-bids.md`](market-product-and-uniform-bids.md)
> (how `market.product` / `bid` / `latest.price` are modeled) and to the launch
> hub's open question on cumulative-bid / ack semantics.

## The idea: the market rulebook is the scaling substrate

A bid is defined by its adherence to a market's rulebook, not by who emitted it.
Participant differences (a house vs a 10 MW aggregator) live in
**authorization / registry** and in **which markets they may bid into** — not in
a different bid schema. If that holds, one uniform `bid` from a house up to a
fleet is the cleanest expression of the architecture, not a compromise.

Vocabulary note: the brainstorm says "MarketType"; in our model that is the
`market.product` plus the rulebook dimensions not yet modeled on it (settlement,
ticks, bounds — see the companion exploration). Read "MarketType" below as "the
product's rulebook."

## Candidate bid axioms

Design-shaping candidates for the `bid` Sema type
(`sema/definitions/types/bid/000.yaml`), to weigh as concrete markets are built —
not yet committed:

**Normalized to the product's price/quantity domain:**

1. **Domain anchor** — `PqPairs[0].Price == Product.PriceMax` (this is the
   existing bid Axiom 1, restated against the product rulebook).
2. **Units match the product** — `Bid.PriceUnit == Product.PriceUnit`,
   `Bid.QuantityUnit == Product.QuantityUnit`.
3. **Ticks respected** — every price a multiple of `PriceTick` within
   `[PriceMin, PriceMax]`; every quantity a multiple of `QuantityTick`.
4. **Complexity bounded** — `len(PqPairs) <= Product.MaxSegments`.

These let curves aggregate cheaply and predictably.

**Shape-valid for aggregation** — pick one curve semantics as product policy
(step / piecewise-linear / block) and enforce it so aggregation operators
(sum-by-price, interpolate) are deterministic:

5. **Monotone price grid** — strictly decreasing (or increasing; pick one and be
   consistent), `PriceMax → PriceMin`.
6. **No duplicate prices** unless the product explicitly allows them.
7. **Monotone quantity** if the chosen semantic requires it. This forces a
   single reading of `PqPairs` — *marginal supply* vs *cumulative willingness* —
   rather than leaving it ambiguous.

**Self-contained for rate-limiting / anti-spam** (scaling + security):

8. **Verifiable signature / fee** against the bidder-alias registry and product
   policy. The cryptographic check can live outside pydantic; the *axiom* is
   "must verify." This is what keeps adversarial load from breaking self-scaling.

## The MarketSlotName must decode authoritatively

For self-scaling to be real, `MarketSlotName` must deterministically imply the
product, the settlement interval, and the market layer / venue. Our
`market.slot.name` format already fixes four structural parts (commodity ·
product token · maker alias · slot start) but validates structure only — it does
**not** bind the token to a maker's product enum or check slot-start alignment.
Today that decode is opt-in on the receiving maker's side
(see the companion exploration). The open tension: self-scaling wants an
authoritative **MarketSlot / market.product registry** the maker consults, so
validation is never ambiguous — without forcing the wire format to `$ref` every
maker's enum. Reconciling "uniform, maker-agnostic wire type" with "authoritative
decode" is the live question.

## Why this serves "one market maker everywhere"

If every layer defines its product rulebook with these parameters, one maker can
validate bids uniformly, convert them to a canonical internal curve, aggregate by
simple operators, bound compute via segments + ticks, and keep liquidity bounded
by anchoring at PriceMax/PriceMin. The algorithm stays stable as participants and
layers grow because the inputs are normalized and bounded — that is what
"self-scaling" means here.
