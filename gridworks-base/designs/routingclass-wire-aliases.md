# `RoutingClass` enum: accept production short-form aliases

Status: Draft · Pass 0 · Updated 2026-05-27

> Wire-codification mismatch: ActorBase 0.4.0's `RoutingClass` set is
> the long forms only; production routing keys use short forms
> (`ws`, `s`) that aren't enumerated, so every wrapped scada / weather
> message gets dropped at parse with "Unknown routing class".

## Symptom

ActorBase 0.4.0's registered `RoutingClass` set is `['ta', 'cn',
'ltn', 'mm', 'scada', 'price', 'weather', 'time', 'super']`.
Production routing keys use **`ws`** for the weather service and
**`s`** for what looks like "scada-short" — neither appears in the
registered set.

Concrete prod examples observed during the 2026-05-24
journalkeeper-on-base-0.4.0 prod-broker integration test (recorded
in [`../../gridworks-journalkeeper/research/refactor-to-base-0.4.2.md`](../../gridworks-journalkeeper/research/refactor-to-base-0.4.2.md)):

- `rjb.hw1-isone-ws.ws.weather` — weather service broadcast,
  every ~10 minutes
- `gw.<scada-alias>.to.s.gridworks-ping` — wrapped ping addressed
  to scada-short, fires constantly
- `gw.<scada-alias>.to.s.slow-contract-heartbeat` — heartbeat
- `gw.<scada-alias>.to.s.gridworks-ack` — acks

Every one of these gets dropped at ActorBase's parse step with
"Unknown routing class". In a 5-minute prod run, 48 messages were
dropped this way — and weather messages (which fire every ~10
minutes per the operator) were never captured even once across two
runs totaling > 5 minutes inside the expected window.

The bug isn't in production: production traffic predates this
ActorBase 0.4.0 codification and uses its established short forms.
The bug is that the codification only enumerates the long forms.

## Plan

Either (a) add the short forms as aliases in the `RoutingClass`
enum (`ws` aliases `weather`; `s` aliases `scada`; maybe others once
their producers are identified), or (b) migrate production to the
long forms (a breaking wire change affecting every existing
deployment — far larger blast radius).

**(a) is the obvious move.** Audit production routing keys (via the
mgmt API or by widening a journalkeeper consumer) to enumerate the
actual short-form set, then extend the enum to accept both.
Routing-key build functions can keep emitting the long forms; only
the parse needs to be tolerant.

## Discovery note

This finding was only visible because the prod-broker run bound `#`
(catch-all) on `ear_tx` — production journalkeeper at
`hw1.isone.journal-F6c6` binds narrow keys (`#.atn-bid`,
`#.energy-instruction`, …) so it never sees these drops. Worth
re-checking with a wider audit binding before the gwbase migration
of the LTN (Stage 1 of `wiki/gridworks-ltn/executor/primary.md`'s
cleanup epic), because the LTN's wire vocabulary likely uses some
of these short forms.
