# stand-up-web-admin

Status: Draft · Pass 0 · Updated 2026-06-26 · Linear: OPS-429

**EDD: yes** verified by real operator→broker→SCADA admin commands authorized
end-to-end by FIS over mTLS — and a web-session-without-a-hardware-assertion
attempt **denied** — not code review.

> What this is: the build plan to stand up GridWorks **web admin** — operator,
> incident-mode, direct actuator/relay control of a SCADA. The full spec already
> lives in [`../executor/primary.md`](../executor/primary.md) (incident-mode
> TopState `Auto→Admin`, prod-broker substrate, FIS one-layer authz, per-method
> routing keys, the 5–7 admin methods, the fat-client TUI + thin-client web
> gateway). This design is the ordered path to ship it; it graduates the
> [`../explorations/admin-gateway-service.md`](../explorations/admin-gateway-service.md)
> exploration. The in-`Auto`, LTN-brokered customer/app-comms half is **separate**
> ([OPS-408](https://linear.app/gridworks/issue/OPS-408)).

## Core security invariant — a web login is not enough

Certificates onto the prod broker are GridWorks' **single core security mechanism,
by design.** The web gateway must not collapse that to the strength of a web
session — otherwise a phished password could drive relays. So:

- The operator presents a **phishing-resistant, hardware-bound credential**
  (WebAuthn/FIDO2 **passkey**) registered to their FIS operator Principal — never
  a password/session alone.
- **High-impact ops require a fresh step-up assertion** (re-tap the key); a
  hijacked session cannot drive actuators.
- The gateway **forwards** the operator's assertion to FIS and holds **no standing
  authority** to issue commands on a session's behalf — it is a transport bridge,
  not an authority.
- The **fat-client TUI** keeps the pure operator-cert path (operator cert on the
  laptop, direct mTLS) for ops staff and low-level debugging.

Authority scales with impact: `ReadState` < `AdminKeepAlive` < `AdminDispatch` /
relay — the strongest proof gates the strongest action.

## Build order (per the executor Migration)

1. **Prod-broker admin topology + FIS operator Principals.** Per-method routing
   keys (`admin.<scada>.<method>`), operator-Principal permission maps, the
   `validated-user-id` plugin for audit. Rides mtls-fis-auth
   ([OPS-420](https://linear.app/gridworks/issue/OPS-420)).
2. **TUI on prod broker (max code lift).** Lift `gwa` (~60%) swapping MQTT→AMQP;
   operator certs on ops laptops; run alongside tailscale for some homes, then
   deprecate the tailscale-MQTT path.
3. **Admin gateway (web v2).** HTTPS+WebSocket → service-Principal cert → broker;
   **WebAuthn/passkey** operator auth + step-up (the invariant above); the gateway
   logs operator identity into every audit event to `ear`.

## FIS-ready seam — build ahead of FIS

Like the passkey ceremony (built in
[OPS-408](https://linear.app/gridworks/issue/OPS-408)), the admin build does
**not** have to wait for FIS. The FIS dependency is a single
seam: the **authz decision** the broker's `auth-backend-http` makes (may this
operator publish `admin.<scada>.<method>`?). Build the topology, the per-method
routing, the TUI/gateway, and the SCADA-side handlers against a **stub
authorizer**, then plug FIS in at that seam — a swap, not a rewrite.

What does **not** move: the **production-deploy gate**. Web admin SHALL NOT drive
real relays until mTLS + FIS + the passkey credential are real. A stub authorizer
is for building, never for a live house — that would be the weak path
[OPS-420](https://linear.app/gridworks/issue/OPS-420) exists to kill.

## Done-when

- An operator issues `AdminDispatch` / `ReadState` from the TUI (then the web
  client), authorized end-to-end by FIS over mTLS; every op emits an audit event.
- A **web session without a hardware-bound assertion is denied** a high-impact
  command.
- Tailscale is no longer load-bearing for admin.

## Depends on / relates

- **mtls-fis-auth** ([OPS-420](https://linear.app/gridworks/issue/OPS-420)) — the
  cert + FIS plane; this **integrates at its authz seam** and is **production-
  deploy-gated** by it, not blocked from being built.
- **Passkey ceremony** — built in ltn-brokered-app-comms
  ([OPS-408](https://linear.app/gridworks/issue/OPS-408)); reused here for operator
  principals.
- **ltn-brokered-app-comms** ([OPS-408](https://linear.app/gridworks/issue/OPS-408))
  — the in-`Auto`, customer/app half; parallel to this, not part of it.
