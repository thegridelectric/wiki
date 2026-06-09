# Concern: admin gateway service

Status: Draft · Pass 0 · Updated 2026-05-30

> Open architectural question. To serve web and mobile-responsive
> admin clients (the durable end-state per
> [`../../executor/primary.md`](../executor/primary.md) "Client
> form factor"), we need a backend **admin gateway service** that
> bridges web SSO+MFA to the prod broker's mTLS+FIS Principal model.
> Browser mTLS doesn't scale to the operator/partner/field-tech
> audience; a gateway is the only sane bridge.
>
> This concern captures the design surface — what the gateway is,
> how operators authenticate, how it interacts with FIS, how audit
> attribution works — without locking decisions. Converges into a
> design once the prod-broker TUI path is shipping.

## What the gateway is

A long-running cloud-side service that:

- Terminates HTTPS+WebSocket from web/mobile clients
- Authenticates the human operator via web SSO + MFA
- Maintains AMQP connections to the prod broker, holding a
  service-class Principal cert that FIS authorizes
- Translates HTTPS admin operations into AMQP publishes to per-method
  routing keys (`admin.<scada-alias>.<method>`)
- Streams SCADA state updates back to the client via WebSocket
- Attributes every operation in the audit stream to the **human**
  operator (from the SSO session), not the gateway's service cert

```
Operator (web SSO+MFA) → HTTPS+WS → admin-gateway
                                       │
                              service-class Principal cert
                                       │
                                       ▼
                          AMQP (prod broker, mTLS)
                                       │
                                       ▼
                                     SCADA
```

## Authentication shape

Two distinct authentications:

1. **Operator ↔ Gateway** — web SSO (Okta / Google Workspace /
   GridWorks IdP) + MFA. The operator is a human; their identity
   comes from the SSO session token.
2. **Gateway ↔ Broker** — mTLS using a service-class Principal cert
   (`kind=service` in the
   [principal-model](../../gridworks-fleet-index-service/explorations/principal-model.md)).
   FIS authorizes this Principal to publish to all `admin.*.*`
   routing keys (the gateway is a trusted proxy for any in-scope
   operator).

The gateway becomes the boundary where human identity (from SSO)
maps to machine identity (the service cert FIS sees). Audit-attribution
spans the boundary explicitly — see below.

## Authorization shape

Per-operation, the gateway checks:

1. **Operator scope** — is this human operator authorized for this
   SCADA? Stored in the gateway's operator-registry (or a small FIS
   extension that tracks operator scopes separately from broker
   permissions).
2. **Operator role** — is this operator allowed to invoke this
   method? `ops_dispatcher` may send dispatches; only `ops_admin`
   may push hardware layouts.
3. **Method itself** — the gateway publishes to
   `admin.<scada-alias>.<method>` only if (1) and (2) pass.

Note: the **broker's FIS check is still in the path** — FIS
authorizes the gateway's service cert to publish to admin.*
routing keys. The gateway does the human-operator-level authz
*before* the AMQP publish; the broker authorizes the gateway's
publish *after*. Two trust checks, two trust authorities — the
gateway and FIS — each with the right scope.

## Audit attribution — the load-bearing concern

Every admin event in `ear` must attribute the **human** operator,
not the gateway service. The gateway has to inject operator
identity into the audit chain:

- **Option A:** the gateway sets a custom AMQP message header
  (e.g., `x-gw-operator-subject`) on every publish. The SCADA
  reads this header for the audit event. Trust model: the SCADA
  trusts the gateway's claim (which is itself trusted via FIS
  auth at the broker).
- **Option B:** the gateway signs a "delegated operation" envelope
  containing the operator's SSO subject + a short-lived signature.
  The SCADA verifies the gateway's signature before trusting the
  operator-attribution. Stronger cryptographic guarantee; more
  complex.
- **Option C:** the gateway emits the audit event directly to
  `ear` (HTTPS or AMQP), bypassing the SCADA's audit emit for
  this dimension. The SCADA emits its own "operation received +
  decision" event separately.

Probably **A** for MVP (broker trust is already required); **B**
later if a compliance audit demands cryptographic delegation
proof.

## Operations the gateway exposes

A REST-shaped HTTPS surface that maps 1:1 to the admin operation
contracts:

| HTTP verb + path | AMQP routing key it triggers |
|---|---|
| `POST /scadas/{alias}/admin/dispatch` | `admin.<alias>.dispatch` |
| `POST /scadas/{alias}/admin/analog-dispatch` | `admin.<alias>.analog-dispatch` |
| `POST /scadas/{alias}/admin/keep-alive` | `admin.<alias>.keep-alive` |
| `POST /scadas/{alias}/admin/release` | `admin.<alias>.release` |
| `GET /scadas/{alias}/state` | `admin.<alias>.read-state` + response queue |
| `POST /scadas/{alias}/admin/push-layout` (later) | `admin.<alias>.push-layout` |
| `WS /scadas/{alias}/stream` | per-scada subscription to outbound updates |

Mechanism-meaning decoupling stays: an HTTPS POST and an AMQP
publish carry the same operation contract.

## Open

- **SSO provider.** Which IdP? Likely Google Workspace for
  internal staff; eventually federated for partners. MFA
  enforcement is provider-level.
- **Operator-registry vs. FIS-extension.** Does the gateway hold
  its own operator-scope table, or does FIS gain an `operator`
  principal kind that the gateway queries? The latter centralizes
  trust authority in FIS; the former keeps FIS scoped to broker
  auth. Probably the latter long-term; flexible to start.
- **Audit attribution mechanism (A/B/C above)**. A for MVP; B if
  compliance compels.
- **Gateway HA / failover** — single-instance for MVP, or
  active-passive cluster? Admin is rare and time-bounded; a brief
  gateway outage probably acceptable. Field-tech use cases may
  argue otherwise.
- **Where does the gateway deploy** — alongside FIS in the same
  cloud account, or a separate ops account? Separate is
  blast-radius-safer but more ops overhead.
- **Rate limiting.** Per-operator? Per-SCADA? Per-method? Critical
  for safety: an "infinite loop dispatch" bug in the web client
  shouldn't drain a heat pump's actuator life.
- **Live state streaming** — WebSocket from gateway to client is
  obvious; the gateway-to-AMQP side is per-scada subscription.
  Question: does the gateway keep a *persistent* subscription per
  SCADA (efficient if many operators watching the same SCADA),
  or per-operator-session subscription (simpler, less coupling
  between operators)?

## Cross-references

- [`../../executor/primary.md`](../executor/primary.md) — admin
  domain hub; "Client form factor" section explains why this
  gateway is needed
- [`when-to-add-grpc.md`](when-to-add-grpc.md) — gRPC alternative
  to HTTPS for the gateway's API; deferred
- [`../../gridworks-fleet-index-service/explorations/principal-model.md`](../../gridworks-fleet-index-service/explorations/principal-model.md)
  — the Principal model that authorizes the gateway's
  service-class cert; may grow to track operator scopes
- The existing TUI (`gridworks-scada/packages/gridworks-admin/`) —
  fat-client path that runs in parallel and doesn't go through
  the gateway
