# rmqbot — the broker's authentication path

Status: Draft · Pass 0 · Updated 2026-08-14

Sub-spec of the rmqbot deployment spec — **start at
[`primary.md`](primary.md)**. This file holds what the broker can and cannot
carry into an authentication decision, and the one custom Erlang artifact
GridWorks runs. The authority that *answers* those calls is the Fleet Index
Service; its gate rules live in the FIS executor spec.

## What the broker forwards to an auth backend

Read from the rabbitmq-server and plugin source rather than assumed
(2026-08-14). These facts constrain every design that wants a client to say
something at connect time:

- **`rabbitmq_auth_backend_http` forwards, on `user_path`, `username` plus
  everything in `AuthProps`** — it filters only internals, sockets, and
  connection context (`extract_other_credentials/1`). The other paths send
  fixed fields; `topic_path` additionally carries the **`routing_key`** of
  every topic publish. Password "may be missing if e.g.
  rabbitmq-auth-mechanism-ssl is used" (plugin README).
- **The AMQP 0-9-1 reader never puts `client_properties` into `AuthProps`.**
  They are stored on the `#connection` record and emitted in the
  `connection_created` event — visible to the management API — but they are
  structurally isolated from authentication. Anything an authorization
  decision depends on therefore **cannot** travel this way; it can only be
  audit and reconciliation material.
- **The MQTT adapter builds `AuthProps = [{vhost, VHost}, {client_id,
  ClientId}, {password, Password}]`**, so an MQTT client's `client_id` does
  reach the backend at connect. MQTT 3.1.1 has no client_properties at all.
- **The stock `rabbit_auth_mechanism_ssl` (EXTERNAL) ignores the SASL
  response bytes entirely** and calls `check_user_login(Username, [])`; the
  username comes from the peer cert via `rabbit_ssl:peer_cert_auth_name/1`.

The consequence worth carrying: on AMQP the SASL response is the *only*
client-controlled channel that reaches an auth backend, and stock parts throw
it away. That is the entire reason the mechanism plugin below exists.

## The GridWorks mechanism plugin

A two-change fork of `rabbit_auth_mechanism_ssl`, and the only custom Erlang
in the system. It keeps the stock behavior — refuse when there is no usable
peer cert, derive the username from it (honoring `ssl_cert_login_from`) —
and instead of discarding the SASL response, passes it through **verbatim**
as a single `claims` `AuthProps` param. Everything downstream is stock: the
http backend forwards it unmodified.

The plugin **never parses the payload**. Claim evolution is therefore a
schema version on the wire, not a plugin rebuild — the property that keeps a
custom broker artifact from becoming a maintenance burden.

Source, build, and mount recipe:
`gridworks-infra/rmqbot/auth-mechanism/README.md`. It compiles **inside the
pinned broker image**, because a beam built against a different OTP major is
refused at load time and the symptom is a broker that boots healthy and
authenticates nobody. Rebuild whenever the image pin moves.

Alternatives considered: a custom auth *backend* sees the same `AuthProps`
and unlocks nothing; an upstream patch (reader appends `client_properties`
to `AuthProps`) is worth filing but not worth waiting on.

## MQTT is asymmetric, deliberately

MQTT's handshake has one client-controlled slot, so the instance identifier
rides `client_id` and there is no schema envelope. Two facts pin this:

- With `ssl_cert_login` the CONNECT password arrives as `{password, none}`
  and is filtered out, so it is not a second slot.
- An explicit username+password **takes priority over the cert-derived name**
  (`creds/3`). A live password user is therefore a **CN bypass**, which is
  why fleet password users are deleted as they migrate rather than merely
  left unused.

## Broker-side configuration of the gate

- **Chained backends** — `auth_backends.1 = internal`, `.2 = http`. The
  management UI (15671, HTTPS) and one break-glass account stay on internal
  permanently; every fleet principal authorizes through the http backend.
  This is a decision, not a deferral: an "internal loses all accounts"
  cutover costs the management UI and the break-glass path for no security
  gain.
- **No verdict caching on connect.** `rabbit_auth_backend_cache` is
  rejected: a cached allow for a just-revoked instance id would breach the
  single-writer invariant for the length of the TTL. The authority being
  reachable is a hard dependency, by design.
- **Topic authorization** fires `/auth/topic` on every topic publish,
  carrying the routing key — the hook the alias rule uses. Its verdicts
  **are** cached per (connection, exchange, routing key), which is accepted:
  authority latency is a boot cost, not a steady-state publish cost. The
  consequence is that a mid-connection registry change is invisible to
  cached keys, so a rename must **kill that identity's connections** to
  flush the cache; the reconnect re-runs every check.
- **`validated-user-id`** makes the broker enforce that `properties.user_id`
  on every publish matches the connection's authenticated identity — the
  basis for attributing a message to a sender.

## The authority is colocated on this box

FIS runs on the broker box with its own small Postgres. The decisive
argument is that **the broker box dying already takes the fabric with it**,
so colocation adds no new single point of failure, while a separate box
would create one: a live broker that can admit nobody because a different
box, or the path to it, is down. Colocation also makes the auth path
localhost, and broker and authority restart and recover as one unit — the
authority starts before (or with) the broker in the box's boot order, and
the rebuild runbook treats them as one.

One authority per broker box, scoped to that box's fabric(s). A staging box
runs its own, holding its own run's lease state; a different universe gets
its own registry, broker, and authority entirely.

The compound event — broker restart while the authority is down, so the
fleet is denied until it returns — is **designed behavior**, the
architecture keeping its own promise, not an outage bug.
