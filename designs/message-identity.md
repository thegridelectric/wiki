# message-identity

Status: Draft · Pass 0 · Updated 2026-08-28 · Linear: OPS-502

**EDD: yes** verified by replaying one real window through both paths: live
messages journaled from the dev rabbit, then the same window imported from
S3, with zero duplicate `messages` rows for every type, including the ones
with no created time.

> What this is: two small changes that make every scada-originated message
> journal exactly once, whether it arrives live or from the S3 archive.
> Spans gwproto (the header), JournalKeeper (the persistor and importer) and
> gridworks-data (one table).

## Why

The `messages` table is keyed `(timestamp, id)` and dedupes across the live
and import paths only when both halves come from the payload. Words with no
created time (`power.watts`, `atn.bid`, `latest.price`, the weather
cmd/ack/observation records) get a path-dependent id and timestamp, so an
overlap between the back-fill and the live era writes the same message
twice. Today the recorded per-type floors keep the paths from overlapping;
that is a fence, not a fix.

A message id identifies the utterance. It says nothing about when the fact
is true, so adding one does not reintroduce a sender clock into words whose
authoritative time is the receiving authority's receipt stamp.

## Which words carry what today

From the JournalKeeper persistor's id / created-at field maps against the
vendored vocabulary (2026-08-26). "Path-dependent id" means
`uuid5(from_alias | type | persisted_ms)`, where `persisted_ms` is JK's
receipt time on the rabbit path and the ear's S3 key time on the import
path, so the two paths never agree.

| word | payload id | payload created time | dedupes across paths today |
|---|---|---|---|
| `report.event`, `layout.lite`, `scada.params`, `gridworks.event.problem`, `gw.weather.channel.gt`, `gw.weather.forecast.channel.gt`, `gw.weather.location.gt`, `gw.weather.forecast.bundle.gt` | `MessageId` (or `Id`) | yes | yes |
| `snapshot.spaceheat`, `glitch`, `energy.instruction`, `new.command.tree`, `ticklist.reed.report`, `ticklist.hall.report`, `heating.forecast`, `gw.weather.forecast`, `flo.params.house0`, `weather.forecast` | none (path-dependent) | yes | no — same timestamp, different id |
| `power.watts`, `atn.bid`, `latest.price`, `gw.weather.observation`, `gw.weather.cmd.ack`, `gw.weather.cmd.nack`, `gw.weather.create.cmd` | none (path-dependent) | **none** — `timestamp = persisted_at` | no — different timestamp and id |

The third group is what the S3 importer refuses outright (no created time
to key on); the second group it imports only because the recorded floors
keep it clear of the live era. Of the third group, `power.watts` (2024-10
onward) and `atn.bid` (Dec 2024 onward) are the ones with archive below the
2026-01-09 floor that the OPS-498 load could not carry; `latest.price` is
small, and the weather cmd/obs words only exist from Aug 2026. Change 1
moves every scada-originated word in groups two and three into group one
without touching the payloads; the gwbase-native words (`atn.bid`, the
weather cmd/ack) stay with OPS-501.

## Change 1: the header always carries a `MessageId`

`gwproto` `Header.MessageId` exists and defaults to `""`
(`gridworks-protocol/src/gwproto/message.py:35`). Every message gets a
fresh uuid at construction; the field becomes required. The ear stores the
wrapped `{Header, Payload, TypeName}` object
(`gridworks-journalkeeper/src/gjk/version_scan.py:190`) and the live
JournalKeeper reads the header (`journal_keeper.py:143`), so the id is
visible on both paths. `gridworks.header` is a published word, so this is a
new version, not an in-place edit. On the wire today (eventstore, Aug 2026)
the proactor event and `gridworks.ping` envelopes already carry a real
header `MessageId` with `AckRequired: true`; `report.event`, `layout.lite`
and `scada.params` headers carry their payload's id; `gridworks.ack` rides
with `""`. The change is for the remaining words.

Out of scope: gwbase-native words (bids, acks, instructions) do not ride
this header. Their identity is the authority's ack record; see OPS-501.

Archive below the change carries no header id for the clock-free words;
those rows stay keyed on the ear's key time, which is adequate for
analytics.

## Change 2: an identity table in gw_data

`messages` is a Timescale hypertable partitioned on `timestamp`, and a
hypertable's unique constraints must include the partition column, so
"unique on id" cannot live there. A pre-insert lookup is racy and probes
every chunk; folding the id into the timestamp has nothing to fold.

`gridworks.message_ids (id uuid primary key, timestamp timestamptz not
null)`, owned by gridworks-data. In the same transaction that writes
`messages`, the persistor runs `INSERT INTO message_ids ... ON CONFLICT DO
NOTHING RETURNING id`; only returned ids proceed to the `messages` row and
derived readings and channel work. Batch path: one `executemany ...
RETURNING`, no extra round trip per message. One-time backfill:
`INSERT INTO message_ids SELECT id, timestamp FROM messages ON CONFLICT DO
NOTHING`.

The vocabulary rule this enables: a word journaled exactly once carries a
`MessageId`; a created time still places the row in time but is no longer
required for identity. The importer's refusal loosens from "created time
required" to "id or created time".

## Sequencing

After the OPS-498 load lands. Nothing in that load depends on this; the
floors keep the paths apart until then.

## Open

- Whether the persistor takes the id from the header or the payload when
  both are present (payload `MessageId` today for `report.event`,
  `layout.lite`, `scada.params`; they should agree, and the header is the
  universal one).
- The `gridworks.header` version bump lands in gwproto; confirm the proactor
  makeover (OPS-428) envelope carries the same field so the rule survives
  the transport change.
