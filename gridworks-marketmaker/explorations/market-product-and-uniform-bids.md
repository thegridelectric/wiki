# Market products & uniform market messages in Sema

Status: Draft · Pass 0 · Updated 2026-06-08

> What this is: informal pointers to how *market products* and the *uniform
> market messages* (`bid`, `latest.price`) are modeled in Sema after the
> "untangle market.type.name" work. Not a normative spec — for the rationale +
> industry landscape see
> [`../research/market-product-taxonomy.md`](../research/market-product-taxonomy.md);
> for authoring the structured enum see the sema spec at
> `spec/authoring/enums.md` ("Structured Enums").

## What a market product is

A **market product** is one of the kinds of market a MarketMaker offers. The
same product is offered at *every* node that maker runs. Conceptually it anchors
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

A market maker / owning org defines a **structured enum** named
`<ns>.market.product.name`. GridWorks's own is `gw.market.product.name`
(`sema/definitions/enums/gw.market.product.name/000.yaml`).

It is a *structured* enum — each token decodes via typed per-value attributes:

- `timeframe` (`da` / `rt`), `slot_minutes`, `gate_minutes`, `quantity_unit`.
- e.g. `rt60gate5` → `{ timeframe: rt, slot_minutes: 60, gate_minutes: 5,
  quantity_unit: AvgkWh }`.

So the **name-decodable dimensions live IN the vocabulary** — the token is a
faithful, decodable encoding of its own slot timing, not an opaque label.

Tokens MUST conform to the single-token `spaceheat.name` shape: lowercase,
starting with a letter, internal hyphens allowed, no dots. To author or extend
one, see the sema spec section `spec/authoring/enums.md` "Structured Enums"
(append-only: never mutate a published attribute cell).

"Open the enum" here means *multiplicity of namespaced structured enums*, one
per maker — not an open / freeform pattern. Each maker may carry its own
`*.market.product.name`.

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
opt-in against *its own* `*.market.product.name` structured enum — e.g. via the
generated `GwMarketProductName.<token>.attrs.slot_minutes`.

This is the same grain as `market.product.Name`: a **bare token carried on the
wire, decode is an opt-in consumer-side step.** A single shared `market.product`
type (and a single shared `market.slot.name` format) cannot statically `$ref`
thousands of per-maker enums and would become maker-specific if it pinned one —
so the discriminator (`ProductNameEnum`) names the vocabulary, and any consumer
that wants the decode seeds that maker's enum and looks the token up in it.
