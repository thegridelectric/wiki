# gridworks-base — Application layer & diagnostics

Status: Draft · Pass 0 · Updated 2026-08-14

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global; this file holds
the application layer and diagnostics. Transport mechanics are in
[`transport.md`](transport.md); the codec in [`codec.md`](codec.md).

---

## The application layer

The actor framework is a **three-tier linear hierarchy** — each tier adds
exactly the capability its name implies, so a service rides the tier that
matches what it actually is:

```
ActorBase            raw rabbit + sema toolkit; a passive ear-tap.
   ▲ extends           ServiceSettings, NO GNode identity.
Orchestrator         + class-routing + the heartbeat / sim-timestep rhythm.
   ▲ extends           transport_class; used by Supervisor, TimeCoordinator.
GridworksActor       + Sema-validated GNode identity (g.node.gt.json).
                       Used by SCADA, LTN, MarketMaker, forecast services.
```

A `GridworksActor` *is an* `Orchestrator` *is an* `ActorBase`. The tiers are
not siblings.

**Why three tiers (not two-with-a-mixin).** The world has three categories —
no-orchestration / orchestration-non-GNode / orchestration-GNode — and three
classes mirror them 1:1. The heartbeat + sim-time machinery is *stateful*,
and stateful mixins are where Python's MRO surprises bite; the flexibility a
mixin would buy (orchestration attachable to any class) isn't used, since
everyone who needs orchestration also needs rabbit. The middle tier is named
`Orchestrator`, not `ControlPlane`: real control (dispatch, relay,
hierarchical state machines) lives at the GNode tier in subclasses like
`Scada` / `Ltn`; the middle tier only runs the system *rhythm* (heartbeat
ceremony + sim.timestep pulse).

**Who rides which tier:**

| Subclass | Tier | Settings | Source of identity |
|---|---|---|---|
| Journalkeeper, ear actor-side | `ActorBase` | `ServiceSettings` | env `service_alias` |
| Supervisor, TimeCoordinator | `Orchestrator` | `ServiceSettings` | env `service_alias` |
| SCADA, LTN, MarketMaker, forecast services | `GridworksActor` | `GNodeSettings` | `g.node.gt.json` ↔ `service_alias` |

## ActorBase

`ActorBase` is the "I am a RabbitMQ-connected actor" base class, and by
default a **passive ear-tap**: it consumes the universal audit exchange and
publishes nothing. Non-GNode services (journalkeeper, ear's actor-side,
audit-tap consumers) ride it directly with `ServiceSettings` — no
`g.node.gt.json`, no GNode identity. It provides:

- Identity (`primary.md` "Identity"): `alias` + `instance_id` from `ServiceSettings`. **No**
  `transport_class` — a tap has no routing identity to name.
- A per-actor `logger` (XDG state-home, bijective human format — see the
  logging substrate).
- Connection / channel / queue / consume lifecycle (`transport.md` "Threading and lifecycle"), reconnect-with-
  backoff in a dedicated consumer thread.
- Default consume exchange `ear_tx`, and **no automatic binding**:
  `bind_queue()` is a no-op for the tap — the subclass binds its slice of
  `ear_tx` (or other exchanges) in `local_rabbit_startup()` via
  `subscribe_broadcast` / `subscribe_amq_topic`.
- **No publish exchange** (`_publish_exchange is None`). `send` of a
  `WrappedRoutingEnvelope` still reaches `amq.topic`; `send` of a
  Direct/Broadcast returns `NO_PUBLISH_EXCHANGE` (`actors.md` "Diagnostics") — a tap cannot
  class-route.
- `wrapped_envelope(...)` (the only envelope helper here — it needs no
  `from_class`). `direct_envelope` / `broadcast_envelope` live one tier up.
- Subclass hooks: `local_start()`, `local_stop()`, `local_rabbit_startup()`.

`ActorBase` is abstract on a single framework method:

```
dispatch_message(envelope: RoutingEnvelope, body: bytes) -> None
```

The transport calls this for every parsed delivery. A bare tap implements
it directly (it has no control plane); `Orchestrator` implements it to
filter control-plane traffic and forward the rest to `process_message`.

