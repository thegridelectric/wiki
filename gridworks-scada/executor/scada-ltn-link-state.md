Status: Draft · Pass 0 · Updated 2026-06-25

# SCADA ↔ LTN link state (the proactor linking mechanism)

What this is: how the scada's broker links come up, stay alive, and fail
— the gwproactor link state machine (Andrew Schweitzer's design) as the
scada uses it today. Seeded from the first live run on `gw-dev-rabbit`
(2026-06-10). This is the **verified account of what IS** — current
behavior and the structural critique of today's mechanism; the rewrite
spec it motivated now lives in the proactor makeover
([OPS-428](https://linear.app/gridworks/issue/OPS-428)). Proactor
internals belong to the `wiki/gridworks-proactor/` domain; this doc
covers the scada-side contract and observed behavior.

## The three links

`gridworks_mqtt` (upstream, to the LTN) · `local_mqtt` (LAN, Scada2) ·
`admin`. Each is an independent instance of the same state machine.

## How a link stays alive

The parent initiates the key mechanism by which both parties keep
aware that their link is active: a `gridworks.ping`, about once a
minute. The child responds with a `gridworks.ack`. Every ping demands
an ack, and an ack that does not arrive within 5 s
(`ack_timeout_seconds`) drops the sender's side to `awaiting_peer` —
so each party learns of a dead ally within about a minute. The roles
are asymmetric in operation even though both ends run the same code:
each side pings only after 60 s of its own quiet
(`mqtt_link_poll_seconds`), and the child's telemetry keeps its
direction busy, so the recurring steady-state pair is the parent's
ping and the child's ack.

Any AckRequired send arms the same 5 s timer — event uploads are
AckRequired too (`link_manager.py:283,344,489`) — and any inbound
message re-activates `awaiting_peer → active`. The two directions
detect differently: pings fire off `last_send + 60 s`, so the child's
own chatter (snapshots every ~30 s, no ack demanded) suppresses its
pings — **the child learns of a dead parent through its event uploads**
(~1/min in practice; on an event-quiet house, not until the next
event), while the send-quiet parent's pings bound its detection at
~65 s regardless.

**Smell (2026-06-11): the snapshot cadence is unwittingly load-bearing
for liveness.** Part of why snapshots go every 30 s is to keep the
link alive — but that wiring is weak and implicit: `seconds_per_snapshot`
is a `.env` telemetry setting, hijacked for a comm purpose it never
declares. It suppresses the child's pings (last_send stays fresh) and
supplies the parent's steady evidence of life; change it for a
telemetry reason (bandwidth, reporting cadence) and you silently
change the link's keepalive behavior. There is no
`last_recv` silence deadline: liveness rides outbound-ack accounting,
not inbound silence, which also keeps detection *internal* to each
party (the emission gap below). The 5 s timeout is an order of
magnitude tighter than the original design intent ("gross, ~1 min")
and is the flap period under poison events (below).

## The state machine (gwproactor `links/link_state.py`)

States: `none · not_started · connecting · awaiting_setup_and_peer ·
awaiting_setup · awaiting_peer · active · stopped`.

One FSM instance per link, the same code on both ends, **one peer per
link — 1:1 by design** (see the structural critique below). Designed
transport-agnostic: a rabbit-native carrier was anticipated from the
start (the setup-steps state generalizes beyond MQTT suback). Not yet
traced live: the failure edges (connect-failure self-loop, per-state
disconnect → `connecting`, and the `awaiting_setup` path, reached only
when the peer appears before your own suback). The ever-5 s flapping
in the capture below was only visible because poison events kept an
AckRequired send perpetually in flight.

## The contract-tier heartbeat is a separate, unfinished story

The LTN demands no acks on its application sends (dispatches,
send.layout — `Header.AckRequired` defaults False and nothing in
`actors/ltn/` sets it); transport liveness is the ping mechanism
above. `SlowContractHeartbeat` (sent every 60 s while a contract is
live, `ltn/contract_handler.py:285`) is a first rough attempt at what
is really wanted: a contract-tier heartbeat in the **`heartbeat.a`
shape** — the `MyHex`/`YourLastHex` echo, where each side proves the
other actually heard it, missed or duplicated beats are detectable,
and liveness does not depend on the proactor's ack machinery (so it
survives the transport redo). Today the SlowContractHeartbeat has no
silence deadline of its own — the only time-based logic in its loop is
contract expiry. One sema wrinkle to resolve before adopting the
shape: `heartbeat.a`'s own extended_description scopes it to
supervisor-tier liveness in a single trust domain and explicitly names
scada↔LTN contract liveness as "a distinct, heavier mechanism … not
modeled by this type" — amend that canon or mint a sibling type
(sema-side decision, pending).

## What belongs on the upstream stream (principle, 2026-06-11)

The upstream stream backs contracts. Its audience is the ally
and any referee (a JournalKeeper, an umpire) — and neither should be
inside the business of a process-controls company. Today every process
start uploads comm events for **all three links** — including
`local_mqtt` and `admin` — to the LTN, so a referee watching the
stream learns which sub-scada links reported active. That is
house-internal telemetry, not contract backing. The line to hold:
liveness of the scada↔LTN link itself belongs upstream; the health of
internal links stays local (or goes to observability channels, never
the contract stream).

- **Send-readiness is broader than active:** `state_is_active_for_send()`
  admits both `active` and `awaiting_peer` — a side will publish toward
  a peer it hasn't heard from yet.
- **Verified live path (2026-06-10, scada on gw-dev-rabbit, nolan
  layout):** all three links walked `connecting → (mqtt_connected) →
  awaiting_setup_and_peer → (mqtt_suback) → awaiting_peer`, with
  periodic `send_ping` tasks per link. `awaiting_peer → active` requires
  hearing the peer — verifying that back-and-forth (and the
  `response_timeout` regression `active → awaiting_peer`) needs the LTN
  running too: it rides the unlimbo hello-world work
  ([OPS-392](https://linear.app/gridworks/issue/OPS-392)).

## Observed startup sequence (verified 2026-06-10, dev rabbit; wire capture + both process logs)

Topic grammar: `gw/<src>/to/<dst>/<type-kebab>`; note the **asymmetric
short names** — scada addresses `ltn`, the LTN addresses `s`, and the
LTN's source alias is the *parent* gnode (`…orange1`, no `.scada`).
Two views of the same startup: first the **wire view** — message arrival
order with full routing keys, i.e. *what is normal to see on the broker*
for anyone watching with a catch-all consumer; then the **protocol
view** — the same exchange interleaved with the link-FSM transitions
that drive it (connection setup is invisible on the gw topics: MQTT
CONNECT/SUBACK are broker control packets, FSM transitions are
process-internal — those come from the two process logs).

### Wire view — what a broker observer sees, in order

| SCADA | dir | LTN | message (TypeName · topic) |
|---|---|---|---|
| scada | → | (void) | `gridworks.ping` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/gridworks-ping` — sent while `awaiting_peer`, no LTN alive |
| scada | → | (void) | `heating.forecast` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/heating-forecast` |
| scada | → | (void) | `weather.forecast` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/weather-forecast` |
| scada | → | (void) | `snapshot.spaceheat` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/snapshot-spaceheat` — repeats every ~30 s (`awaiting_peer` is send-active) |
| scada | ← | ltn | `gridworks.ping` · `gw/d1-isone-ct-newhaven-orange1/to/s/gridworks-ping` — LTN's first breath |
| scada | ← | ltn | `send.layout` · `gw/d1-isone-ct-newhaven-orange1/to/s/send-layout` — LTN asks for the layout |
| scada | → | ltn | `layout.lite` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/layout-lite` |
| scada | → | ltn | `gridworks.event.startup` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/gridworks-event-startup` |
| scada | → | ltn | `gridworks.event.shutdown` · `…-scada/to/ltn/gridworks-event-shutdown` — the *previous* run's, from the persisted backlog |
| scada | → | ltn | `gridworks.event.comm.mqtt.connect` · `…-scada/to/ltn/gridworks-event-comm-mqtt-connect` — ×3 per process start (one per link) |
| scada | → | ltn | `gridworks.event.comm.mqtt.fully.subscribed` · `…-scada/to/ltn/gridworks-event-comm-mqtt-fully-subscribed` — ×3 likewise |
| scada | → | ltn | `gridworks.event.comm.peer.active` · `…-scada/to/ltn/gridworks-event-comm-peer-active` |
| scada | → | ltn | `gridworks.event.comm.response.timeout` · `…-scada/to/ltn/gridworks-event-comm-response-timeout` |
| scada | → | ltn | `gridworks.event.problem` · `…-scada/to/ltn/gridworks-event-problem` |
| scada | → | ltn | `report.event` · `gw/d1-isone-ct-newhaven-orange1-scada/to/ltn/report-event` — the bulk of upload volume |
| scada | ← | ltn | `gridworks.ack` · `gw/d1-isone-ct-newhaven-orange1/to/s/gridworks-ack` — one per event; the highest-count message on the broker |
| scada | ⇄ | ltn | `gridworks.ping` both directions, ongoing |

### Protocol view — the same exchange with the link FSM

**Phase A — each side independently brings up its link** (same FSM both
sides; LTN at 22:26:36, scada at 22:28:47):

| SCADA | dir | LTN | step |
|---|---|---|---|
| `connecting → awaiting_setup_and_peer` | | (same, earlier) | MQTT CONNECT accepted (`mqtt_connected`) — control packet, no gw message |
| `awaiting_setup_and_peer → awaiting_peer` | | (same, earlier) | SUBSCRIBE → SUBACK (`mqtt_suback`) |
| scada | → | (no peer yet) | `awaiting_peer` is **send-active**: `gridworks.ping` · `gw/…orange1-scada/to/ltn/gridworks-ping`; `heating.forecast`, `weather.forecast`, `snapshot.spaceheat` (~30 s) keep flowing into the void |
| scada (down) | ← | ltn | likewise the LTN, started first, sent into the void: `gridworks.ping` · `gw/…orange1/to/s/gridworks-ping`, then `send.layout` · `gw/…orange1/to/s/send-layout` — **lost**: the scada wasn't subscribed yet and MQTT doesn't retain these |

**Phase B — mutual peer detection (milliseconds, 22:28:47.126–.136):**

| SCADA | dir | LTN | step |
|---|---|---|---|
| scada | → | ltn | first publishes after suback (ping / `gridworks.event.startup`) |
| | | `awaiting_peer → active` | LTN hears the scada: `message_from_peer` (.135) |
| scada | ← | ltn | LTN's reply (`gridworks.ack` · `gw/…orange1/to/s/gridworks-ack` / ping) |
| `awaiting_peer → active` | | | scada hears the LTN: `message_from_peer` (.136) |

**Phase C — on peer-active, the upload:**

| SCADA | dir | LTN | message (TypeName · topic) |
|---|---|---|---|
| scada | → | ltn | `layout.lite` · `…-scada/to/ltn/layout-lite` (sent on peer-active; the LTN's earlier `send.layout` was lost in phase A) |
| scada | → | ltn | persisted event backlog: `gridworks.event.startup`, `gridworks.event.shutdown` (the *previous* run's), `gridworks.event.comm.mqtt.connect` / `…mqtt.fully.subscribed` (×3 per startup — one per link), `gridworks.event.problem`, `report.event` — on `…-scada/to/ltn/gridworks-event-*` / `…/to/ltn/report-event` |
| scada | ← | ltn | `gridworks.ack` · `gw/…orange1/to/s/gridworks-ack`, one per event |

**Phase D — steady state, which in this capture was a pathology: the
link flaps every ~5 s.** Scada log, repeating: `active --
response_timeout --> awaiting_peer` then `awaiting_peer --
message_from_peer --> active` (~5.01 s period). Something the scada
sends is never acked within the ack timeout; each flap generates a
`ResponseTimeoutEvent` + `PeerActiveEvent` pair **and restarts the
reupload**, which is the observed `report.event` duplication (7 unique
events delivered 127 times; one 31×). The ~30 `response.timeout` and
~31 `ally.active` events in the capture are mostly this *live* flapping,
not history; the ×33 `mqtt.connect`/`fully.subscribed` are genuine
multi-startup backlog (3 links × ~11 process starts). (Snapshot/
forecast repeats themselves are periodic fresh payloads, not resends.)

**Root cause (verified 2026-06-10): poison messages in the persisted
event store.** The scada log shows the same 5 stuck events re-sent every
cycle (`start_reupload: … Reuploads started: 39, completed: 0`); the LTN
log shows why — pydantic `literal_error`s on decode: `Input should be
'003', input_value='002'` (RelayActorConfig) and `'001' vs '000'`
(I2cThermistorChannelConfig). They are events **persisted before the
version-bump glean**, carrying old-version payloads the post-bump code
refuses. The decode failure produces **silence** — no nack, no ack —
so the scada re-uploads forever and the link flaps at the ack-timeout
period. The LTN was NOT restarting (one `mqtt_connected` in its whole
log; its side stayed `active`).

Two durable lessons, one fix:

- **Local-rig fix:** clear the scada's persisted event store
  (`~/.local/share/gridworks/scada/event/…`) after a type-version bump.
- **Protocol gap #1:** a type-version bump **strands persisted
  events** — the event store has no upgrade-on-read (contrast sema's
  upgrade-template discipline) and no tolerant decode (contrast the
  gwbase tolerant parser + JK `legacy_hack`, which solved exactly this
  class on the consumer side).
- **Protocol gap #2 — the maple shape again:** an undecodable message
  is *swallowed*, not refused. No nack / dead-letter / skip-after-N in
  the reupload loop, so one poison event degrades the link forever.
  Same principle as the capability work's "an order refused and an
  order swallowed are opposite things" ([OPS-394](https://linear.app/gridworks/issue/OPS-394)) — here for transport.

## Link-down behavior — the gap (told + code-grounded, 2026-06-10)

Both sides are **internally aware** of every link transition: the
proactor generates `CommEvent`s (`MQTTConnectEvent`,
`MQTTDisconnectEvent`, `PeerActiveEvent`, `ResponseTimeoutEvent` — 
`links/link_manager.py`) and counts them per-link in stats.

But **nothing is emitted live**. CommEvents ride the persist-then-upload
event path — **stored-until-acked, which by construction delivers only
after the link is back**. So at the moment a link drops, each side
transitions silently: the knowledge exists in both processes and reaches
no one until the outage is already over.

**The naming half of the gap (decided 2026-06-10):** the proactor's
event vocabulary is **mechanism-named, not peer-state-named**. Peer-up
is semantic (`PeerActiveEvent`, `link_manager.py:686`) but peer-DOWN has
no counterpart — it exists only as two mechanism events covering two
specific failure paths: `MQTTDisconnectEvent` (transport dropped) and
`ResponseTimeoutEvent` (`link_manager.py:604`, ack timed out). An MQTT
disconnect is not the only way a peer goes away — and there is no
unified **PeerInactiveEvent** that means "I no longer have my peer,
however it happened."

**Improvement seed :** a fire-and-forget
**"link down" / ally-inactive message** — explicitly NOT
stored-until-acked — published immediately on the links that still work
(e.g. scada announces gridworks_mqtt-down on local/admin; LTN announces
scada-link-down upstream), so live observers (JK, monitoring, admin)
learn about an outage while it is happening. Not yet an issue; raise to
a Linear issue/design when picked up.

## Broker-access liveness — a second, worse gap (observed incident, reported 2026-06-11)

A real outage, not a wire-capture finding: the scada stayed **comms-dead
for ~15 minutes while looking healthy.** The service was up and logging
normally (confirmed over SSH), but had no traffic to or from the broker
the entire time. The trigger was a network/IP routing change on the Pi
side; the connection did not recover on its own for ~15 minutes (how it
eventually recovered is not established).

This is a different gap from the emission gap above. There the transition
*is* detected internally and only the live announcement is missing. Here
the detection itself failed one layer down: the broker connection was
silently dead and **nothing fired a transition or forced a reconnect**. A
route/IP change blackholes packets without a TCP RST, so the socket sits
half-open; paho's loop sees no error, and without a working
keepalive→reconnect cycle or an independent reachability probe, a dead
connection persists until something external resets it. The broker/peer
conflation (below) makes it invisible from the contract stream: the only
liveness signal rides broker-message accounting, which itself depends on
the dead broker connection.

It lands on the redo's **broker-connection machine** — the "up or it
isn't" half of the two-machines split, which this incident shows is not
trivial when the failure mode is a silent blackhole. That machine needs a
first-class **broker-access liveness check** (an active probe that the
broker is actually reachable, not just "paho believes it is connected")
and a **bounded reconnect** that tears down and re-establishes — re-
resolving DNS/route, since the trigger was an IP change — well before
minutes pass. The MQTT keepalive interval and paho's reconnect backoff
are the levers; whatever they are set to today, they did not reconnect in
15 minutes.

Worth examining whether a small mitigation fits the **existing** proactor
ahead of the redo (tighten the MQTT keepalive / reconnect so detection is
bounded to a minute or two) rather than carrying this only as a redo
requirement. Raise to a Linear issue when picked up. The specifics —
exact duration, what the IP change was, what the logs did and did not
show — may sharpen from the aging Linear issues being triaged; this note
is the symptom-level account plus the design seed.

## Multiple children — the structural critique 

The proactor link mechanism **does not work for a parent with multiple
children** — one peer per link is baked in. That sinks more than scada
topology options: the aggregation-providing-regulation example (substrate-fit
work, [OPS-391](https://linear.app/gridworks/issue/OPS-391)) requires an aggregator parent
talking with thousands of children. This is not hypothetical: it was
GridWorks' first manifestation as **VCharge**
(https://gridworks-consulting.com/vcharge-in-pennsylvania), aggregating
a couple thousand ceramic-brick thermal-storage room units in
Pennsylvania — built *without* a notion of "talking with," which drove
the design pain that motivated one. Two distinct objections:

1. **It assumes proactor on both ends** — an ally must run this stack
   to hold up the state machine.
2. **One parent ↔ many children is unexpressible** — the LinkStates
   model has no fan-out.

Verdict (2026-06-10): Andrew's mechanism, as is, won't carry the
aggregation future. The transport direction is **DECIDED (2026-06-11):
the LTN SHALL BE gwbase (rabbit-native), and the link mechanism gets
redone** — the monitored-peer *idea* ("talking with") is the keeper;
the 1:1 proactor implementation is the suspect, per the
legacy-first-pass rule.

**What gwbase already provides that the proactor link lacks** (from the
retired transport-and-links exploration): strict **transport/codec
separation** (transport routes raw bytes; the application owns its
codec — the proactor entangles MQTT plumbing with message handling); a
**routing fabric that is the authoritative "who may talk to whom"**
(two-exchange-per-class + declared bindings — the *broker* enforces
reach, actors can't grant themselves reach); and **multiple peers per
class by construction** (topic exchanges + per-actor queues). The
rabbit model is many-to-many natively; the proactor models a link as a
single-up/single-down pairing.

**And a third structural defect (2026-06-11): the link concept
conflates the peer with the broker.** One FSM walks broker-connection
steps (`mqtt_connected`, `mqtt_suback`) and peer-relationship steps
(`message_from_peer`, `response_timeout`) as one lifecycle; the link
named `gridworks_mqtt` is a broker connection that *means* "the LTN."
Tonight's findings are symptoms of the conflation: comm events split
across broker-named (`MQTTDisconnectEvent`) and peer-named
(`PeerActiveEvent`) vocabularies, and a peer's death being detectable
only through broker-message accounting. The everyday absurdity: **the
scada believes it connects to three brokers when only two exist** — it
cannot represent talking to admin AND its child pi on the *same*
broker, because peer and broker are one object. In the gwbase model
these are two different things by construction: the broker connection
is shared infrastructure; peers are addresses on the routing fabric.
The conflation is also where the machine's complexity comes from
(verdict 2026-06-11: it is too complicated): three of its eight states
(`awaiting_setup_and_peer`, `awaiting_setup`, `awaiting_peer`) exist
only to track two independent facts — broker setup done? ally heard? —
crossed into one machine. Separate the concerns and each machine is
small: a broker connection is up or it isn't; an ally is silent,
greeted, active, or lost. The redo builds two simple machines, not one
clever one.

## The rewrite spec — extracted (2026-06-25)

The rewrite spec that accumulated here as dated verdicts has been pulled together
into a tracked design ([OPS-428](https://linear.app/gridworks/issue/OPS-428)): the axioms (LTN on gwbase; scada
MQTT-native; NO BACK DOOR), rewrite-not-refactor, the two small state machines,
the three-beat hello, the hex-bearing `heartbeat.a` keepalive, the inverted-ack
default, the upstream-stream principle, parent/child/ally vocabulary, the sema
ride-alongs (left.right.dot `From`), the AllyLink two-track program, and the
sim/real TaDeed constraint. The third-party-umpire requirement for the scada↔LTN
SLA rides with it. This doc remains the durable **link analysis** that design
builds on.