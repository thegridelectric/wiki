# Price-forecast service — open questions and findings

Status: Draft · Pass 0 · Updated 2026-11-15

> What this is: the research and the open questions around the
> price-forecast service that do not belong in its executor tables
> (`executor/`): when ISO-NE posts, what a store of forecasts would be
> for, and the gaps the executor's Vectors table leaves open.

## When ISO-NE posts

Three sources agree (2026-11-11). ISO-NE posts the day-ahead results
for the next operating day around 13:00 ET: of 148 days of journaled
LTN requests from 2025-11 to 2026-11 whose "tomorrow" prices changed,
66 first showed real prices at the LTN's 12:57 fetch and 71 at 13:57;
the service's first six days on oak split three and three across
13:00. The `/info` endpoint gives the posting time directly (operating
day 2026-11-11 was posted 2026-11-10 at 13:10:05 ET; operating day
2026-11-15 at 12:44:51 ET on 2026-11-14). The
`/day/latest/location/{id}` path answers 500 and an unposted day is an
empty `HourlyLmp` list, so the service reads `/info` and asks for the
day by date.

## A store of forecasts

The service keeps one document and its basis as two files, enough to
serve views between postings and to survive a restart without a
rebuild or a rebroadcast. The next step is a local database of
forecasts, for two reasons:

- **More than one kind of forecast.** A document today is one price
  per hour for one market, built one way (posted day-ahead prices,
  repeated by hour of day, plus the tariff). A store keyed by identity
  lets the service keep and serve forecasts of other kinds beside it:
  a different horizon, a different method (a model's output, a
  real-time-anchored forecast), a different market or product, each a
  word of its own or a version of this one, each with its basis.
- **The basis as a record.** The basis file says which posting a
  document came from and how many hours are ISO-NE's own. Kept per
  forecast in a store, with the tariff revision behind the delivery
  price and later a model's inputs, it is the provenance a reader
  needs to tell a forecast built before a posting from one built
  after it. Until a basis word exists, journaled beside the forecast,
  the journal tells them apart only by `CreatedMs`.

The MarketMaker's store is the same question from the other side: the
price it published for each slot, so a restart can republish or at
least know what it published, and the clearing it will do keeps its
book somewhere.

## Open

- The 25-hour and 23-hour days at the DST changes: ISO-NE labels the
  repeated fall hour `02X` in its reports; how the Web Services API
  represents it is unverified. Slot starts in UTC seconds leave the
  word nothing to say about it.
- The actor has no test in CI (it needs a broker), and CI does not run
  mypy.
- The Vectors rows with no Path: the facade's routes and 503, the
  watcher's cadence before 12:30 and its failure, the restart with a
  current document. None has a field window; each is induced on the
  dev broker when the trace harness runs.
- `glitch` 000 has no example in sema, so the maker's Vectors row for
  it cannot exist; raised through sema's change control.
