# journalkeeper-and-history — projection + the legacy replay

Status: Draft · Pass 0 · Updated 2026-08-11

What this is: how weather lands in JournalKeeper and how the legacy
record is preserved, for [stand-up-weather-forecast](primary.md) —
plus the persistence grill. Designed with Joe where JK's own tables
move.

## JK MVP — journal the new vocabulary first (2026-08-12)

Before ANY legacy work, and before [`populate.md`](populate.md)
runs: gjk vendors the `gw.weather.*` words into its snapshot and
journals ALL of them — the two stream words (observation, forecast)
and the four record words — into `gridworks.messages`. No projection
yet, no readings rows: messages-table-only, so JK's own tables do
not move and the MVP does not need the Joe conversation. The point:
everything populated is in the journal DB from its first broadcast,
not only in the S3 store. (Emissions before the MVP lands are
recoverable from the eventstore by hand — an accepted, bounded gap.)

## Sema-fy PseudoChannel (the word)

JK's `gjk.pseudo` channel discriminator (see
[`evidence.md`](evidence.md)) becomes a sema word — sketch, to be
settled at the authoring gate:

    gjk.pseudo.channel.gt (working name)
      Name:        flat channel name (today's dash-separated form)
      DisplayName: string
      Unit:        enum gw1.unit
      Quantity:    enum gw1.quantity   # replaces the hand-kept unit_type
      Id:          uuid4.str

Open at authoring: whether Quantity cleanly replaces the legacy
`unit_type` string; per-terminal-asset scoping (today JK syncs pseudo
rows per TA — declared scoping vs mechanical duplication); whether
the word is `.gt`-coupled to JK's channel table.

Rich weather channel records declare their own projection down into
pseudo-channels: flat name = dash-rendering of the LRD Name, unit =
the channel's Unit — mechanically derivable, so the declared knobs
are only the genuinely per-channel choices (JK-facing display name;
whether to project at all; scoping).

**First instances: NEW observed-series pseudo-channels for
Millinocket temperature and windspeed** — declared to accompany the
legacy (Thomas-era) observation history below, which never had a
journaled series (the legacy service published ~2 h stale and its
record was S3-only).

## Historical actual weather — the legacy replay (decided 2026-08-11)

The fleet has no actual-weather series anywhere today. The legacy
`weather` messages are imported ONCE into the new vocabulary — by
**replaying them through the bus**, not by a JK-side importer:

1. **Collect locally.** Pull every legacy `weather` message from the
   S3 eventstore into a gitignored local dir (location open — likely
   a `local/` in gridworks-weather-forecast; nothing under git).
2. **Convert.** Script maps each to a plain `gw.weather.observation`:
   ObservationTime = the legacy `UnixTimeS` (which carried the TRUE
   observation time — the staleness was publish lag, see
   `evidence.md`), Interpolated false, readings on the Millinocket
   channels. The committed wire fixture in the gwwf repo is the
   conversion's reference input.
3. **Populate locally + emit.** The same script both loads the
   converted series locally (dev-side verification against the local
   JK/postgres before anything touches prod) and then emits the
   messages onto the bus as ordinary observation broadcasts — so the
   **ear archives the converted history into the eventstore** and JK
   journals + projects it through the exact same path as live
   messages. One pipeline, no import-only side door; the new-vocab
   history becomes part of the permanent record.
4. **Provenance holds by design.** Replayed messages carry their true
   ObservationTime; publish time = replay time, which the design
   already treats as provenance, not part of the observation claim.
   Consequence to accept explicitly: eventstore keys date by capture,
   so the converted history lands under replay-day keys — fine,
   because ObservationTime in the payload is authoritative and JK
   readings key on it.
5. **Idempotent + re-runnable.** JK's readings insert is
   on-conflict-do-nothing on (timestamp, channel); a re-run is safe.
   Pace the replay so it doesn't crowd live traffic.

**Backfill from archives** (NWS/NOAA historical, keyed by the location
word's external ids) remains available for the gaps: legacy
service-down windows, everything after 2026-07-18, and any station
outage longer than the 3 h interpolation bound.

## Do next — the persistence grill

1. **The JK MVP** (above) — journal all six `gw.weather.*` words,
   messages-table-only; no Joe dependency. Gates populate.
2. The word-gate: author the pseudo-channel word in sema (registry +
   authoring spokes for the type kind, summary posted, confirmation)
   — the sketch above is the input, the gate settles the shape.
3. With Joe: JK's consumption of the word (table shape, per-TA
   scoping, deactivating the twelve legacy forecast-oat/-ws rows, JK
   handling of forecast messages — messages table only; readings stay
   current-weather-only), and where gwwf glitches land.
4. The replay script + local collection (legacy-replay steps 1–3
   above), verified against a local JK before the prod replay.
5. EDD witness: a dev-broker gwwf→JK round trip — a new observation
   word journaled and projected into the new pseudo-channels.
