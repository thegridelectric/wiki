# gridworks-base — Transport layer

Status: Draft · Pass 0 · Updated 2026-07-03

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global across the spec
(this file holds `transport.md` except `provisioning.md`, which is in
[`provisioning.md`](provisioning.md)).

---

## The transport layer

## TransportClass

A **TransportClass** is the routable kind of an actor. It is intentionally
NOT the same vocabulary as Sema `GNodeClass`: for example `Supervisor` is
a TransportClass but is not a GNode.

Members: `TerminalAsset`, `LeafTransactiveNode`, `ConnectivityNode`,
`MarketMaker`, `Scada`, `PriceForecastService`,
`WeatherForecastService`, `TimeCoordinator`, `Supervisor`.

Each TransportClass has a short **RoutingClass** token used in routing
keys (the lower-case abbreviation, e.g. `ta`, `ltn`, `cn`, `mm`, `scada`,
`price`, `weather`, `time`, `super`). The mapping is bijective; the
transport layer parses routing-key tokens via RoutingClass and converts
them to TransportClass for the application.

## MessageCategory

Three live categories of message exist; their structure differs:

| Category          | Token | Direction                | Semantics                          |
| ----------------- | ----- | ------------------------ | ---------------------------------- |
| `JsonDirect`      | `rj`  | Unicast (point-to-point) | One named recipient                |
| `JsonBroadcast`   | `rjb` | Multicast                | Topic-style broadcast              |
| `GridworksWrapped`| `gw`  | Unicast (to a class)     | Header+payload envelope; published to `amq.topic` (e.g. the scada/MQTT-bridge interface) |

(A `Serial` token `s` is reserved but unimplemented.)

## Routing-key grammar

Aliases in routing keys are written with hyphens (LRH = "left-right-hyphen")
because dots are token separators in AMQP topic routing keys. The
transport converts between dotted aliases (canonical) and hyphenated
aliases (wire form) at the parse/build boundary.

Grammars:

```
rj.<from-alias-lrh>.<from-class>.<type-name-lrh>.<to-class>.<to-alias-lrh>
rjb.<from-alias-lrh>.<from-class>.<type-name-lrh>[.<radio-channel>...]
gw.<from-alias-lrh>.to.<to-class>.<type-name-lrh>
```

Where `<from-class>` and `<to-class>` are RoutingClass tokens.
`<type-name-lrh>` is the Sema `type_name` (a LeftRightDot string such as
`heartbeat.a` or `sim.timestep`) with dots replaced by hyphens.
`<radio-channel>` (optional) is one or more extra dotted segments
appended to a broadcast routing key.

Parsing is **tolerant of class tokens**. The `<from-class>` / `<to-class>`
slots are read as **opaque short_names** and resolved to a `TransportClass`
*best-effort* — `None` when the token is not a known RoutingClass (e.g. a
proactor **short_name** like `s`=scada, `a`=atn, `ws`=weather that rides in the
class slot of current production keys). Parse still raises on an unknown
**category**, wrong **arity**, or a malformed **alias** token — but **never on
a class token**. Rationale: a consumer only receives a message because it
subscribed, so a key it cannot fully classify must not be silently dropped.
(History: an earlier strict parser raised on any unknown RoutingClass and
`on_message` acked-then-`return`ed — silent data loss of every production
message whose class slot used a short_name, ~48 dropped in one 5-min prod run.
Fixed in 0.5.2; see `provisioning.md` receive callback and the class-token note in `transport.md` "RoutingEnvelope".)

## RoutingEnvelope

The `RoutingEnvelope` is the single value object that crosses the boundary
between transport and application. It is a discriminated record:

```
RoutingEnvelope (abstract)
  type_name: string                # Sema type name in dotted form
  from_alias: string               # canonical (dotted)

DirectRoutingEnvelope     : RoutingEnvelope
  from_class: TransportClass
  to_class:   TransportClass
  to_alias:   string

BroadcastRoutingEnvelope  : RoutingEnvelope
  from_class:    TransportClass
  radio_channel: string | null

WrappedRoutingEnvelope    : RoutingEnvelope
  to_class: TransportClass
  # Invariant: type_name MUST be the *inner* application type, never "gw".
```

