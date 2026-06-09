# Market-product taxonomy — how others name & structure electricity-market products

Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: a cited landscape survey of how transactive-energy efforts,
> demand-response programs, and ISOs/RTOs name and structure market *products*,
> plus the design implication for GridWorks' MarketMaker vocabulary
> (`market.product.name` + a coupled `market.product` type). The design decision
> shipped as `gw.market.product.name` + the `market.product` type in
> `sema/definitions/` (spec: `sema/spec/`).
> Pre-spec research, not normative. Claims below were adversarially verified
> (3-vote; "killed" claims are listed as caveats, not used).

## TL;DR

Every mature framework models a market product as **multi-dimensional and
orthogonal** — commodity/product-type × time(interval/duration) × location ×
performance/response-time × units × price-formation — **not** as a single flat
token. Flat tokens appear only as operational DR program lists and ISO product
*names*, and even those resolve to structured attributes underneath. This
validates splitting GridWorks' concept into a simple decodable **name** plus a
rich **product type** that carries the attributes.

## Landscape

### Transactive energy

- **TeMIX / EMIX (OASIS, ed. Edward Cazalet, 2012)** — the closest precedent.
  - A product = **{quantity of a commodity} + {delivery interval} + {location}
    + {price}** — four orthogonal dimensions
    ([oasis temixbrief](https://docs.oasis-open.org/emix/emix-temixbrief/v1.0/emix-temixbrief-v1.0.html)).
  - The product space is restricted to **two commodities — Energy and
    Transport** (+ Options); Transport = the locational/delivery service (ibid).
  - **Intervals are a standard *nested* hierarchy (year/month/day/hour/5-min),
    constant power within each, so a coarse interval is composed of identical
    finer sub-intervals** (ibid) — i.e. GridWorks' fractal-slot intuition is
    already a standard.
  - Claims the **same structure scales from bulk generation to home
    appliances** ([temix.com](https://temix.com/transactive-energy/)).
  - Full **EMIX**: a product = **product type + response time + delivery time**
    ([oasis emix](https://docs.oasis-open.org/emix/emix/v1.0/emix-v1.0.html));
    **location is a first-class typed object** ("EMIX Interface" → PNode /
    Aggregated PNode (zonal) / Service Delivery Point / Transport) (ibid); and
    **time is composable WS-Calendar primitives** (Duration, Interval,
    Sequence, Gluon, Schedule) where one start time is inherited and the rest
    computed — slot duration & start are *structural objects, not substrings of
    a name* (ibid).
- **CalFUSE** — a **CPUC Energy Division staff** proposal (Jean Lamming,
  Achintya Madduri, Aloke Gupta), whitepaper 2022-06-22 → rulemaking
  R.22-07-005 — **not** an LBNL creation
  ([cpuc](https://www.cpuc.ca.gov/-/media/cpuc-website/divisions/energy-division/documents/demand-response/demand-response-workshops/workshop-pdfs/slides-calfuse-workshop-21july2022f-publish-pdf.pdf)).
  Price = **LMP + distribution-capacity + RA/generation-capacity +
  Flex-RA/ramping**, each from a distinct real-time input; explicitly
  **locational and multi-timeframe** (next-day hourly, week-ahead 7×24, forward
  contracts) (ibid). Pricing is *stacked components*, not one number.
- **Bruce Nordman (LBNL)** — the "LBNL Bruce": two areas, *price-based demand
  flexibility* and *Local Power Distribution* ("networked electricity")
  ([brucenordman.com](https://brucenordman.com/)). His specific nested-market
  model is **underspecified in verified sources** — open follow-up.
- **PNNL Pacific NW Smart Grid Demonstration** — a "transactive control system"
  coordinating assets via price-like signals rather than direct dispatch
  ([pnnl](https://www.pnnl.gov/projects/transactive-systems-program/pacific-northwest-smart-grid-demonstration)).

### Demand response — the "named template" counter-school

- **OpenADR 2.0** defines DR products as a **closed set of named program
  templates** (Critical Peak Pricing, Capacity Bidding, Thermostat, Fast DR
  Dispatch, EV-TOU, DER…)
  ([openadr](https://www.openadr.org/assets/openadr_drprogramguide_1_1.pdf)) —
  a flat enum of named products.
- But OpenADR also splits the signal into **two orthogonal enums: `signalName`
  (what — ELECTRICITY_PRICE, LOAD_DISPATCH, BID_ENERGY…) ⊥ `signalType`
  (units/semantics)** (ibid) — validating separating "what" from "in what
  units."

### ISOs/RTOs — named products that decode to structured attributes

- **CAISO PDR** bids into **DA energy, DA & RT spin/non-spin reserve, and 5-min
  RT energy**
  ([caiso](https://www.caiso.com/documents/pdr_rdrrparticipationoverviewpresentation.pdf))
  — products separated by commodity and timeframe.
- **CAISO locational rule**: aggregations must sit **within a single sub-LAP**
  (subset of Pnodes; 24 sub-LAPs around transmission constraints) (ibid) —
  location/sub-tree scope is enforced.
- **PJM** ([M-11](https://www.pjm.com/-/media/DotCom/documents/manuals/m11.pdf)):
  **DA (hourly settlement, day-prior clearing) + RT (RT-SCED, 5-min dispatch)**;
  **settlement interval ≠ dispatch interval**; **gate closure** is explicit (RT
  bids alterable up to **65 min before the operating hour**); energy/reserve/
  regulation are **co-optimized with different commitment timeframes** (ASO
  clears regulation for a half-hour, inflexible reserves for an hour, jointly
  with energy).

## Design implication for GridWorks

Chosen direction (authoritative version is the shipped vocabulary in
`sema/definitions/` + `sema/spec/`):

1. **`market.product.name` is a plain versioned enum** of product-name tokens —
   the closed set of valid names (e.g. `da60`, `rt60gate5`). The token is a
   human-decodable encoding of its slot timing, but the enum carries only the
   names.
2. **Open the enum by allowing MANY product-name enums, namespaced per market
   maker / territory** — e.g. `gw.versant.market.product.name`. The fractal
   architecture expects each MarketMaker to define its own product vocabulary;
   "open" = multiplicity of namespaced enums, not an open pattern.
3. **`market.product`** — a coupled sema **type** that carries the per-product
   attributes as typed fields: `Name` (the token) + `ProductNameEnum` (which
   enum) + `MarketProductId` (UUID) + `SlotDurationMinutes` + `GateClosingSeconds`
   + `QuantityUnit`. Further market-specific attributes (settlement, dispatch,
   response, price-formation) are added to the type **as each market is designed**.

**Where attributes live:** all per-product attributes — even those decodable
from the token name — live on the `market.product` **type**, not the enum.

> An earlier draft split them (name-decodable → a *structured enum* value, else →
> the type). The structured-enum capability was rolled back (`0bf8f0f`); the
> `market.product` type is now the single home for product attributes.

This mirrors the industry pattern — a **named product** (ISO/OpenADR style)
whose name carries **structured attributes** (EMIX/TeMIX style) — while keeping
the semantics in versioned, closure-tracked vocabulary rather than a separate
catalog/database (the explicitly-rejected alternative: encapsulation over a
second source of truth). Location stays **out** of the product and in
`market.slot.name`'s maker-alias segment (≈ EMIX Interface / CAISO sub-LAP) —
which GridWorks already does correctly.

### Naming verdict

Industry term of art is **"product"** (EMIX "market product", TeMIX "products",
ISO "market products"). **"type" is ambiguous** ("market type" can read as
DA-vs-RT market). → `market.product[.name]` over `market.type.name`.

## Caveats

- **Killed in verification (do NOT rely on):** "PDR = economic vs RDRR =
  reliability" (refuted 0-3); the exact OpenADR `signalType` = quantity-unit
  value set (refuted 1-2 — the broader signalName ⊥ signalType split *did* hold).
- **Bruce Nordman's nested-market model** is unconfirmed in detail — sparse
  source; worth a focused follow-up.
- Synthesis of the deep-research run was assembled by hand (the harness's
  auto-synthesis hit a session limit); the underlying claims are the verified
  set, not a model summary.

## Primary sources

OASIS EMIX & TeMIX briefs; CPUC CalFUSE workshop slides; temix.com; PNNL PNW
Smart Grid Demo; CAISO PDR/RDRR overview + Flexible Ramping Product appendix;
OpenADR DR Program Guide; PJM Manual 11; ISO-NE Market Rule 1 accounting; FERC
Order 2222 explainer; LBNL DER-participation report; GridWise TE Framework
(PNNL-22946). (URLs inline above; full fetch list in the deep-research run
output.)
