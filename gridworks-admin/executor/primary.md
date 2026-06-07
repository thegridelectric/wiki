# gridworks-admin — primary

Status: Draft · Pass 1 · Updated 2026-05-30

> **What this is.** The acceptable-minimum hub for the GridWorks
> admin domain — the operator-facing surface for incident-mode
> intervention on a deployed SCADA. Captures the substrate (prod
> broker), the one-layer FIS authz model, the tight operation
> surface (5–7 SCADA admin methods), and the migration off the
> tailscale-MQTT path. Most operational details are Open.

## One-line summary

Admin is the rare, time-bounded, mTLS-authed surface for
incident-mode operator intervention on a SCADA. It runs on the
prod RabbitMQ broker (the same broker the control plane uses)
under FIS-authorized operator Principals, with per-method routing
keys for fine-grained authz. Admin is **parallel to** the control
plane — not part of it — and explicitly suspends the heating SLA
when invoked. Customer-facing thermostat preferences DO NOT come
here; they route through the LTN.

## Motivation

The existing admin path (`gridworks-scada/packages/gridworks-admin/`,
the `gwa watch` TUI talking to a local Mosquitto broker on each Pi
via tailscale) was right for the <30-home era. Two pressures break
it:

1. **Tailscale device-limit (~100)** caps the fleet at hundreds of
   homes; we're sized for thousands.
2. **Trust model** — tailscale-membership-authed admin doesn't
   compose with the mTLS+FIS Principal model we want for all
   prod-broker connections (see
   [`../../gridworks-fleet-index-service/research/concerns/principal-model.md`](../../gridworks-fleet-index-service/research/concerns/principal-model.md)).

Admin needs its own design domain because its trust model, audit
requirements, and operational shape differ from both the control
plane (which it interrupts) and the customer-facing LTN API.

## Scope

Admin is **incident mode**: SCADA TopState `Auto → Admin`. When an
operator enters Admin on a SCADA, that SCADA's hierarchical control
goes Dormant; the actuator forest reassigns to operator commands;
the **heating SLA is suspended** for the duration. Time-bounded by
`AdminKeepAlive` renewals; auto-reverts on timeout.

Operation surface (per `gw_spaceheat/actors/scada.py:78-82, 287-487`):

| Method | Status |
|---|---|
| `AdminDispatch` — direct actuator/relay command | Existing |
| `AdminAnalogDispatch` — analog setpoint command | Existing |
| `AdminKeepAlive` — extend Admin-mode timeout | Existing |
| `AdminReleaseControl` — explicit return to Auto | Existing |
| `ReadState` — live state snapshot query | MVP-likely |
| `PushLayout` — hardware-layout reconfig | Defer |

5–7 methods total. Tight.

### What admin is NOT

- The customer-facing thermostat interface. Homeowner / fleet-owner
  preferences route through the LTN and stay in `Auto`.
- General remote management or developer-style RPC.
- Live-state monitoring at fleet scale — that's observability
  ([`../../observability/`](../../observability/)), always-on, both
  modes.
- Provisioning / installer
  ([`../../gridworks-provisioning/`](../../gridworks-provisioning/)),
  which runs pre-identity over HTTPS.

## Substrate — prod broker

The SCADA Pi is double-NAT'd behind a residential router and a
GridWorks router; inbound connections aren't possible. The Pi
makes outbound AMQP connections to brokers. So admin's substrate
must be a broker — the only NAT-friendly carrier for
operator→SCADA traffic.

**Admin runs on the same prod broker the control plane uses.**

Rationale: we have to trust the prod broker anyway (it carries the
control plane); standing up a second broker doesn't reduce the
trust surface. The Principal model
([principal-model](../../gridworks-fleet-index-service/research/concerns/principal-model.md))
gives per-cert isolation between principal kinds (gnode / service /
operator) — trust-realm separation is enforced at the cert and
permission-map level, not at the broker boundary. This parallels
the analytics-broker deferral ([`../../rmqbot/designs/analytics-broker-shovel.md`](../../rmqbot/designs/analytics-broker-shovel.md))
which landed at the same conclusion for the same reason.

A dedicated admin broker stays as a future option if compliance,
cross-region failover, or a class of consumers needs broker-level
separation. Not now.

### Mechanism vs. meaning decoupling

