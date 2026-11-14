# Market products & uniform market messages in Sema

Status: Draft · Pass 0 · Updated 2026-11-11

> What this is: informal pointers to how *market products* and the *uniform
> market messages* (`bid`, `latest.price`) are modeled in Sema after the
> "untangle market.type.name" work. Not a normative spec — for the rationale +
> industry landscape see
> [`../research/market-product-taxonomy.md`](../research/market-product-taxonomy.md);
> for the `market.product` type's typed fields see
> `sema/definitions/types/market.product/000.yaml`; for bid-curve axioms +
> self-scaling thinking see
> [`bid-axioms-and-self-scaling.md`](bid-axioms-and-self-scaling.md).

## What a market product is

A **market product** is one of the kinds of market a MarketMaker offers. An
operator that runs MarketMakers at many nodes offers the same product at
each of them. Conceptually it anchors
the market's full rulebook: settlement, dispatch/response timing, the
non-performance penalty when a cleared bid is not met, and how price is formed.

Today the `market.product` Sema type
(`sema/definitions/types/market.product/000.yaml`) is **intentionally minimal**:

- `MarketProductId` — a stable UUID identity.
- `ProductNameEnum` — a `left.right.dot` identifier naming which product-name
  vocabulary `Name` is drawn from (e.g. `gw.market.product.name`); the namespace
  segment encodes ownership.
- `Name` — a bare product token (e.g. `rt60gate5`), deliberately **not** a
  `$ref` to that enum (see below).

The rulebook dimensions that are *not* decodable from the name — settlement
interval (which may differ from the dispatch interval), dispatch response time,
non-performance penalties, stacked price-formation components — are associated
with the product but **not modeled yet**. Whether they later become fields on a
`market.product` version or separate Sema types that *reference* a
`market.product` is left open on purpose, to be decided as concrete markets are
built. v000 commits only to identity + the product-name discriminator.

## Each market owner brings its own product-name enum

A market maker / owning org defines a versioned enum named
`<ns>.market.product.name` — a closed set of product-name tokens. GridWorks's own
is `gw.market.product.name`
(`sema/definitions/enums/gw.market.product.name/000.yaml`): tokens like `da60`,
`rt60gate5`, `rt60gate30`, `rt5gate5`.

The token is a human-decodable name (`rt60gate5` reads as real-time, 60-minute
slot, gate 5), but the **authoritative decode lives on the `market.product`
type**, not the enum: one `market.product` instance per token carries the typed
attributes — `SlotDurationMinutes`, `GateClosingSeconds`, `QuantityUnit`
(`sema/definitions/types/market.product/000.yaml`). The enum is the names; the
type is the per-product data.

> An earlier draft modeled these as a *structured enum* whose tokens decoded via
> a typed `.attrs` accessor. That capability was rolled back (`0bf8f0f`) — the
> attributes are plain typed fields on the `market.product` type instead. The
> split is now simply: the enum holds names, the type holds attributes.

Tokens MUST conform to the single-token `spaceheat.name` shape: lowercase,
starting with a letter, internal hyphens allowed, no dots. The enum is
append-only per Sema's additive-enum rule.

"Open the enum" here means *multiplicity of namespaced product-name enums*, one
per maker — not an open / freeform pattern. Each maker may carry its own
`*.market.product.name`.

## One MarketMaker identity per priced node

Decided 2026-11-11. A MarketMaker is a GNode at the node where a distinct
price forms, and each such node has its own MarketMaker identity: its own
alias, its own queue as the ordering authority, its own stored acks. An
ISO-NE PNode is such a node. A distribution constraint below a PNode
becomes another when it is known, which is the registry's rule that a
connectivity node may become a MarketMaker. MarketMakers nest: a
node-level maker faces the price of the maker above it and makes its own.

Three things follow.

- **A market is named by its MarketMaker's alias and its product.** A
  `MarketSlotName` adds the slot start, and `latest.price` states one
  price per slot name. A maker spanning two priced nodes would need two
  prices under one name.
- **The upstream pricing point is a fact about the MarketMaker.** Which
  ISO-NE location a maker faces belongs in the maker's own record. A word
  about the market (a price, a forecast of it) names the maker and has no
  separate node field.
- **The application is a deployment choice.** One codebase runs as one
  instance per identity today, since a certificate is the identity of one
  running program. Hosting several identities in one process later
  changes no word, because the words address a MarketMaker by its alias.

A market declares one delivery tariff, so its price is the full price for
every bidder on it. Homes in another utility's territory, or on another
rate, are bidders on another market.

## `latest.price` is the full price, stated in its parts

Decided 2026-11-11. `latest.price` is the price that settles the contract
between a bidder and its MarketMaker, so it is the full price the bidder
faces at the maker's node. The MarketMaker's work is that of a DSO, built
piece by piece: it turns the prices and charges it faces upstream, which
may be structured differently from its own market, into one price per
slot. From version 001 the word also lists the named parts that sum to
the price (`price.component.name`: the wholesale energy, congestion and
loss parts, delivery under the market's tariff, and two coincident-peak
parts reserved for a recipe not yet decided), so each part can settle
with its own counterparty while the contract stays on the one price.

## `bid` and `latest.price` are uniform across ALL makers

`bid` (`sema/definitions/types/bid/000.yaml`) and `latest.price`
(`sema/definitions/types/latest.price/000.yaml`) are designed to be the **same
contract for every market maker**. They are intentionally **not** namespaced
per maker — one shared bid / latest-price message regardless of who runs the
market.

Both carry a `MarketSlotName` field typed by the maker-agnostic
`market.slot.name` format (`sema/definitions/formats/market.slot.name.yaml`).
That format validates **structure only** — four dot-separated parts:

1. commodity class — one of `[erd]`;
2. the product-name token — `spaceheat.name`-shaped;
3. the market-maker alias — `left.right.dot`-shaped;
4. a 10-digit Unix-seconds slot start.

Crucially the format does **not** validate the product token against any
specific maker's enum, and does not check that the slot start aligns to the
product's slot duration. Keeping it maker-agnostic is exactly what lets
`bid`/`latest.price` stay uniform.

## Decode is opt-in, on the receiving maker's side

Whether a product token is *real*, and whether the slot start *aligns* to that
product's slot duration, is the **receiving market maker's** concern. It decodes
opt-in by resolving the token against *its own* `*.market.product.name` enum and
the matching `market.product` instance — e.g. checking the slot start against
that product's `SlotDurationMinutes`.

This is the same grain as `market.product.Name`: a **bare token carried on the
wire, decode is an opt-in consumer-side step.** A single shared `market.product`
type (and a single shared `market.slot.name` format) cannot statically `$ref`
thousands of per-maker enums and would become maker-specific if it pinned one —
so the discriminator (`ProductNameEnum`) names the vocabulary, and any consumer
that wants the decode seeds that maker's enum and looks the token up in it.
