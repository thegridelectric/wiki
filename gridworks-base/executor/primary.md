# gridworks-base — Rebuild Specification (primary)

This is the **faithful-rebuild specification** for `gridworks-base`: the
authoritative, language-agnostic account of the system, intended to be
complete enough that someone (or Claude) could rebuild the entire package —
with all its intended features — from these docs alone. It describes WHAT
the system is and HOW its layers compose, not the particulars of Python or
pika.

> Status: converging. Items marked "Open" flag decisions still being
> resolved or features not yet built; everything else is intended as
> normative.

This is the **hub** document — short by design. Depth lives in the
sub-specs below; section numbers are **global** across all of them (so a
"§3.4" reference resolves regardless of which file it sits in).

## Map of the spec

| Sections | File | Covers |
| --- | --- | --- |
| §1–§2, §7 | **primary.md** (this file) | Overview, identity, glossary, the cross-cutting invariant checklist |
| §3 (excl. §3.6) | [`transport.md`](transport.md) | TransportClass/RoutingClass, routing-key grammar, RoutingEnvelopes, AMQP topology, scada/MQTT bridge, message properties, threading/lifecycle |
| §3.6 | [`provisioning.md`](provisioning.md) | Topology generation, dev/prod delivery, GHCR, identities |
| §4 | [`codec.md`](codec.md) | SemaType, SemaCodec, versioning, property formats, the `gw` envelope + wrap/unwrap |
| §5–§6 | [`actors.md`](actors.md) | ActorBase, GridworksActor, the hello example, diagnostics |

## The central commitment

The defining architectural commitment is a **strict separation between
transport and codec**. The transport layer routes raw bytes; the codec
layer encodes and decodes typed application messages. The boundary between
them is a single value object (a `RoutingEnvelope`) plus a `bytes` payload.

Note: "envelope" here means the transport-layer routing record. There is a
*separate*, application-layer envelope (`Gw`) that wraps inner messages for
end-to-end hop traversal — see §4.7 ([`codec.md`](codec.md)). The two are
distinguished by name (`RoutingEnvelope` vs. `Gw` / "gw envelope") and live
at different layers.

---

## 1. The two layers

```
+---------------------------------------------------------------+
| Application layer  (subclasses of ActorBase / GridworksActor)
|   - owns its own SemaCodec instance (registry of message types)
|   - decides how to dispatch on envelope.type_name
+--- process_message(envelope, body)  <----- send(envelope, body)
|                                                                |
|                  (bytes + RoutingEnvelope)                     |
|                                                                |
+--- ActorBase (transport) -------------------------------------+
|   - opens broker connection, channel, queue                    |
|   - parses routing keys -> Envelope                            |
|   - builds routing keys <- Envelope                            |
|   - never opens the payload bytes                              |
+---------------------------------------------------------------+
              |                                  ^
              v                                  |
        publish(routing_key, body)        on_message(routing_key, body)
                       (RabbitMQ / AMQP topic exchanges)
```

The transport layer **does not know about Sema** — it does not import the
codec. The codec layer **does not know about RabbitMQ** — it does not
import the transport.

The contract:

- **Receive:** transport parses the routing key into a `RoutingEnvelope`,
  ACKs the delivery to the broker, and calls `dispatch_message(envelope,
  body)` — which `GridworksActor` resolves to `process_message` for
  application traffic. The application decodes `body` with whatever codec
  it holds.
- **Send:** application constructs a typed message, encodes it to bytes
  with its codec, builds a `RoutingEnvelope`, and calls
  `send(envelope, body)`. Transport derives the routing key from the
  envelope and publishes.

This boundary is the only place where bytes and routing metadata travel
together. Either side can be swapped (RabbitMQ → gRPC, JSON → Protobuf)
without changing the other.

---

## 2. Identity

Every actor has identifiers that together place it in the system:

| Field                 | Lifetime    | Source                                      | Purpose                                       |
| --------------------- | ----------- | ------------------------------------------- | --------------------------------------------- |
| `alias`               | Durable     | `g_node.json` file (`Alias` field)          | Routable address (e.g. `d1.hello`)            |
| `g_node_id`           | Durable     | `g_node.json` file (`GNodeId` field, UUID)  | Stable identity across reboots                |
| `g_node_class`        | Durable     | `g_node.json` file (`GNodeClass` field)     | Free-form Sema class (e.g. `Scada`)           |
| `g_node_instance_id`  | Per-process | Freshly generated UUID at construction time | Identifies one process lifetime (FIS uses it) |
| `transport_class`     | Per-process | Application config                          | Routing taxonomy (closed enum — §3.1)         |

The `g_node.json` file is provisioned externally and read verbatim at
construction time. The actor does not validate it; whatever placed the
file is responsible for that.

At broker connect, the actor advertises `g_node_alias`,
`g_node_instance_id`, and `g_node_class` as AMQP client properties so the
broker's auth backend (FIS) can authorize the connection.