Operation contracts are designed REST-shaped — typed request,
typed response, idempotent where possible, one audit event per
call — even though the carrier is AMQP. The HTTPS gateway path
(see "Client form factor" below) consumes the same operation
contracts. See
[`../research/concerns/when-to-add-grpc.md`](../research/concerns/when-to-add-grpc.md)
for the related gRPC question.

## Client form factor

Two client paths, sharing one operation contract.

### Fat client — TUI (lift from existing `gwa watch`)

A long-running terminal app maintains an mTLS+AMQP connection
directly to the prod broker. The operator's laptop holds the
operator cert. ~60% of the existing `gridworks-admin` package
lifts cleanly (TUI widgets, CLI scaffolding, protocol-state
machines, message types); the focused rewrite is the MQTT
transport → AMQP transport layer (~700 lines of paho → pika).

```
TUI (laptop, operator cert) → AMQP (prod broker) → SCADA
```

**Audience:** GridWorks ops staff who already use `gwa`.
Transitional — narrow audience that doesn't scale to partners or
field techs.

### Thin client — Web (the durable end-state)

A backend **admin gateway service** maintains AMQP connections to
the broker; clients (browser, mobile-responsive) talk
HTTPS+WebSocket to the gateway. Operators authenticate to the
gateway via web SSO+MFA; the gateway holds a service-class
Principal cert that FIS authorizes; the gateway logs the human
operator identity (from the SSO session) into every audit event.

```
Browser → HTTPS+WS → admin-gateway (service Principal cert) →
  AMQP (prod broker) → SCADA
```

**Audience:** GridWorks ops at HQ (fleet-wide visibility), field
installers / partner staff (responsive on tablet / phone), broader
future audience. Phone-native is deferred behind PWA-on-web, which
typically covers field-tech needs at far lower build cost than
iOS/Android native.

The gateway is its own design surface — see
[`../research/concerns/admin-gateway-service.md`](../research/concerns/admin-gateway-service.md).

### Why both, and why the gateway is non-optional eventually

Browser mTLS for end-users is hostile (per-device cert install with
no real story for mobile / partner audiences). A gateway tier is
needed to bridge web SSO+MFA → broker mTLS+FIS. Since the gateway
must exist for any web/phone path, it gets designed alongside the
TUI work — not bolted on after.

The TUI continues to work alongside the gateway path. Operators
who prefer it can keep using it (or also use it for low-level
debugging) even after web v2 ships.

## Authz — single layer, FIS-driven

**One-layer authz**: FIS, via the broker's HTTP auth-backend, makes
the entire access decision. SCADA does not duplicate the authz
check; it trusts FIS and executes.

### Per-method routing keys

Each admin method gets its own routing key on the prod broker:

```
admin.<scada-alias>.dispatch
admin.<scada-alias>.analog-dispatch
admin.<scada-alias>.keep-alive
admin.<scada-alias>.release
admin.<scada-alias>.read-state
admin.<scada-alias>.push-layout      (later)
```

The FIS Principal's permission map for an operator names which
routing keys (`admin.<scope>.<method>`) they may publish to.
Scope (which SCADAs) and method (which actions) are encoded
together as the resource pattern.

### Flow

```
Operator publishes AdminDispatch payload to routing key
  admin.d1.scada.beech.dispatch
       ↓
Broker calls FIS /auth/resource
  (operator cert subject, resource=admin.d1.scada.beech.dispatch, permission=write)
       ↓
FIS Principal lookup → permission map check → allow/deny
       ↓
SCADA consumes the routing key; suffix names the method
SCADA executes (trusting FIS's authz decision)
```

### Operator identity for audit

Depends on the client form factor:

- **TUI (fat client):** operator publishes directly with their
  cert. With RabbitMQ's `validated-user-id` plugin enabled on the
  prod broker, `properties.user_id` on every message is guaranteed
  to match the AMQP connection's authenticated identity (the
  operator's cert subject). SCADA reads `properties.user_id` and
  trusts it for the audit event.
- **Gateway (thin client):** gateway publishes on behalf of the
  operator. `properties.user_id` is the gateway's *service*
  identity. The operator identity rides as a custom message header
  the gateway sets (e.g., `x-operator-subject`); the SCADA trusts
  the claim because the gateway is itself FIS-authorized to be the
  operator proxy.

