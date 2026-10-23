# readings-fan-out-cost

Status: Draft · Pass 0 · Updated 2026-10-22 · Linear: OPS-616

**EDD: yes** verified on hw1 at a five-minute reporting mark: with the
change deployed, every message in the burst is persisted within one
second of its send time, and a `report.event` of 900 readings costs the
keeper's message loop no more than any other message. The witness is a
journal query over one mark, before and after.

> What this is: the journalkeeper's message loop persists one message at
> a time, and a `report.event` costs it 1 to 3 s because every reading
> in the report is written as its own row inside that loop. At five
> houses the fleet's five-minute burst delays everything else journaled
> by up to 12 s; at a hundred houses the burst outlasts the reporting
> period and the journal never catches up. This design takes the
> readings fan-out off the keeper's clock.

## Why

The keeper is one consumer on the broker. It takes a message, writes its
`messages` row, runs the type's projection (`readings` for a report,
the channel sync for a layout) and only then takes the next. A
`report.event` from a house every five minutes holds 300 to 900
readings, and the projection inserts them one row each into the
`readings` hypertable at 1 to 3 ms a row. Every other journaled type,
glitches, snapshots, the MarketMaker's `latest.price`, persists in
about 10 ms.

Measured on hw1 at the 2026-10-22 20:00Z mark with five reporting
houses: 32 messages in the minute, the last persisted 8.5 s after it
was sent; the same spike at every five-minute mark, and the same shape
a week earlier. The first real `latest.price` from the stopgap
MarketMaker was persisted 5.6 s after the maker published it, having
waited behind four reports. The record is
`experiments/2026-10-22-stopgap-mm/` "Found".

The keeper on hw1 runs code from before the layouts and house-status
projections, so neither is a cause today; the house-status projection's
newest-snapshot read over `messages` is a second cost of the same kind
that joins the loop when it deploys.

At a hundred houses the five-minute burst is 100 to 300 s of keeper
time, the whole reporting period. The queue never drains. The journal
is the source for every consumer that reads fleet state (the dashboard,
the alerter's projections, the settled-price series), so its lag is
theirs.

## Requirement

A message's time in the keeper's loop is bounded by its own `messages`
row. A report's reading count does not set the loop's pace.

## Options

1. **Bulk load per report.** Keep the fan-out in the loop but make it
   one load per report rather than one insert per row: a `COPY` or a
   single multi-row statement sized to the report. Cheapest change; the
   loop still pays per report, and the conflict check per row on the
   hypertable's unique index stays. Likely 10x, not 100x.
2. **Fan-out off the loop.** The loop writes the `messages` row and
   enqueues the report's id; a second worker in the same process reads
   `messages` and projects `readings` behind it. The loop is bounded by
   one row; readings lag the message by the worker's backlog but never
   block it. The S3 backfill importer already projects readings from
   stored messages, so the projection-from-a-row path exists.
3. **Readings as a database projection.** The keeper writes only
   `messages`; `readings` is maintained by the database (a trigger, a
   continuous aggregate, or a scheduled job over new rows). Moves the
   cost into Postgres, where it competes with readers. The journal DB
   health design (gridworks-data) is the place that cost is budgeted.

Option 2 is the shape the keeper already half has (the importer), keeps
the readings projection in the keeper's own code, and gives the
observable the requirement asks for. Option 1 is a fine first step
inside option 2's worker.

## Also

- `readings` has no index on `message_id`; a per-message count of
  readings is a full scan and hits the statement timeout. Whether to
  index it is a reader-side question for the same design, since the
  off-loop worker will want to know what it has already projected.
- The keeper logs nothing per message. A per-message timing line
  (type, sender, loop time, projection time) is the instrument this
  design is verified with and stays after.

## Out

- The scada's reporting rate or report size.
- The layouts and house-status projections' own cost, beyond noting
  that they ride the same loop.
- Retention and refill of `readings` (gridworks-data).

## Open

- Whether readings consumers tolerate readings lagging `messages` by a
  worker's backlog, and by how much. The dashboard reads snapshots, not
  readings, for live state; analysis reads readings hours later.
- The worker's restart contract: what it does with reports journaled
  but not yet projected.

## Plan

Open until the design is Accepted. Expected shape: the timing line
first (the instrument), then the worker, then the witness at one mark.
