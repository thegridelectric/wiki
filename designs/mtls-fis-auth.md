# mTLS + FIS auth

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-420

**EDD: yes** verified by a real SCADA proving identity to the prod broker with a
client certificate and FIS authorizing it (and denying an unknown/suspended
cert) — not code review.

> What this is: move the production broker from password auth to **certificate-
> based mutual TLS**, with the **Fleet Index Service (FIS)** as the authorization
> authority. A 2026-summer goal. Cross-cutting — it spans **rmqbot** (the broker
> conf), **FIS** (the principal model), and **provisioning** (client certs).

## The target

- **mTLS for every prod-broker connection.** The cert subject (`CN=<service_alias>`)
  is the identity; the broker delegates authorization to FIS over HTTP
  (`rabbitmq-auth-backend-http` → `/auth/{user,vhost,resource}`).
- **One FIS path for GNodes and services.** The connect handshake carries
  `ServiceAlias` + `ServiceInstanceId` always, and `GNodeClass` iff the principal
  is a GNode; FIS enforces single-writer per `GNodeId` for GNodes and a static
  grant for services (FIS principal-model).
- **Trustworthy publisher identity.** Run the broker's `validated-user-id` plugin
  so `properties.user_id` on every publish must match the connection's
  authenticated cert subject — the basis for audit attribution.

## Gateway boundary — a web login is not enough

Certificates onto the prod broker are GridWorks' **single core security mechanism,
by design.** A web gateway that bridges a browser session onto the broker (admin —
[OPS-429](https://linear.app/gridworks/issue/OPS-429); customer app-comms —
[OPS-408](https://linear.app/gridworks/issue/OPS-408)) **SHALL NOT** collapse that
to the strength of a web session. A login (password / OIDC session) alone is never
authority to issue a control command:

- the human presents a **phishing-resistant, hardware-bound credential**
  (WebAuthn/FIDO2 passkey) registered to their FIS Principal — not a password or
  bearer token;
- **high-impact commands require a fresh step-up assertion**; a stolen session
  cannot actuate;
- the gateway **forwards** that assertion to FIS and holds **no standing
  authority** to issue commands on a session's behalf — it is a transport bridge,
  not an authority;
- authority **scales with impact** (read < low-impact preference < mode change <
  relay/actuator) — the strongest proof gates the strongest action.

## The design work — pin these three open dimensions

These are why it was an exploration; turning it into a design means settling them:

- **Cert lifecycle** for per-SCADA client certs — issue / rotate / revoke. Likely
  mirrors the GNode path (FIS-issued, or FIS-via-certbot), minted by provisioning
  alongside the `principal` row.
- **FIS ↔ broker wire format** — the exact `auth-backend-http` request/response
  (principal-model half-specs it; pin it).
- **N-home cutover** — old 3.9-era SCADAs may not speak mTLS cleanly; sequence the
  migration across homes without a flag day.

## Domain split

- **rmqbot** — broker conf: require + verify client certs, the `auth-backend-http`
  endpoint, the `validated-user-id` plugin; the one parameterized broker conf
  (the broker conf parameterization folds in here for the TLS/auth-backend era).
- **FIS** — the `principal` table + `/auth/*` endpoints + the handshake; this is
  the authoritative auth spec (FIS `principal-model`).
- **provisioning** — mint client cert + `principal` row for both GNode and
  service kinds.

## Done-when

- A SCADA connects to the prod broker with its client cert; FIS returns allow;
  an unknown or `suspended` cert is denied.
- A publish carries a `user_id` the broker validates against the cert subject.