The broker-side `validated-user-id` decision is captured in
[`../../gridworks-fleet-index-service/research/concerns/principal-model.md`](../../gridworks-fleet-index-service/research/concerns/principal-model.md)
(needs the plugin enabled). Gateway-side custom-header attribution
mechanism details in
[`../research/concerns/admin-gateway-service.md`](../research/concerns/admin-gateway-service.md).

## Audit

Every admin operation emits a structured event to `ear` for
durable audit. Operator subject (per "Operator identity for
audit"), target SCADA, method (from routing key), payload hash,
result. The audit stream is the *first-class record* of all admin
activity — treat it as the primary surface, with broker logs as
backup.

## Migration

Three stages:

1. **Today — `gwa` over tailscale + local Mosquitto.** Existing
   path continues. No change required.

2. **TUI on prod broker (max code lift).** Stand up the
   per-method-routing-key topology + FIS operator-Principal
   support on the prod broker. Lift the existing `gwadmin` package
   to a `gridworks-admin-cli` (or in-place extension) that swaps
   the MQTT transport for AMQP — ~60% of the code carries over.
   Operator certs installed on ops laptops. Run alongside stage 1
   for some number of homes before deprecating tailscale-MQTT.

3. **Web v2 via admin gateway (durable end-state).** Build the
   admin gateway service exposing HTTPS+WebSocket to web/mobile
   clients; gateway holds a service-class Principal cert and
   logs operator identity from SSO sessions. Build the web client
   against the gateway. TUI continues to work; ops staff can
   choose. PWA-on-web covers field-tech / phone needs.

Tailscale stops being load-bearing for admin after stage 2.
Stage 3 opens admin to a broader audience without requiring
per-device cert install.

## Open

- **Q6.4 Cert lifecycle for operator certs** — FIS-issued. Rotation
  cadence, revocation triggers, MFA gating for high-impact
  operations. Captured in
  [principal-model](../../gridworks-fleet-index-service/research/concerns/principal-model.md)
  Open list.
- **Q6.7 First-MVP-shipped operations** — recommend: `ReadState`,
  enter-admin (via first `AdminDispatch`), `AdminReleaseControl`,
  `AdminDispatch`, `AdminAnalogDispatch`, `AdminKeepAlive`. Defer
  `PushLayout` and cert-rotate until v2.
- **TUI package extraction.** Does the lifted TUI live in the
  existing `gridworks-scada/packages/gridworks-admin/` (re-pointed
  at prod broker), or extract to a standalone `gridworks-admin-cli`
  repo? Probably extract when the prod-broker path is verified —
  removes the admin client's coupling to the SCADA repo's release
  cadence.
- **Admin gateway** — design decisions captured in
  [`../research/concerns/admin-gateway-service.md`](../research/concerns/admin-gateway-service.md):
  SSO provider, MFA gating, audit-attribution shape, gateway
  high-availability, where it deploys (cloud-side; alongside FIS?).
- **Per-method routing-key naming** — kebab-case (`analog-dispatch`)
  vs lower-snake (`analog_dispatch`) vs sema-typed (`admin.dispatch`).
  Probably kebab-case for routing-key segments; align with
  RabbitMQ idioms.
- **When to consider a dedicated admin broker (deferred B3)** —
  compliance audit physically requires separation; cross-region DR;
  admin volume grows beyond plausible.

## Cross-references

- [`../research/concerns/when-to-add-grpc.md`](../research/concerns/when-to-add-grpc.md)
  — when to add a gRPC pathway alongside the broker substrate
- [`../../gridworks-fleet-index-service/research/concerns/principal-model.md`](../../gridworks-fleet-index-service/research/concerns/principal-model.md)
  — FIS-side auth model; operator is one Principal kind
- [`../../rmqbot/designs/analytics-broker-shovel.md`](../../rmqbot/designs/analytics-broker-shovel.md)
  — same-reasoning analytics-broker deferral
- [`../../gridworks-scada/research/concerns/non-gnode-interfaces.md`](../../gridworks-scada/research/concerns/non-gnode-interfaces.md)
  — original framing of admin as an open concern
- [`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md)
  — gwbase 0.5.0; admin runs as a non-GNode actor (`ActorBase` ear-tap) on
  the rabbit toolkit (operator-side may not use gwbase at all)
- Legacy code: `gridworks-scada/packages/gridworks-admin/` (the
  `gwa` CLI), `gridworks-scada/gw_spaceheat/actors/scada.py:287-487`
  (the AdminDispatch / AdminKeepAlive / AdminReleaseControl
  handlers)
