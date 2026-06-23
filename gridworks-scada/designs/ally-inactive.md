# ally-inactive (design)

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-410

> What this is: a fire-and-forget liveness announcement — when a peer
> goes away, say so immediately, on whatever still works — so live
> observers learn about an outage while it is happening. Small,
> deliberately independent of the proactor overhaul (this is a
> change-now item from `executor/scada-ltn-link-state.md`; the overhaul
> is the big job that comes later).

## The gap

Both sides of a scada↔LTN link know every link transition internally,
but nothing is emitted live. The existing comm events
(`MQTTDisconnectEvent`, `ResponseTimeoutEvent`, `PeerActiveEvent`) ride
the persist-then-upload path — stored-until-acked, which by construction
delivers only after the link is back. Verified 2026-06-10 on the dev
rabbit: 30 historical response-timeout events arrived only at the moment
the peer returned. A third-party referee adjudicating "who went dark,
when" — the most important thing a referee could hear — currently can't
hear it.

There is also no unified peer-down concept: peer-up is semantic
(`PeerActiveEvent`) but peer-down exists only as two mechanism events
(MQTT disconnect; ack response timeout). An MQTT disconnect is not the
only way a peer goes away.

## What gets built

1. **A semantic liveness-announcement pair**, new sema words (via
   `/make-sema-word` at build time; deliberately under-prescribed here).
   Vocabulary ruling (2026-06-11): **these two are not peers** — the
   relationship has a natural implied tree order, so the words speak
   parent and child (a parent announcing a child gone dark and a child
   announcing a lost parent are different facts with different
   audiences). Carrying: who noticed, who went dark, the triggering
   mechanism (mqtt-disconnect / response-timeout / future causes), and
   when. New types — not extensions of the existing persisted
   `gridworks.event.comm.*` family, and not stepping on Andrew's.
2. **Fire-and-forget emission, never persisted.** This is a new delivery
   class in the proactor (everything event-like today is
   stored-until-acked): publish immediately, no ack expected, no
   reupload. The seam is small — `generate_event` already branches on
   event kind; this class skips the persister entirely.
3. **Emit on whatever still works:**
   - Peer dead but broker alive (LTN process dies; the response-timeout
     case): announce on the *same* broker — observers like a JK with a
     catch-all binding see it instantly. This case works precisely
     because peer ≠ broker, even though the current link concept
     conflates them.
   - Broker connection dead (the MQTT-disconnect case): the scada
     announces on its other links (local, admin); the LTN announces
     upstream on the rabbit side.
4. **Mirror `ally.active` on recovery**, same fire-and-forget class, so
   observers see outage *and* restoration without consulting either
   interested party.

## Explicitly out of scope

- Detection. The ping→ack keepalive already bounds each party's
  awareness of a dead ally at about a minute, in both
  directions — neutral, not a problem. This design is about
  *emission*, not detection.
- Any change to the stored-until-acked comm events — they stay, as the
  durable record; ally.inactive is the live wire, not the archive.
- The proactor link overhaul (1:1, peer/broker conflation). This design
  must land without waiting for it.

## Acceptance

- Kill the LTN process while both sit on the dev rabbit: a
  `ally.inactive` from the scada is visible to a catch-all broker
  observer within seconds of the response timeout (not after
  reconnection).
- Pull the scada's broker connection: `ally.inactive` about the scada
  appears from the LTN upstream, and the scada announces on local/admin.
- Restore the peer: `ally.active` follows, same path.
- A JK (or `mosquitto_sub`) sees outage and recovery as they happen,
  with neither the scada nor LTN consulted.

## Relationships

- Born from the link-state findings (`executor/scada-ltn-link-state.md`)
  and the third-party-referee thread — the same requirement the
  marketmaker's constitutive stored ack serves from the other end:
  contracts whose truth outsiders can hear.
- Code lands in gwproactor (emission seam) + scada/LTN wiring; sema
  words via `/make-sema-word`.
- Pairs naturally with the poison-message change-now item (separate
  design) — both are small transport honesty fixes that precede the
  overhaul.
