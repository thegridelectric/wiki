# gridworks-base — Rebuild Specification (primary)

Status: Draft · Pass 0 · Updated 2026-09-02

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
| [`transport.md`](transport.md) | TransportClass/RoutingClass, routing-key grammar, RoutingEnvelopes, AMQP topology (class exchanges, direct edges, ear taps, MQTT bridges, standing queues), scada/MQTT seam, message properties, threading/lifecycle |
| [`provisioning.md`](provisioning.md) | Topology generation from `gwbase.topology`, the vhost grammar, definitions artifacts + drift guard, dev image on GHCR, identities |
| [`codec.md`](codec.md) | SemaType, SemaCodec, versioning, property formats, the generated vendored snapshot (seed + regen), the `gw` envelope + wrap/unwrap |
| [`actors.md`](actors.md) | ActorBase / Orchestrator / GridworksActor tiers; connect-time identity (client properties vs connect claims, the universe-ladder URL checks); per-service settings, XDG file locations & logging; the hello example; diagnostics |
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
Sema codec boundary, `gwbase.topology` — the single source of truth for the
broker fabric (every service's exchanges, bindings, standing queues and
policies derive from it, `provisioning.md`) — and the client half of the
broker's cert-plus-claims gate (`gwbase.credentials`, `actors.md`
"Connect-time identity"). Services import it as a package and subclass the
tier that matches their role (`actors.md` "The application layer").
Imported today by **gridworks-ear** and **gridworks-journalkeeper** (bare
`ActorBase` taps), **grid-node-registry** (an `Orchestrator`),
**gridworks-weather-forecast** (a `GridworksActor`), and the
**gridworks-timecoordinator** / **gridworks-terminalasset** hellos; intended
as the base for **gridworks-ltn** (`ltn`), **gridworks-marketmaker** (`mm`)
and the **price** (`price`) forecast service. The routing taxonomy for all of
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
| `run`                 | Per-process | ActorBase       | Derived from the broker URL's vhost (`<universe>__<run>`) | The universe run being joined; claimed at the gate, never declared twice |
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

At broker connect an actor says two things, and only one carries weight.
AMQP `client_properties` (`ServiceAlias` + `ServiceInstanceId`, plus
`GNodeClass` for a GNode) are recorded on the connection for audit and
reconciliation; the broker never hands them to an auth backend. **Connect
claims** — a `fis.connect.claims` word (alias, instance id, run, and
`GNodeClass` iff the principal is a GNode) sent as the SASL response under
the `GRIDWORKS` mechanism — are what the gate decides on; the presence of
`GNodeClass` there is FIS's GNode-vs-service discriminator. Identity is
never claimed: the TLS client certificate proves it. Claims ride only when
the settings carry a `rabbit.tls` block; without it, password connect is
untouched (`actors.md` "Connect-time identity").

The `ServiceSettings` / `GNodeSettings` shapes (each service subclasses with
its OWN env prefix — `GJK_`, `GWWF_`, … — never `GWBASE_*` vars), the
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
  **`gnr_ear_tx`** is the registry's scoped audit tap: the same shape, fed
  only by the registry's consume + publish exchanges.
- **Universe / run / vhost** — a universe is the durable GNode set (`d1`,
  `hw1`, `w`); a run is one execution of time against it; the broker vhost
  names the run as `<universe>__<run>` (`provisioning.md`). Authority for the
  ladder: grid-node-registry executor "Universes".
- **Connect claims** — the `fis.connect.claims` word an actor presents at
  the broker gate under the `GRIDWORKS` SASL mechanism (`actors.md`
  "Connect-time identity"). Distinct from `client_properties`, which are
  audit-only.
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
3. Per AMQP-actor class (the `AMQP_ACTOR_CLASSES` opt-in set): `<rc>_tx`
   (internal) for consume, `<rc>mic_tx` (non-internal) for publish; wrapped
   messages publish to `amq.topic` (any actor may send wrapped). The wrapped
   routing-key `type_name` slot carries the **inner** application type,
   never `"gw"`.
