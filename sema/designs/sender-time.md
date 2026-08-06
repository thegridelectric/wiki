# Sender-time: one name for the sender's clock

Status: Draft · Pass 0 · Updated 2026-08-05

> What this is: the standard for carrying time-as-the-sender-understands-it
> in sema words — one field name, one format, applied as words naturally
> version — plus the first adopter (`g.node.forest/001`) and the snapshot
> upgrades it triggers.

## The standard — two times, not one

A message has up to two sender-clock facts, and store-and-forward words
prove they are different:

- **`SendTimeMs`** — the sender's clock at the moment the message is
  assembled for sending. In-word `SendTimeMs` is ONLY for words that are
  assembled fresh per send (current-state payloads like `g.node.forest`),
  where assembly and send coincide. For persisted-until-acked events the
  send happens hours after creation and re-sends repeat — and a persisted
  artifact is immutable, so it cannot be re-stamped per transmission.
  Per-transmission send time, if ever needed for those, is envelope
  territory (transport metadata), not the word's.
- **`CreatedMs`** — the sender's clock when the message content was
  created. This is what the persisted-event words already carry under
  diverging names (`report.event` and `report` both mean exactly this and
  spell it differently; `glitch` already says `CreatedMs`). The standard
  name is `CreatedMs` — the existing glitch precedent — converged on at
  each word's natural next version.

Common to both:

- **Format:** `$ref` `utc.milliseconds`. A simulated clock still reads as
  epoch milliseconds; nothing in the format distinguishes simulated from
  real — that distinction lives in which universe the sender runs in.
- **Optionality:** optional on adoption. A word MAY make the field
  required in a later version once its senders all stamp it.
- **Neither is** receipt time (the consumer records that) nor
  payload-content time (a forecast's horizon, a reading's sample time —
  those stay their own fields).

## Why

Today every word reinvents this field: `CreatedMs`, `TimeCreatedMs`,
`SendTimeMs`, `UnixMs`, `SnapshotTimeUnixMs`, `MessageCreatedMs`,
`ForecastCreatedS` — the JournalKeeper keeps lookup tables
(`MSG_CREATED_AT_FIELDS_S/_MS` in `sema_message_persistor.py`) just to
find it. As the hybrid universe adds simulated-time actors, consumers
need a uniform slot for the sender's clock: for honest sim-time
analytics, for replayable captured runs, and for order-aware projections
(a consumer can refuse to let an older assertion overwrite a newer one).

## Adoption path — no version-bump cascade

Published versions are immutable and a fleet-wide bump is a known
cascade. The standard applies:

1. **Now:** `g.node.forest/001` — optional `SendTimeMs`, stamped by gnr
   at forest assembly. The registry is never simulated: gnr is a notary,
   and notarization time is wall-clock even when the fleet described runs
   simulated time — recorded as an invariant in the word's description.
   The flip to **required** rides the `g.node.gt/006` sweep (OPS-488):
   the forest bumps to 002 there anyway, and gnr, the sole emitter,
   already stamps at every assembly site.
2. **As words naturally version:** any word carrying a sender-clock field
   under another name converges on the standard at its next version —
   `CreatedMs` for creation time (the persisted-event words:
   `report.event`'s and `report`'s divergent spellings both land here),
   `SendTimeMs` only where assembly and send coincide. New words use the
   standard from birth.
3. **Convention home:** when ratified, the naming rule lands in the sema
   authoring spec (change-controlled — that edit is part of this design's
   completion, discussed per the spec-change protocol).

## Consumers needing upgraded snapshots (for the first adopter)

- **grid-node-registry (gnr)** — emitter; vendored snapshot regen + stamp
  `SendTimeMs` where `get_forest` assembles the broadcast/response.
- **gridworks-journalkeeper (gjk)** — consumer; snapshot regen (seed
  already `include_all_versions`), `persist_v001` on the forest
  persistor; `SendTimeMs` becomes the message's `created_at`.
- **Not affected:** gwbase (its snapshot predates the forest lineage and
  does not carry it); the ear (lossless witness, no sema decode); web
  (reads gnr's REST API, not a snapshot).
- **Later:** the terminalasset-registry inherits the standard at birth;
  the gw_data sent-time column (tracked in the integrate-gwbase-sema-updates
  design) gives projections their do-not-regress guard.
