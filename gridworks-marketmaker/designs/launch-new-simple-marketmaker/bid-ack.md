# The gate and the ack

Status: Draft · Pass 0 · Updated 2026-11-13 · Linear: OPS-431

> What this is: the spoke of the MarketMaker launch that makes a bid a
> contract: the maker books the bids that arrive before the gate, acks
> each one it books, and the LTN contracts only with an ack in hand.
> Sketched 2026-11-13 while the visualizer price panel settled the
> market's product name; not yet grilled.

## Where it starts from

- The Keene market's product is `rt60gate1`: hourly slots, gate closing
  60 s before the slot. The LTN asks the FLO 180 s before the slot, the
  FLO answers in about 10 s, and the bid is sent off the answer, so a bid
  is in the maker's queue about 110 s before the gate.
- The maker receives bids and drops them. The LTN forms its contract
  from `latest.price` alone, which it requires within the first 5 s of
  the hour.
- The fabric has no binding from `amq.topic` into the maker's queue, so
  the LTNs' bids do not reach the maker today.
- Decided 2026-06-10 (hub "Locked decisions"): the queue is the ordering
  authority, and the stored timestamped ack is the contract; the sent
  message is notice of it.

## Proposed

- **The gate is enforced on dequeue.** The maker reads its own clock when
  it takes a bid off the queue. A bid dequeued at or after the gate is
  not booked and is answered with a nack naming the reason; the queue
  stays the ordering authority.
- **The maker acks every bid it books.** Two words in the shape of
  `gw.dispatch.ack` and `gw.dispatch.nack`, with no `gw.` segment
  because, like `bid` and `latest.price`, they are uniform across makers:
  - `bid.ack` 000: `BidderAlias`, `MarketSlotName`, `BidSha256` (the
    SHA-256 of the bid's canonical serialized form; `bid` 000 has no id,
    and naming the bid by content is the standard the tariff evidence
    takes), `CreatedMs` (the maker's clock when it stored the ack, which
    is the contract's time), `MessageId`. The ack asserts one thing: this
    bid is the bidder's bid in this slot's book. It says nothing about
    quantity, which the cleared price decides at the slot start. A
    second bid from the same bidder for the same slot before the gate
    replaces the first and is acked in turn; the latest ack stands.
  - `bid.nack` 000: the same identity fields and a `Reason` from a new
    enum `bid.nack.reason` 000: `Unknown`, `GateClosed`, `WrongMarket`
    (the slot name is not this maker's product and alias),
    `UnitMismatch`, `PriceCeilingMismatch`.
- **The LTN keeps the ack.** It holds the ack for the slot it bid. At
  the slot start it forms its contract from `latest.price` only when it
  holds the ack for that slot; otherwise it runs its no-contract path
  and sends a `glitch` at `Warning`. A nack is logged and sent on as the
  same glitch. This is the behavior change the ack buys: a bid the maker
  never booked no longer becomes a contract on the house's side.
- **The maker stores before it sends.** The stored ack is the record;
  the journalkeeper journals the broadcast ack as it journals
  `latest.price`. Where the maker stores is this spoke's open question;
  the umpire design names the record it serves.

## Open

- Where the maker stores its acks (a local store the umpire reads, or
  the journal alone).
- Whether the ack goes to the bidder directly or is broadcast on the
  maker's mic exchange as `latest.price` is; the LTN hears either on its
  MQTT link.
- What the ack asserts once clearing reads the book: still nothing about
  quantity, or the booked curve by hash.

## Do this next

The fabric binding from `amq.topic` into the maker's queue, proved on
the dev broker with an LTN's real bid arriving and being logged by the
maker. Everything above waits on bids that arrive.
