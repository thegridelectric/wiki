# mTLS + FIS auth

Status: Draft · Pass 0 · Updated 2026-07-30 · Linear: OPS-420

**EDD: yes** verified by a real SCADA proving identity to the prod broker with a
client certificate and FIS authorizing it (and denying an unknown/suspended
cert) — not code review.

> What this is: move the production broker from password auth to **certificate-
> based mutual TLS**, with the **Fleet Index Service (FIS)** as the authorization
> authority. A 2026-summer goal. Cross-cutting — it spans **rmqbot** (the broker
> conf), **FIS** (the principal model), and **provisioning** (client certs).

## The target

- **mTLS for every prod-broker connection.** The cert subject is the **immutable
  identity**: for a GNode, `CN=<GNodeId>` (rabbit derives `username = GNodeId` from
  the CN — `gridworks-infra/authority/fleet-index-service/lifecycle.md`; FIS
  executor *Separation of identity and instance*). The **alias is a runtime claim**
  in `client_properties` (`g_node_alias`), checked against the registry's current
  alias — not part of the cert, so a rename never reissues it. The broker delegates
  authorization to FIS over HTTP (`rabbitmq-auth-backend-http` →
  `/auth/{user,vhost,resource}`).
- **One FIS path for GNodes and services.** The connect handshake carries
  `ServiceAlias` + `ServiceInstanceId` always, and `GNodeClass` iff the principal
  is a GNode; FIS enforces single-writer per `GNodeId` for GNodes and a static
  grant for services (FIS principal-model).
- **Trustworthy publisher identity.** Run the broker's `validated-user-id` plugin
  so `properties.user_id` on every publish must match the connection's
  authenticated cert subject — the basis for audit attribution.

## GNode identity binds the immutable `GNodeId` (from OPS-419)

The grid-node-registry standup ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
converged a contract this design owns. A GNode's **`alias` is mutable** (re-parent)
but its **`GNodeId` is immutable**, and the fleet routes by alias — so a renamed
node carries a stale alias until it is redeployed. Two requirements fall out:

