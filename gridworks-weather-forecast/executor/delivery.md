# delivery — cadence, binding shape, the pull path

Status: Draft · Pass 0 · Updated 2026-11-26

What this is: how a message leaves the service, for
[the hub](primary.md): when it is published, on what routing key, and
the one path a consumer pulls by.

## Cadence

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-11@711a8cc (`experiments/archive/2026-08-11-nws-updatetime-probe/`) — the top-of-hour choice; no emission minute beats another

- Cadence is a record fact: EmitPeriodS and EmitOffsetS on the channel
  and bundle words. Raising a station's cadence to its true update
  rate is a channel-record change.
- The production records emit observations at the top of each hour
  and forecasts one minute after. NWS data freshness is
  issuance-driven, two to four revisions a day, so no emission minute
  beats another; the one-minute offset puts this hour's forecast on
  the wire as soon as "next hour" changes.
- **Records broadcast once, at creation.** Each new record goes out a
  single time when minted, so the archive resolves an archived message
  against the record active at its time. There is no re-broadcast and
  no boot re-emission.
- **A stream emits once when it becomes active, then on its grid.** On
  the first tick after the scheduler is built, a stream with no published
  state at or before the clock's now (a station or bundle just minted, an
  empty database, a clock that moved back) fires the latest grid slot at
  or before now; a stream with such state waits for its next slot.
  Published state is the stream's own: the station's last published slot
  for an observation stream, the bundle's newest served forecast for a
  forecast stream. A source's stored product is shared by every bundle
  on that source, so it says nothing about whether a bundle has
  published. State stamped after now is dropped at build.
- **A channel joins at its station's next fresh observation.** An
  observation channel minted on a station that has already published is
  in the station's next message with a newer observation time. The last
  observation is never sent again with the new channel added.
- **A rebuild loses no slot.** When the records change, the streams as
  they were fire what is due at that tick, and the rebuilt streams start
  from the same now.
- **A failed build is tried again.** A scheduler build that fails is a
  Warning glitch and is retried 30 s later; the streams built before it
  keep emitting until one succeeds.

## Broadcast binding shape

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-12@f4f3d01 (`experiments/archive/2026-08-11-gwwf-obs-roundtrip/`, `experiments/archive/2026-08-12-gwwf-record-broadcast/`)

The radio channel is the dotted tail of the `rjb` routing key,
appended verbatim with dots preserved, so a consumer binds per
segment.

- **Observations:** radio channel = the station alias (`kmlt`). The
  message is per station and holds every quantity the station
  reported.
- **Forecasts:** radio channel = the bundle Name, verbatim
  (`us.me.millinocket.raccoon`), one message per bundle per emission.
- **Records:** location, station, channel, forecast-channel and
  seasonal-template broadcasts have the record's own name as the
  tail. The bundle record broadcasts with no tail. The TypeName
  segment separates record broadcasts from stream messages.
- **Glitches** broadcast with no tail.

## The pull path

The HTTP read API is the single pull path, public and read-only,
every response a sema word byte-identical to its broadcast. It serves
a listing per record kind, the latest observation per station, the
latest forecast per bundle, and a ping. There is no broker
request/response vocabulary. A consumer that misses a broadcast, or
boots without one, pulls here; the emission schedule on the record is
what tells it a message is late.

## Open

- **One stream that cannot be wired fails the whole build.** A forecast
  channel whose Method has no adapter stops every stream from being
  rebuilt. No record has hit it.
- **Bundles with different horizons on one source overwrite each
  other's stored product.** After a restart with the live fetch failing,
  the longer bundle can find a stored product too short for its grid and
  fall to the template rung until the next live fetch.
