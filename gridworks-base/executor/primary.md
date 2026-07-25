# gridworks-base — Rebuild Specification (primary)

Status: Draft · Pass 0 · Updated 2026-06-10

This is the **faithful-rebuild specification** for `gridworks-base`: the
authoritative, language-agnostic account of the system, intended to be
complete enough that someone (or Claude) could rebuild the entire package —
with all its intended features — from these docs alone. It describes WHAT
the system is and HOW its layers compose, not the particulars of Python or
pika.

> Items marked "Open" flag decisions still being resolved or features not
> yet built; everything else is intended as normative.

This is the **hub** document — short by design. Depth lives in the
sub-specs below. Sections are cited by header slug — `file.md "Header
text"` — and a `##` header in these files is a near-immutable reference
slug (see the wiki conventions "Headers are reference slugs").

## Map of the spec

| File | Covers |
| --- | --- |
| **primary.md** (this file) | Overview, identity, glossary, the cross-cutting invariant checklist |
| [`transport.md`](transport.md) | TransportClass/RoutingClass, routing-key grammar, RoutingEnvelopes, AMQP topology, scada/MQTT bridge, message properties, threading/lifecycle |
| [`provisioning.md`](provisioning.md) | Topology generation, dev/prod delivery, GHCR, identities |
| [`codec.md`](codec.md) | SemaType, SemaCodec, versioning, property formats, the `gw` envelope + wrap/unwrap |
| [`actors.md`](actors.md) | ActorBase / Orchestrator / GridworksActor tiers; settings, XDG file locations & logging; the hello example; diagnostics |
| [`service-deployment.md`](service-deployment.md) | Recommended box pattern: systemd unit → venv binary (template units for multi-instance), homedir README, XDG logs; vendored runtimes as containers; the ci.sh gate |

## The central commitment

The defining architectural commitment is a **strict separation between
transport and codec**. The transport layer routes raw bytes; the codec
layer encodes and decodes typed application messages. The boundary between
them is a single value object (a `RoutingEnvelope`) plus a `bytes` payload.

Note: "envelope" here means the transport-layer routing record. There is a
*separate*, application-layer envelope (`Gw`) that wraps inner messages for
end-to-end hop traversal — see [`codec.md`](codec.md) "The gw application
envelope". The two are
distinguished by name (`RoutingEnvelope` vs. `Gw` / "gw envelope") and live
at different layers.

## Role in the GridWorks fleet