**Routing key per envelope.** Each envelope's `routing_key` is a pure
function of its fields. On the wire, aliases and type names are in **LRH**
(hyphen) form and classes are **RoutingClass** tokens (`transport.md` "TransportClass"):

| Envelope                   | Cat.  | `routing_key`                                                      | Published to            |
| -------------------------- | ----- | ----------------------------------------------------------------- | ----------------------- |
| `DirectRoutingEnvelope`    | `rj`  | `rj.<from-alias>.<from-class>.<type>.<to-class>.<to-alias>`        | sender's `<from-class>mic_tx` |
| `BroadcastRoutingEnvelope` | `rjb` | `rjb.<from-alias>.<from-class>.<type>[.<radio-channel>]`           | sender's `<from-class>mic_tx` |
| `WrappedRoutingEnvelope`   | `gw`  | `gw.<from-alias>.to.<to-class>.<inner-type>`                       | `amq.topic`             |

Worked examples:

- `rj.d1-ltn.ltn.heartbeat-a.super.d1-super1` — `d1.ltn` (a
  LeafTransactiveNode) sends `heartbeat.a` directly to Supervisor
  `d1.super1`.
- `rjb.d1-ltn.ltn.snapshot-spaceheat.weather` — `d1.ltn` broadcasts
  `snapshot.spaceheat` on optional radio channel `weather`.
- `gw.d1-ltn.to.scada.heartbeat-a` — `d1.ltn` sends a `gw`-wrapped
  `heartbeat.a` toward a Scada (the `gw` body carries the
  `GridworksHeader` + inner payload; `codec.md` "The gw application envelope" in [`codec.md`](codec.md)).

**How each is delivered:**

- **Direct (`rj`):** the cross-class fabric forwards
  `<from-class>mic_tx → <to-class>_tx` (binding filter
  `*.*.<from-class>.*.<to-class>.*`), and the recipient's own queue
  binding `rj.*.*.*.*.<to-alias>` on its `<to-class>_tx` matches.
- **Broadcast (`rjb`):** no fabric forwarding; a *subscriber* binds its
  queue directly to the publisher's `<from-class>mic_tx` with the `rjb`
  pattern (`transport.md` "AMQP topology").
- **Wrapped (`gw`):** published to `amq.topic`, which reaches MQTT
  subscribers (scada) and the ear tap.

**Class tokens: load-bearing for `rj`, advisory for `gw`.** This is the key
asymmetry. For a **Direct** message the broker's cross-class fabric routes on
the `<from-class>` / `<to-class>` slots (binding filter
`*.*.<from-class>.*.<to-class>.*`), so those tokens **determine delivery** —
they are load-bearing, and gwbase emits them in long form. For a **Wrapped
(`gw`)** message the `to`-class is **just a semantic indicator**: delivery
happens because the consumer subscribed to `amq.topic` (or the MQTT peer to its
own topic), never because the broker matched the class — so gwbase resolves it
best-effort and never depends on it. A `gw` consumer already knows who it is
talking to, so it needs the `to`-class neither for routing nor to disambiguate
partners. This asymmetry is *why* tolerant class-token parsing (`transport.md` "Routing-key grammar") is safe:
the only slot that is load-bearing for routing — the `rj` cross-class fabric —
always carries gwbase's own long-form tokens; the short_name tokens that need
tolerance only ever appear in `gw` `to` / `rjb` `from` slots, where the class is
advisory.

**Storage representation.** Each class slot is stored as the **raw wire token**
(`from_class_token` / `to_class_token`, a `str`); `from_class` / `to_class` are
**derived** best-effort `TransportClass | None` views (`None` for an unresolved
short_name). Build-side constructors — `DirectRoutingEnvelope.from_classes(...)`,
`WrappedRoutingEnvelope.from_classes(...)`, etc. — take typed `TransportClass`
values and emit long-form tokens, so construction stays type-safe while parsing
stays tolerant.

