# umpire-service

Status: Draft · Pass 0 · Updated 2026-08-26 · Linear: OPS-501

**EDD: yes** the umpire is verified by a real-broker dispute experiment: kill
one party mid-contract on the dev rabbit and show the umpire's record alone
answers "who went dark, when" without consulting scada or LTN.

> What this is: a gwbase service, independent of scada, LTN and MarketMaker,
> that holds the record of authority for contract state between GNodes. It
> settles a question the analytics database should never have to carry.

## The decision this design carries

**gw_data is a projection, not an authority.** The JournalKeeper-fed
database serves visualization, analysis and field issues. It does not
record, adjudicate or attest the state of communication between GNodes
(scada ↔ LTN, LTN ↔ MarketMaker). Two consequences:

- gw_data schema changes are low-stakes. The friction of two people
  co-owning that schema is bounded to the analytics use, and nothing about
  contract authority hangs on it.
- Words with no sender clock stay that way. `power.watts` and the bid carry
  no created-at because the time that matters is when the *authority*
  received them (the aggregator, the MarketMaker). The journal may stamp a
  receipt time for analytics; the authoritative time lives on the
  authority's own record (the timestamped ack that is the contract).

The scada health diagnostics work (OPS-317) keeps JournalKeeper as the
referee for the liveness signal set. That is observability, and it stays in
gw_data. The umpire is the party a financial dispute is settled against.

## What the umpire holds

A narrow, append-only set, each record stamped with the umpire's own receipt
time:

- bids and the MarketMaker's acks (the ack is the binding contract);
- the slow contract heartbeat between scada and LTN;
- ally liveness: `ally.inactive` / `ally.active`, startup / shutdown of the
  contracting parties.

Not held: telemetry, reports, layouts, forecasts. Those are the analytics
database's, and the S3 eventstore is the deep archive for both.

## Why a service, not a second database

The requirements differ from the analytics database in every dimension:
append-only and tamper-evident rather than mutable channels and caches;
retention for the life of the contract rather than a rolling window;
receipt-time stamping by a neutral party; verification of per-beat
signatures and chain links (the current `MyDigit` toggle is a liveness
signal, not evidence); and periodic anchoring (a Merkle root of a contract
window) so the record can be checked later without trusting the umpire
either. That is a service with its own store, addressed like any GNode
service under the universe root, receiving from the broker on its own
bindings.

## Depends on

- The MarketMaker launch (OPS-431): the ack record the umpire holds is
  defined there.
- Umpire-grade contract beats: signed, chained, per the liveness and SLA
  exploration in `wiki/gridworks-scada/explorations/`.
- Message identity (OPS-502): every scada-originated message carries a
  header `MessageId`, so the umpire and the journal name the same utterance.

## Open

- Universe placement and alias (`<universe>.umpire`?), and whether one umpire
  per universe or one per market.
- Store choice: a small Postgres with an append-only role is the obvious
  first cut; the anchoring target (notary, chain) is deferred with
  substrate-fit (OPS-391).
- Which party may query the record and through what read façade
  (`api-pattern.md`).
- The first experiment: the dispute reproducer named in the EDD line, on the
  dev rabbit with a simulated scada and LTN.
