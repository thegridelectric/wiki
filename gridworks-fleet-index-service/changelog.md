# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-fleet-index-service` code repo**. The matching git commit
holds the WHAT (the diff). Each entry's date and one-line title
mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

<!-- pending commit -->
## 2026-09-05 — gate.py docstrings: drop two build-time notes

Two docstrings in `gate.py` still described the build as it stood in
August: one said the executor spec's JSON response mapping "needs
correcting" (it was corrected then, and code does not cite wiki state),
the other said `GateReason` would be retired when the auth event shipped
(it shipped, and the enum stays because it also names the per-publish
verdicts, which have no event). Both now state what is.

---

## 2026-09-05 — The claimed run reaches `/auth/vhost` as the connection's user tag (`41cac52`)

Closes Finding B from the dev battery. The broker's HTTP backend never
sends a connection's claims and its vhost in one request (AMQP picks the
vhost at Connection.Open, after SASL), so `/auth/vhost` had been answered
from the lease table: "does this principal hold an Active lease on the
opened vhost". That inference is wrong exactly when the identity is
legitimately live there, and a second connection that claimed another run
opened the vhost anyway. The backend does carry one piece of
per-connection state from the user verdict to every later call: the tags
after `allow` become the connection's `#auth_user` tags and ride the
vhost, resource, and topic requests as `tags`. So `/auth/user` now answers
`allow <run>`, and `/auth/vhost` compares that tag to the vhost, no lease
lookup. The tag is the run, not the instance id, because the broker
interns each distinct tag as an atom and runs are a bounded set. The
battery's `run_claim_vs_vhost_with_live_lease` line is promoted from
KNOWN-GAP to a scored deny.

## 2026-09-05 — Supersession kill closes by username and confirms through the broker's tracking table (`4d7e6d6`)