`ActorBase` deliberately **knows nothing about codecs**. It holds no
SemaCodec; it never calls `to_bytes` / `from_bytes`. (It also does not
import `gwbase.sema` — alias/uuid wire formats come from the codec-free
`gwbase.transport_format`.) Any subclass that talks in typed messages owns
its own codec instance.

## Orchestrator

`Orchestrator` is the first tier that **class-routes**, and the home of the
GridWorks orchestration rhythm. Supervisor and TimeCoordinator — which are
**not** GNodes — ride this tier with `ServiceSettings` (no `g.node.gt.json`).

It adds:

- `transport_class`, supplied as an `__init__` param (intrinsic to the
  actor's role, not deployment config — like `my_super_alias`). From it,
  `Orchestrator` overrides the tap defaults: consume `<rc>_tx`, publish
  `<rc>mic_tx`, and `bind_queue()` binds the queue **direct-to-me**
  (`rj.*.*.*.*.<my-alias-lrh>`).
- `direct_envelope` / `broadcast_envelope` — the helpers that stamp
  `from_class = transport_class`.
- A **private** `SemaCodec` for the two control-plane types, and the
  control-plane handling so applications don't re-implement it:
  - `heartbeat.a` **from `my_super_alias`** — auto-ponged; semantic hook
    `on_supervisor_heartbeat(from_alias)` fires. A `heartbeat.a` from any
    *other* sender falls through to `process_message`, so a supervisor can
    observe its subordinates' heartbeats.
  - `sim.timestep` from the time coordinator — updates the simulated clock;
    `on_simulated_time(time_unix_s, from_alias, is_new)` fires.
- Construction requires `my_super_alias` and `my_time_coordinator_alias`.

The dispatch rule (implemented in `Orchestrator.dispatch_message`):

```
dispatch_message(envelope, body):
    if envelope.type_name in {"heartbeat.a", "sim.timestep"}:
        decode (private codec); handle internally
        # a heartbeat.a NOT from my_super_alias is re-routed to process_message
    else:
        process_message(envelope, body)
```

`Orchestrator` is abstract on `process_message` — final application classes
implement it and do **not** override `dispatch_message`.

Behavioral rules of note:

- A `sim.timestep` with `time_unix_s` less than the latest observed value is
  dropped (anti-rewind).
- A `sim.timestep` equal to the latest is still surfaced via
  `on_simulated_time` with `is_new = false` — distinguishing a clock advance
  from a re-announcement.
- The pong is sent as a direct message, encoded by the private codec.
- `send_ready(time_unix_s?)` constructs a `Ready` and sends it direct to the
  time coordinator (defaults to the latest observed simulated time). It uses
  `instance_id` for the `from_g_node_instance_id` slot.

## GridworksActor

`GridworksActor` adds durable GNode identity on top of `Orchestrator`. It is
the canonical actor for GridWorks GNodes — SCADA, LTN, MarketMaker, the
forecast services — one subclass per `TransportClass`, each passing its
fixed `transport_class` up to `Orchestrator`.

At construction it:

- Loads its `g.node.gt.json` (default path via XDG, `primary.md` "Identity") and **Sema-validates
  it as a `GNodeGt`** (axioms 1–5 fire) — rather than reading three untyped
  strings the way the old base did. A typo, missing field, or drifted
  schema fails at boot with a clear `ValueError`, not a mid-run crash.
- Enforces the binding `GNodeGt.alias == settings.service_alias`
  (provisioning-drift guard).
- Sets `g_node_id`, `g_node_class`, and adds `GNodeClass` — the
  GNode-vs-service discriminator (`primary.md` "Identity") — to both
  connect-time channels: `client_properties` and the connect claims
  ("Connect-time identity" below). `g_node_alias` / `g_node_instance_id`
  survive as back-compat property aliases for `alias` / `instance_id`.

## Connect-time identity

An actor tells the broker two different things when it connects, and the
distinction matters because only one of them can carry weight.

**`client_properties`** (`ActorBase._client_properties`) advertises
`ServiceAlias` + `ServiceInstanceId`, plus `GNodeClass` for a GNode. The
broker records these on the connection, where the management API and the
`connection_created` event can read them. They are for audit and
reconciliation only: the AMQP reader never passes `client_properties` to an
auth backend, so nothing an authorization decision depends on may live here.

**Connect claims** (`ActorBase._connect_claims`) build a
`fis.connect.claims` word — alias, instance id, the run being joined, and
`GNodeClass` iff the principal is a GNode — which
`GridworksClaimsCredentials` (`gwbase/credentials.py`) sends as the SASL
response under the `GRIDWORKS` mechanism. This is the channel an
authorization gate can act on. Identity itself is never claimed: it is
proven by the connection's TLS client certificate, so completing a
claims-bearing connect requires that certificate's private key.

The credentials class holds no secret and therefore does not erase itself
after connecting. A broker that does not offer the `GRIDWORKS` mechanism
gets `(None, None)`, which pika reads as an ordinary negotiation miss — so a
broker still on password auth fails cleanly rather than crashing the actor.

**Switching an actor to cert-plus-claims is config, not code.** A
`rabbit.tls` block on the settings (`ca_cert_path`, `cert_path`,
`private_key_path` — all three required, names matching the proactor's)
makes `connect_consumer()` build mTLS from the declared material and
authenticate with the claims; the URL scheme must then be `amqps`. Without
the block, password connect is untouched. The `Run` claim is never declared:
it derives from the broker URL's vhost, which IS the `universe.run` being
joined — one source, no drift.

**Every broker URL is checked against the universe ladder at boot** (gnr
executor "Universes" is the authority), claims path or not:

- the vhost must parse as a `universe.run` whose universe kind is `d` (dev),
  `h` (hybrid), or exactly `w` — the single production universe;
- the URL host is `localhost`/`127.0.0.1` **iff** the universe is d-kind.
  This is the dev rung's isolation guarantee ("all comms go through
  localhost brokers") enforced rather than trusted: a remote dev universe
  and a localhost `hw1` both refuse to boot.

The grammar lives in `transport_format.py` (`Universe`, `UniverseRun`) —
the settings layer stays sema-import-free per the transport/codec
separation, and the kind rule carries a note naming the missing sema word
(a `universe` format) that would retire it.

## Example: hello_rabbit

The minimal end-to-end shape (a `LeafTransactiveNode` GNode — scada is
MQTT-native with no AMQP exchanges, `transport.md` "AMQP topology"):

```
class HelloGNode(GridworksActor):
    def process_message(self, *, envelope, body):
        return                              # ignore everything

# settings: GNodeSettings(service_alias="d1.hello"), g.node.gt.json on disk
gn = HelloGNode(
    settings=settings,
    transport_class=TransportClass.LeafTransactiveNode,
    my_super_alias="d1.super1",
    my_time_coordinator_alias="d1.time",
)
gn.start()                                  # spawns consumer thread, binds queue

hb = HeartbeatA(my_hex="0", your_last_hex="a")
gn.send(
    envelope=gn.broadcast_envelope(type_name=hb.type_name),
    body=hb.to_bytes(),                     # SemaType serializes itself
)
gn.stop()
```

What the broker sees:

- A new queue `d1.hello-Fxxx` declared and bound to `ltn_tx` with pattern
  `rj.*.*.*.*.d1-hello`.
- One message published to `ltnmic_tx` with routing key
  `rjb.d1-hello.ltn.heartbeat-a` and body
  `{"MyHex":"0","YourLastHex":"a","TypeName":"heartbeat.a","Version":"..."}`.
- The queue auto-deletes when the actor stops.

A **non-GNode tap** (e.g. journalkeeper) instead subclasses `ActorBase`
directly, constructs with `ServiceSettings(service_alias=...)` and no
`g.node.gt.json`, and binds its slice of `ear_tx` in `local_rabbit_startup`.

## Settings, file locations, and logging

Every actor is constructed from settings and writes to per-service XDG
locations — no root or `/etc` needed.

**Settings.** `ServiceSettings` is the minimum (any actor); `GNodeSettings`
extends it with `g_node_path`. On the base classes the fields read from the
`GWBASE_` env prefix; a deployed service subclasses with its OWN prefix
(`GJK_`, `GWWF_`, …) plus a dev-default `service_alias` and its own
`service_name` — one `.env`, one prefix per service, never `GWBASE_*` vars:

- `service_alias` (`LeftRightDot`, required) — becomes the actor's `alias`.
- `instance_id` (UUID; auto-generated per boot if unset).
- `service_name` — the directory segment for file locations (e.g. `scada`),
  distinct from the alias.
- `log_level`, `log_rotate_bytes`, `log_rotate_count`.
- `g_node_path` (`GNodeSettings` only) — the `g.node.gt.json` location.

Logging is provided, not configured: every actor gets `self.logger` at
construction (the per-actor rotating XDG file logger below); a service
does not call `logging.basicConfig` or add handlers of its own.

**File locations (XDG Base Directory)**, keyed on `service_name`:

| Kind | Path |
|---|---|
| config | `$XDG_CONFIG_HOME/gridworks/<service_name>/` |
| `g.node.gt.json` | `…/config/gridworks/<service_name>/g.node.gt.json` |
| data | `$XDG_DATA_HOME/gridworks/<service_name>/` |
| state | `$XDG_STATE_HOME/gridworks/<service_name>/` |
| logs | `$XDG_STATE_HOME/gridworks/<service_name>/log/<service_alias>.log` |

With `XDG_*_HOME` unset these default under `~/.config`, `~/.local/share`,
`~/.local/state` — so on a Pi a scada logs to
`~/.local/state/gridworks/scada/log/<alias>.log`. A small inline helper
(`gwbase.config.paths`) derives these; tests redirect them by setting the bare
`XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_STATE_HOME` env vars.

**Path convention — a cloud/edge boundary (normative).** gwbase uses **plain
XDG** keyed on `service_name`; there is **no** `<PREFIX>_PATHS__BASE/NAME`
nested-env path object. That nested form belongs to **gwproactor's** separate
`Paths` class (`gwproactor/config/paths.py`), which the on-device proactor
services (scada, the LTN) use. The two are distinct worlds and the split is
deliberate: **all GridWorks *cloud* actors are gwbase** (journalkeeper,
marketmaker, the weather/price services, …) and therefore uniformly plain-XDG;
the on-**device** proactor fleet is `PATHS__`. So a gwbase service MUST NOT pull
`gridworks-proactor` in merely to obtain `Paths` — that inverts the layering for
one feature and imports the wrong convention. A new gwbase service's path
template is *the other gwbase cloud actors*, never scada/LTN.

**Logging.** `ActorBase` builds a per-actor `logger` at construction: a
`RotatingFileHandler` (capped at `log_rotate_bytes` × `log_rotate_count`)
writing a **bijective human-readable** line —
`<iso-ts> <LEVEL> <alias> > <message>[ key=val …]`, with a file header and
`  | …` exception continuation, and a context filter injecting
`service_alias` + `instance_id`. The format is designed to map 1:1 onto a
future `observability.log-entry/000` Sema type, so a downstream
broker-forwarding handler can attach to the same logger with **no**
actor-side change. That downstream work (broker forwarding, verbosity
requests) is out of scope here — see
[`../explorations/logging-for-observability.md`](../explorations/logging-for-observability.md).

---

## Diagnostics

Both ends of the boundary expose enums rather than raising on
transport-or-decode failure paths, so the broker event loop is never
disrupted by application bugs.

`OnSendMessageDiagnostic`: `MESSAGE_SENT`, `CHANNEL_NOT_OPEN`,
`STOPPED_SO_NOT_SENDING`, `STOPPING_SO_NOT_SENDING`, `NO_PUBLISH_EXCHANGE`
(a tap, or any actor with no `mic_tx`, tried to send a Direct/Broadcast),
`UNKNOWN_ERROR`.

`OnReceiveMessageDiagnostic`: `MESSAGE_DELIVERED`,
`ROUTING_KEY_PARSE_ERROR`, `UNHANDLED_CATEGORY`.

The latest diagnostic is stored on the actor and is intended for test
assertions and operational logging.