`gridworks-base` (module `gwbase`) is the **shared foundation for the
GridWorks GNode service fleet**: the RabbitMQ-transport actor framework, the
Sema codec boundary, and `gwbase.topology` — the single source of truth for
the broker fabric (every service's exchanges/bindings derive from it, `provisioning.md`).
Services import it as a package and subclass `GridworksActor`, one per
`TransportClass`. Imported today by **gridworks-ear** and
**gridworks-journalkeeper**; intended as the base for **gridworks-ltn**
(`ltn`), **gridworks-marketmaker** (`mm`), and the **weather** (`weather`)
and **price** (`price`) forecast services. The routing taxonomy for all of
them already lives here in `gwbase` (`transport.md` "TransportClass").

---

## The two layers

```
+---------------------------------------------------------------+
| Application layer  (ActorBase / Orchestrator / GridworksActor subclasses)
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
  body)` — which `Orchestrator` resolves to `process_message` for
  application traffic (a bare `ActorBase` tap implements `dispatch_message`
  itself). The application decodes `body` with whatever codec
  it holds.
- **Send:** application constructs a typed message, encodes it to bytes
  with its codec, builds a `RoutingEnvelope`, and calls
  `send(envelope, body)`. Transport derives the routing key from the
  envelope and publishes.

This boundary is the only place where bytes and routing metadata travel
together. Either side can be swapped (RabbitMQ → gRPC, JSON → Protobuf)
without changing the other.

---

## Identity

Every actor has identifiers that together place it in the system:

Identity scope matches base-class scope across the three tiers
(`ActorBase` → `Orchestrator` → `GridworksActor`):

| Field                 | Lifetime    | Tier            | Source                                            | Purpose                                       |
| --------------------- | ----------- | --------------- | ------------------------------------------------- | --------------------------------------------- |
| `alias`               | Durable     | ActorBase       | `ServiceSettings.service_alias` (`LeftRightDot`)  | Routable address (e.g. `d1.hello`)            |
| `instance_id`         | Per-process | ActorBase       | `ServiceSettings.instance_id`, else fresh UUID    | Identifies one process lifetime (FIS uses it) |
| `transport_class`     | Per-process | Orchestrator    | `Orchestrator.__init__` param (intrinsic to role) | Routing taxonomy (closed enum — `transport.md` "TransportClass")         |
| `g_node_id`           | Durable     | GridworksActor  | `g.node.gt.json` (`GNodeId`, UUID; Sema-validated)| Stable GNode identity across reboots          |
| `g_node_class`        | Durable     | GridworksActor  | `g.node.gt.json` (`GNodeClass`; Sema-validated)   | Free-form Sema class (e.g. `Scada`)           |

A non-GNode actor (journalkeeper, ear actor-side, audit-tap) rides
`ActorBase` with **only** `alias` + `instance_id` — no GNode file, no
`transport_class`. `GridworksActor` loads its `g.node.gt.json` and
**Sema-validates it as a `GNodeGt`** (axioms enforced) at construction,
asserting `GNodeGt.alias == service_alias` (provisioning-drift guard) — it is
no longer read verbatim. `g_node_alias` / `g_node_instance_id` survive as
back-compat property aliases for `alias` / `instance_id`.

At broker connect, every actor advertises `ServiceAlias` + `ServiceInstanceId`
as AMQP client properties; a `GridworksActor` additionally advertises
`GNodeClass`. The presence of `GNodeClass` is the broker auth backend's (FIS)
discriminator between a GNode and a plain service.

The `ServiceSettings` / `GNodeSettings` shapes (one `GWBASE_` env prefix), the
XDG file locations (config / data / state, keyed on `service_name`), and the
per-actor logger are detailed in [`actors.md`](actors.md) `actors.md` "Settings, file locations, and logging". gwbase uses
**plain XDG** for those locations — the `<PREFIX>_PATHS__BASE/NAME` path object
is gwproactor's, for the on-device (scada/LTN) world. **All cloud actors are
gwbase ⇒ uniformly plain-XDG; a gwbase service never pulls in gwproactor for
`Paths`** (the cloud/edge boundary — see `actors.md` "Settings, file locations, and logging").

---

## Glossary

- **TransportClass / RoutingClass** — the routable kind of an actor and
  its short routing-key token (`transport.md` "TransportClass"). A closed taxonomy, *not* sema
  vocabulary; `Supervisor` is a TransportClass but not a GNode.
- **RoutingEnvelope** — the transport-layer routing record (`transport.md` "RoutingEnvelope"):
  `Direct`, `Broadcast`, `Wrapped`. Its `routing_key` and `category` are
  derived, not stored.
- **`gw` / GridworksHeader** — the *application-layer* envelope (`codec.md` "The gw application envelope"):
  header + opaque payload, for end-to-end hop traversal. Distinct from
  RoutingEnvelope.
- **SemaType / SemaCodec** — a named, versioned, JSON-on-the-wire message
  type, and its registry/transformer (`codec.md`).
- **`<rc>_tx` / `<rc>mic_tx`** — per-class consume (internal) and publish
  exchanges (`transport.md` "AMQP topology"). The binding table between them is the broker-enforced
  "who may talk to whom" policy.
- **ear / `ear_tx`** — the universal passive audit tap (`transport.md` "AMQP topology"; full spec in
  [`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md)).
- **ActorBase / Orchestrator / GridworksActor** — the three actor tiers:
  the transport-only ear-tap base (non-GNode services ride it directly), the
  class-routing + control-plane orchestrator (Supervisor, TimeCoordinator),
  and the GNode-identity actor (`actors.md` "The application layer", [`actors.md`](actors.md)).
- **`dispatch_message` / `process_message`** — the transport-level
  framework hook (ActorBase) and the application hook (GridworksActor)
  respectively.

---

## Faithful-reimplementation checklist

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
   (`transport.md` "AMQP topology"–`provisioning.md`).
6. Default prefetch 1; subclass-tunable.
7. Reconnect backoff: 0 on a known-good prior consume; otherwise +1 per
   failed attempt, capped at 30 seconds.
8. ACK immediately on delivery; the application owns retry semantics.
9. `send` never throws; it returns a diagnostic. It does **not** publish on
   the caller's thread — the AMQP client is not thread-safe, so the actual
   publish is **marshaled onto the ioloop thread** (pika:
   `add_callback_threadsafe`); `MESSAGE_SENT` means *scheduled*, not confirmed.
   (Publishing from the caller's thread corrupts the shared connection under
   load — it breaks consuming too. See transport.md `transport.md` "Threading and lifecycle".)
10. AMQP `client_properties` advertise `ServiceAlias` +
    `ServiceInstanceId` at connect time (every actor); a GNode
    (`GridworksActor`) additionally advertises `GNodeClass`. The presence of
    `GNodeClass` is FIS's GNode-vs-service discriminator.
11. `scada` is MQTT-only (no AMQP exchanges); reached via `amq.topic`.
    Broadcasts are subscriber-bound, not forwarded by the direct fabric.

**Dev brokers vs prod broker.** The above invariants describe what
**gwbase** declares. Actors **only** publish to `<rc>mic_tx` and
passively assert their consume `<rc>_tx` exists — nothing else. A
fresh dev broker (e.g. `gw-dev-rabbit`) is *empty* until you stand up
the fabric (consume exchanges + cross-class bindings) yourself. The
deployed **prod broker** additionally carries a set of legacy /
temporary exchanges (`ws_tx`, etc.) and bindings that **are not part
of the gwbase contract**; treat them as broker-fabric infra to be
re-thought, not as canonical routing. If a consumer needs traffic
from a publisher, the canonical move is to bind directly to the
publisher's `<rc>mic_tx`.

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
    `ActorBase`, implemented by `Orchestrator`) and `process_message`
    (abstract on `Orchestrator`, implemented by final application
    classes). Applications implement `process_message` and do not touch
    `dispatch_message`. A bare `ActorBase` tap implements
    `dispatch_message` directly (it has no control plane).
21. `Orchestrator` privately handles `heartbeat.a` and `sim.timestep`
    for its configured supervisor and time coordinator; a subclass's
    codec does not need those types registered. (`GridworksActor`
    inherits this.)
22. A `sim.timestep` whose value rewinds is dropped; one whose value
    repeats is surfaced with `is_new = false`.
23. A `heartbeat.a` from `my_super_alias` is handled internally (pong +
    `on_supervisor_heartbeat`); a `heartbeat.a` from any *other* alias
    falls through to `process_message` (so e.g. a supervisor observes its
    subordinates' heartbeats).
24. The supervisor is identified by alias only; there is no separate
    secret or token at this layer (auth lives in the broker
    `client_properties` handshake).
