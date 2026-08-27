# message-identity

Status: Draft · Pass 0 · Updated 2026-08-26 · Linear: OPS-502

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

## Change 1: the header always carries a `MessageId`

`gwproto` `Header.MessageId` exists and defaults to `""`
(`gridworks-protocol/src/gwproto/message.py:35`). Every message gets a
fresh uuid at construction; the field becomes required. The ear stores the
wrapped `{Header, Payload, TypeName}` object
(`gridworks-journalkeeper/src/gjk/version_scan.py:190`) and the live
JournalKeeper reads the header (`journal_keeper.py:143`), so the id is
visible on both paths. `gridworks.header` is a published word, so this is a
new version, not an in-place edit.

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
