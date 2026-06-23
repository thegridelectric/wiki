# Scada health diagnostics

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-317

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

## The signal it consumes (emitted by the `ally-inactive` design)

The live peer-down signal this design relies on — fire-and-forget `ally.inactive`
(with `ally.active` on recovery), published the moment a peer goes dark on
whatever broker still works, deliberately **not** a stored-until-acked Event so it
arrives live rather than after the link is back — is designed and emitted by the
**ally-inactive** design (OPS-410). This design does **not** re-specify emission;
it **consumes** that signal — persisting it and surfacing it. (Gate: the
`ally.inactive` sema word is not yet authored — that coining belongs to the
ally-inactive design.)

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
  release** (the `ally.inactive` word — coined by the ally-inactive design —
  needs a JK snapshot regen from sema dev). Gated behind that emission work.