4. Queue is `<alias>-F<3-hex>`, auto-delete, bound to
   `rj.*.*.*.*.<my-alias-lrh>` by default.
5. Actors **passively** assert their consume exchange exists and never
   declare `mic_tx` or cross-class bindings — infra owns the fabric
   (`transport.md` "AMQP topology"–`provisioning.md`). Every reach grant
   is declared in `gwbase.topology`: the direct edges (`ROUTING_EDGES`),
   the ear taps, the two broadcast bridges to `amq.topic` (`timemic_tx`,
   `gnrmic_tx`, `rjb.#` only), the standing `debug` queue + its cap
   policy.
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
10. AMQP `client_properties` (`ServiceAlias` + `ServiceInstanceId`, plus
    `GNodeClass` for a GNode) are audit-only. What the gate decides on is
    the `fis.connect.claims` word sent under the `GRIDWORKS` SASL mechanism,
    built from the actor's live alias, instance id, the vhost's run, and
    `GNodeClass` iff GNode — presented only when `rabbit.tls` is configured.
    The credentials object holds no secret and is never erased.
11. `scada` is MQTT-only (no AMQP exchanges); reached via `amq.topic`.
    Broadcasts are subscriber-bound, not forwarded by the direct fabric.
12. Every broker URL is checked at boot, claims path or not: the vhost
    parses as `<universe>__<run>` with a universe of kind `d`, `h`, or
    exactly `w`; and the host is localhost **iff** the universe is d-kind.
    The `run` claim derives from that vhost, never from a second setting.

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

13. Wire JSON keys are PascalCase; null fields are omitted.
14. Decoding rejects non-PascalCase keys recursively.
15. Strict mode rejects unknown types or versions; degraded mode
    returns a `DegradedSemaType` wrapper that MUST NOT drive control
    logic.
16. Old versions auto-upgrade by chained `upgrade()` calls; the walk
    is bounded by `(latest - current)` steps.
17. Versions are zero-padded integer strings; breaking changes require a
    new `type_name`, not a version bump.
18. YAML under `sema/definitions/types/` is the source of truth for the
    wire shape. gwbase's copy, `src/gwbase/sema/`, is a generated snapshot
    from a pinned seed (`codec.md` "The vendored snapshot is generated"):
    never hand-edited, versions pinned not floating, the boundary classes
    rebranded `GwBase*` by the regen script so an application's own
    `SemaCodec` and the transport layer's never share a name.
19. The `gw` application envelope is a separate concept from the
    transport `RoutingEnvelope`; `wrap_bytes` / `unwrap_bytes` live in
    `gwbase.sema.wrapped` and depend only on `GridworksHeader` and
    `Gw` — never on a SemaCodec registry. `Gw.Header.MessageType ==
    Gw.Payload.TypeName == WrappedRoutingEnvelope.type_name`.

**Application:**

20. `ActorBase` knows nothing about codecs; the application owns its
    codec.
21. The two framework methods are `dispatch_message` (abstract on
    `ActorBase`, implemented by `Orchestrator`) and `process_message`
    (abstract on `Orchestrator`, implemented by final application
    classes). Applications implement `process_message` and do not touch
    `dispatch_message`. A bare `ActorBase` tap implements
    `dispatch_message` directly (it has no control plane).
22. `Orchestrator` privately handles `heartbeat.a` and `sim.timestep`
    for its configured supervisor and time coordinator; a subclass's
    codec does not need those types registered. (`GridworksActor`
    inherits this.)
23. A `sim.timestep` whose value rewinds is dropped; one whose value
    repeats is surfaced with `is_new = false`.
24. A `heartbeat.a` from `my_super_alias` is handled internally (pong +
    `on_supervisor_heartbeat`); a `heartbeat.a` from any *other* alias
    falls through to `process_message` (so e.g. a supervisor observes its
    subordinates' heartbeats).
25. The supervisor is identified by alias only; there is no separate
    secret or token at this layer (auth lives in the broker
    `client_properties` handshake).