- **For a GNode principal, identity binds the immutable `GNodeId`**, not the mutable
  alias — confirmed by the original infra source
  (`gridworks-infra/authority/fleet-index-service/lifecycle.md`: *"Cert CN =
  GNodeId"*) and the FIS executor spec. *The target* above is corrected to match
  (an earlier `CN=<service_alias>` reading was drift). A rename never reissues the
  cert; only the runtime `g_node_alias` claim changes.
- **FIS auth doubles as the rename-convergence backstop.** FIS resolves
  connection → `GNodeId`, looks up the registry's **current** alias, and **denies on
  mismatch**. A stale node cannot authorize, so it is forced to reconcile —
  convergence by authorization, not by message delivery (the registry's change
  broadcast is then best-effort, not load-bearing). The FIS deny is just the "stale"
  signal — it needs **no** rich payload. A renamed node is recovered by **provisioning
  redeploy** (provisioning reads the grid-node-registry's internal API and redeploys
  affected nodes on a topology change); the FIS deny is the observable backstop that
  catches any node provisioning missed. See OPS-419.

## Publish-time alias pinning

Connect-time auth proves who a client IS; nothing above ties the
**routing key's from-alias segment** — asserted per message — to that
identity. An authorized client could still publish keys wearing someone
else's alias. The closure is one FIS rule in machinery this design
already specifies: with RabbitMQ **topic authorization** enabled, the
broker's `/auth/resource` call carries the routing key on every topic
publish, and FIS enforces

> publish is authorized iff segment 2 of the routing key equals the
> wire-form (hyphenated) of the connection's verified current alias.

One rule covers all three transport grammars — `rj`, `rjb`, and `gw` all
put the from-alias at segment 2. The from-alias in every routing key
becomes broker-authenticated for every consumer at once: consumers do no
crypto and hold no identity state, they trust the broker (the one-authz-
layer principle). Together with `validated-user-id`, header and key
cannot disagree by construction — `user_id` is the connection's GNodeId,
and the key's from-alias is that GNodeId's current alias, both enforced
against the same connection. The alias ↔ GNodeId binding is the
registry's alias ledger, which FIS already consults at connect; this
rule extends the same lookup to publish-time.

Cost: the broker caches topic-auth verdicts per
connection/exchange/routing-key, and the fleet's set of distinct keys is
small — a handful of FIS calls per connection lifetime, accepted.

Until this lands, consumers that project current state from a specific
authority pin the sender app-side (e.g. a registry projection accepts
only its universe's `<universe>.gnr`, witnessing but not projecting
anything else) — correct under the honor-system broker today and
redundant-but-harmless once the broker enforces it.

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

## The on-ramp — notches 2–4 of the TLS ratchet

OPS-423 ships notch 1 (encryption-only TLS: fresh CA + broker cert, conf at
`verify_peer` with `fail_if_no_peer_cert = false` — client certs optional,
verified when presented). This design owns the remaining notches, which run
after the RabbitMQ 4.x upgrade (OPS-424):

2. **Client certs** — mint per-client certs and migrate actors one at a time;
   `verify_peer` checks each cert as it appears, so there is no flag day
   (this is the N-home cutover dimension below).
3. **Require certs** — `fail_if_no_peer_cert = true`: no valid cert, no
   connection. Passwords still do the login.
4. **Cert is the identity** — `rabbitmq_auth_mechanism_ssl`
   (`auth_mechanisms = EXTERNAL`, `mqtt.ssl_cert_login = true`): the CN
   becomes the username, each account loses its password, PLAIN is dropped,
   and the plaintext listeners 5672/1883 close. The management UI (15671)
   keeps password login over HTTPS.

Notches 3 and 4 may combine into one restart once every client presents a
cert and every CN has its passwordless user; written as separate notches,
handshake failures (TLS layer) stay distinguishable from auth failures
(CN→user mapping) on cutover day.

Notch 2 forces one naming question beyond the GNode story: the CN for
**non-GNode principals** (service principals — `analytics.ear.reader`,
web-backend's gateway). GNodes bind `CN=<GNodeId>`; services need an equally
immutable subject, presumably from the FIS principal row.

**Notch-2 pilot (beech): COMPLETE, 2026-07-17.** One house ran ahead of the
design as its feeding experiment. Beech presents a client cert with
CN = `19ee09df-80ba-437b-b6c1-1eebe9d34801` (the scada GNodeId; CA-2026;
expires 2028-06-06 per the summer-stagger leaf policy); the broker log shows
the plaintext 1883 connection closing and the same house accepted on 8883 —
encrypted, cert verified at the handshake, telemetry continuous through the
LTN. Findings for the rollout: stock `getkeys.py` cannot set the CN (mint
with `gwcert key add --common-name <GNodeId>` on certbot, getkeys
`--copy-only` for the transfer); the laptop rclone `certbot` remote needs
`key_use_agent = true` with the per-person ssh key; the proactor needed
nothing beyond `SCADA_GRIDWORKS_MQTT__TLS__USE_TLS=true` — port and cert
paths defaulted correctly. Per-house recipe: mint (with consent) → copy →
flip → restart → confirm the 8883 accept in the broker log.
**Fleet rollout waits for this design's grill and Accepted · Pass ≥ 1.**

## The design work — pin these three open dimensions

These are why it was an exploration; turning it into a design means settling them:

- **Cert lifecycle** for per-client certs — issue / rotate / revoke, with
  **renewal automation as the core of it** (certificates made by the agents
  themselves and signed centrally — `gridworks-infra/authority/certbot/README.md`
  names this as the next iteration). Lifetime policy carried in from OPS-423: 2 years
  while renewal is manual, expiries steered to summer and staggered so the
  fleet never shares an expiry cliff; once renewal is automatic, drop hard
  (90–180 days) — short-lived certs are also the practical revocation story,
  since no realistic CRL/OCSP distribution to the fleet exists. Likely
  mirrors the GNode path (FIS-issued, or FIS-via-certbot), minted by
  provisioning alongside the `principal` row.
- **FIS ↔ broker wire format** — the exact `auth-backend-http` request/response
  (principal-model half-specs it; pin it).
- **N-home cutover** — old 3.9-era SCADAs may not speak mTLS cleanly; sequence the
  migration across homes without a flag day.

## Domain split

- **rmqbot** — broker conf: require + verify client certs, the `auth-backend-http`
  endpoint, the `validated-user-id` plugin — extending the parameterized conf
  OPS-423 ships with the require-cert and auth-backend knobs.
- **FIS** — the `principal` table + `/auth/*` endpoints + the handshake; this is
  the authoritative auth spec (FIS `principal-model`).
- **provisioning** — mint client cert + `principal` row for both GNode and
  service kinds.

## Done-when

- A SCADA connects to the prod broker with its client cert; FIS returns allow;
  an unknown or `suspended` cert is denied.
- A publish carries a `user_id` the broker validates against the cert subject.
