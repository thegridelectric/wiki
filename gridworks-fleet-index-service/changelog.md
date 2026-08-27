# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-fleet-index-service` code repo**. The matching git commit
holds the WHAT (the diff). Each entry's date and one-line title
mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-08-23 — sema improvements - regen script and minimum-cover seed (`4929947`)

fis vendored its Sema snapshot with no seed or regen script in-repo. Adds
the standard `scripts/regen_sema_snapshot.sh` (`--allow-staged` while
`fis.connect.claims` stages) and a minimum-cover seed derived from the
snapshot's recorded worklist: `fis.connect.claims:000`, `g.node.forest:002`,
`g.node.forest.request:000`, `g.node.instance.gt:001` — `g.node.gt:006`
drops as a direct target because `g.node.forest:002` structurally declares
exactly that version, so closure delivers it (same for
`connectivity.edge.gt` and the enums). Versions stay explicitly pinned:
prod posture, no silent latest-chasing. The README gains the standard Sema
paragraph (canonical language + boundary-scoping sentence).

## 2026-08-16 — Mirror apply + reconvergence kill <!-- pending commit -->

Step 5. `mirror.apply_gnode` upserts one `g.node.gt` snapshot into the mirror
and, when the write is a rename (an alias change on an already-mirrored
identity), calls the killer to flush that identity's connections — the one
mirror update the per-connection `/auth/topic` verdict cache cannot see, so
the reconnect re-checks against the new alias. Insert, no-op, and non-alias
field changes touch no connection.

The killer grows a second method: `kill_identity` closes every connection for
a principal across all vhosts. Unlike supersession's `kill`, it is best-effort
— the reconnect re-authorizes, so a management-API failure is logged, not
fatal — and it is not confirmed-empty.

Kept apply as a pure function over (session, validated `GNodeGt`, injected
killer), unit-tested with a fake, matching the gate's shape. **Not built
here**: the transport that feeds `apply_gnode` from gnr's `g.node.forest`
broadcasts (the mirror seam, plus forest-level retirement/heal) — it is
unslotted in the design's build order and is its own unit. 5 tests.

## 2026-08-16 — Add `/auth/{vhost,resource,topic}` (`943c4d9`)

Step 4, the three remaining auth paths. **vhost** cross-checks the claimed
run against the vhost being opened: the run reached FIS in the claims at
`/auth/user` (which fires first) and was recorded as the lease's run, so an
Active lease for (principal, vhost) exists iff claimed-run == vhost. gwbase
derives `Run` from the vhost, so an honest actor matches by construction; a
hand-built client claiming a different run has no lease here and is denied.
**resource** is v1 allow-all. **topic** read is allowed (authority, not
visibility); topic write is the alias-pinning rule — the routing key's
from-alias segment must equal the wire-form (hyphenated) current alias of the
identity.

The from-alias sits at token 1 across all three grammars (rj/rjb/gw), read
from gwbase `transport_encoding.py` — token 0 is the category, token 1 the
LRH from-alias ("segment 2" of the grammar). MQTT slash-separated topics are
normalized to dots first, so one rule covers both surfaces.

v1 service-principal call, flagged for review: a non-GNode service principal
(CN = principal UUID, not in the registry mirror) has no registry alias to
pin, so its topic writes are allowed (it is cert-authenticated infra); a
username that is neither a GNode mirror row nor an active service principal is
denied. GNode principals — weather included — are mirror-backed and stay
alias-pinned. 12 tests cover the vhost cross-check,
the alias rule across rj/gw grammars and MQTT slashes, malformed keys, and
the service/unknown paths.

## 2026-08-16 — Build the `/auth/user` gate (`8fcd779`)

Step 3, the heart of the service. `gate.py` holds the decision as a pure
function over a DB session, a parsed request, and an injected
`ConnectionKiller`; `api.py` wires `/auth/user`; `rabbit_admin.py` is the
management-API kill. Splitting the decision from the broker call is what lets
every verdict run in the dev battery without a broker — the injected killer is
a fake there and the real `RabbitMgmtKiller` only on staging, the verification
that counts.

The five verdicts land in order: malformed (bad claims / non-uuid MQTT
client_id) → deny; principal missing or suspended → deny; matching active
lease → allow (idempotent reconnect); revoked instance → deny forever;
never-seen instance → synchronous supersession — revoke the prior lease, kill
its connections, confirm none remain (empty kill = success), create the new
lease, allow; unconfirmable kill → deny, fail closed, with the prior revoke
rolled back so the predecessor keeps its lease. AMQP additionally checks the
claimed alias/class against the registry mirror; MQTT defers the alias to
first-publish. A run outside this FIS's universe is refused up front.

**Response is plain text `allow`/`deny`, not JSON** — the stock
`rabbitmq_auth_backend_http` contract, read from source. The executor spec's
`{"result": "allow"}` mapping was corrected to match.

`httpx` moves to a runtime dependency (the killer uses it). 21 gate tests
against a real Postgres cover every verdict, ordered supersession, fail-closed,
and request parsing.

## 2026-08-14 — Vendor the sema snapshot and build the schema (`5040613`)

Step 2. The vendored snapshot carries five words: the lease row
(`g.node.instance.gt/001`), the mirror's word (`g.node.gt`), the two
forest words the mirror seam consumes, and the connect claims the gate
will decode. Built with `--allow-staged`, so it is a **dev-only**
snapshot — two words are still staging, which is correct while the build
runs on `d1` and is the reason `fis.connect.claims` must publish before
the staging box serves `hw1__2`.

Three tables. `g_nodes` and `leases` are bijective with their words and
carry `to_gt`/`from_gt`; `principals` is hand-built because **no sema
word covers the principal model** — the registry was searched, not
assumed, and a `fis.principal.gt` word retires the hand-building along
with the two hand-coded enums beside it.

The single-writer invariant is a **partial unique index** on
(principal_id, run) where status is Active, not just care in the gate.
The gate's sync-kill supersession is what keeps it satisfiable; the index
is what makes a bug in that path fail loudly instead of quietly admitting
two writers. Tests prove all three faces of run-scoping: a second Active
lease on the same run is rejected, the same identity holds Active leases
on `hw1__1` and `hw1__2` at once, and a revoked row never blocks its
successor.

Alembic reads `FIS_DB_URL` from the same Settings the service uses, so
the connection string has one home. The compose Postgres is on 5437 —
5435 is gnr's and 5436 is already taken by weather-forecast.

## 2026-08-14 — Default to the dev universe (`0c1ebb8`)

`FIS_UNIVERSE` and `FIS_DB_URL` now default to `d1` and the local
Postgres, so a fresh clone runs in the dev universe with no `.env` at
all. Dev is where the build is exercised first — the whole done-when
battery runs on `d1__1` against the local broker before any remote box —
and a required-field wall in front of the primary workflow is friction
paid on every run to guard a case that only arises on a deployed box.

The deployed case is covered where deployment already is: a prod or
staging box has an `.env`, and provisioning writes it. Note this differs
from grid-node-registry, which defaults `db_url` but requires
`universe`; FIS is the service run locally far more often, so the
ergonomic default is worth more here.

The universe is still validated for shape and kind letter, so a
malformed value fails at boot rather than mirroring nothing.

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