---

## Glossary

- **TransportClass / RoutingClass** — the routable kind of an actor and
  its short routing-key token (§3.1). A closed taxonomy, *not* sema
  vocabulary; `Supervisor` is a TransportClass but not a GNode.
- **RoutingEnvelope** — the transport-layer routing record (§3.4):
  `Direct`, `Broadcast`, `Wrapped`. Its `routing_key` and `category` are
  derived, not stored.
- **`gw` / GridworksHeader** — the *application-layer* envelope (§4.7):
  header + opaque payload, for end-to-end hop traversal. Distinct from
  RoutingEnvelope.
- **SemaType / SemaCodec** — a named, versioned, JSON-on-the-wire message
  type, and its registry/transformer (§4).
- **`<rc>_tx` / `<rc>mic_tx`** — per-class consume (internal) and publish
  exchanges (§3.5). The binding table between them is the broker-enforced
  "who may talk to whom" policy.
- **ear / `ear_tx`** — the universal passive audit tap (§3.5; full spec in
  [`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md)).
- **ActorBase / GridworksActor** — the transport-only base and the
  canonical control-plane-aware default actor (§5).
- **`dispatch_message` / `process_message`** — the transport-level
  framework hook (ActorBase) and the application hook (GridworksActor)
  respectively.

---

## 7. Faithful-reimplementation checklist

If you are porting `gridworks-base` to another language, the following
invariants are load-bearing — preserve them.

**Transport:**

1. Routing key is **derived** from envelope fields, never stored
   alongside them.
2. Aliases on the wire are hyphenated; canonical form is dotted.
   Convert at the parse/build boundary only.
3. Per AMQP-actor class: `<rc>_tx` (internal) for consume, `<rc>mic_tx`
   (non-internal) for publish; wrapped messages publish to `amq.topic`
   (any actor may send wrapped). The wrapped routing-key `type_name` slot
   carries the **inner** application type, never `"gw"`.
4. Queue is `<alias>-F<3-hex>`, auto-delete, bound to
   `rj.*.*.*.*.<my-alias-lrh>` by default.
5. Actors **passively** assert their consume exchange exists and never
   declare `mic_tx` or cross-class bindings — infra owns the fabric
   (§3.5–§3.6).
6. Default prefetch 1; subclass-tunable.
7. Reconnect backoff: 0 on a known-good prior consume; otherwise +1 per
   failed attempt, capped at 30 seconds.
8. ACK immediately on delivery; the application owns retry semantics.
9. `send` never throws; it returns a diagnostic.
10. AMQP `client_properties` advertise `g_node_alias`,
    `g_node_instance_id`, `g_node_class` at connect time.
11. `scada` is MQTT-only (no AMQP exchanges); reached via `amq.topic`.
    Broadcasts are subscriber-bound, not forwarded by the direct fabric.

**Codec:**

12. Wire JSON keys are PascalCase; null fields are omitted.
13. Decoding rejects non-PascalCase keys recursively.
14. Strict mode rejects unknown types or versions; degraded mode
    returns a `DegradedSemaType` wrapper that MUST NOT drive control
    logic.
15. Old versions auto-upgrade by chained `upgrade()` calls; the walk
    is bounded by `(latest - current)` steps.
16. Versions are zero-padded integer strings; breaking changes require a
    new `type_name`, not a version bump.
17. YAML under `sema/definitions/types/` is the source of truth for the
    wire shape.
18. The `gw` application envelope is a separate concept from the
    transport `RoutingEnvelope`; `wrap_bytes` / `unwrap_bytes` live in
    `gwbase.sema.wrapped` and depend only on `GridworksHeader` and
    `Gw` — never on a SemaCodec registry. `Gw.Header.MessageType ==
    Gw.Payload.TypeName == WrappedRoutingEnvelope.type_name`.

**Application:**

19. `ActorBase` knows nothing about codecs; the application owns its
    codec.
20. The two framework methods are `dispatch_message` (abstract on
    `ActorBase`, implemented by intermediate layers) and
    `process_message` (abstract on `GridworksActor`, implemented by
    final application classes). Applications implement
    `process_message` and do not touch `dispatch_message`.
21. `GridworksActor` privately handles `heartbeat.a` and
    `sim.timestep` for its configured supervisor and time coordinator;
    a subclass's codec does not need those types registered.
22. A `sim.timestep` whose value rewinds is dropped; one whose value
    repeats is surfaced with `is_new = false`.
23. A `heartbeat.a` from `my_super_alias` is handled internally (pong +
    `on_supervisor_heartbeat`); a `heartbeat.a` from any *other* alias
    falls through to `process_message` (so e.g. a supervisor observes its
    subordinates' heartbeats).
24. The supervisor is identified by alias only; there is no separate
    secret or token at this layer (auth lives in the broker
    `client_properties` handshake).
