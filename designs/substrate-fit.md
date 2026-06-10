# Substrate fit (design — parked brainstorm)

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-391

> What this is: the parking lot for the substrate question — evaluating the
> fit of blockchain / alternative substrates for the crypto / validation /
> market-running layers. Cross-cutting because it spans credentials
> (TaDeeds, TaTradingRights), validation (the TaValidator membrane), and
> market machinery (binding ack, settlement) across multiple domains.

## Charter (read first)

**Toss ideas in here — brainstorming only. No research, no organization.**
We only really focus on this design AFTER THE LAUNCH (the MarketMaker +
Sema clear-and-present pair in the vision hub). Until then, any session
where the substrate conversation starts is one append to this file away
from getting back to gate-work. Bullets below need no order, no maturity,
no defense.

## Standing context (the question as currently understood)

- The chain's real draw is **anti-capture**, not throughput. Framework-
  agnostic per economy-energy-markets invariant 14: requirements are the
  standard; cryptographic evidence mechanisms may be substituted.
- Two roles likely get different answers: **credentials/rights are
  NFT-like** (TaDeeds, TaTradingRights with immediate unilateral clawback);
  **market machinery** could be a distributed web of interactive smart
  contracts — or not. The open question is **layering**: what goes on-chain
  (binding ack? settlement? deeds/rights?) vs off-chain (the fast
  cumulative bid stream, which fees/latency make a poor on-chain fit).
- The unbundled-contract framing: axioms = grammar, signatures over
  canonical bytes = attribution, physics + TaValidator reputation =
  consequence — see
  [`../sema/research/axioms-as-unbundled-contracts.md`](../sema/research/axioms-as-unbundled-contracts.md).
  Whatever substrate is chosen carries the *consequence/custody* layer, not
  the grammar.
- Decidability discipline: if contract-like logic is adopted, prefer
  restricted/decidable languages (Clarity-style) over Turing-complete ones.

## The brainstorm pile

_(append freely; no order, no vetting)_
