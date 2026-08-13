# record-lifecycle — how records enter and grow the production set

Status: Draft · Pass 0 · Updated 2026-08-13

What this is: how a location, channel, forecast-channel, or bundle
enters gwwf's production record set for [gwwf](primary.md) — the
minting mechanism, referential order, and the GNode-registration
procedure a service needs before it can mint anything at all.

## Minting is a human act

A new record enters the world by a person sending the create
command — a sema word over the bus (`gwwf create <record.json>` wraps
the authored record instance). The command word carries the full
record plus a `Proof` placeholder (authority = the authenticated
connection until the authority substrate lands); ack/nack twins reply
direct, discriminated by TypeName and correlated by the command's
content hash. One command word covers all four record kinds — its
Record slot is a closed `oneOf` over the four record words — because
the act is the same regardless of kind: create a record.

The sender is its own weather-class operator identity
(`<universe>.weatherminter`), never the service's own alias — this
identity is created fresh for each invocation and torn down
afterward; it has no persistent presence. Command and verdict ride
the fabric's `(WeatherForecastService, WeatherForecastService)`
self-edge.

gwwf's actor validates the command through the vendored snapshot,
inserts the record (insert-only — records are durable identities,
never upserted; a bundle's embedded channel copies must equal the
canonical rows or the create is refused), broadcasts the record once
(radio tail = its own name, the bundle tail-less — see
[`delivery.md`](delivery.md)), replies with the verdict, and rebuilds
its emission scheduler from the DB — a freshly minted bundle starts
emitting without a restart. The ear witnesses the command, the
verdict, and the record broadcast — full provenance for every
record's existence. There is no in-code record source; nothing
automates record creation. Once-ness of the broadcast is the
deliberate act itself.

A minted record's broadcast is also its durable copy: records live in
the DB and the persistent store, not in git, so a DB rebuild recovers
records from the eventstore by hand — or by re-minting through
`gwwf create`, which re-broadcasts as a fresh deliberate act.

## Order of a mint

Referential order, so each record's references already exist when its
axioms fire: **location → observation channels → forecast channels →
bundle** (the bundle embeds its channels).

## GNode registration — required before a service can mint anything

Before a service's actor can accept create commands at all, its own
GNode identity must be real, not self-asserted:

1. Check `gnr` for an existing registration at the intended alias
   (`GET /gnr/g-node-by-alias/<alias>`) before assuming one needs
   minting.
2. Verify gwbase's own vendored `g.node.gt` snapshot supports the
   registry's current schema version — a stale vendored copy will
   reject (or worse, silently accept a malformed) identity file.
3. If no registration exists, register for real via `gnr create` —
   never place a hand-authored `g.node.gt.json` and call it done.
4. Write the service's local `~/.config/gridworks/<service>/g.node.gt.json`
   FROM the registry's own served record
   (`GET /gnr/g-node-by-alias/<alias>`), never hand-authored. The
   `GridworksActor` binding invariant requires
   `GNodeGt.alias == settings.service_alias` — keep both in sync
   whenever either changes.

`gnr`'s registry is an append-only ledger: there is no delete, and
today (2026-08-13) there is no supported path from `Pending` to
`Active` status either — every node in the fleet's registry is
currently `Pending`. This does not block a service from running:
`GridworksActor` only validates the local identity file's own
structure at boot, never live registry status.

## The JournalKeeper gate

Populate (widening beyond the initial record set) runs only after
JournalKeeper has vendored and journals every `gw.weather.*` word
messages-table-only, so everything populated is in the journal DB
from its first broadcast, not only in the persistent store. gjk also
auto-creates a reading channel per embedded OBSERVATION channel the
moment it journals a bundle-creation broadcast — see gjk's own
executor docs for that mechanism; this repo asserts only what gwwf
itself does.

## Open

- The target channel set beyond the initial standup (additional
  quantities, locations, challenger forecasters to skill-score) —
  settle with the user as populate widens.
- Whether mint commands take flags or always a records file.
