# Dispatch terms — the draft agreement

Status: Draft · Pass 0 · Updated 2026-11-16 · Linear: OPS-686

> What this is: the draft of the legal agreement that the first dispatch
> terms name. The sema constant `dispatch.terms.first.isone.hack` 000
> (staging) is the agreement's unique name on the wire: every valid
> instance is the same JSON, so a contract that names it names this text
> and no other. `market.terms` 000 is how a MarketMaker states which
> agreement its product runs under. The signed text and the constant's
> promotion are OPS-686's last step; this draft is written here and moves
> to the executor with the rest of the folder.

## Parties

Open. The MarketMaker for the product and the bidder (the LTN acting for
a terminal asset).

## The slot and the price

Open. One clock hour; the price in two stages, `Provisional` at the open
and `Final` on the market's upstream posting; the Provisional is the
Final when no Final is published within 240 s of the open.

## The contract

Open. Created within 10 s of the slot's start; one amendment, at the
Final; the bidder acts on a Provisional only toward less consumption;
completion, termination and the grace period as the heartbeat word
states them.

## Settlement

Open. Energy against the contracted average power; what is owed and to
whom; the market's own settlement with ISO-NE is outside this agreement.
