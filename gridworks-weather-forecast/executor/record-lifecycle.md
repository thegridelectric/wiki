# record-lifecycle — how a record enters

Status: Draft · Pass 0 · Updated 2026-11-16

What this is: how a location, station, channel, forecast channel,
bundle or seasonal template enters the service's record set, and how a
station's history enters its channels, for [the hub](primary.md).

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

## Filling history

A station's past enters by the archive command, the same round as a
mint: one sema word from the minter principal, the verdict direct to
the sender, correlated by the command's content hash. The command
names the station, its channels, a Method with its SourceLocator, and
a half-open window. The actor checks every refusable fact before it
pulls: the station and channels are records on that station, the
Method is in its table of long pulls, and the pull serves each
channel's Quantity. It then pulls the whole series, lays each quantity
on the channels' shared grid, and acks. The ack means the pull
succeeded and the replay is under way.

The replay is one `gw.weather.observation` per grid point in the
window that has at least one reading, Interpolated false, published
on the station's radio channel from a worker thread with a fixed
interval between sends, so the keeper's loop is not swamped. A point
the source has no value for has no reading; a point with no readings
has no message. A failure mid-replay is a glitch naming how far it
got. History travels the bus as live observations do, so the archive
and the journal receive it by their ordinary paths, and the command
and its verdict beside it are the provenance of the window.

The Method table is code: one long pull per Method, with the
quantities its product serves. Open-Meteo's Historical Forecast API
(`open.meteo.historical.forecast.hourly`) is the archive of past
forecasts stitched from the most recent run for each hour; irradiance
shifts back one hour as the live product does, temperature and wind
speed are instantaneous at the label. The IEM ASOS archive
(`iem.asos.hourly`, `src/gwwf/iem_asos.py`) is a station's own routine
METAR record, temperature and wind speed; each observation goes to the
top of the hour nearest it (KMLT reports at :53), the nearest row wins
an hour with several, and knots become mph. The station's own record is
the only honest backfill for a station: a model gridpoint's values on
a station's channels would claim the station observed what a model
computed.

A station with no network identifier is a model gridpoint. Its
observation stream is the pinned model's hour-mean value for the hour
just ended, from the product the forecast fetch already pulls, so the
series stays continuous after a backfill with no further command. The
Open-Meteo Millinocket gridpoint (`ommillinocket`) has three channels.
Its irradiance is the fleet's irradiance actual: no measured irradiance
is in reach. Its temperature and wind speed are a second, labelled
instrument beside kmlt's, which stays the station record; a consumer
picks its channels by station alias and name, and the hourly function
reads kmlt first and the gridpoint where kmlt has no reading. A composite actual is the consumer's: the observation word keeps
one station per message, and each journal reading names its channel.

Verified on prod 2026-11-16 (`fa8b0d6`): the journal has
`ommillinocket-irradiance` on the hour from 2024-10-01 continuing live,
and `kmlt-temperature` and `kmlt-windspeed` on the hour from 2024-10-01
to the live start on 2026-10-25, one row per hour KMLT reported, with
no "readings dropped" line in the JournalKeeper log. The hours with no
kmlt row are hours the station filed no routine report.

## Identity at boot

The actor reads its identity file at boot, validates it, and refuses
to start when the file's alias differs from its configured alias. The
file is the registry's own served record for the service's alias;
obtaining it is the registry's procedure (gnr executor). The actor
checks the file's structure and nothing about live registry status.

## Open

- Whether the create command takes flags or always a records file.
- The pull ledger: one row per fetch, live or archive, naming the
  Method, SourceLocator, window and code revision.
