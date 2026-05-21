# gridworks-base — Transport layer (§3)

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global across the spec
(this file holds §3 except §3.6, which is in
[`provisioning.md`](provisioning.md)).

---

## 3. The transport layer

### 3.1 TransportClass (closed taxonomy)

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

### 3.2 MessageCategory

Three live categories of message exist; their structure differs:

| Category          | Token | Direction                | Semantics                          |
| ----------------- | ----- | ------------------------ | ---------------------------------- |
| `JsonDirect`      | `rj`  | Unicast (point-to-point) | One named recipient                |
| `JsonBroadcast`   | `rjb` | Multicast                | Topic-style broadcast              |
| `GridworksWrapped`| `gw`  | Unicast (to a class)     | Header+payload envelope; published to `amq.topic` (e.g. the scada/MQTT-bridge interface) |

(A `Serial` token `s` is reserved but unimplemented.)

### 3.3 Routing-key grammar

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

Parsing is strict: unknown categories, unknown RoutingClass tokens, or
malformed alias tokens raise an error and the message is dropped (after
ACK) with a diagnostic.

### 3.4 RoutingEnvelope

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
(hyphen) form and classes are **RoutingClass** tokens (§3.1):

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
  `GridworksHeader` + inner payload; §4.7 in [`codec.md`](codec.md)).

**How each is delivered:**

- **Direct (`rj`):** the cross-class fabric forwards
  `<from-class>mic_tx → <to-class>_tx` (binding filter
  `*.*.<from-class>.*.<to-class>.*`), and the recipient's own queue
  binding `rj.*.*.*.*.<to-alias>` on its `<to-class>_tx` matches.
- **Broadcast (`rjb`):** no fabric forwarding; a *subscriber* binds its
  queue directly to the publisher's `<from-class>mic_tx` with the `rjb`
  pattern (§3.5).
- **Wrapped (`gw`):** published to `amq.topic`, which reaches MQTT
  subscribers (scada) and the ear tap.

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

### 3.5 AMQP topology

The topology is built on a **two-exchange-per-class** pattern. For every
class that runs as an AMQP actor — the `AMQP_ACTOR_CLASSES` opt-in set in
`gwbase/topology.py` (§3.6, [`provisioning.md`](provisioning.md)):
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
`client_properties` at connect time, §3.8: FIS controls *who may
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
(§3.6). `tests/_stubs.py` derives the same set from that one source, so
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
(§3.6). Initial edges:

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
  replay (§4.7).
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

This is exactly the `WrappedRoutingEnvelope` grammar (§3.4), and the body
is a `gw` `Message{Header, Payload}` — the same envelope as §4.7. So
gwbase's `gw` routing key + envelope and the scada interface are the **same
wire format**: a `ta ↔ scada` bridge can use the existing
`WrappedRoutingEnvelope` (→ `amq.topic`) plus `wrap_bytes` / `unwrap_bytes`
directly — no new format needed.

(Aside: `gwproto/topic.py`'s `MQTTTopic` helper encodes a 3-component
`ENVELOPE_TYPE/SRC/MESSAGE_TYPE` topic with no `to/<to-class>` segment,
which does *not* match the production key above — so it appears to be a
different or older code path. The production routing key is authoritative;
confirm which encoder proactor actually uses when wiring the bridge.)

### 3.7 Message properties

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
open envelope question in [`codec.md`](codec.md) §4.7) and carries
provenance in the AMQP `headers` table rather than a body envelope:

```python
properties = pika.BasicProperties(
    reply_to=self.queue_name,
    app_id=self.alias,                    # GNode alias (also in the key)
    type=envelope.category.value,         # rj / rjb / gw
    correlation_id=correlation_id or str(uuid.uuid4()),
    headers={
        "g_node_instance_id": self.g_node_instance_id,
        # optional message signing — non-repudiation beyond connection mTLS:
        "sig":     signature,             # signature over (routing_key + body + g_node_instance_id)
        "sig_alg": "ed25519",             # or the cert's key algorithm
        "sig_kid": self.g_node_id,        # key id → look up the GNode's public cert
    },
)
```

A verifier (FIS / ear / a peer) checks `sig` against the GNode's public
certificate (the same identity mTLS authenticates at connect). **Caveat:**
AMQP `headers` do **not** survive the MQTT hop, so this covers
AMQP-internal traffic only; cross-MQTT provenance (scada) must live in the
`gw` **body** header instead (§4.7). This split — properties sidecar on the
fabric, body envelope across the MQTT hop — is the current lean, pending the
§4.7 envelope decision.

### 3.8 Threading and lifecycle

The transport runs an AMQP event loop on a dedicated **consumer thread**
(daemon). The application's main thread is free; subclasses may spawn
additional threads in `local_start`.

State flags (`shutting_down`, `_stopping`, `_stopped`, `_consuming`,
`should_reconnect_consumer`, `was_consuming`, `_closing_consumer`) are
shared between the consumer thread and external callers. The reference
implementation relies on the GIL and write-once-then-read patterns; a
faithful reimplementation in a language without a global interpreter
lock must protect these with atomics or a mutex.

**Lifecycle:**

```
construct  -> read g_node.json, allocate identifiers, build queue name
start()    -> local_start() hook
              spawn consumer thread, which:
                  connect -> open channel -> assert exchange (passive)
                  -> declare queue -> bind direct pattern -> set QoS
                  -> begin consuming -> local_rabbit_startup() hook
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
3. Parse the routing key into a `RoutingEnvelope`. On parse failure, log
   and return.
4. Call `dispatch_message(envelope, body)` on the application
   (`GridworksActor` filters control-plane types, then forwards to
   `process_message`; see [`actors.md`](actors.md) §5).

**Send** (`send(envelope, body, correlation_id?)`):

1. If stopping/stopped, return a diagnostic and do nothing.
2. If wrapped envelope, target `amq.topic`; else target
   `<routing-code>mic_tx`.
3. If the channel is not open, return `CHANNEL_NOT_OPEN`.
4. Publish with `BasicProperties` as in §3.7.
5. Return `MESSAGE_SENT` (or an error diagnostic).

`send` is **synchronous and best-effort** from the application's
perspective: it returns a diagnostic, never raises on transport failure.
