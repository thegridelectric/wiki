# gridworks-admin — primary

Status: Draft · Pass 1 · Updated 2026-09-09

> **What this is.** The hub for the GridWorks admin domain: the
> operator-facing surface for incident-mode intervention on a deployed
> scada. Holds the trust model (one admin identity per universe, named
> humans behind it), the admin session (holder, session id, heartbeat,
> hold), the substrate and its routing gap, and the stages off the
> tailscale + local-MQTT path. The running mechanism today is in
> [`conversation.md`](conversation.md).

## One-line summary

Admin is the rare, time-bounded back door through which a named human
drives a scada's actuators directly. The scada's TopState goes
`Auto → Admin`, its own control goes Dormant, and the heating SLA is
suspended for the duration. Admin is parallel to the control plane,
never part of it: the LTN stays the scada's one normal writer, and
customer preferences never come here (they ride the LTN,
[OPS-408](https://linear.app/gridworks/issue/OPS-408)).

## Motivation

The existing admin path (`gridworks-scada/packages/gridworks-admin/`,
the `gwa watch` TUI talking to a local Mosquitto broker on each Pi via
tailscale) was right for the bench and the first houses. Two pressures
break it:

1. **No identity on the path.** The local broker takes any client;
   nothing says which human sent a dispatch, and nothing notices when
   the human's link dies (bench run 4, 2026-09-05: a tunnel died
   silently and the scada sat in Admin with no operator attached).
2. **Trust model.** Tailscale-membership auth does not compose with the
   mTLS + FIS Principal model for every prod-broker connection
   ([OPS-420](https://linear.app/gridworks/issue/OPS-420)), and a
   per-Pi tailnet does not scale with the fleet.

Admin needs its own domain because its trust model, audit
requirements, and operational shape differ from both the control plane
(which it interrupts) and the customer-facing LTN API.

## Scope

Admin is **incident mode**: SCADA TopState `Auto → Admin`. When an
operator enters Admin on a SCADA, that SCADA's hierarchical control
goes Dormant; the actuator forest reassigns to operator commands;
the **heating SLA is suspended** for the duration.

Operation surface (per `gw_spaceheat/actors/scada.py:78-82, 287-487`):

| Word | Status |
|---|---|
| `admin.dispatch` — direct actuator/relay command | Existing |
| `admin.analog.dispatch` — analog setpoint command | Existing |
| `admin.keep.alive` — extend the hold | Existing |
| `admin.release.control` — explicit return to Auto | Existing |
| take-control — open a session, name the operator | Planned (session) |
| holder-changed — the scada announces a takeover | Planned (session) |
| `ReadState` — live state query | MVP-likely |
| `PushLayout` — hardware-layout reconfig | Defer |

The method is the TypeName. There is no method slot in any routing
key, on any carrier ([`../../api-pattern.md`](../../api-pattern.md)
"Route grammar", gwbase `transport.md` "Routing-key grammar").

### What admin is NOT

- The customer-facing thermostat interface. Homeowner / fleet-owner
  preferences route through the LTN and stay in `Auto`.
- General remote management or developer-style RPC.
- Live-state monitoring at fleet scale — that's observability
  ([`../../observability/`](../../observability/)), always-on, both
  modes.
- Provisioning / installer
  ([`../../gridworks-provisioning/`](../../gridworks-provisioning/)),
  which runs pre-identity over HTTPS.
- A platform-down tool. Every admin path rides a broker; when the
  broker is gone the scada is in LocalControl by design and the human
  path is ssh to the Pi.

## Invariants

- **One admin identity per universe.** The scada has two talkers, its
  LTN and `<universe>.admin` (`hw1.admin`). Admin is one broker
  principal with one cert; FIS single-writer on it gives one admin
  connection per run. Four people never become four scada peers.
- **Named humans behind it, each with a personal cert.** The admin
  identity is held by an admin process the humans authenticate to with
  their own client certs (a CLI or TUI over HTTPS, not a browser). The
  roster of who may drive admin is the set of certs that process
  accepts. The human's name rides in the take-control word and in
  every audit event; the broker never sees the human.
- **A login is never authority.** If a browser front ever exists it
  follows the mTLS rule: a phishing-resistant hardware-bound credential
  per human, a fresh step-up assertion for actuator commands, and a
  gateway that mints a short-lived cert for that human rather than
  holding standing authority of its own (mtls-fis-auth,
  [OPS-420](https://linear.app/gridworks/issue/OPS-420), "Gateway
  boundary").
- **The scada owns the session.** Holder, session id, last heartbeat
  and deadline live on the scada. The admin process arbitrates which
  human is behind the identity; the scada enforces one session per
  scada regardless. Neither layer trusts the other to have got it
  right.
- **Session and hold are different things.** A session is a human at
  the controls, bounded by heartbeat; losing it ends live control
  within seconds. A hold is a deliberately set timed posture (pump off
  for three hours), bounded by its deadline and a safety cap; it may
  outlive the session only when the operator asked for that. The
  default is session-bound.
- **Hearing a heartbeat is never an invitation.** Every beat carries
  the session id; a beat or command on an unknown session is ignored.
  Joining is an explicit take-control, recorded and announced.
- **Every direct message names both parties.** From-alias and to-alias
  in the routing key and the header; the broker pins the from-alias
  (the addressed `gw` envelope,
  [OPS-428](https://linear.app/gridworks/issue/OPS-428)).
- **Every open, takeover, release and expiry is an audit event** on
  `ear`, naming the human.

## The admin session

The session is the unit of "we are actually talking right now".

- **Open.** The admin process sends take-control naming the human
  (`OperatorName`) and minting a session id. The scada records
  `(holder, session id, last hex, deadline)`, enters Admin, and answers
  with its first beat.
- **Beat.** `heartbeat.a` both ways, 2 s cadence, no acks demanded: a
  fresh `MyHex` and the peer's last as `YourLastHex`, plus the session
  id (planned `heartbeat.a/001`; one hex character stays enough once
  the session id carries identity). The client shows "in control" only
  while its own echo returns. Three missed beats end the session at the
  scada; a dead tunnel is visible at both ends in under ten seconds.
- **Takeover.** A take-control from another human opens a new session;
  the old one is dead from that moment. The scada publishes
  holder-changed so the bumped client shows "admin taken by George"
  and stops beating. The admin process tells both humans first, but
  the scada's rule does not depend on that.
- **Release and expiry.** Explicit `admin.release.control`, missed
  beats, or the hold deadline. Any of them returns the scada to Auto
  through the same path.
- **What survives a dead session** is the hold question above; the
  first pass leaves the existing timeout as the hold and lets the
  session govern only live control and the display.

## Substrate and routing

**Today:** the admin client speaks MQTT to the Pi's local Mosquitto
over tailscale, on the `gw` envelope, as the proactor's fixed `admin`
peer (`conversation.md`). No identity, no liveness.

**Target: the prod broker.** We trust it for the control plane; a
second broker would not shrink the trust surface. The Principal model
separates admin from the control plane at the cert and permission
level, not at a broker boundary (the same reasoning as the
analytics-broker deferral, `../../rmqbot/designs/analytics-broker-shovel.md`).

**The routing gap.** The scada sits outside the gwbase fabric: it
subscribes on `amq.topic`, so reach to a scada is gated by connection
auth alone, never by the binding table, and the `gw` key has no
destination alias (`to.<to-class>` only resolved because each proactor
link was 1:1). Admin is the first second talker and needs a real
to-alias. Two consequences, both owned by the proactor makeover
([OPS-428](https://linear.app/gridworks/issue/OPS-428)):

- the addressed envelope, `gw.<from-alias>.to.<to-class>.<to-alias>.<type-name>`
  with a header carrying `MessageId` and `CreatedAtUnixMs`;
- the scada joining the fabric, so `adminmic_tx → scada_tx` and
  `ltnmic_tx → scada_tx` are the only edges into a scada. The MQTT
  plugin's exchange (`mqtt.exchange`) can be pointed at `scada_tx`
  instead of `amq.topic`; this holds as long as every MQTT client on
  the prod broker is a scada.

Until then admin stays on the local broker, with the session built
there so that only the carrier changes later.

### Mechanism vs. meaning decoupling

Operation contracts are typed request, typed response, idempotent
where possible, one audit event per call, whatever the carrier. See
[`../explorations/when-to-add-grpc.md`](../explorations/when-to-add-grpc.md)
for the gRPC question.

## The capabilities contract (what the admin client consumes today)

Status: Verified · Pass 1 · Updated 2026-09-08 · Reviewed 2026-09-08@ea3365b5

The `gwa` TUI learns what it can operate from
**`scada.control.capabilities`**, published by the scada on link-up
(the client asks with `SendControlCapabilities` and re-asks every 60 s
until it arrives). Its purpose: **decouple the admin's knowledge of the
house from `layout.lite`**. Historically every flo-params change bumped
layout.lite's version and broke the TUI until it was upgraded;
capabilities is the stable, control-focused projection the admin
depends on across layout churn. The client never reads `layout.lite`.

**The word, `001` (staging;
`sema/definitions/types/scada.control.capabilities/001.yaml`).**
`RelayNodes`, `DacNodes` and `CommandNodes` as `spaceheat.node.gt`,
`ControlChannels` as `data.channel.gt`, and `CommandInterfaces`, one
`gw.command.interface/000` per commandable node: `ActorName`,
`EventType` (an enum word), `StateType` (an enum word) and `Commands`,
the `{Event, ToState}` pairs the node takes. Axiom 4,
CommandInterfacesCoverTheTree, is **the cover rule read off handles**:
an interface exists for exactly the relays and command nodes whose
handle does not extend a command node's handle. A relay owned by an
interior command node (`vdc-relay` under the pico-cycler,
`hp-scada-ops-relay` under hp-boss) keeps its state row and no
interface; the operator commands it through its owner. DAC nodes take
an analog value and carry no interface. The scada builds the cover from
its live handles (`gw_spaceheat/actors/scada.py:1692`
`control_capabilities`); relay vocabulary comes from each relay's own
config, interior nodes' from `Scada.COMMAND_NODE_INTERFACES`
(`scada.py:1653`).

**What the client keys off.** One row per `CommandInterfaces` entry,
keyed by `ActorName` (`watch/clients/relay_client.py:167`). The dispatch
address is `admin.<ActorName>`; the row's actions are the interface's
`Commands`; the row's state is the node's `StateType` value, taken from
`snapshot.spaceheat`'s `LatestStateList` and from the
`single.machine.state` the scada forwards over the admin link for every
relay and command node (`scada.py:1556`). A row shows `?` until its
node's first state report arrives. Readings for the 0-10V channels
still arrive as forwarded `single.reading`. An interior node's owned
relays are listed under it, by name, as presentation only; the word
stays a flat per-node list.

**Replies.** Every command node answers the boss that commanded it:
`gw.dispatch.ack` on take, `gw.dispatch.nack` with a
`gw.scada.cmd.refusal.reason` on refusal (Busy, UnknownEvent,
OutOfRange today). The client tracks each command by `TriggerId` and
toasts one line per answer (`watch/relay_app.py:255`).

**Verified on the real house, 2026-09-08**
(`experiments/2026-09-08-spruce-admin-panel/`): on spruce's Nolan
layout the panel rendered the twenty relays, the pico-cycler and
hp-boss rows and the DAC; Reboot picos, relay and valve events and DAC
levels each reached the actor the row names and the row followed the
node's state report. The sim witness with the same client is
`experiments/2026-09-07-admin-reboots-picos/`.

## Identity and audit

- **On the broker,** `hw1.admin` is a service-kind Principal: one cert,
  one FIS lease per run, from-alias pinned on every publish. FIS needs
  no operator kind and no per-method permission map.
- **Behind it,** the admin process holds the roster: the client certs
  of the humans allowed to drive admin in that universe. A human's
  identity is universe-independent; their authority is not (a `w`
  admin is a separate, heavier question under the validation plane).
- **Attribution.** The human's name is in the take-control word and in
  every audit event the scada and the admin process emit. Broker-side
  `validated-user-id` does not survive the MQTT hop and is not relied
  on.
- **Audit stream.** Every open, takeover, release, expiry and dispatch
  goes to `ear` as a structured event: human, target scada, word,
  session id, result. This is the first-class record; broker logs are
  backup.

## Stages

1. **Today.** `gwa` over tailscale to the Pi's Mosquitto; the proactor
   admin link; hold by timeout only.
2. **Session on the local broker.** Take-control, heartbeat, takeover
   and holder-changed on the existing path; one fixed MQTT client id so
   the broker disconnects the previous admin client; the scada
   ignoring an old session. Everything built here carries into stage 3
   unchanged. Design:
   [OPS-529](https://linear.app/gridworks/issue/OPS-529).
3. **Admin on the fabric.** `hw1.admin` on the prod broker with the
   addressed envelope and the scada in the fabric
   ([OPS-428](https://linear.app/gridworks/issue/OPS-428)), FIS
   pinning ([OPS-420](https://linear.app/gridworks/issue/OPS-420)).
   Tailscale stops carrying admin. Design:
   [OPS-429](https://linear.app/gridworks/issue/OPS-429).
4. **Read-only views**, when wanted, come through the public read
   façade ([`../../api-pattern.md`](../../api-pattern.md)), no
   session. A browser front for control is not planned.

## Open

- **Hold semantics** past the first pass: the default hold when a
  session dies, the "until released" option and its safety cap
  ([OPS-194](https://linear.app/gridworks/issue/OPS-194)).
- **`heartbeat.a/001`** with a required session id, adopted for
  admin ↔ scada, LTN ↔ scada link liveness and supervisor ↔
  supervisee alike; the contract-tier instrument stays its own word.
  Sema authoring turn, not yet done.
- **Admin process shape at stage 3:** a cloud service, or the same
  process on an operator's laptop holding the `hw1.admin` cert as the
  interim.
- **`ReadState` and `PushLayout`** scope; the TUI package extraction out
  of the scada repo.
- **When a dedicated admin broker would be worth it:** compliance
  separation, cross-region DR, or admin volume beyond plausible.

## Cross-references

- [`conversation.md`](conversation.md) — how the client and a scada
  talk today: the admin link, the request/forward conversation, the
  timeout, the tree under admin, the two indirect addresses.
- [`../explorations/when-to-add-grpc.md`](../explorations/when-to-add-grpc.md)
  — when to add a gRPC pathway alongside the broker substrate
- [`../explorations/admin-gateway-service.md`](../explorations/admin-gateway-service.md)
  — the browser-front question, still exploratory
- [`../../gridworks-fleet-index-service/explorations/principal-model.md`](../../gridworks-fleet-index-service/explorations/principal-model.md)
  — FIS-side auth model
- [`../../gridworks-base/executor/transport.md`](../../gridworks-base/executor/transport.md)
  — routing-key grammars and the fabric the scada is not yet in
- [`../../gridworks-scada/executor/scada-ltn-link-state.md`](../../gridworks-scada/executor/scada-ltn-link-state.md)
  — the LTN link's liveness today and why the 1:1 link cannot carry a
  second talker
- Legacy code: `gridworks-scada/packages/gridworks-admin/` (the
  `gwa` CLI), `gridworks-scada/gw_spaceheat/actors/scada.py:287-487`
  (the AdminDispatch / AdminKeepAlive / AdminReleaseControl
  handlers)
