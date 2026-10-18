# record-lifecycle — how a record enters

Status: Draft · Pass 0 · Updated 2026-10-18

What this is: how a location, station, channel, forecast channel,
bundle or seasonal template enters the service's record set, for
[the hub](primary.md).

## Minting is a human act

A record enters the world by a person sending the create command, one
sema word over the bus. The command holds the full record; one command
word covers all six record kinds, because the act is the same whatever
the kind. The verdict, an ack or a nack with its reason, goes back
direct to the sender, correlated by the hash of the command bytes as
published. There is no in-code record source and nothing automates
record creation.

The sender is its own operator identity, `<universe>.weatherminter`, a
durable Service principal with its own cert. Each invocation is a fresh
instance on that principal, torn down afterward, so the minter has no
persistent presence on the bus and cannot supersede the actor.

On a command the actor validates it through the vendored snapshot,
inserts the record, broadcasts it once, replies with the verdict, and
rebuilds its emission scheduler from the store, so a freshly minted
bundle starts emitting without a restart. A record that fails
validation, references a record that does not exist, or embeds channel
copies that differ from the canonical rows is refused and nothing is
inserted.

A minted record's broadcast is also its durable copy. Records live in
the store and in the archive; a store rebuild recovers them by
re-minting, which broadcasts each again as a fresh deliberate act.

## Order of a mint

Referential order, so each record's references exist when its checks
run: location and stations, then observation channels, then forecast
channels, then bundles; the location's seasonal template any time
after the location.

## Identity at boot

The actor reads its identity file at boot, validates it, and refuses
to start when the file's alias differs from its configured alias. The
file is the registry's own served record for the service's alias;
obtaining it is the registry's procedure (gnr executor). The actor
checks the file's structure and nothing about live registry status.

## Open

- Whether the create command takes flags or always a records file.
