# Concern: when and why to add a gRPC pathway alongside the broker

Status: Draft · Pass 0 · Updated 2026-05-28

> Open question. The MVP `gridworks-admin` is broker-based (AMQP on
> a dedicated admin broker). Operation contracts are deliberately
> designed REST-shaped (typed request / typed response / idempotent
> where possible / one audit event per call) so a gRPC pathway can
> be added later without rewriting the operations themselves. This
> doc captures *when* that might be worth doing.

## Context — why broker for MVP

See `wiki/gridworks-admin/executor/primary.md` once drafted.
Short version: the SCADA Pi is in a double-NAT setup behind a
GridWorks router behind a residential router. Inbound connections
to the Pi are not possible. The Pi connects *outbound* to brokers
(prod control plane, admin broker, eventually analytics). A
broker-based admin substrate is the only NAT-friendly option for
operator → SCADA traffic.

The "mechanism vs. meaning" decoupling discipline ensures we keep
the option to add other carriers without redoing the operation
contracts.

## Candidate triggers for adding gRPC

A gRPC pathway becomes worth the integration cost if/when one of
these is true:

### 1. Cloud-side service-to-service admin federation

Today there are no admin clients other than human operators. If
GridWorks ever stands up a cloud-side service that needs to call
admin operations programmatically (e.g., an auto-remediation
service, a fleet-management orchestrator, an LLM-driven incident
responder), that consumer is a service-to-service caller, not a
human. Service-to-service traffic strongly prefers:

- Strongly-typed contracts via protobuf (clients and servers
  can't drift)
- Streaming for live-state queries
- Rich status codes (`FAILED_PRECONDITION`, `PERMISSION_DENIED`,
  etc.) over coarse HTTP statuses

If/when such a consumer lands, exposing the admin contracts via
gRPC alongside the broker path saves the consumer's authors from
implementing AMQP req-rep handshakes.

### 2. Partner integrations with strict schema enforcement

If GridWorks ever exposes a subset of admin operations to a partner
(a utility, an aggregator, a market operator), the partner will
want a stable contract with codegen support. gRPC's `.proto` files
are the industry-standard portable contract format. REST + OpenAPI
also works; gRPC is more first-class for strict-schema partners.

### 3. Bidirectional streaming for live dispatch monitoring

If a future need surfaces for live, low-latency streaming of SCADA
dispatch state to admin (e.g., a real-time grid-operations console
that needs sub-second updates), gRPC's server-streaming or
bidirectional-streaming primitives are first-class. AMQP can do
streaming via a long-lived consumer queue, but the gRPC shape is
ergonomically better for this case.

### 4. Performance pressure at fleet scale

At 1000+ SCADAs, the message-volume on the admin broker may become
non-trivial (especially with live dispatch streaming if added).
gRPC's binary protobuf wire + HTTP/2 multiplexing is more compact
than AMQP-JSON. This is unlikely to be the *primary* driver but
could tip the analysis at scale.

## Triggers for staying broker-only

Reasons to NOT add gRPC even when one of the above appears:

- **Operational complexity.** Two transports means two sets of
  auth, two sets of audit hooks, two failure modes to debug. The
  ops tax persists.
- **Trust-model duplication.** mTLS + FIS cert validation works for
  both — but the broker-auth hook and the gRPC-auth interceptor
  are different code paths that need to stay in sync on policy.
- **NAT topology unchanged.** gRPC still cannot reach the SCADA Pi
  directly; a cloud-hosted gRPC endpoint would have to call back
  through the broker anyway. Only useful if the *callers* are
  cloud-side services, not human operators on laptops.

## When the analysis should be redone

Periodic re-evaluation when any of the following changes:

- A new service-to-service admin client is being designed (consider
  before building it on top of AMQP req-rep).
- A partner integration is on the roadmap.
- Live dispatch streaming is added as a feature.
- Fleet size crosses ~500 SCADAs (operational scale where
  performance starts to matter).

## Cross-references

- `wiki/gridworks-admin/executor/primary.md` (when drafted)
- Original framing in the grill session 2026-05-27/28 with
  `modest-rosemary`: my initial REST recommendation was wrong-shaped
  because of NAT; broker is the right answer for MVP. The mechanism
  / meaning decoupling discipline is what keeps gRPC an additive
  option rather than a rewrite.
