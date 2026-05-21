# gridworks-proactor — Rebuild Specification (primary)

> **First pass — acceptable minimum.** This captures the load-bearing
> structure of `gridworks-proactor` from its README and package layout so
> the domain has a spec to grow into. Most depth is still **Open**. This is
> *our* converging understanding, **not authoritative over the code** —
> the repo is owned by SmoothStoneComputing (Andrew), is ~2 years in
> production under [gridworks-scada], and a faithful spec requires reading
> the code with the maintainers before any rebuild is attempted.

This is the **hub** document — short by design; section numbers are global
across the (mostly not-yet-written) sub-specs.

## What it is

`gridworks-proactor` provides **"live actor" + "application-monitored
communication" infrastructure** for the GridWorks SpaceHeat SCADA. It is
deliberately separated from the scada so the scada stays
application-focused and the comms/actor infra is reusable.

Relationship to the rest of GridWorks:

- **gridworks-scada** is built *on* proactor (`ShNodeActor` extends
  proactor's `Actor`).
- **gridworks-base** is the *other* actor framework — rabbit/AMQP-native,
  sema-codec boundary. Proactor is **MQTT-native** (Mosquitto/RabbitMQ-MQTT)
  and asyncio-based. The two meet at the scada↔cloud boundary over
  `amq.topic` using the `gw` envelope (see
  [`../../gridworks-base/executor/transport.md`](../../gridworks-base/executor/transport.md)
  §3.5 — a production `gw.<from>.to.<to-class>.<inner-type>` key is the
  confirmed shared wire format).

## Map of the spec (planned)

| Sections | File | Covers | Status |
| --- | --- | --- | --- |
| §1–§2 | **primary.md** (this file) | Overview, core model, the "active" invariant, glossary | thin |
| §3 | `links.md` | MQTT links, the active-state machine, acks, reupload, message timing | **Open / TBW** |
| §4 | `actors.md` | `Proactor`, `Communicator`/`Actor`, message dispatch, the asyncio loop, sync-thread bridge | **Open / TBW** |
| §5 | `events-persistence.md` | Event store-and-forward, the persister interface | **Open / TBW** |
| §6 | `app-and-io.md` | `App`, `web_manager`, `io_loop`, watchdog, stats, config | **Open / TBW** |

## 1. Core model (verified from README)

- A **`Proactor`** is a **single-threaded event loop on asyncio** that
  exchanges messages between the main application object, "live actor"
  subobjects, and MQTT clients.
- Long-running / blocking work is kept off the loop via a sync-thread
  bridge (`sync_thread.py`, `io_loop.py`) — *details Open.*
- Transport is **MQTT** (Mosquitto for tests; RabbitMQ-MQTT in
  deployment), **TLS by default** (certs via `gwcert`).
- The package ships **`gwproactor_test`**, a live-test harness that
  simulates communication between Proactors.

## 2. The "active" communication-state invariant (verified, load-bearing)

Each external link exposes a **communication state** to the proactor and
its sub-objects. Per the README, a link is **"active"** iff **all** of:

1. the underlying MQTT connection is connected;
2. all input channels (MQTT topic subscriptions) are established;
3. all application messages requiring acknowledgement have been ACKed in
   time (default **5 s**);
4. a message has been received "recently" (default within **1 min**).

**Reliable Event delivery:** locally-generated "Events" are **persisted
locally until acknowledged**, and unacknowledged Events are **retransmitted
when "active" is restored**. (The persister lives under `persister/`;
interface + a timed-rolling-file implementation — *details Open.*)

This active-state + store-and-forward behavior is the heart of "application
**monitored** communication" and is the first thing a faithful rebuild must
reproduce.

## Glossary (provisional)

- **Proactor** — the single-threaded asyncio message loop
  (`proactor_implementation.py`, `proactor_interface.py`).
- **Actor / Communicator** — a "live actor" sub-object hosted by the
  Proactor (`actors/actor.py`); scada's `ShNodeActor` extends it. *Contract
  Open.*
- **LinkManager / link state** — manages MQTT links and the "active" state
  machine (`links/`). *Open.*
- **Event** — a locally-generated message with reliable, acked,
  store-and-forward delivery. *Schema/Open.*
- **persister** — local durable store for unacked Events
  (`persister/interface.py`). *Open.*
- **App** — the top-level application object wiring a Proactor + actors +
  links + web (`app.py`, `web_manager.py`). *Open.*

## Invariants (what we can assert now)

1. Single-threaded asyncio loop; sub-objects and MQTT clients communicate
   by passing messages to it (no shared-state concurrency on the loop).
2. "Active" is the 4-part conjunction in §2 — connection + subscriptions +
   timely acks + recent receipt.
3. Locally-generated Events are store-and-forward: persisted until acked,
   retransmitted on reconnection/active-restore.
4. TLS by default; identity via `gwcert`-issued certs.

## Open (the bulk of the real spec)

- **Message & dispatch model** (§4): the `Message` envelope
  (`message.py`), how the Proactor routes to actors, the
  `Communicator`/`Actor` contract, callbacks.
- **MQTT topic / routing-key scheme** (§3): **explicitly Open** — do *not*
  assume. One confirmed data point is the production
  `gw.<from>.to.<to-class>.<inner-type>` key (gridworks-base
  `transport.md` §3.5); the `gwproto/topic.py` `MQTTTopic` 3-component form
  did **not** match production, so the authoritative encoder is TBC.
- **codecs** (`codecs.py`) and the relationship to `gwproto` types.
- **Link state machine** details: acks (`acks.py`), reupload
  (`reuploads.py`), message timing (`message_times.py`), timers.
- **Persister** interface + implementations and durability guarantees.
- **App / web / io_loop / external watchdog / stats** roles.
- **Config** surface (`config/*`): app/proactor settings, links, mqtt,
  paths, logging.
- **How proactor relates to gridworks-base's `RoutingEnvelope` model** —
  whether/where the two converge as FIS and the universal-envelope
  question (gridworks-base `codec.md` §4.7) are resolved.

[gridworks-scada]: https://github.com/thegridelectric/gridworks-scada