**Critical property:** `category` and `routing_key` are **derived**, not
stored. They are pure functions of the structural fields. This means a
parsed envelope and a constructed envelope share the same type, and the
routing key cannot drift out of sync with the addressing.

For `WrappedRoutingEnvelope` there is a second invariant: `type_name`
holds the **inner** application type name carried in
`Gw.Payload.TypeName` — never the literal `"gw"`. The transport routes
on inner type so consumers can bind without opening bodies; the
construction helper rejects `type_name == "gw"`.

The transport offers three envelope-construction helpers on the actor
that fill in `from_alias` and `from_class` automatically:
`direct_envelope`, `broadcast_envelope`, `wrapped_envelope`. The
application only specifies the destination.

## AMQP topology

The topology is built on a **two-exchange-per-class** pattern. For every
class that runs as an AMQP actor — the `AMQP_ACTOR_CLASSES` opt-in set in
`gwbase/topology.py` (`provisioning.md`, [`provisioning.md`](provisioning.md)):
`{ta, ltn, mm, price, weather, time, super}`; `scada` is MQTT-only and
`cn` is passive, so neither gets exchanges — the broker has:

| Exchange      | Type  | Durable | Internal | Role                            |
| ------------- | ----- | ------- | -------- | ------------------------------- |
| `<rc>_tx`     | topic | yes     | **yes**  | Actors of class `<rc>` consume  |
| `<rc>mic_tx`  | topic | yes     | no       | Anyone publishes here to reach `<rc>` traffic |

The **internal** flag on `<rc>_tx` is load-bearing. An internal exchange
cannot receive messages directly from a publisher — only via an
exchange-to-exchange binding from another exchange. So an actor consumes
from `<rc>_tx` but *cannot publish into it directly*. All traffic must
enter through a `<src>mic_tx` and be forwarded by an explicitly declared
binding into the destination `<dst>_tx`. **The broker's binding table is
therefore the authoritative "who may talk to whom" policy**, enforced at
the broker and declared out-of-band — actors cannot grant themselves
reach. (This complements the connection-level FIS authorization done via
`client_properties` at connect time, `transport.md` "Threading and lifecycle": FIS controls *who may
connect*; the binding table controls *who may route to whom*.)

**What an actor declares at startup vs. what must pre-exist.** Infra owns
the fabric; the actor owns only its ephemeral endpoint. At startup an
actor:

- **passively** asserts its consume exchange `<rc>_tx` exists
  (`passive=true` — an existence check that fails fast if the broker was
  not provisioned; the actor does *not* define the exchange's params, so
  there is no `PRECONDITION_FAILED` tug-of-war between actor and
  definitions);
- declares its own queue `<alias>-F<3-hex>` (`auto_delete = true`:
  vanishes when the consumer disconnects);
- binds `<rc>_tx` ← `rj.*.*.*.*.<my-alias-lrh>` so every direct message
  addressed to this actor is delivered.

It does **not** declare exchange params, any `<rc>mic_tx`, or any
cross-class binding. The entire exchange set + routing fabric **must be
provisioned before any actor runs** — generated from `gwbase/topology.py`
(`provisioning.md`). `tests/_stubs.py` derives the same set from that one source, so
test / dev / prod cannot diverge.

**Publish targets:**

- `JsonDirect` / `JsonBroadcast` → the sender's own `<rc>mic_tx`.
- `GridworksWrapped` → the built-in `amq.topic`, bypassing the
  `mic_tx`/internal-exchange fabric. **Any actor may send wrapped** (e.g.
  to reach scada over MQTT).
- **MQTT peers (`scada`).** `scada` is MQTT-native with **no AMQP
  exchanges**; it is reached over `amq.topic` (RabbitMQ maps MQTT topic
  `a/b/c` ↔ key `a.b.c`). A gwbase AMQP actor (e.g. a simulated `ta`)
  reaches scada by publishing to `amq.topic`, and receives from it by
  binding its queue to `amq.topic` — an `ActorBase` capability, not a
  topology artifact.

