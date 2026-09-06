# FIS mirror, database, CLI and configuration

Status: Draft · Pass 0 · Updated 2026-09-05

> What this is: everything FIS keeps and everything it is told: the
> registry mirror and how it stays current, the four tables, the
> vocabulary it speaks, the `fis` command, and the environment. The hub
> ([`primary.md`](primary.md)) holds the invariants these serve.

## Vocabulary

FIS speaks sema at every boundary. Its snapshot seeds five words, and the
generated classes are the only way an instance is built or read:

| Word | Version | Where it is used |
| --- | --- | --- |
| `fis.connect.claims` | 000 | the AMQP `claims` param at `/auth/user` |
| `g.node.instance.gt` | 001 | the lease row |
| `fis.instance.authorization.event` | 000 | the auth event row |
| `g.node.forest.request` | 000 | the reconcile pull |
| `g.node.forest` | 002 | the reconcile reply; carries `g.node.gt` 006, the mirror row |

## FIS db structure

FIS maintains its own `g_node` mirror table in **strict bijection with
`g.node.gt`** (no position_point table or foreign key). The mirror consumes
the registry over **HTTP, never gnr's Postgres and never rabbit** — FIS is a
pure HTTP service and joins no broker. Three inputs keep it current, all over
gnr's read façade:

- **Boot seed + periodic pull-reconcile.** FIS pulls the forest under its
  universe (`g.node.forest.request` with `Roots = [universe]` — the bare
  universe token is a valid root, and one FIS serves one universe) at
  startup, and re-pulls on an interval. The reconcile is the correctness
  backstop: it heals a mirror that missed an update. A mirrored id the pull
  does not carry is a registry anomaly to log, never a status to write: a
  registry node never vanishes, the mirror is bijective with `g.node.gt`,
  and absence grants no authority since the gate needs a live alias/class
  match.
- **gnr push, for immediacy. Open: not built.** The intended shape is a
  FIS mirror-update endpoint that gnr POSTs each change to, best-effort
  (it never blocks gnr, the authority, which is why the reconcile above
  must exist), so a rename converges without waiting for the next
  reconcile. It is a non-localhost ingress, so it is mTLS-authenticated to
  gnr's principal. Until it exists, convergence is bounded by the
  reconcile interval (`FIS_GNR_RECONCILE_S`, 300 s default).
- **Read-through on miss.** An auth for a GNodeId absent from the mirror (a
  freshly provisioned node connecting before its push/reconcile) is read
  through by id (`g-node-by-id`) on the spot and applied to the mirror
  before the alias/class check. A registry that does not know the id, or
  cannot be reached, admits nothing new.

gnr being down never stops auth: FIS serves from the last-known mirror. The
registry is run-agnostic — runs are a fabric/FIS concern. The `principal`
table keys on the cert subject (GNodeId for GNodes — no second id; principal
UUID for services); the lease table keys on (principal, run). Principal
rows are minted by `fis principal create` before the cert is cut, so the
CN is always a FIS-minted id, never a hand-picked UUID a row is back-filled
to match: `create` prints the id, and that id is the cert's common name. A
service principal's id is a fresh uuid4 minted here; a GNode principal's id
is its GNodeId, given. `list`, `suspend` and `activate` complete the
emergency eviction lever the gate honors. A row minted on one FIS database
is carried to the database that will gate the cert (staging, then prod) as
a record, not re-typed.

**Invariant 1 is enforced in the schema**, not only in the gate: a partial
unique index on (principal_id, run) where status is Active. Supersession is
what keeps that index satisfiable; the index is what makes a bug in the
supersession path fail loudly instead of admitting two writers. No sema word
covers the principal model yet, so that table alone is hand-built — a
`fis.principal.gt` word retires the hand-building.

## Tables

Four tables, three of them bijective with a word:

- `g_nodes` ↔ `g.node.gt`: the mirror. Primary key is the GNodeId.
- `principals`: hand-built (no word yet). `id` (the cert CN), `kind`
  (`GNode` | `Service`), `status` (`Active` | `Suspended`), optional
  `display_name`, `created_at`.
- `leases` ↔ `g.node.instance.gt`: primary key `g_node_instance_id`;
  `principal_id`, `run`, `status`, `transport`, `connected_at_unix_ms`,
  `revoked_at_unix_ms`. The partial unique index on (`principal_id`,
  `run`) where status is `Active` is invariant 1. The word is version
  `001` (`staging`), which carries `Run`: the lease is keyed (principal,
  run), so the run belongs in the row. `000` keys on GNodeId alone and
  does not upgrade, since a run cannot be recovered from a standalone
  instance.
- `auth_events` ↔ `fis.instance.authorization.event`: `event_id`,
  `principal_id`, `instance_id`, `run`, `alias`, `g_node_class`,
  `transport`, `decision`, `reason`, `decided_at_unix_ms`.

Schema changes are migrations (alembic), run up and down on a fresh
database before they land.

## Registry façade calls

Both over gnr's public read façade (`FIS_GNR_URL`, `http://localhost:8000`
in dev), every reply decoded strictly:

- `POST /gnr/g-node-forest-request` with a `g.node.forest.request` body,
  `Roots = [universe]`; the reply is a `g.node.forest`.
- `GET /gnr/g-node-by-id/<GNodeId>`; a 404 means the registry does not
  know the id.

A transport error or a non-200 other than that 404 is logged and treated
as "registry unreachable": the reconcile keeps the last mirror, the
read-through admits nothing new.

## The `fis` command

- `fis api`: run the HTTP surface. Boot seeds the mirror, then re-pulls
  every `FIS_GNR_RECONCILE_S`; neither waits on gnr.
- `fis principal create --kind GNode|Service [--g-node-id <id>]
  [--display-name <text>]`: mint the row and print its id, the cert CN.
  `--g-node-id` is required for a GNode and refused for a Service.
- `fis principal list`, `fis principal suspend <id>`,
  `fis principal activate <id>`.

## Configuration

Settings are environment variables with a `FIS_` prefix (pydantic
settings; a deployed box keeps them in its `.env`, never committed).
Defaults are the dev rig.

| Variable | Default | Meaning |
| --- | --- | --- |
| `FIS_UNIVERSE` | `d1` | the one universe this FIS serves; a run outside it is denied |
| `FIS_DB_URL` | local `fis-postgres` on 5437 | FIS's own Postgres |
| `FIS_API_HOST` / `FIS_API_PORT` | `127.0.0.1` / `8080` | where the broker reaches FIS |
| `FIS_RABBIT_MGMT_URL` | `http://localhost:15672` | the broker's management API, for the kill and its confirm |
| `FIS_RABBIT_MGMT_USER` / `FIS_RABBIT_MGMT_PASSWORD` | dev broker | an `internal`-backend user with the `administrator` tag (closing another user's connections needs it), one reason the internal backend stays chained |
| `FIS_RABBIT_CONFIRM_S` | `8.0` | the supersession confirm budget |
| `FIS_GNR_URL` | `http://localhost:8000` | gnr's read façade |
| `FIS_GNR_RECONCILE_S` | `300` | the pull-reconcile interval |
| `FIS_GNR_TIMEOUT_S` | `5.0` | per-call timeout to gnr |