Closes Finding A from the dev battery (single-writer, invariant 1). The
kill no longer enumerates the predecessor's connections through the
management listing: it issues one `DELETE /api/connections/username/<id>`,
which the broker applies to live state, so a connection younger than the
last stats tick is closed too. The confirm no longer reads the listing
either: it polls `GET /api/connections/username/<id>`, which the broker
serves from its connection-tracking table (the same table the close acts
on), until the identity holds no connection, and the gate fails closed on
the confirm budget. Two confirms were tried and measured on the way:
`rabbitmqctl list_connections` deadlocked with the gate (it asks every
reader for its info, and the successor's own reader is blocked
mid-handshake on FIS: 6.5 s against an 8 s auth hang), and `rabbitmqctl
eval` on the tracking table answered in 0.4 s but boots an Erlang VM per
call, so the 100-connection storm pushed every connect past 9 s of the
10 s handshake; the by-username GET is the same table in milliseconds and
needs no box wiring. The close is two-phase: the broker waits for the
client's close-ok before dropping a closed reader, so a predecessor that
never answers (the battery's idle client, or a wedged actor) stays tracked
until the broker's 30 s close timeout; a second close on a reader already
closing forces it down at once, so the kill gives a 1 s grace, closes
again, then confirms. Even forced, a reader whose peer is not reading
lingers 5 s in the TLS socket close (OTP's close_notify wait), so the
confirm budget defaults to 8 s. The kill is broker-wide for the identity,
exact while a broker hosts one run; the dev battery witnesses the
over-reach on its `d1__2` leg and logs it as a known limit.
`template.env` now documents the management credentials FIS always
needed. The reconvergence flush uses the same close-by-username. Unit
tests cover the killer against a mock management API. The test fixture
disables testcontainers' ryuk sidecar and asks for the `psycopg` driver:
on this machine ryuk could not mount the Docker socket and the default
URL named `psycopg2`, so all 48 database tests had been skipping
silently.

## 2026-09-05 — First real-broker run: form parsing, AMQP service principals, supersession-confirm mitigation (`7280642`)

The dev-universe gate battery
(`experiments/2026-09-05-fis-gate-battery/`) is the first time FIS ran
against a real broker + the rmqbot gate overlay rather than the
in-process handlers. Three code changes it forced, all invisible to the
handler tests (which drive the endpoints directly and use a fake killer):

- Every connect answered 500: `rabbitmq_auth_backend_http` POSTs its
  params form-encoded, and Starlette's `request.form()` needs
  `python-multipart`, never a declared dependency. Added at runtime.
- Every service principal was denied `NotInRegistry` over AMQP: the
  registry alias/class check ran for every AMQP claim, but a service has
  no registry row (its claims carry no `GNodeClass`, the GNode
  discriminator). The check is now gated on the principal's kind; a new
  test connects a service principal over AMQP.
- The supersession confirm-empty step now polls the management listing
  briefly instead of reading it once, so a just-deleted connection that
  lingers in the listing does not immediately read as unconfirmed.

The battery also surfaced a defect this commit does **not** close: the
kill both enumerates and confirms through the management HTTP listing,
which is stats-DB-backed and not real-time, so supersession is neither
safe (a just-connected predecessor is unlisted and survives) nor
reliable (removal lag denies a clean restart). The fix is a design
decision tracked in OPS-422; the confirm poll above is only a partial
mitigation. See the experiment and the design's "Open findings".

## 2026-09-04 — fis words now staging; fis records every connect-gate verdict (`682547d`)

Step 6: FIS records a `fis.instance.authorization.event` after every
`/auth/user` verdict, allow and deny alike, into its own `auth_events`
table (bijective with the word), written from a background task so the
gate carries no second synchronous write. The word and its two enums
(`fis.authorization.reason`, `fis.authorization.decision`, with the
reason→decision projection and axiom) were authored and flipped
`draft → staging` so FIS v1 can vendor them; the record keys on the
`PrincipalId` (not a GNodeId) and requires `Run`. The sink is FIS's own
Postgres because FIS joins no broker; the fleet store draining it through
a read façade stays Open.

## 2026-09-04 — Mirror seam: pull from gnr over HTTP; mint principal rows before certs (`0e2d856`)

Step 5b (mirror seam, phase A) and 5d (principal minting). `gnr_client`
reads the registry's public read façade over httpx, every reply decoded
strictly through the snapshot codec; a FastAPI-lifespan reconcile loop
boot-seeds the mirror and re-pulls on `FIS_GNR_RECONCILE_S`, and
`decide_user` reads through on a mirror miss so a freshly provisioned
node is admitted on its first connect. gnr unreachable → serve the
last-known mirror. `fis principal create|list|suspend|activate` mints the
row first and prints its id (the cert CN), so a CN is never a hand-picked
UUID a row is back-filled to match: a service mints a fresh uuid4, a
GNode's id is its GNodeId.

## 2026-08-23 — sema improvements: regen script and minimum-cover seed (`4929947`)

Tooling around the vendored snapshot: `scripts/regen_sema_snapshot.sh`
regenerates it from `src/fis/sema_seed_request.yaml`, and the seed is
trimmed to a minimum cover — the words FIS actually consumes plus their
dependency closure — so the snapshot carries no dead vocabulary.

## 2026-08-17 — FIS off rabbit (`e1c99ce`)

Step 5: the mirror-apply path and the reconvergence kill, both off the
message bus. `mirror.apply_gnode` upserts a `g.node.gt`, detects a rename,
and flushes the identity; the connection kill (`rabbit_admin`) closes an
identity's connections so the per-connection topic-verdict cache flushes
with them. Deliberately not an AMQP actor — FIS reaches the broker only
through its management API, and otherwise talks to its own Postgres.

## 2026-08-16 — Add /auth/{vhost,resource,topic} (`943c4d9`)

Step 4: the remaining broker auth paths. vhost cross-checks the claimed
run against the vhost opened (else deny); resource is v1 allow-all; topic
write pins routing-key segment 2 to the connection identity's wire-form
current alias, and topic read is allowed.

## 2026-08-16 — Build the /auth/user gate (`8fcd779`)

Step 3: the five-verdict gate. malformed / unknown / suspended → deny;
instance matches the active lease → allow; previously revoked → deny
forever; never-seen → synchronous supersession before responding (revoke
the prior lease, close its connections, confirm none remain, create the
lease, allow; unconfirmable → deny, fail closed). Claims decode strictly
through the snapshot codec; for an AMQP GNode the claimed alias and class
must match the registry mirror.

## 2026-08-14 — Vendor the sema snapshot and build the schema (`5040613`)

Step 2: the vendored sema snapshot (codec plus the claims word,
`g.node.gt`, the lease row, the forest words the mirror seam consumes,
and their enums and formats) and the FIS Postgres schema behind an
alembic baseline — the `g_node` mirror, the `principal` table (keyed on
cert subject), and the `lease` table keyed (principal, run) with
single-writer enforced as a partial unique index. Vendored before the
first consumer line, per sema-at-every-boundary.

## 2026-08-14 — Scaffold the service (`5f7bb51`)

Step 1 of the build: FastAPI + Postgres + `uv`, mirroring the
grid-node-registry stack so the two authority-plane services are one
shape to operate — same layout, same `ci.sh` gate, same
`pydantic-settings` pattern under the service's own `FIS_` prefix.

`universe` is validated at boot for shape and kind letter. A FIS
instance is scoped to one universe: its `g_node` mirror is a bijection
with one registry, and a registry serves exactly one universe. Runs
partition *inside* that scope — the lease key is (principal, run) — so
one FIS serves every run its broker hosts.

No sema consumer lines yet: the snapshot is vendored before the db
models land, which is the first code that means anything in sema terms.

## 2026-03-04 — Initial commit (`4686986`)

**What:** Repo genesis — `.gitignore` (standard Python ignore set),
`LICENSE`, and a 2-line `README.md`. No application code yet.

**Why:** Stands the `gridworks-fleet-index-service` repository up as an
empty scaffold so subsequent work has a home. Logged only to mark the
repo's starting point; the first substantive code commit will carry the
real *why*.
