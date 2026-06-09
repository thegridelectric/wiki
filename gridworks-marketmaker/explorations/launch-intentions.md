# MarketMaker launch intentions

Status: Draft · Pass 0 · Updated 2026-06-08

> What this is: durable *intentions* for the GridWorks MarketMaker as we prepare
> to launch it — what we're committed to, and the open threads still to settle.
> Pre-spec, not normative. Companions:
> [`../research/market-product-taxonomy.md`](../research/market-product-taxonomy.md)
> (how others structure products) and
> [`market-product-and-uniform-bids.md`](market-product-and-uniform-bids.md)
> (how products + uniform messages sit in Sema).

## Committed intentions

- **The MarketMaker is the authoritative advertiser of its own markets and their
  rules.** Each maker is the go-to place for what markets it runs and the rules
  for each (slot duration, gate timing, settlement, dispatch, penalties, price
  formation). A maker's database of its own market products is **essential**, not
  a smell — this is a deliberate reversal of the earlier worry about core market
  semantics living "in some database." The maker *is* that source of truth.
- **Emergent market semantics live in type upgrades and axioms — not in clever
  vocabulary.** As real markets get designed, new semantics are added as fields
  on the `market.product` type (versioned, with real `$ref`'d units) or as
  axioms on `market.slot.name` — not smuggled into enum metadata. One place for
  rich, evolving meaning keeps the system simple. (This is the principle behind
  rolling back the structured-enum experiment — see the sema untangle design.)

## Open threads (to settle before / at launch)

- **5-minute slot granularity.** Markets for grid balancing in 5-minute units
  was a founding VCharge thesis, and it matches ISO real-time patterns
  (CAISO/PJM 5-min dispatch). Likely lands as an axiom that a `market.slot.name`
  slot-start be divisible by 300 s. Open: bind it on the *maker-agnostic* format
  (every maker on a 5-min grid) vs. leave it a maker-side opt-in check.
- **Adoption tiers — what must an adopter use vs. what we merely prefer.** First
  cut:
  - **MUST** — use GNodeAliases and register them in a shared, distributed grid-
    node registry; run a functional, *unique* market at each node.
  - **Likely strong-preference** — the uniform `bid` / `latest.price` contract
    (one shared message shape across all makers).
  - **Don't-care** — the rest of a maker's internal product modeling.
  - Getting this layering right is what lets people adopt the ecosystem easily
    and naturally; lowering the bar (fewer MUSTs) is itself a design goal.
- **Regional ISO rules will shape products per region.** Existing market rules at
  the ISO level will strongly influence which products make sense in a given
  region; product vocabularies are expected to vary accordingly.
