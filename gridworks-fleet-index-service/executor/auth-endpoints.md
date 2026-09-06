# FIS auth endpoints — the HTTP surface the broker calls

Status: Draft · Pass 0 · Updated 2026-09-05

> What this is: the contract of the four `rabbitmq_auth_backend_http`
> endpoints FIS serves, and the verdict each one returns. The hub
> ([`primary.md`](primary.md)) holds the invariants these enforce and how
> the claims reach FIS; this spoke is what a rebuild has to answer on the
> wire.

## HTTP contract

FIS listens on `FIS_API_HOST:FIS_API_PORT` (`127.0.0.1:8080`, localhost
because it is colocated with the broker). The broker calls four paths,
`/auth/user`, `/auth/vhost`, `/auth/resource`, `/auth/topic`, as a POST
of a form body (rmqbot pins `auth_http.http_method = post`); FIS also reads
the same names from a GET query string so either broker configuration
works. Every reply is HTTP 200 with a plain-text body: `deny`, `allow`,
or on the user path `allow <run>`. Any other status or body is an error
to the broker, which refuses the connection. Parameters, by path:

- **user**: `username` (the cert CN) and either `claims` (AMQP: the SASL
  response bytes, the JSON of a `fis.connect.claims`) or `client_id` +
  `vhost` (MQTT). The transport is discriminated by which is present.
- **vhost**: `username`, `vhost`, `ip`, `tags`.
- **resource**: `username`, `vhost`, `resource`, `name`, `permission`,
  `tags`. Not consulted in v1.
- **topic**: the resource parameters plus `routing_key`. On MQTT the
  routing key arrives slash-separated; FIS normalizes to dots before
  applying the rule.

Every sema payload is decoded strictly through the vendored snapshot
codec: a claims body that does not decode is malformed, never guessed at.

## `/auth/user` — the gate

- **Malformed or missing required claims** → deny. On MQTT, a `client_id`
  that is not a uuid4 is malformed.
- **Claimed run outside this FIS's universe** (`Run` does not start with
  `<universe>__`) → deny, before any lookup.
- **Principal not found or not `active`** → deny.
- **Instance id matches the (identity, run) active lease** → allow
  (idempotent reconnect).
- **Instance id previously revoked** → deny. Forever — revoked lease rows
  are permanent (a TTL cleanup would re-admit an old zombie).
- **Instance id never seen** (AMQP also: claimed alias/class must match the
  registry's current values — deny on mismatch) → supersession,
  synchronously, before responding: mark the prior lease revoked; close the
  identity's connections with one management-API call,
  `DELETE /api/connections/username/<principal-id>`; confirm through
  `GET /api/connections/username/<principal-id>` that **no connection
  remains for this identity** (an empty kill is success — every restart is
  a supersession and a clean stop leaves nothing to close); create the new
  lease ACTIVE; return allow. If the close is refused or the confirm does
  not land within its budget (`FIS_RABBIT_CONFIRM_S`) → deny, fail closed.
  If the lease insert loses to a concurrent boot of the same identity on
  the same run (the partial unique index refuses it) → deny; the loser
  retries on its next connect.

  **Why those two calls and not the management listing.** The listing
  (`GET /api/connections`) is served from the stats database, which lags
  by up to its collection interval: a predecessor younger than the last
  tick is unlisted, so a kill that enumerates through it misses the
  predecessor and admits a second live instance (invariant 1), and a
  just-closed connection lingers in it, so a clean restart reads as
  unconfirmed. The by-username close and the by-username view are both
  served from the broker's connection-tracking table, its own record of
  established connections: live, held in ETS, answered without asking any
  connection process (a connection mid-handshake, such as the successor
  itself, is neither counted nor consulted), and covering MQTT connections
  too. The listing gates no safety decision. The close is broker-wide for
  the identity, exact while a broker hosts one run; a broker that
  multiplexes runs would need a vhost-scoped close. The 204 from the close
  returns before the sockets are gone, which is why the confirm is a poll
  and a delayed admission is the accepted cost. The close is issued twice
  when needed: the broker sends `Connection.Close` and waits for the
  client's `Close-Ok` before tearing the reader down, so a wedged
  predecessor that never answers stays tracked (routing nothing) until the
  broker's 30 s close timeout, and a second close on a reader already
  closing forces it down at once. FIS gives the predecessor a short grace
  for its close-ok, closes again to force any straggler, then confirms.
  Even forced, a reader whose peer is not reading lingers about 5 s in
  the TLS socket close (OTP's wait for a close_notify that never comes),
  so the confirm budget is 8 s: a wedged predecessor's successor is
  admitted in one connect at about 6.5 s, a responsive one's in well
  under a second, and both stay inside the broker's 10 s handshake
  timeout.

Map: allow → the plain-text body `allow <run>` (the claimed run becomes the
connection's user tag, "How the claims arrive"); every deny → the
plain-text body `deny`. The stock `rabbitmq_auth_backend_http` backend
expects a text body, not JSON, and the protocol carries no hint channel
besides; none is needed, since every verdict is recorded as an auth event.

**A lease ends only by supersession.** There is no shutdown notification:
clean stop and crash are identical, and a decommissioned node's eternal
lease is inert (the gate denies on principal status regardless). Emergency
eviction is principal suspension + connection kill, independent of leases.
Instance liveness ("is one running *now*?") is deliberately out of the
gate — see
[`../explorations/g-node-instance-and-liveness.md`](../explorations/g-node-instance-and-liveness.md).

## `/auth/vhost`

Allow iff `tags` is exactly one word and it equals `vhost`. The tag is the
run this connection claimed at `/auth/user` (hub, "How the claims
arrive"), so this is the claimed-run ≟ vhost cross-check, decided per
connection with no lease lookup. gwbase derives `Run` from the vhost, so
an honest actor matches by construction; a client that claims one run and
opens another is denied even when its identity is already live on that
vhost.

## `/auth/resource`

v1: allow all. Exchange, queue and binding permissions are not a FIS
concern yet.

## `/auth/topic`

`permission: read` (every MQTT subscribe) → allow: authorization is about
authority, not visibility. `permission: write`, on a routing key with at
least two segments (fewer → deny):

- The connection's identity is a GNode in the mirror → allow iff segment 2
  (index 1) equals the identity's current alias in wire form (dots →
  hyphens). The alias is looked up per verdict; the broker caches the
  verdict per (connection, exchange, routing key), which is why a rename
  kills the connection (hub, "Registry changes force reconvergence").
- Not in the mirror but an `Active` **Service** principal → allow. A
  service has no registry alias to pin in v1; it is cert-authenticated
  platform infrastructure.
- Anything else → deny.

## Auth event

After responding, record the verdict as a
**`fis.instance.authorization.event`** (its `fis.authorization.reason`
carries one value per verdict path above; a projection fixes the
`fis.authorization.decision` each reason implies). Every outcome is
recorded, allow and deny alike. The sink is FIS's own `auth_events`
table, bijective with the word, since FIS joins no broker; the write rides
a background task after the response so the gate's latency is untouched.
**Open:** the fleet's persistent store does not yet see these records —
the path is a read (a façade endpoint the ear or a journal puller drains,
per the house API pattern), not a publish.
