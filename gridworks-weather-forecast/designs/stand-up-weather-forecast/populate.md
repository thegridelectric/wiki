# populate — growing the production record set

Status: Draft · Pass 0 · Updated 2026-08-12

What this is: how the production record set grows beyond the standup
seed for [stand-up-weather-forecast](primary.md) — the minting acts,
their order, and the JournalKeeper gate.

## Minting is a human act

A new location / channel / forecast-channel / bundle enters the world
by a person sending the create command — a sema word over the bus
(`gwwf create <record.json>` wraps the authored record instance;
[`build.md`](build.md) step 7, the gnr write pattern). gwwf validates,
inserts, broadcasts the record, and acks; the ear witnesses command,
verdict, and record — the store holds the full provenance of every
record's existence. Nothing automates record creation. Once-ness of
the broadcast is the deliberate act itself — no bookkeeping column,
no re-emission.

A minted record's broadcast is also its durable copy: minted records
live in the DB and the store, not in git — `gwwf seed` restores only
the standup six (`records.py`), so after populate begins, a DB
rebuild recovers minted records from the eventstore by hand.

## Order of a mint

Referential order, so each record's references already exist when its
axioms fire: location → observation channels → forecast channels →
bundle (the bundle embeds its channels).

## The JournalKeeper gate

Populate runs AFTER the JK MVP
([`journalkeeper-and-history.md`](journalkeeper-and-history.md)
"JK MVP"): gjk first learns to journal ALL the new-vocabulary
messages — the two stream words and the four record words — so
everything populated is in the journal DB from its first broadcast,
not only in the S3 store.

## Open

- The target channel set: quantities beyond temperature/windspeed,
  additional locations, challenger forecasters to skill-score —
  settle with the user when populate begins.
- Whether mint commands take flags or a records file.
