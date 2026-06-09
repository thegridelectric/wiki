# Market-structure survey — prior art → gems

Status: Draft · Pass 0 · Updated 2026-06-09

> **QUEUED research prompt — not yet executed.** A seed for later work, not a
> finished survey. Purpose: study a range of *mature and imagined* electricity-
> market structures, extract the obviously-good choices others have proven, and
> let them inform a **foundational** MarketMaker that supports **a lot of local
> and regional variation** without privileging any one region's rules. Companion:
> [`market-product-taxonomy.md`](market-product-taxonomy.md) (how products are
> structured); design anchor: [`../designs/launch-new-simple-marketmaker/primary.md`](../designs/launch-new-simple-marketmaker/primary.md);
> background eval: [`../designs/launch-new-simple-marketmaker/evaluate-existing-repo.md`](../designs/launch-new-simple-marketmaker/evaluate-existing-repo.md).

## The thesis to test

Design **one** foundational substrate (the `market.product` fields + the slot /
gate / settlement / dispatch / penalty / price-formation dimensions + the
bid/offer-curve semantics) flexible enough to express many real and imagined
markets — while adopting the design choices others have already learned are
right. Wide variation *on top of* a small, shared core.

## Seed material (skim, then mine)

- **VCharge ↔ National Grid (NGET) FDFR** — `legacy/old_words/FDFR NGET-VCharge
  Signed LOI.pdf` and `FDFR VCharge NG Contract.pdf`. A real UK ancillary-
  services (Firm Demand-side Frequency Response) commercial agreement: a mature,
  signed market-product structure to study for product definition, performance /
  baseline, settlement, and non-performance terms. (Binary PDFs — extract text
  when executing this survey.)

## Candidates to survey (verify; not authoritative recall)

- **ISO/RTO wholesale** — day-ahead + real-time energy, 5-min dispatch
  (CAISO / PJM / ISO-NE); locational marginal pricing.
- **Ancillary services** — frequency regulation, fast/firm frequency response
  (the FDFR family), operating reserves; performance-scored payment.
- **Capacity / flexibility** — capacity markets; DSO-level local flexibility
  markets (UK Piclo, Cornwall LEM, Elexon settlement separation).
- **Transactive energy / double auction** — PNNL transactive-energy work,
  GridLAB-D market objects, community/peer designs.

## What to extract (the "gems")

For each structure: product definition, slot/settlement intervals (and where
dispatch ≠ settlement), gate timing, baseline/measurement, price formation
(uniform vs pay-as-bid, stacked components), non-performance penalty, and the
participation/credentialing model. Map each onto candidate `market.product`
fields / axioms — keeping the maker-agnostic core small and pushing variation
into product instances.

## Output

Research notes here; the durable choices graduate into the `market.product` type
design and the clearing-engine selection. **Run this AFTER the walking skeleton**
(see the launch design), so there is a concrete clearing seam to evaluate options against.