**Broadcasts are subscriber-bound, not in the static fabric.** A publisher
publishes `rjb.<from>.<class>.<type>[.channel]` to its own `mic_tx`; a
*subscriber* binds its own queue to the publisher's `mic_tx` with that
pattern (an `ActorBase.subscribe_broadcast` helper). So the cross-class
fabric is **direct-only**.

**The cross-class direct-edge fabric** — generated from `ROUTING_EDGES`
(`provisioning.md`). Initial edges:

| From          | To        | Routing key           |
| ------------- | --------- | --------------------- |
| `ltnmic_tx`   | `mm_tx`   | `*.*.ltn.*.mm.*`      |
| `ltnmic_tx`   | `super_tx`| `*.*.ltn.*.super.*`   |
| `ltnmic_tx`   | `time_tx` | `*.*.ltn.*.time.*`    |
| `mmmic_tx`    | `super_tx`| `*.*.mm.*.super.*`    |
| `mmmic_tx`    | `time_tx` | `*.*.mm.*.time.*`     |
| `supermic_tx` | `ltn_tx`  | `*.*.super.*.ltn.*`   |
| `supermic_tx` | `mm_tx`   | `*.*.super.*.mm.*`    |
| `supermic_tx` | `time_tx` | `*.*.super.*.time.*`  |
| `timemic_tx`  | `super_tx`| `*.*.time.*.super.*`  |

