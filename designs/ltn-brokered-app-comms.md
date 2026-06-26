# ltn-brokered-app-comms

Status: Draft · Pass 0 · Updated 2026-06-26 · Linear: OPS-408

**EDD: yes** verified by a real round trip — change a house's mode/params from a
web frontend and observe the SCADA apply it (no restart) via the LTN, on a real
broker; not code review.

> What this is: the path for **application-level control from a web frontend to a
> SCADA, brokered through the LTN.** A house's `SystemMode`, control parameters,
> and (later) thermostat-style preferences flow **web → LTN → SCADA**, never web →
> SCADA directly. This is the in-`Auto`, customer/fleet-owner, **SLA-preserving**
> half. The parallel **admin / direct-relay** path (incident-mode, operator,
> broker-mTLS, which *suspends* the SLA) is out of scope — it is already specified
> in [`../gridworks-admin/executor/primary.md`](../gridworks-admin/executor/primary.md)
> and depends on mtls-fis-auth ([OPS-420](https://linear.app/gridworks/issue/OPS-420)).

## Why the LTN brokers it (the core decision)

The LTN is the SCADA's **parent GNode and "thinking half"** — already the single
writer of dispatch and mode to the SCADA (`RemoteControl`), and the party that
**holds the SLA** (whoever owns the LTN's financial choices). Routing all
application comms through it:

- keeps **one writer** of mode + dispatch + params to the SCADA — no second
  master racing the LTN;
- lets the LTN **reconcile** a customer's intent with its optimization, dispatch,
  and the live contract, rather than a web app poking the SCADA behind its back;
- keeps the **SLA coherent** — the LTN owner sees and mediates every customer
  intent.

A web frontend talking directly to the SCADA would split control authority and
undercut the SLA model. Direct web→SCADA control is reserved for the
admin/incident path, which deliberately suspends the SLA.

## The two legs and their trust

- **Web → LTN (cloud-side, HTTPS).** The LTN is cloud-side (gwbase). A web
  frontend calls the LTN's application API over HTTPS with a **customer /
  fleet-owner identity** (web SSO / API token) — a different identity model from
  operator certs. **This leg does not need broker mTLS**, so it can ship on the
  LTN's own API auth before the mtls-fis plane lands.
- **LTN → SCADA (prod broker).** The LTN already reaches the SCADA as its parent
  over the prod broker (the dispatch contract / link). Application commands ride
  this existing path; the SCADA accepts mode / param / preference commands **from
  its LTN** (its authenticated parent). This leg hardens under mtls-fis-auth
  ([OPS-420](https://linear.app/gridworks/issue/OPS-420)) when that lands, but
  starts on the existing contract.

So this design's prerequisites are **light** next to the admin path: the LTN's app
API plus new LTN↔SCADA message types, not operator certs or an admin gateway.
That is why it can land sooner.

## What flows through (scope)

1. **`SystemMode` / posture change at runtime.** Today posture is **static** —
   read from `settings.system_mode` at boot, so a switch is a **restart**
   ([`../gridworks-scada/executor/primary.md`](../gridworks-scada/executor/primary.md)).
   Add a **runtime mode-change command** (LTN→SCADA) so a house moves
   Heating↔Standby without restarting. The maple post-mortem
   ([OPS-393](https://linear.app/gridworks/issue/OPS-393)) exposed the
   mode-authority gap; the capability surface
   ([OPS-394](https://linear.app/gridworks/issue/OPS-394)) is the SCADA-side seam
   this rides.
2. **Control parameters.** Today HaParams / flo-params change via code + redeploy
   or `layout.lite` version bumps. Split them:
   - **Optimizer params (flo)** live **LTN-side** (private `gridworks-innovations`);
     changing them is an LTN-side re-parameterization — the web app sets them on
     the LTN, no SCADA message needed.
   - **SCADA control params** that affect on-device behavior need a **runtime
     param-update** LTN→SCADA, instead of a layout bump.
3. **Thermostat-style preferences (later).** Customer comfort intent → LTN; the
   LTN **translates** it into dispatch / contract terms (it is the thinking half).
   The house stays in `Auto`.

## Web-frontend auth (the passkey ceremony)

The web frontend's auth — the **WebAuthn/passkey ceremony** — is built here (it is
the web-frontend tier), **FIS-ready** so it lands before FIS: registration stores
`(principal → credential public key)` in a **pluggable principal store** (stub now,
FIS later), and `verify(assertion)` becomes the FIS call later — both interfaces,
so wiring FIS is a swap.

- **Authority scales with impact.** A session may carry a low-impact comfort
  preference, but a **high-impact command (mode / control-param change) requires a
  fresh hardware-bound assertion** — a web login alone is never enough to drive
  control (cross-cutting invariant: mtls-fis-auth,
  [OPS-420](https://linear.app/gridworks/issue/OPS-420)).
- **SCADA-local safety backstop.** Independent of auth: the SCADA's local safety
  floors (freeze protection, max-SWT, …) hold **regardless of any remote command**,
  so a bad or spoofed LTN message cannot endanger a house. The SCADA acts on behalf
  of the customer, not whoever sent the message.
- **Phasing.** The low-impact read/preference surface can ship first; the ceremony
  gates the high-impact commands. The admin half
  ([OPS-429](https://linear.app/gridworks/issue/OPS-429)) reuses this ceremony for
  operator principals.

## What does not come here

Incident-mode operator control of actuators is the **parallel** `gridworks-admin`
path: broker-mTLS + FIS, TopState `Auto→Admin`, SLA suspended. A web admin
controlling relays **depends on mtls-fis-auth**
([OPS-420](https://linear.app/gridworks/issue/OPS-420)) and is **not** allowed
over the weak password-only broker path. It does not ride this LTN-brokered
surface; track its implementation separately.

## Open

- The **LTN↔fleet AMQP protocol** is still Open
  ([`../gridworks-ltn/executor/primary.md`](../gridworks-ltn/executor/primary.md)
  §8) — this design defines part of it (the app-comms message types: mode-change,
  param-update).
- **Runtime mode-change** needs the SCADA to apply posture without restart-
  rebuilding the LocalControl tree — scope with the capability work
  ([OPS-394](https://linear.app/gridworks/issue/OPS-394)).
- **Customer / fleet-owner identity model** for the web→LTN leg (SSO vs token;
  per-home authz) — distinct from operator certs (see the passkey ceremony above).
- Whether the web frontend calls the LTN directly or via an **app-gateway** tier
  (mirrors the admin-gateway pattern, but with customer identity).
