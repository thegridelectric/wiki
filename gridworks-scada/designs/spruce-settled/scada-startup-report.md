# Scada startup report (spoke)

Status: Draft · Pass 0 · Updated 2026-09-19 · Linear: OPS-532

> What this is: a `scada.startup.report` word that a scada sends once per
> run, saying when the run started, when the report was sent, and which
> commit the box runs.

## Problem

Nothing on the broker says that a scada restarted, when, or on what code.
A restart is read today off a gap in the readings or off the box's
journal.

- The proactor's `gridworks.event.startup` does not answer this. It is
  about the comm layer's start, it carries no application facts, and it
  rides the acked event path: `gwproactor/links/link_manager.py`
  `generate_event` publishes only when the upstream link is `active` and
  persists the event otherwise, so with no LTN it stays on the box.
- The commit a box runs is checked from the laptop when an experiment
  window opens (`experiments/house_window.sh`), and is recorded nowhere
  in the data the fleet emits.

## Decision: a plain report word, beside the deed

`scada.startup.report` is a scada word like `layout.lite`. It is not a
proactor event: no event envelope, no `gridworks.event.*` name, no ack.
The proactor's events describe communication; this describes the
application's run.

The home's `ta.deed` stays its own message and is not a field of the
report. The deed is a validator's signed attestation and is found by its
type; with no deed the scada's `no-ta-deed` glitch is the statement.

Fields:

| Field | Format | Holds |
| --- | --- | --- |
| `FromGNodeAlias` | `left.right.dot` | the scada's GNode alias |
| `StartedAt` | `utc.milliseconds` | when this run of the scada started |
| `SentAt` | `utc.milliseconds` | when the report was handed to the link |
| `Commit` | a new format word | the commit the scada checkout is at |

A report that arrives late says so by the distance between `StartedAt`
and `SentAt`.

Sema has no format for a commit hash (`hex.char` is the nearest word).
The commit gets a format word of its own, forty lowercase hex characters,
and not a bare string with a length axiom.

## Change

- Sema: the format word, then `scada.startup.report/000`, flat, with the
  gwsproto twin written by hand and checked with `sema validate`.
- Scada: the report is one more send in `Scada.send_startup_announcements`,
  the once-per-run method (`executor/scada-ltn-link-state.md` "The startup
  announcements"). `StartedAt` is taken once when the scada app starts;
  `SentAt` when the method runs.
- The LTN decodes the report and drops it, as it does the deed. The
  journal is the reader.

## Tests

Each shown red with the change reverted.

- The twin round-trips and rejects a commit that is not forty lowercase
  hex characters.
- `send_startup_announcements` sends exactly one report; `StartedAt` is
  the app's start and does not move when the send is late; `SentAt` is
  not before `StartedAt`.

## Witness

EDD, in dev: a window with no LTN puts one `scada.startup.report` on
`gw-dev-rabbit`, its `Commit` equal to the checkout's head. Then a window
started with the broker unreachable and the tunnel opened minutes later:
the report arrives once, with `SentAt` minutes after `StartedAt`.

## Do this next

1. Pass this spoke with the human.
2. The sema sitting for the format word and the type.
3. Build the twin, the send and the tests; run the dev witness.

## Open

- How the scada learns its commit: read from the checkout at start
  (a deployed box holds a full clone), or handed in by the service unit.
  A dirty tree on a dev laptop needs an answer too.
- Whether JournalKeeper journals the word, or the eventstore is where it
  is read.
- Other facts that identify a run and may belong here: the layout and ops
  words' versions the scada booted on, the gwsproto version.
