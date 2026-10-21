# Sender-time: one name for the sender's clock

Status: Accepted · Pass 1 · Updated 2026-10-21 · Linear: OPS-472

> What this is: the standard for the sender's clock in sema words:
> `CreatedMs` by default, `SendTimeMs` for reassembled current-state
> words, one format, applied as words naturally version. The first
> adopter (`g.node.forest`) and the authoring rule are done; the
> consumer rule remains.

## The standard — two times, not one

A message has up to two sender-clock facts. `CreatedMs` is the default
and every word has it; `SendTimeMs` is the exception.

- **`CreatedMs`** — the sender's clock when the message content came
  to be. Every word takes it from birth. A word whose content is a
  state change, an observation or a record is complete with this one
  field, whether it is sent at once or stored and re-sent later: the
  content was created once, and that is its time. `glitch`, fire-and-forget
  and never stored, already says `CreatedMs`; the persisted-event words
  have the same fact under diverging names (`report.event` and `report`
  both mean exactly this and spell it differently) and each converges
  on `CreatedMs` at its natural next version.
- **`SendTimeMs`** — the sender's clock at the moment the message is
  assembled for sending, for a word whose assembly indicates no state
  change: a reassembly of current state on each request or broadcast,
  where a re-send rebuilds the message rather than repeating it
  (`g.node.forest`, a dashboard summary). Such a word has no
  `CreatedMs`, since nothing in it came to be at a moment.

A word never has both. For a word created at one time and transmitted
later, stored until acked and re-sent, the time of each transmission is
transport metadata and belongs in the envelope; the stored word stays
immutable with its `CreatedMs`.

Two worked examples. `gw.house.operating.status` is assembled fresh on
every change, but each instance records a state change and may one day
be stored and re-sent as an event, so it takes `CreatedMs`. A
house-summary response is rebuilt per request from projections and
says nothing about when any state changed, so it takes `SendTimeMs`.

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

1. **First adopter, done.** `g.node.forest/001` has optional
   `SendTimeMs` and `/002` requires it. gnr stamps it at every forest
   assembly (`src/gnr/db/authority.py`, the registry's wall clock: gnr
   is a notary, and notarization time is wall-clock even when the fleet
   described runs simulated time, recorded as an invariant in the word's
   description). Journalkeeper's forest persistor takes it as the
   message's created time for both versions.
2. **As words naturally version:** any word with a sender-clock field
   under another name converges on the standard at its next version:
   `CreatedMs` for creation time (the persisted-event words,
   `report.event`'s and `report`'s divergent spellings both end up
   here; `gw.house.operating.status` renames `UnixMs` before it is
   published), `SendTimeMs` only for the reassembled current-state
   words. New words use the standard from birth. One published word
   misfits: `energy.instruction/000` says `SendTimeMs` for what is a
   command created at a moment. Nothing sends or handles it (checked
   2026-10-21: a protocol class, two seed requests, a journalkeeper
   table entry, three TODO comments), so it converges on `CreatedMs`
   at whichever version revives it and no bump is forced now.
3. **Consumers read the standard names first.** The journalkeeper's
   sema message persistor takes `CreatedMs`, else `SendTimeMs`, from
   any payload before consulting its per-type table, so a word on the
   standard needs no table entry; the table shrinks to the legacy
   spellings and goes when the last of them converges. The first
   beneficiary is the latest-status projection for
   `gw.house.operating.status`, and this step is built with that
   projection rather than as its own issue. The dashboard frontend
   reads the same two names and nothing else.
4. **Convention home: `wiki/conventions/sema-CLAUDE.md` "Registry
   rules".** The sema spec is the language-neutral standard and says
   nothing about which field names a GridWorks word uses; that is our
   own authoring rule, so it lives in the protocol file every sema
   session loads. Written 2026-10-21.

## Build status

- `g.node.forest/001` and `/002`, gnr stamping, journalkeeper
  persisting: done.
- `layout.bundle/000` (`SendTimeMs`), `glitch/000` and
  `gw.opsgenie.alert/000` (`CreatedMs`): on the standard from birth.
- The rule in `sema-CLAUDE.md`: done.
- Open: the consumer rule in journalkeeper's sema message persistor
  (step 3, built with the `gw.house.operating.status` projection); the
  `UnixMs` rename in that word before it is published.
- Not affected: gwbase (its snapshot predates the forest lineage); the
  ear (lossless witness, no sema decode). The gw_data `sent_at` columns
  give projections their do-not-regress guard.
