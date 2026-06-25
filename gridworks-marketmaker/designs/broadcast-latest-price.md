# Broadcast latest.price

Status: Draft · Pass 0 · Updated 2026-06-22 · Linear: OPS-289

**EDD: no** build-out/integration — verified by the suite plus confirming
JournalKeeper actually captures a published `latest.price`, not by a standalone
real-world experiment.

> What this is: have the market maker broadcast `latest.price` on the bus so it
> lands in the persistent store (JournalKeeper), and retire the deprecated
> `EnergyInstruction`. Bite-size, but it carries a protocol decision (the
> publication/persistence path), so it gets a design.

## Current state (verified 2026-06-22)

- `LatestPrice` is a gwsproto named type
  (`packages/gridworks-scada-protocol/.../named_types/latest_price.py`). Today it
  reaches the **LTN** (`ltn.py` `process_latest_price` L1163) and drives contract
  clearing in `contract_handler` (holds `latest_price`, converts
  `PriceTimes1000`). It is **not persisted** — JournalKeeper does not capture it.
- `EnergyInstruction` is a gwsproto named type but is **already deprecated**: its
  only remaining traces are three stale TODO comments in `leaf_ally`
  (`all_tanks.py` L353, `buffer_only.py` L271/295). No live code path uses it.

## Scope

- [ ] **Maker broadcasts `latest.price`** on a topic JournalKeeper subscribes to,
  so the cleared price is persisted. Define the publication (topic / routing /
  cadence). The rebuilt maker owns the `latest.price` out-surface, so this rides
  that work rather than retrofitting a soon-replaced path (sequencing tracked in
  Linear).
- [ ] **Remove the deprecated `EnergyInstruction`** named type and its stale TODO
  references; confirm nothing live depends on it first.

## Open

- Does JournalKeeper already subscribe to a `latest.price` topic, or is a new
  subscription / routing key needed? (Confirm the persistence path.)
- Is the persisted record the raw `latest.price` message, or a projection?