Plus the **ear tap**: `<rc>mic_tx → ear_tx (#)` for every AMQP class, and
`amq.topic → ear_tx (#)`. `ear_tx` is durable/internal/topic and
**passive** — no consumer on the control broker, **no `dummy_ear_q`** by
default (bind one by hand to debug). The ear is the universal audit tap and
shovel source; see
[`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md).

Plus the **MQTT bridge tap** (added 2026-06-11): `timemic_tx → amq.topic
(rjb.#)` — the one declared exception to "broadcasts are
subscriber-bound". MQTT-native actors (scada) cannot bind queues on the
AMQP fabric, so the time coordinator's broadcasts (sim timesteps) cross
to the MQTT plugin's exchange in the static fabric, where an MQTT
subscriber sees e.g. `rjb/d1-tc/time/sim-timestep`. Broadcasts only
(`rjb.#`); direct traffic stays on the AMQP fabric. Declared in
`topology.py` like every other reach grant — the broker, not the actor,
decides that MQTT-world may hear the clock.

(Binding keys are 6-token `JsonDirect` patterns filtering on the `<src>`
and `<dst>` class slots; they don't match 4-token broadcast keys, which is
why broadcasts are subscriber-bound rather than forwarded by this fabric.)

- **QoS / prefetch:** default prefetch is `1` — one unacknowledged
  delivery at a time. Configurable per actor.

**Talking to MQTT-native scada.** `scada` does not participate in the
AMQP `_tx`/`mic_tx` fabric — it is **MQTT-native** (gwproactor) and
connects through RabbitMQ's MQTT plugin, publishing and subscribing on
`amq.topic` (the configured `mqtt.exchange`). RabbitMQ maps an MQTT topic
`a/b/c` to the AMQP routing key `a.b.c`, so AMQP and MQTT peers meet on
`amq.topic`. Two consequences:

- **Cloud ↔ scada in production is the `gw`/wrapped path.** A
  `LeafTransactiveNode` reaches its scada by sending a
  `WrappedRoutingEnvelope` — published to `amq.topic` as
  `gw.<ltn-alias>.to.scada.<inner-type>` — which the scada's MQTT
  subscription receives. The `gw` body carries the `GridworksHeader`
  (src / dst / message-id / ack) the scada needs for correlation and
  replay (`codec.md` "The gw application envelope").
- **Any non-scada AMQP actor ↔ scada uses the same `amq.topic` seam.** A
  simulated `ta`, or an admin/provisioning controller, reaches scada by
  publishing to `amq.topic` on the topic the scada subscribes to, and
  receives from scada by binding its own queue to `amq.topic` with the
  matching pattern. This is an `ActorBase` capability (the AMQP↔MQTT
  bridge), **not** a topology artifact — `amq.topic` is built-in, and
  `amq.topic → ear_tx (#)` already audits scada traffic.

Because scada is MQTT, there is **no** `super_tx → scada_tx` internal-fabric
path (no `scada_tx` exists); admin/provisioning to scada is an `amq.topic`
publish, gated by the broker's MQTT auth (and, later, mTLS), not by the
binding-table ACL.

**gwproactor publishes `gw` (GridworksWrapped), not `rj`/`rjb`.** The scada
interface *is* the wrapped/`amq.topic` path: proactor sends and expects
`GridworksWrapped` messages (header + payload in the body), precisely
because the MQTT hop drops AMQP message properties and provenance must ride
in the body. So a gwbase AMQP actor reaches scada with a
`WrappedRoutingEnvelope` (→ `amq.topic`) and receives scada's `gw` messages
by binding to `amq.topic`.

**Confirmed (production routing key) — scada matches gwbase's grammar.**
A live key observed on the production broker:

```
gw.hw1-isone-me-versant-keene-maple-scada.to.ltn.snapshot-spaceheat
=  gw.<from-alias>.to.<to-class>.<inner-type>
```

This is exactly the `WrappedRoutingEnvelope` grammar (`transport.md` "RoutingEnvelope"), and the body
is a `gw` `Message{Header, Payload}` — the same envelope as `codec.md` "The gw application envelope". So
gwbase's `gw` routing key + envelope and the scada interface are the **same
wire format**: a `ta ↔ scada` bridge can use the existing
`WrappedRoutingEnvelope` (→ `amq.topic`) plus `wrap_bytes` / `unwrap_bytes`
directly — no new format needed.

(Aside: `gwproto/topic.py`'s `MQTTTopic` helper encodes a 3-component
`ENVELOPE_TYPE/SRC/MESSAGE_TYPE` topic with no `to/<to-class>` segment,
which does *not* match the production key above — so it appears to be a
different or older code path. The production routing key is authoritative;
confirm which encoder proactor actually uses when wiring the bridge.)

## Message properties

When publishing, the transport sets these AMQP `BasicProperties`:

| Property         | Value                                           |
| ---------------- | ----------------------------------------------- |
| `reply_to`       | The sender's own queue name                     |
| `app_id`         | The sender's alias                              |
| `type`           | The MessageCategory token (`rj`, `rjb`, `gw`)   |
| `correlation_id` | Caller-supplied; otherwise a fresh UUID         |

These properties are advisory; the routing key is authoritative.

**Open — per-message provenance & signing (FIS era).** FIS authorizes at
*connect* time (client_properties → broker → FIS), but an audit trail wants
to know which runtime instance sent each *message*. The working lean keeps
`rj`/`rjb` bodies as **bare sema types** (the JSON *is* the type — see the
open envelope question in [`codec.md`](codec.md) `codec.md` "The gw application envelope") and carries
provenance in the AMQP `headers` table rather than a body envelope:

```python
properties = pika.BasicProperties(
    reply_to=self.queue_name,
    app_id=self.alias,                    # GNode alias (also in the key)
    type=envelope.category.value,         # rj / rjb / gw
    correlation_id=correlation_id or str(uuid.uuid4()),
    headers={
        "ServiceInstanceId": self.instance_id,
        # optional message signing — non-repudiation beyond connection mTLS:
        "sig":     signature,             # signature over (routing_key + body + instance_id)
        "sig_alg": "ed25519",             # or the cert's key algorithm
        "sig_kid": self.g_node_id,        # key id → look up the GNode's public cert
    },
)
```

A verifier (FIS / ear / a peer) checks `sig` against the GNode's public
certificate (the same identity mTLS authenticates at connect). **Caveat:**
AMQP `headers` do **not** survive the MQTT hop, so this covers
AMQP-internal traffic only; cross-MQTT provenance (scada) must live in the
`gw` **body** header instead (`codec.md` "The gw application envelope"). This split — properties sidecar on the
fabric, body envelope across the MQTT hop — is the current lean, pending the
`codec.md` "The gw application envelope" envelope decision.

**Principle — audit & identity live in the infrastructure, not the payload.** A
message body is a **bare sema type**: its semantic content, kept deterministic and
replayable, so it means the same thing wherever/whenever it is re-handled
(location transparency). Everything about *this delivery* — who sent it, when, in
what order — is the fabric's job, not baked into the body. Two infra audit trails
cover it, so **no message type carries its own timestamp**:

- **the ear** (`ear_tx`, `transport.md` "AMQP topology") — the universal *comms* trail: every message with the
  broker's receive-time and order, uniformly;
- a service's own **command log** — an append-only, content-addressed record of
  *applied mutations* (e.g. the grid-node-registry's `command_log`): the *write-side*
  trail, and the primitive an on-chain record later inherits.

**Three id layers, kept distinct.**

- **entity id** — the identity of a thing (`GNodeId`, an edge id); payload;
  deterministic where it lands in authoritative state (e.g. an edge id derived from
  its endpoints).
- **content-address** — the hash of a semantic command/state (idempotency, dedup, an
  eventual chain tx-id); deterministic, payload-derived. Its *canonical* form is
  chain-specific (Algorand SHA-512/256/base32 vs Ethereum Keccak-256/hex), so it stays
  behind the owning service's authority seam, **not** fixed as a wire format.
- **delivery id** — `correlation_id` / a per-send message id; an AMQP *property*
  (above), never the body; identifies one *delivery*, not the content.

**Run context is fabric context.** A message body SHALL NOT carry which
**run** (`<universe>__<run>` vhost) it rode — the run *is* the fabric the
connection is on, so it is delivery metadata by definition, and keeping it out of
bodies keeps commands run-agnostic (the same recorded command replays into a new
run byte-identically). The run is stamped where messages are **persisted**: the
ear's capture keys (file/S3 key prefixed by vhost) and the JournalKeeper's
storage (a vhost column / partition key). A replayer feeding recorded messages
into a new run is just a publisher on that run's vhost; the recording's
provenance lives in the recording store.

**Timestamps + ordering.** A wall-clock **SHALL NOT** live in a sema body: it is
non-deterministic (clock skew), redundant with the ear, and breaks any future
content-address / signature (the same state would serialize to different bytes each
send). Send-time is a fabric concern (properties + the ear). Where a consumer must
*order* events (an event-sourced projection applying deltas), the ordering key is a
**monotonic sequence** — a command-log height, later a block height — **not** a
clock, and it is added to a specific type only when that convergence need is real.
(The message-driven / event-sourced idiom: the log is the audit trail; payloads stay
deterministic; the transport carries delivery metadata. The Sema-payload half —
serialized artifacts stay deterministic, identity via `TypeName` + content-address,
never an embedded clock — is the sema spec's to state.)

## Threading and lifecycle

The transport runs an AMQP event loop on a dedicated **consumer thread**
(daemon). The application's main thread is free; subclasses may spawn
additional threads in `local_start`.

State flags (`shutting_down`, `_stopping`, `_stopped`, `_consuming`,
`should_reconnect_consumer`, `was_consuming`, `_closing_consumer`) are
shared between the consumer thread and external callers. The reference
implementation relies on the GIL and write-once-then-read patterns; a
faithful reimplementation in a language without a global interpreter
lock must protect these with atomics or a mutex.

**Publishing is thread-confined to the ioloop.** The AMQP client (pika) is
**not thread-safe**: the connection and channel may only be touched from the
thread running their event loop (the consumer thread). But `send` is called
from *any* thread — an actor's own timer/sensor loop, a Supervisor initiating
heartbeats, the main thread. So `send` MUST NOT publish on the caller's thread;
it **marshals the actual publish onto the ioloop thread** (pika:
`connection.ioloop.add_callback_threadsafe`). Every publish — including
control-plane sends already on the ioloop — goes through this one uniform path;
all publishes are thus serialized on the ioloop with the loop's own socket I/O.
Publishing directly from the caller's thread corrupts the shared connection
under load — empirically ~100% delivery loss with a pika-internal error inside
`basic_publish`, and it breaks *consuming* too (the connection is shared), not
just the one message. **Trade-off:** marshaling removes the inline backpressure
a synchronous publish gave, so a sustained publish rate above the ioloop's drain
rate grows the callback queue (frames buffer in memory). Bounded by gwbase's
low-rate traffic; if it ever bites under a high-throughput load, the answer is a
*bounded* publish queue, not a different threading model.

**Lifecycle:**

```
construct  -> identity from ServiceSettings (alias, instance_id); build
              queue name; build logger. (Orchestrator additionally sets its
              class exchanges from transport_class; GridworksActor loads +
              Sema-validates g.node.gt.json — see actors.md `actors.md` "The application layer".)
start()    -> local_start() hook
              spawn consumer thread, which:
                  connect -> open channel -> assert consume exchange (passive)
                  -> declare queue -> bind_queue() -> set QoS
                  -> begin consuming -> local_rabbit_startup() hook
              (bind_queue() is tier-dependent: a tap binds nothing — it
               subscribes to its ear_tx slice in local_rabbit_startup;
               Orchestrator binds the direct-to-me pattern on its <rc>_tx.)
stop()     -> set shutting_down
              cancel consumer, close channel, close connection
              local_stop() hook
              join consumer thread
```

**Reconnect:** if the broker drops the connection unexpectedly, the
transport reconnects with backoff. The delay starts at 1 second and
increments by 1 each failed attempt, capped at 30 seconds. A successful
consume resets the delay to 0.

**Receive callback** (`on_message`):

1. Record the routing key.
2. ACK the delivery immediately (fire-and-forget at the broker level;
   the application is responsible for any retry semantics).
3. Parse the routing key into a `RoutingEnvelope`. On parse failure (now rare
   — only a bad category / arity / alias, never an unknown class token, `transport.md` "Routing-key grammar"),
   call the overridable `on_routing_key_parse_error(routing_key, body, error)`
   hook **instead of silently returning**. The delivery is already ACKed and the
   body is handed in, so an override can salvage it. Default = log + drop
   (historical behavior); a consumer MAY override to recover the body — e.g.
   JournalKeeper's permanent `legacy_hack` that persists the LTN's legacy
   `broadcast.*` keys (which gwbase's main parser deliberately does *not* learn
   as a category).
4. Call `dispatch_message(envelope, body)` on the application
   (`Orchestrator` filters control-plane types, then forwards to
   `process_message`; a bare tap implements `dispatch_message` directly;
   see [`actors.md`](actors.md) `actors.md` "The application layer").

**Send** (`send(envelope, body, correlation_id?)`) — runs the cheap checks
synchronously on the caller's thread, then *schedules* the publish on the
ioloop (see "Publishing is thread-confined" above):

1. If stopping/stopped, return a diagnostic and do nothing.
2. If wrapped envelope, target `amq.topic`; else if there is no publish
   exchange (a tap has none), return `NO_PUBLISH_EXCHANGE`; else target
   `<routing-code>mic_tx`.
3. **Synchronous channel-open pre-check** — if the channel is obviously closed,
   return `CHANNEL_NOT_OPEN` now (the common case; this is the diagnostic a
   caller can act on).
4. Build the `BasicProperties` (`transport.md` "Message properties") and **schedule** a callback on the ioloop
   that will do the actual `basic_publish`. Guard the *schedule* call itself
   (the connection may be closed/reconnecting) so `send` never raises.
5. Return `MESSAGE_SENT` — meaning **scheduled**, not confirmed.

The scheduled callback, running on the ioloop thread, **re-checks** the channel
is open (state may have changed since scheduling), publishes, and swallows any
error (log + drop) — it must never raise into the ioloop. The dual check (sync
pre-check + in-callback re-check) is deliberate: the pre-check gives callers the
`CHANNEL_NOT_OPEN` signal for free, the re-check is the authoritative one.

`send` is **fire-and-forget and best-effort** from the application's
perspective: it returns a diagnostic, never raises on transport failure, and
`MESSAGE_SENT` means the publish was *scheduled* (delivery is best-effort by
contract — invariant #9; critical paths use end-to-end application acks, not
broker publisher-confirms). Validated under load: many non-ioloop threads
publishing concurrently leave the connection healthy with full delivery
(the same blast corrupts the pre-fix direct-publish path).
