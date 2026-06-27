# Scada health diagnostics

Status: Draft · Pass 0 · Updated 2026-06-26 · Linear: OPS-317

**EDD: yes** verified by a real-broker outage experiment: kill a peer and observe
the live `ally.inactive` signal published + journaled immediately, and the
back-office reflect the down state well inside the current ~10-minute lag.

> What this is: make a SCADA going dark **fast to detect and easy to observe**.
> One design, two halves: **emit** a live peer-down signal the moment a peer goes
> away (fire-and-forget `ally.inactive` / `ally.active`), and **persist** the
> durable liveness signal set so a third-party referee (JournalKeeper) holds the
> "who went dark, when" record. (Folds the former ally-inactive work —
> [OPS-410](https://linear.app/gridworks/issue/OPS-410); moved here from
> [OPS-386](https://linear.app/gridworks/issue/OPS-386) #3.) The proactor overhaul
> is the big job that comes later — this is a change-now item from
> [`../executor/scada-ltn-link-state.md`](../executor/scada-ltn-link-state.md).

## The problem

- A peer going dark is only learned **after the fact**. The proactor's
  `CommEvent`s (`MQTTDisconnectEvent`, `ResponseTimeoutEvent`, `PeerActiveEvent`)
  ride the **stored-until-acked** path, so they reach the wire only **after the
  link is already back** — stale, duplicated under a flap. Verified 2026-06-10 on
  dev rabbit: 30 historical response-timeout events arrived only when the peer
  returned. A third-party referee adjudicating "who went dark, when" can't hear it
  live.
- No **unified peer-down** concept: peer-up is semantic (`PeerActiveEvent`) but
  peer-down exists only as two mechanism events (MQTT disconnect; ack
  response-timeout). An MQTT disconnect is not the only way a peer goes away.
- No **back-office visibility** into the up/down state.

## Emit — the live `ally.inactive` / `ally.active` signal

1. **A semantic liveness-announcement pair**, new sema words (via `/make-sema-word`
   at build; deliberately under-prescribed here). Vocabulary ruling (2026-06-11):
   **these two are not peers** — the relationship has a natural implied tree order,
   so the words speak **parent and child** (a parent announcing a child gone dark
   vs a child announcing a lost parent are different facts with different
   audiences). Carrying: who noticed, who went dark, the triggering mechanism
   (mqtt-disconnect / response-timeout / future causes), and when. New types — not
   extensions of the persisted `gridworks.event.comm.*` family.
2. **Fire-and-forget, never persisted** — a new delivery class in the proactor
   (everything event-like today is stored-until-acked): publish immediately, no
   ack, no reupload. Small seam — `generate_event` already branches on event kind;
   this class skips the persister.
3. **Emit on whatever still works:**
   - Peer dead, broker alive (LTN process dies; response-timeout): announce on the
     *same* broker — a JK with a catch-all binding sees it instantly. Works because
     peer ≠ broker.
   - Broker connection dead (MQTT-disconnect): the scada announces on its other
     links (local, admin); the LTN announces upstream.
4. **Mirror `ally.active` on recovery**, same class — observers see outage *and*
   restoration without consulting either interested party.

Detection is **not** in scope: the ping→ack keepalive already bounds each party's
awareness of a dead ally at about a minute, both directions. This design is about
*emission*, not detection.

## Persist — the durable liveness signal set

JournalKeeper is the third-party referee — it ingests + persists the durable
**semantic** liveness signals (not the proactor **mechanism** events the rewrite
will churn):

- **Persist:** `gridworks.event.startup`, `gridworks.event.shutdown`,
  `gridworks.event.comm.peer.active`, and `ally.inactive` (the one outage type JK
  can stamp with a real live `time_received`). `gridworks.ack` / `gridworks.ping`
  ride along as general durable signals.
- **Skip:** `send.layout`, `gridworks.event.comm.mqtt.connect` /
  `…fully.subscribed` / `…response.timeout` — mechanism detail the proactor
  rewrite redefines.

The **how** (JK's seed → snapshot-regen → persistor recipe) is JournalKeeper's own
mechanism, documented JournalKeeper-side. This design owns the *what + why*.

## Acceptance

- Kill the LTN process while both sit on the dev rabbit: an `ally.inactive` from
  the scada is visible to a catch-all broker observer within seconds of the
  response timeout (not after reconnection), **and** journaled.
- Pull the scada's broker connection: `ally.inactive` about the scada appears from
  the LTN upstream; the scada announces on local/admin.
- Restore the peer: `ally.active` follows, same path.
- The back-office reflects the down state well inside the current ~10-minute lag.

## Open

- Back-office surface: where/how the up/down state shows (admin panel? a derived
  channel?).
- Sequencing gate: the **persist** half is blocked on a clean `sema` + `wiki/sema`
  release (the `ally.inactive` word needs a JK snapshot regen from sema dev). The
  **emit** half lands independently — it does not wait on the proactor overhaul.
- Pairs with the poison-messages change-now fix
  ([OPS-432](https://linear.app/gridworks/issue/OPS-432)) — both are small
  transport-honesty fixes that precede the overhaul.
