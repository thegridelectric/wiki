# local-admin-session

Status: Draft · Pass 0 · Updated 2026-09-09 · Linear: OPS-529

**EDD: yes** verified on the bench rig against a real broker: cut the admin
client's tunnel and watch the scada leave Admin within ten seconds; open a
second client and watch the first go dead and say who took it.

> What this is: the admin session and the admin process behind which
> the named humans stand, built on today's carrier, the Pi's local
> Mosquitto over tailscale, with no dependency on the new envelope.
> Stage 2 of the hub's Stages (`../executor/primary.md`). Every word
> here carries unchanged onto the prod broker later
> ([OPS-429](https://linear.app/gridworks/issue/OPS-429)). It absorbs
> the admin peer-liveness chunk of the spruce rope
> ([OPS-392](https://linear.app/gridworks/issue/OPS-392)).

## The problem, as observed

Neither side notices a dead link. The admin client publishes a dispatch
and watches for a few seconds; the scada holds Admin until a fixed timer
from the last admin message and never learns whether the operator is
still there; the operator never learns whether the scada is still
listening. On bench run 4 (2026-09-05, `experiments/2026-09-05-dac-output-bench/boot-2026-09-05-run4.log`)
the laptop's tunnel died silently eight seconds after a send; the scada
logged nothing for two minutes, then its 120 s timer fired after SIGTERM
had already cancelled its tasks:

```
23:01:37.205 [secondary-010v] Dispatch from admin: volts x10 55 -> code 2200
23:03:37.205 Shutting down due to ShutdownMessage, [Signal received: SIGTERM (15)]
23:03:37.287 [scada] Admin timed out! Auto
```

A second problem sits next to it: any client on the local broker is
"admin". Two operators can both believe they hold the pump, and a stray
client that hears the scada's traffic can answer it.

## The admin process and the humans behind it

One admin identity per universe. The scada has two talkers, its LTN and
`<universe>.admin`. Behind that identity is the admin process, which
the named humans use with their own credentials:

- **Here** the admin process is `gwa` itself on an operator's laptop.
  There is no cert on the local path; the human's name is typed into
  the client and rides in take-control. The roster is who has the
  tailscale key.
- **On the prod broker** ([OPS-429](https://linear.app/gridworks/issue/OPS-429))
  the same process holds the `hw1.admin` cert and a roster of human
  client certs, and the humans present their own cert to it. Nothing in
  this design changes for that; only the carrier under it does.

Either way the scada sees one admin peer and learns the human only from
the take-control word. Four people never become four scada peers.

## The mechanism

Four words and one broker setting. The scada
owns the session record `(holder, session id, last hex seen, deadline)`.

1. **Take-control** (new word). Carries `OperatorName` and a fresh
   session id. The scada enters Admin (or stays there), records the
   holder and the session, and replies with its first beat. A
   take-control while another session is live is a takeover: the old
   session is dead from that moment and the scada publishes
   holder-changed.
2. **`heartbeat.a`, both ways, carrying the session id.** 2 s cadence, no
   acks demanded. Each beat carries a fresh single-character `MyHex` and
   the peer's last as `YourLastHex`. The scada answers only beats on the
   live session. Three missed beats end the session: the scada leaves
   Admin the way the timer does today, in seconds, not minutes. The
   client shows "in control" only while its own echo returns, never
   "sent".
3. **Holder-changed** (new word). Published by the scada on its admin
   topic on every takeover, naming the new `OperatorName` and session.
   Both clients hear it; the bumped one shows "admin taken by George"
   as its final line and stops beating.
4. **Release.** The existing `admin.release.control`, missed beats, or
   the hold deadline. All three return the scada to Auto through the
   same path.
5. **One MQTT client id for every admin client.** MQTT requires the
   broker to disconnect an existing client when a new one connects with
   the same ClientId, and Mosquitto does. That is the kick at the
   transport level, free. It is not enough alone: the kicked client is
   told nothing but "disconnected", and an old client that auto-reconnects
   steals the connection back. The session record and holder-changed
   are what make both visible and harmless. Where gwadmin sets its
   ClientId today (inside the proactor's ConstrainedMQTTClient) is the
   first thing to check.

**Hearing a beat is never an invitation.** A beat or command on an
unknown session is ignored and logged. Joining is an explicit
take-control. This is what stops the stray-client case.

**Session and hold.** The session governs live control and the display.
The existing per-command timeout stays as the hold for this first pass:
a session that dies ends the beats and the "in control" display, and the
scada leaves Admin by the missed-beat rule. Whether a deliberately set
long hold should outlive a dead session is decided in
[OPS-194](https://linear.app/gridworks/issue/OPS-194), not here.

## What the words look like

- **take-control**: `OperatorName` (the human, a name format, not an
  alias), `SessionId`. Minted by the client. Sema word, new.
- **heartbeat.a/001**: `MyHex` (`hex.char`), `YourLastHex` (`hex.char`,
  optional), `SessionId` (required). 000 is published and unused, so 001
  is a new version, not an edit in place, and its canon is rewritten: a
  heartbeat is always inside an explicitly opened session, within one
  trust domain, peers identified by alias at the envelope; the same
  word serves admin ↔ scada, LTN ↔ scada link liveness and supervisor
  ↔ supervisee. The contract-tier instrument stays a separate, heavier
  word. No FromAlias in the payload: the sender is the envelope's fact.
- **holder-changed**: `OperatorName`, `SessionId`. Published by the scada.
- The four existing admin words gain `SessionId` in their next versions
  so a stray dispatch from a dead session is refused too. Not required
  here; the window is the few seconds before the old client sees
  holder-changed.
- **Open: the audit word.** Every open, takeover, release and expiry
  should reach `ear` naming the human, the scada, the session and the
  outcome. The local path has no `ear`, so the word is authored with
  the prod-broker design
  ([OPS-429](https://linear.app/gridworks/issue/OPS-429)); whether
  holder-changed doubles as it or a separate session-event word is
  minted is decided there.

Every word above is authored under the sema gate: registry and authoring
spokes read, summary posted, confirmation waited for, before any edit.
`heartbeat.a` and the new words need gwsproto twins (the closure mirror
rule).

## Build order

1. Check the admin client's MQTT ClientId; fix it to one value.
2. `heartbeat.a/001`, take-control, holder-changed in sema; gwsproto
   twins; snapshot refresh.
3. Scada: the session record, take-control and holder-changed handling,
   the beat loop with the three-miss rule, ignore-unknown-session. All
   as ordinary application messages on the existing admin link; the
   proactor link mechanism is not touched.
4. Client: take-control on connect with the operator's name, the beat
   loop, "in control" only on echo, holder-changed display.
5. Bench: the two EDD runs above, logged under `experiments/`.

## Done-when

- Cutting the client's tunnel: the scada logs the missed beats and
  leaves Admin within ten seconds; the client shows not-in-control
  within the same window.
- A second client's take-control: the scada publishes holder-changed;
  the first client shows who took it and stops beating; its later beats
  are ignored and logged.
- A client that only listens and echoes, with no take-control, never
  gets an echo back.

## Out of scope

- The missing `return` in `process_admin_dispatch` (`scada.py`, the
  "Ignoring AdminDispatch" branch that then executes the dispatch). It
  belongs to the spruce rope
  ([OPS-392](https://linear.app/gridworks/issue/OPS-392)).
- The prod broker, `hw1.admin`, the human roster of certs
  ([OPS-429](https://linear.app/gridworks/issue/OPS-429)) and the
  envelope grammar under it
  ([OPS-428](https://linear.app/gridworks/issue/OPS-428)).
- Hold semantics ([OPS-194](https://linear.app/gridworks/issue/OPS-194)).
- A browser front. Not planned. If it ever comes it follows the hub's
  "A login is never authority" invariant and gets its own design.
