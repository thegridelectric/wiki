# Scada health diagnostics

Status: Draft · Pass 0 · Updated 2026-06-22 · Linear: OPS-317

**EDD: yes** verified by a real-broker outage experiment: kill a peer and observe
the live `ally.inactive` signal published + journaled immediately, and the
back-office reflect the down state well inside the current ~10-minute lag.

> What this is: make a SCADA going dark **fast to detect and easy to observe**.
> LTNs already learn quickly when a SCADA drops (internet outage, etc.), but the
> alert lags ~10 minutes and the back-office app has no view of it. The fix is a
> live peer-down signal plus persisting the durable liveness signal set so a
> third-party referee (JournalKeeper) has the "who went dark, when" record.
> (Moved here from OPS-386 item #3; JK's persist *mechanism* stays JK-side — see
> below.)

## The problem

- A peer going dark is only learned **after the fact**. The proactor's
  `CommEvent`s (`MQTTDisconnectEvent`, `ResponseTimeoutEvent`, …) ride the
  **stored-until-acked** event path, so they reach the wire only **after the link
  is already back** — stale, and duplicated under a flap. No live outage signal
  exists.
- No back-office visibility into the up/down state.

## The signal: `ally.inactive` (live, fire-and-forget)

The key new piece: a **live peer-down signal** that is deliberately **not** a
`gridworks.event.*` and **not** an Event — being an Event is exactly what makes
the comm types arrive too late.

- **`ally.inactive`** — fire-and-forget, unpersisted at the emitter,
  semantically named (covers MQTT drop AND response-timeout AND any future way a
  peer vanishes). Published the moment a peer goes dark, straight out the
  announcer's **own broker connection** — independent of the (now-dead) path to
  the vanished peer, so any third party hears it immediately. Frame as plain
  broker reachability, **not** proactor "links" (the 1:1 link FSM is the
  abstraction under critique).
- **Up/down asymmetry kept on purpose.** Peer-**up** is the existing proactor
  Event `gridworks.event.comm.peer.active` (after-the-fact); peer-**down** is the
  new non-event `ally.inactive` (live). Different mechanism, different name
  ("peer" vs "ally") — real friction the proactor rewrite will resolve; capture
  it asymmetrically for now rather than papering over it.

**Status of the word: not yet authored.** `ally.inactive` does **not exist** in
any `sema` ref (checked `dev`/`main`/working tree 2026-06-22). The branch
`jm/proactor-link-vocab` it was once parked against is **merged into `sema` dev
and carries no unique commits** — a dead pointer. The word still needs coining
via `/make-sema-word` (read `sema/CLAUDE.md` + `spec/primary.md` first): a
**versioned** type, CamelCase serialized fields, `TypeName` `ally.inactive`,
carrying at least the announcer alias, the ally that went dark, the cause, and an
emit timestamp.

## Persist the durable liveness signal set

JournalKeeper is the third-party referee — it should ingest + persist the durable
**semantic** liveness signals (not the proactor **mechanism** events the rewrite
will churn):

- **Persist:** `gridworks.event.startup`, `gridworks.event.shutdown`,
  `gridworks.event.comm.peer.active`, and `ally.inactive` (the one outage type JK
  can stamp with a real live `time_received`). `gridworks.ack` / `gridworks.ping`
  ride along as general durable signals.
- **Skip:** `send.layout`, `gridworks.event.comm.mqtt.connect` / `…fully.subscribed`
  / `…response.timeout` — mechanism detail the proactor rewrite redefines.

The **how** (JK's seed → snapshot-regen → persistor recipe) is JournalKeeper's
own mechanism and stays documented in
`gridworks-journalkeeper/designs/integrate-gwbase-sema-updates/persisted-type-set.md`
(the JK persist reference). This design owns the *what + why* (which signals,
and the live-detection purpose); JK owns the *how*.

## Open

- Back-office surface: where/how the up/down state shows (admin panel? a
  derived channel?).
- Sequencing gate: the persist half is **blocked on a clean `sema` + `wiki/sema`
  release** (the new `ally.inactive` word needs a JK snapshot regen from sema
  dev). Coin the word first.
- Does peer-down want an eventual `ally.active` / rename, or does that wait for
  the proactor rewrite?
