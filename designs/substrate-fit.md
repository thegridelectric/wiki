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

- **Dispatch-veracity / connection-state authority.** A neutral third-party
  witness of the GNode↔GNode heartbeat that holds authority on "was the link
  (the contract) live at dispatch time T, and whose fault is a missed
  dispatch?" This was the original Algorand instinct; the durable principle is
  the *neutral witness + cryptographic attestation*, not the Algorand plumbing.
  The fast cumulative-bid stream stays off-chain; this attestation is a
  custody/consequence-layer candidate.
- **Substrate ≠ authority.** S3 already persists every ping/ack (raw
  substrate). The *authority* is a derived, signed, append-only attestation of
  link-state — distinct from the raw store. Don't let an analytics store
  silently become the trust anchor.
- **Trust-realm gating matches the launch gate.** A gridworks-operated witness
  suffices while both endpoints share one trust realm (scada + ltn are both us
  today). The neutral-third-party requirement only bites when dispatch crosses
  a money/ownership boundary (MarketMaker→home, third-party aggregator) — i.e.
  after the launch, exactly when this design says to engage.
- **LTN↔SCADA is the special case; GNode-to-GNode auth across the market chain
  is the general substrate.** Ties to the standing-context line "signatures
  over canonical bytes = attribution" — the heartbeat-witness is one instance
  of that general attribution layer. What makes LTN↔SCADA special: the LTN
  holds the heat **SLA** on its side of the **DispatchContract**, so "was the
  link live" is also "was the SLA in force." The same link-active mechanism
  recurs one layer up — e.g. an **aggregation providing regulation** wants a
  live-link witness between the aggregation and each individual LTN. Same
  pattern, different DispatchContract; that recurrence is the argument for
  solving it as a substrate rather than a one-off.
- **Boundary, so it isn't conflated:** the *health/analytics* half ("is this
  SCADA rebooting?") is NOT this concern — it's the observability alerter
  (alert #10 "Rebooting") per `../observability/designs/consolidate-from-infra-scada-jk.md`.
  Journalkeeper does health; the neutral witness does adjudication. Keep them
  separate.
