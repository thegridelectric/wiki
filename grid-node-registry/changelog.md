# Changelog

A reverse-chronological log of WHY we made each commit **in the
`grid-node-registry` code repo**. The matching git commit holds the WHAT
(the diff). Each entry's date and one-line title mirror the corresponding
code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki repo's
git history.

Newest at the top.

---

## 2026-08-05 — minor (`d8375e3`, jm/de-wiki-2)

**Why:** Repo files stand alone — the umbrella wiki is not visible to a
repo reader, so an error message citing `wiki/grid-node-registry` is a
dangling reference outside Jessica's checkout. The message already
carries its reason in place (the production stub list).

## 2026-07-29 — g.node.forest includes a send time (`c021791`)

**What:** on `jm/forest-send-time`. Vendored sema snapshot regenerated for
`g.node.forest/001`; the three forest assembly sites (`get_forest`, the
create and reparent broadcasts) stamp `SendTimeMs` via a `_send_time_ms()`
helper whose docstring records the invariant: always wall-clock — the
registry is a notary and is never simulated. Deprecated `datetime.utcnow`
replaced with timezone-aware `datetime.now(UTC)` across `db/models.py` (5
column defaults) and `db/alias_ledger.py`. New
`scripts/regen_sema_snapshot.sh`, instantiated from sema's
`template_regen_snapshot.sh`.

**Why:** first adopter of the sender-time standard (sema sender-time
design, OPS-472) — consumers projecting the forest gain an order-aware
guard input. The utcnow sweep clears the Python deprecation before it
bites.
**Verified:** suite 58 passed post-regen; ruff clean.

## 2026-07-24 — CLI addresses hw1.gnr (`f02b0ea`)

**What:** `gnr create`'s direct envelope targets
`to_alias=f"{universe}.gnr"` (was `.registry`); the Layer-2 tests' own
registry alias follows (`d1.gnr`).

**Why:** the service-alias rename was incomplete — the box answered as
`hw1.gnr` while the CLI still addressed `hw1.registry`, so the first
post-rename create entered `gnr_tx`, matched no queue binding, and died
unrouted. The failure mode was instructive: the seed ear (binding `#` on
the tap) captured the command anyway, so the audit saw a command with no
verdict and no apply — the archive recording a message the addressee
never received.
**Verified:** suite 58 green; the real proof is the next `gnr create`
applying with an ack.

## 2026-07-24 — gnregistrar alias + daily snapshot cadence (`d186466`)

**What:** the operator CLI's publisher alias becomes
`<universe>.gnregistrar` (was `.registrar` — two letters away from the
service's old `hw1.registry`, an invited confusion), and
`gnr-snapshot.timer` drops from hourly to daily (`OnUnitActiveSec=24h`).
Companion box-config change, not in this diff: `GNR_SERVICE_ALIAS` on the
gnr box goes `hw1.registry` → `hw1.gnr` — one registry among future
registries, named like its box, repo, and exchanges.

**Why:** naming and noise. The forest snapshot broadcast is anti-entropy
for subscribers, and no subscriber exists yet (gjk's projection is
unbuilt) — hourly was 24 near-identical forests a day into the seed
store's precious slice. Daily keeps the mechanism warm at one object a
day; revisit cadence when gjk consumes. On-change broadcasts are
unaffected.
**Verified:** gnr suite 58 passed; alias visible in the next
`gnr create`'s command keys; timer cadence visible on the box after
re-copy.

## 2026-07-21 — Minor adjustment (`b41f6f5`)

**What:** broker CA trust scoped to the CLI's own process —
`GNR_BROKER_CA_FILE` replaces the shell-wide `SSL_CERT_FILE` export in the
operator env template; `gnr create` sets the override just before its broker
connect.

**Why:** a shell-wide `SSL_CERT_FILE` poisons every other tool's TLS (the
env var replaces Python's default bundle — uv/pip fetches were failing in
the operator's shell against a bundle holding only the private CA).

## 2026-07-21 — add deploy script (`70c083f`)

**What:** `deploy.sh` — the one-word deploy: puts the box on the pushed tip
of **main** (hard reset = the clean-SHA guarantee; handles the dev→main
branch switch on first run), `uv sync --frozen`, restarts both services,
health-checks, prints the running SHA.

**Why:** deploys should be a script the operator runs, not hand-work — the
merge-to-main PR is the deploy decision, `./deploy.sh` is the go.

## 2026-07-21 — Typed write verdicts (ack/nack) + refusal no longer kills the channel (`a6d7f0d`)

**What:** the registry replies to every write command with a typed verdict,
direct to the sender — `g.node.cmd.ack` on apply, `g.node.cmd.nack` with the
verbatim reason on refusal — correlated by the content hash of the bytes as
published. The same change fixes the defect the first production refusal
exposed: `CreateError`/`ReparentError` escaping `process_message` tore down
the consume channel; refusals are now answers, not exceptions to die on.
`gnr create` waits on the verdict (instant ✗-with-reason; ~10s fallback to
the old poll against a pre-verdict registry) and keeps the API poll after an
ack as the visibility proof. Snapshot vendors the two new published words.
New Layer-2 experiment (`test_layer2_replies.py`): refused command → nack
with reason → same connection applies and acks the next valid command.

**Why:** fire-and-forget made refusals silence — a 20-second timeout with
the reason buried in the box journal — and each one cost a connection
bounce. Because verdicts ride the bus, the ear now captures every refusal
with its reason: the audit of the registry saying no, out loud.
**Verified:** suite 58 green including the new experiment.

## 2026-07-21 — Operator env template + pinned public CA for API polls (`bcf4c57`)

**What:** `template.operator.env` → gitignored `operator.env` (the
`template.env` idiom for the operator side): the four exports for writes
against the deployed registry (API base, hw1 AMQPS URL, `GNR_WRITE_PROOF`,
the CA file), sourced into the working shell. README gains the operator-setup
recipe; the secret's 1Password name is standardized as "Grid Node Registry
Write Proof".

**Why:** shareable team workflow — the template documents the shape, the
secrets ride 1Password, nothing sensitive can land in git.

Rides along, found by explaining `SSL_CERT_FILE`: the env var **replaces**
the process's default CA bundle, so `gnr create`'s HTTPS ✓-poll against the
API's Let's Encrypt cert would have failed whenever the broker CA was set.
`_api_get` now pins its own context to the public bundle (`certifi`, made an
explicit dependency) — the env var's scope shrinks to its one job, the
broker handshake. Verified positively: a 200 through the pinned context with
`SSL_CERT_FILE` set, and the control (default context) still failing.

## 2026-07-21 — gnrstatus alias (`4fc6779`)

**What:** `gnrstatus` — `systemctl status` over both services + the snapshot
timer, no pager. Read-only, so no sudoers change.

**Why:** the at-a-glance health check alongside start/stop/restart/log.

## 2026-07-21 — Box ergonomics: aliases + write-gate docs (`cd19145`)

**What:** `service/bash_aliases` — `gnrstart`/`gnrstop`/`gnrrestart`/`gnrlog`,
pure spelling over systemctl/tail, sourced from the box login's `.bashrc`
and paired with the narrow `/etc/sudoers.d/gnr` grant (exact-argument
NOPASSWD on the gnr units only; the drop-in lives on the box). README gains
the write-proof-gate prose (was only a template.env comment).

**Why:** the scada-style ergonomics without reviving wrapper scripts —
aliases carry no logic, so the flattened pattern holds (§8 amended to say
so).
**Verified:** on the box — passwordless restart through the exact grant,
aliases resolving in the login shell.

## 2026-07-21 — Update cli with dropdown etc (`6cd7a6d`)

**What:** bare `gnr create` becomes an interactive wizard: a GNodeClass menu
(the four physical classes + known Logical classes + free-form other),
**BaseGNodeClass inferred mechanically from g.node.gt axiom 1**, then
alias / display-name / GNodeId prompts with defaults; the arg form
`gnr create <alias> <GNodeClass> [--g-node-id …]` skips the prompts. Broker
connection rides the settings chain (.env locally; exported env wins for a
remote target).

**Why:** the operator flow is choose-class-then-name; the inference belongs
to the axiom, not a lookup table that can drift.
**Verified:** suite 57 green; wizard smoke-tested through to the publish
confirm.

## 2026-07-21 — Write-proof gate, reparent 001 snapshot, gnr create (`eb76383`)

**What:** stop-gap write authorization: `Settings.write_proof_sha256`
(`GNR_WRITE_PROOF_SHA256`) + `PostgresAuthority._check_proof` refusing any
create/re-parent whose `Proof` doesn't hash-match — before all other checks,
including the idempotent-replay short-circuit. Snapshot rebuilt on
`g.node.reparent.cmd/001` (the sema-side version adding optional Proof; 000
retired to `old_versions`). New `gnr create` operator command: existence
check via the read API, the node built Pending with a staged position, an
explicit publish confirm, then publish over the broker as
`<universe>.registrar` with the Proof from env or prompt (never an
argument), and a poll until the node appears. 5 new Layer-1 guardrail tests
(missing/wrong proof bounce atomically on both commands; correct proof
lands).

**Why:** anyone with fleet broker credentials could otherwise mint arbitrary
GNodes from the public schemas; the Proof field is the schemas' designed
authorization hook, and the hash-gate is its primitive form until mTLS+FIS
(OPS-420) makes identity the credential. The operator enters the fleet one
node at a time at their own cadence.
**Verified:** suite 57 green including the guardrails.

## 2026-07-20 — Published-words snapshot (drop --allow-staged) (`394fc7a`)

**What:** `build_gnr_snapshot.sh` drops `--allow-staged` (the comment now says
promote, never re-flag) and the snapshot is rebuilt from published words only:
the dev-only markers (`indexes/staging.yaml`, the banner README) disappear,
and the vendored registry carries `g.node.create.cmd/000: published`.

**Why:** staging words are dev-broker-only; the registry deploys to `hw1`.
With the sema-side promotion (sema repo, same day) every vendored word is
published — the word-status gate for the deploy is clear.
**Verified:** snapshot round-trip 7 samples OK; gnr suite 52 green.

## 2026-07-20 — Snapshot driver, adopter-grade README (`3bca4e1`)

**What:** `gnr snapshot` — a one-shot that broadcasts a `g.node.forest`
snapshot for every forest root (or the roots given) and exits — plus
`service/gnr-snapshot.timer`/`.service` (oneshot under the timer; cadence is
the timer file, per the flattened box pattern). README rewritten to
standalone-adopter grade from the executor (overview, universes, invariants,
one-prefix config, local dev, the public read API, service table); the stale
"Next steps" (retired edge-consistency invariant, finished steps) is gone.
`scratch.py` deleted (empty, untracked).

**Why:** the anti-entropy path needs a deploy-config cadence, not a sleep
loop inside the write-loop process; a repo README stands alone for a human
adopter.
**Verified:** suite 52 green on the branch; `gnr --help` shows the command.

## 2026-07-20 — Deterministic forest serialization (`6b47826`)

**What:** `get_forest` orders nodes by alias and edges by id.

**Why:** forest serialization is part of the durability contract — broadcasts
and replays compare byte-identically — and full-suite ordering during the
rebuild work exposed that the equality had held only by insertion-order luck.
Dev-bound regardless of the rebuild surface's holding pattern.
**Verified:** full suite 54 green, run twice for order-independence.

## 2026-07-20 — Rebuild replay core + CLI, JSONL feed (`2cabc1b`, on `jm/gnr-rebuild` — held off dev)

**What:** `gnr.rebuild` — replay a capture through the handler core (commands
re-apply, refusals re-refuse and are counted; every captured `g.node.forest`
is a checkpoint, paired FIFO with replay-produced broadcasts — bursts
interleave on a real bus — with current-state equality as the snapshot
fallback) — plus the `gnr rebuild <capture> [--wipe]` CLI (`--wipe` clears
`command_log` too, else idempotent replay short-circuits against wiped
state). Layer-1 test (wipe → replay → identical state, poisoned command
re-refusing) + the Layer-2 EDD experiment (a bare-ActorBase ear tap on a real
broker captures genesis + a re-parent → wipe → rebuild from the file alone →
identical validate-clean forest).

**Why:** the restore path is the registry's durability story and must be repo
code proven by experiment (executor *Durability*). The JSONL feed is
provisional, so this surface stays on the standup branch — off dev — until
OPS-457 (rebuild from the true persistent store, gated on the store's durable
backup + TaValidator activation) lands.
**Verified:** the same 54-green suite runs as the entry above.

## 2026-07-19 — README: running as a service (`78a2f62`)

**What:** the README's thin "Logs" section becomes "Running as a service" —
units, copy-not-symlink, the clean-pushed-SHA discipline, and the
process/logs table (matching the box's homedir README, seeded from
gridworks-infra `gnr/instance-README.md`).

**Why:** a repo README stands alone; someone landing here should see how the
service actually runs without the wiki.

## 2026-07-19 — systemd units for the box (`906983d`)

**What:** `service/gnr-rabbit.service` + `service/gnr-api.service` — the
flattened pattern (gridworks-base executor §8): venv binary invoked directly,
`User=gnr`, `WorkingDirectory` at the repo root so `.env` resolves,
`Restart=always`; copied to `/etc/systemd/system/` at box setup.

**Why:** units are versioned repo content, reviewed like code; the box carries
only copies of a pushed SHA.

## 2026-07-19 — Entry points, public sema-linked read API, active-position invariant (`f114ab9`, squashed)

**What:** real `gnr` CLI (`gnr rabbit` runs the write loop via a new runner;
`gnr api` runs the read façade under uvicorn) replacing the hello-world stub.
Settings for the deploy posture: `RabbitRunSettings` extends gwbase
`ServiceSettings` under the one `GNR_` prefix (broker URL + service alias +
required super/time-coordinator aliases, one `.env`) with
`service_name="gnr"` so actor logs land at
`~/.local/state/gridworks/gnr/log/<alias>.log`; `ApiRunSettings` binds
loopback; the dead `Settings.log_dir`/`log_level` knobs are deleted;
`gnr.db.session` builds its engine **lazily on first use** (a module-import
`Settings()` made even `gnr --help` demand a configured env). The read façade
is public-facing per the deploy decision: docstring corrected (was "internal
service API"), CORS-open middleware (read verbs only), routes returning the
sema types themselves (`response_model_exclude_none` — byte-identical to
`to_dict()`, pinned by the DB-free `test_api_wire.py`) so `/docs` shows real
sema schemas, and an OpenAPI post-pass deriving each schema's definition link
from its TypeName/Version (constant currently the public sema GitHub
`blob/dev` URL; flips to schemas.electricity.works when that host stands up).
New registry invariant **active physical ⇒ PositionPoint row held**
(`check_active_physical_have_position`, audit pass + write path; presence at
activation only — position content trust stays TaValidation's) with 5 DB-free
unit tests + a Layer-1 write-guardrail test (violating create bounces
atomically; Pending ingest posture lands). The dev universe gains `willow`, a
seventh home held Pending with its position staged (opaque id, no row) — the
seed exercises mixed status everywhere.

**Why:** the deploy step (populate-and-deploy spoke) needs the registry
runnable as services; until now only tests could construct `GnrRabbit`, and
the console script printed hello-world. Orchestration aliases are deployer
declarations, so they refuse to boot unconfigured rather than assume `d1`.
The box pattern is native systemd (canonized in gridworks-base executor
§8 service-deployment), so no image machinery entered the tree.
**Verified:** full suite 52 green including integration tiers.

## 2026-07-08 — Create accepts a Pending parent (fleet bootstrap) (`9ff7271` + test in `a799004`)

**What:** `apply_create`'s parent check widens from Active-only to
Pending-or-Active; new Layer-1 test (a Pending copper chain builds
parents-first; an Active child under a Pending parent is still rejected via
the parent-closed-active invariant).

**Why:** the fleet enters the deployed registry as `Pending` (activation comes
with the TaValidator / encryption work, which also adds GPS positions), so at
ingest the parent chain is itself Pending when children arrive.
**Verified:** full suite 42 passed.

## 2026-07-08 — Create command path, universe guardrails, edges reserved for non-tree copper (`13767e3`)

**What:** `AuthoritySource.apply_create` + `GnrRabbit` decode of the vendored
`g.node.create.cmd` (parent-first, ledger claim, command-log append, validate,
one transaction; idempotent replay; alias + universe pre-checks).
`Settings.universe` is REQUIRED — single lowercase word, kind letter `d`/`h`/`w`;
a `w…` universe refuses to boot while `PROD_STUBS` (Proof verification,
validation-cert plane, encrypted positions) stand. `validate_registry(session,
universe)` gains the universe-scope check. `connectivity_edges` is reserved for
**non-tree** copper: covering parent-child edges are no longer stored, a
re-parent touches zero edge rows, and the coverage check is replaced by
endpoint + no-tree-mirror rules; the dev seed inserts no edges. Snapshot
rebuilt `--allow-staged` (dev-only while the create word is staging). Tests
30 → 41: create path, loop-enters-as-non-tree-edge, stored-tree-edge rejected,
settings guard-rails; CI env gains `GNR_UNIVERSE`.

**Why:** three decisions of 2026-07-06/08. Edges: the alias hierarchy is the
spanning tree of the grid graph, loops WILL exist, and the table's one honest
job is the copper the tree cannot express — storing tree edges was redundancy
that needed its own policing (decision B; the loop tests are the executable
statement of how a loop occurs). Universe: a registry is scoped to one
universe, and the deployer must declare it — the config value is what every
money guard keys off. Create: populate requires rows born in `command_log`,
never raw SQL. **Verified:** 41 passed including Layers 1–2 against a real
Postgres + real broker.

## 2026-07-04 — Track gwbase 0.5.6 (`7cd46fa`)

**What:** `pyproject.toml` `gridworks-base>=0.5.5` → `>=0.5.6`; relocked.

**Why:** 0.5.6 carries the `gnrmic_tx → amq.topic` broadcast bridge (gnr's own
forest broadcasts reaching MQTT-native listeners) and the prod→hybrid definitions
rename; gnr's consumed API is unchanged. **Verified:** full suite 30 passed on 0.5.6.

## 2026-07-04 — README: crisp universe-kind ladder (`db7e8d4`)

**What:** the README's Universes section now states the kind ladder —
**dev = runs locally on a single computer (all comms through localhost brokers)**;
**hybrid = most flexible** (distributed, real+simulated mix, re-runnable
`hw1__n`); **production = Validation certs required** for Scadas/MarketMakers +
the only real money. Self-contained (READMEs stand alone).

**Why:** the crisper definitions canonized 2026-07-04; the authoritative
treatment lives in the wiki executor's *Universes* section — the README carries
the adopter-facing summary. **Verified:** doc-only.

## 2026-07-04 — Write-path hardening: collision pre-check + idempotent replay (`906bbd6`)

**What:** `apply_reparent` gains (1) an **alias-collision pre-check** —
before any mutation it computes the full target alias set (N + every rewritten
subtree alias, each with its intended owner) and checks the ledger; any target
permanently owned by a *different* GNodeId raises an explicit
`ReparentError("alias collision — …")` naming the collisions, instead of a raw
`AliasAlreadyOwned` abort mid-rewrite (which stays as defense-in-depth); and
(2) **idempotent replay** — a command whose content hash is already in the
`command_log` returns the affected subtree's current forest (success) instead of
an error, so an at-least-once retrier can't confuse "already applied" with
"rejected". Layer-1 tests updated (`test_reparent_replay_idempotent`; the
squatter test asserts the explicit collision message).

**Why:** the two write-path OFIs carried since the ledger + command-log work —
kind semantics for real writers before the populate/deploy step. **Verified:**
full suite 30 passed.

## 2026-07-04 — Root-keyed forest broadcasts + snapshot (radio_channel = audience-known alias) (`189ccad`)

**What:** `GnrRabbit` now publishes the re-parent's `g.node.forest` with
**`radio_channel = parent_alias(cmd.new_node.alias)`** — the deepest change-stable
ancestor (E), a proper prefix of every moved node's old alias, so every affected
listener's ancestor-binding set matches it. (Keying on N's *new* alias would reach
nobody: listeners bind prefixes of the aliases they knew.) `broadcast_topology` takes
the channel explicitly. The Layer-2 test's MarketMaker stub now binds the channel
**exact-match** (`radio_channel=keene`) and asserts the received envelope's channel —
an un-channeled binding would not match a channeled key, so the pass proves the
radio_channel path end to end. Also adds **`broadcast_snapshot(root)`** — the
snapshot case of the channel rule (nothing changed ⇒ channel = the current
alias): broadcasts `get_forest([root])` on `radio_channel = root`, the
anti-entropy / bootstrap-refresh path; cadence is deploy config. The Layer-2 test
gains a snapshot leg (same keene binding hears it; asserts the post-rename
subtree).

**Why:** the scalable passive-listening pattern — every GNode binds O(depth) ancestor
channels once, hears one bounded forest per relevant change, no polling; a subtree
monitor (FIS) binds one trailing-`#` per authority root. Channel rule + listener
pattern canonized in the executor and `explorations/root-keyed-forest-broadcasts.md`.
Needs no gwbase bump (radio_channel is long-standing envelope API); gwbase **0.5.6**
separately bridges `gnrmic_tx → amq.topic` so the MQTT side hears too. **Verified:**
Layer 2 green over a real broker with the channeled binding; full suite 30 passed.

## 2026-07-04 — CI: GitHub Actions runs the full layered suite (`0e893b5`)

**What:** `.github/workflows/tests.yml` — on push/PR, `uv sync --group dev --locked`
+ `pytest` on Python 3.12, with **Postgres 16** and the **dev-rabbit** broker as `services:`
containers. `GNR_TEST_PG_URL`/`GNR_TEST_RABBIT_URL` point the harness at them (the conftest
opt-in), so all 30 tests — Layer 0 unit **and** the Layer 1/2 + read-façade integration tiers —
run in CI rather than self-skipping.

**Why:** build step 6 — lock the layered harness in as a re-runnable gate (it's the evidence
behind any `Verified` stamp). Mirrors the gwbase house pattern (service containers + the baked
dev broker). Lint (ruff) is a recommended follow-up — gnr has no ruff config yet. **Verified:**
the same services shape (Postgres 5435 + `gw-dev-rabbit` d1__1) was already proven locally via
the `GNR_TEST_*` opt-in.

## 2026-07-04 — Squash migrations to one FK-free baseline; position_point_id is not an FK (`df6689b`)

**What:** `g_nodes.position_point_id` → a plain `UUID4Str` column, **dropping the
FK** to `position_points` (and the SQLAlchemy relationship). Collapsed the three incremental
Alembic migrations (initial → alias_assignment → command_log) into **one clean baseline**
(`a0b1c2d3e4f5_initial_schema`) reflecting the current model — gnr isn't deployed anywhere, so
nothing to migrate.

**Why:** the MVP launch populates `g_nodes` with an **open** API *before* the TaValidator work,
while home locations stay **private + encrypted**. `position_point_id` is the location's opaque
**identity** (carried in the command, satisfies axiom 2, leaks nothing); the **coordinate data**
is a separate, later, encrypted, TaValidator-owned artifact — so an enforced FK from gnr into a
table it write-only-populates-later is the wrong coupling. This lets `g_nodes` be populated with
`position_points` left empty. No sema change. Plan in
`explorations/positions-staging-and-encryption.md`. **Verified:** full suite 30 passed; the
squashed migration applies to a fresh DB and `alembic check` reports no diff vs the models.

## 2026-07-03 — HTTP read façade (forest + point lookups) (`2d7daf3`)

**What:** the read surface over the `AuthoritySource` core, in `gnr.api` (FastAPI),
routed by the house pattern `POST /<service>/<sema-type-with-hyphens>` where the body is a full
Sema type; scalar point lookups are the sanctioned GET exception:
- `POST /gnr/g-node-forest-request` → `g.node.forest` (`get_forest(roots)`: the subtree under
  each root alias + its internal edges) — FIS's authority-scoped bootstrap;
- `GET /gnr/g-node-by-id/{g_node_id}` → `g.node.gt` | 404;
- `GET /gnr/g-node-by-alias/{alias}` → `g.node.gt` | 404 — new `AuthoritySource.resolve_alias`
  resolves an alias **current or past**: a stale (renamed-away) alias returns the same GNode in
  its current form, so the caller detects staleness by queried-vs-returned `Alias` (leans on
  alias-uniqueness-through-time; the "when it retired" timestamp is deferred — not tracked, and
  the deny doesn't need it);
- `GET /ping`. Added `httpx` (dev) for the `TestClient`; `tests/test_read_facade.py`.

**Why:** the read surface FIS actually consults — it bootstraps its authority-scoped
`GNodeId ↔ alias` map from a forest query, resolves possibly-stale aliases via the by-alias
lookup, and rides `g.node.forest` broadcasts for deltas; provisioning + analytics use the same
queries. Thin twin of the `GnrRabbit` write adapter over the same core. **Verified:** full suite
30 passed (5 read-façade tests, incl. stale-alias resolution after a rename).

## 2026-07-03 — Distributed-readiness: deterministic ids + append-only command_log (`e95c854`)

**What:** new `gnr.ids` (`deterministic_uuid4`, `edge_id`, `command_hash` — internal hash salts,
slash-delimited so they can't be read as Sema names). `apply_reparent` now (#1) derives edge ids
from their endpoints (`edge_id`) instead of `uuid.uuid4()` — the ids serialize into
`g.node.forest`, i.e. authoritative state — and (#2) appends every applied command to a new
append-only **`CommandLogSql`** (`command_log` table + Alembic migration), content-addressed by
`command_hash`, with a **replay guard** (a command already in the log is rejected). The dev
universe is now fully deterministic (node/position/edge ids all derived, no `uuid.uuid4()`). Two
Layer-1 tests: deterministic edges + command logged, and replay rejected.

**Why:** distributed-readiness #1/#2 (executor *Distributed-readiness*) — a pure
`(state, command) → state'` + the command log as the primitive make the eventual chain swap a
swap, and pay off now (reproducible state, audit history, replay safety). The content-address
stays gnr-internal, **not** a Sema format: transaction hashes are chain-specific (Algorand
SHA-512/256/base32 vs Ethereum Keccak-256/hex), so the public form is the chosen chain's
machinery, behind the `AuthoritySource` seam (see the content-address exploration). **Verified:**
full suite 25 passed.

## 2026-07-03 — Vendor the forest words; broadcast g.node.forest (retire topology.broadcast) (`15bb75e`)

**What:** re-vendored the Sema snapshot off `jm/sim-vocab` — `gnr_seed_request.yaml`
swaps `g.node.topology.broadcast` for `g.node.forest` + `g.node.forest.request`, and
`g.node.gt` is now **v005** (axiom 6, ≥2-word alias). Regenerated `src/gnr/sema/`
(`GNodeForest`, `GNodeForestRequest`, `g.node.gt/005` + `old_versions/g_node_gt_004`;
`topology.broadcast` dropped). `apply_reparent` now returns a **`GNodeForest`** (roots =
[N.alias], nodes = the updated subtree, edges = the created E→N / N→child edges);
`GnrRabbit.broadcast_topology` publishes it; the Layer-1/2 tests assert on the forest.

**Why:** the forest is the registry's one reusable topology payload (broadcast / snapshot /
read-response) and the scaling unit (see executor *Write path & egress*). **Verified:** full
suite 23 passed — Layer 2 publishes a `g.node.forest` over a real broker and the DB reflects
the recursive rewrite. NB the vendored snapshot tracks `jm/sim-vocab` (the words are not yet
on sema `dev`); re-vendor when that merges.

## 2026-07-03 — dev_universe + validate cleanup: static forest, services, sema format typing (`8aecfd2`)

**What:**
- **`gnr.dev_universe`** — dropped the `tlayouts` dependency + `PROD_UNIVERSE`/`_to_dev`;
  the dev universe is now a static `alias -> (base_class, g_node_class)` map. Dropped the
  `d1` root GNode (the universe token is a **namespace, not a GNode**); `d1.isone` is now a
  **forest root**. Added three Logical simulation services — `d1.time` (TimeCoordinator),
  `d1.isone.me.weather` (WeatherForecastService), `d1.isone.me.price` (PriceForecastService).
  Distinct **deterministic oceanic** `PositionPoint`s per physical node (SHA-256 of the
  alias, uuid4-format id; ~32°N 40°W mid-Atlantic ridge — nowhere a home could be),
  replacing the single shared placeholder (a smell that also sat on plausible land, Maine).
- **`gnr.db.validate`** — `is_root` → **`is_forest_root`** (alias-parent is the bare universe
  token); `parent_alias` always returns a value; the three structural checks exempt forest
  roots (no parent GNode, no incoming edge), and a forest root may only be a CopperNode or a
  non-Scada Logical node.
- **Sema format typing** for the primitive references: `LeftRightDot` for every GNodeAlias
  and `UUID4Str` for every GNodeId (`g_node_id`, alias-ledger owners, `Violation.g_node_id`,
  `_det_uuid4` return) across `dev_universe`, `validate`, `authority`, `alias_ledger`,
  `gnr_rabbit` (SQLAlchemy `Mapped[str]` columns unchanged); `apply_reparent` now guards
  with `is_forest_root`.
- **README** canonizes "the universe segment is a namespace, not a GNode; every GNodeAlias has
  ≥2 words; the registry holds a forest of copper subtrees." Layer-0 fixtures updated + a new
  `test_leaf_or_ta_cannot_be_a_forest_root`.

**Why:** decouple the dev universe from the layout pipeline (being reworked elsewhere) and
canonize the forest/namespace model in code — the registry stores positions but enforces
nothing about them (location trust is TaValidation's, see
`explorations/position-point-semantics.md`). **Verified:** full suite 23 passed; the dev
universe (now with the three services, no `d1` root) loads `validate_registry`-clean; 16
physical nodes get 16 distinct ocean points.

## 2026-07-02 — Track gwbase 0.5.5 (`dbdc2b9`)

**What:** `pyproject.toml` `gridworks-base>=0.5.3` → `>=0.5.5`; relocked.

**Why:** stay on the current published gwbase. 0.5.5 forward-reverted the 0.5.4
`FleetIndexService` add (which gnr never needed — the FIS read path settled as HTTP +
a broadcast subscription), so 0.5.5 is functionally 0.5.3 for gnr's purposes; the bump
is hygiene, not a new capability. **Verified:** `uv sync` resolves 0.5.5 from PyPI,
full suite 22 passed.

## 2026-06-30 — Harness Layer 2: rabbit re-parent loop over a real broker (the EDD experiment) (`80694ef`)

**What:** added `tests/test_layer2_rabbit.py` (the EDD experiment — boot
`GnrRabbit` + a MarketMaker `Orchestrator` stub on a real RabbitMQ, seed the dev
universe into a real Postgres, publish a `g.node.reparent.cmd` **as a MarketMaker**,
and assert the `g.node.topology.broadcast` returns to a real subscriber **and** the
DB reflects the recursive beech-subtree rewrite). Extended `tests/conftest.py` with
the `rabbit_url` fixture (testcontainers `rabbitmq:3.13` by default; `GNR_TEST_RABBIT_URL`
opt-in; self-skip) and an autouse XDG-under-tmp redirect so the gwbase actors' loggers
stay out of `$HOME`. Added the `rabbitmq` testcontainers extra. The test provisions
the gwbase broker fabric from `gwbase.topology` (the `MarketMaker ⇄ GridNodeRegistry`
routing edges + the `gnr_tx`/`gnrmic_tx` pair are already in 0.5.3).

**Why:** the test-harness spoke's Layer 2 — the experiment that proves the whole
step-5 rabbit write loop end to end against reality (a real broker + the atomic
recursive subtree rewrite, the failure mode in-process mocks can't see). **Verified:**
green on a testcontainers RabbitMQ (~6.7s) and again via the `GNR_TEST_RABBIT_URL`
opt-in against the shared `gw-dev-rabbit` on its `d1__1` vhost (~0.55s); full suite
22 passed, unit-only deselects the 5 integration tests.

## 2026-06-30 — Harness Layer 1: AuthoritySource against a real Postgres (`7023969`)

**What:** added `tests/conftest.py` (the harness Postgres fixtures —
testcontainers `postgres:16` by default, an already-running Postgres via
`GNR_TEST_PG_URL` opt-in, self-skip when neither is available; schema via
`Base.metadata.create_all`) and `tests/test_layer1_postgres.py` (the `integration`
tier: seed the `d1` dev universe, assert `validate_registry`-clean, reads resolve
through `PostgresAuthority`, a re-parent of the beech home rewrites its whole
subtree — aliases + edges + ledger — atomically and leaves the registry valid,
and a generated-alias self-collision aborts the whole mutation). Added
`testcontainers[postgres]` to the dev group.

**Why:** the test-harness spoke's Layer 1 — the cheap, broker-free integration
tier beneath the Layer-2 rabbit experiment. Proves the seeded `AuthoritySource`
re-parent against a real Postgres (mocks pass where the atomic recursive subtree
rewrite fails). **Verified:** 4 integration tests green on a testcontainers
Postgres and again via the `GNR_TEST_PG_URL` opt-in against the dev-compose
Postgres on 5435; full suite 21 passed, unit-only run deselects the 4.

## 2026-06-30 — Depend on published gridworks-base 0.5.3 (drop editable path) (`39ffcd5`)

**What (planned):** in `pyproject.toml`, `gridworks-base` → `gridworks-base>=0.5.3`
and removed the `[tool.uv.sources]` editable path to `../gridworks-base`; relocked.

**Why:** the `GridNodeRegistry` transport class merged to gridworks-base `dev`/`main`
(PR #159) and published to PyPI as **0.5.3**, so gnr no longer needs the local
editable checkout — it must not ship depending on a path. **Verified:** `uv sync`
resolves 0.5.3 from PyPI, `GnrRabbit` imports, unit suite green (17).

## 2026-06-29 — Add rabbit transport adapter (GnrRabbit) (`1850f90`)

**What (planned):** `src/gnr/gnr_rabbit.py` — `GnrRabbit`, a thin gwbase
`Orchestrator` (transport class `GridNodeRegistry`) wrapping `AuthoritySource`:
`process_message` decodes a `g.node.reparent.cmd`, calls `apply_reparent`, and
broadcasts the resulting `g.node.topology.broadcast` on the registry's mic
exchange. Added `gridworks-base` as a dependency (editable path to the sibling
`../gridworks-base` so it carries the new `GridNodeRegistry` class).

**Why:** the design's rabbit adapter — one of the two thin transports over the
handler core (build step 5). First cut is the write loop (command in → broadcast
out); the read request/reply surface lands with its Sema request types. **Verified
so far:** imports + constructs against the branched gwbase; the live boot-and-
broadcast proof is harness Layer 2 (next). The read surface + the live Layer-2
experiment are the remaining step-5/6 work.

## 2026-06-29 — Dev-universe seed (mirror the fleet into d1) (`fcefa9d`)

**What (planned):** `src/gnr/dev_universe.py` — `build_dev_universe()` /
`seed_dev_universe(session)`: the copper-backbone parent chain
(`d1` · `d1.isone` MM · `d1.isone.me` CN · `d1.isone.me.versant` CN ·
`d1.isone.me.versant.keene` MM) plus each deployed home's LTN/Scada/TerminalAsset
read from sibling `tlayouts/output/*.uploaded.json`, re-aliased `hw1 → d1`, with
fresh GNodeIds and a shared placeholder PositionPoint, seeded with covering edges.
The `fir` layout lacks an LTN block, so its LTN alias is derived from the Scada
alias. Path overridable via `GNR_TLAYOUTS_DIR`.

**Why:** the dev-universe substrate for the harness (test-harness spoke) — a
production-shaped registry that never touches real money. **Verified:** seeds a
clean `validate_registry` against live Postgres.

## 2026-06-29 — DB-free unit tests + pytest setup (`99ca7e8`)

**What (planned):** added `pytest` (dev group) + `[tool.pytest.ini_options]`
(testpaths, an `integration` marker for the future DB/broker layers) and a
`tests/` suite that needs no infra — `test_g_node_naming.py` (axiom 5: `.ta`/`.scada`
suffix iff), `test_class_hierarchy.py` (CopperNode backbone, LTN/TA/Scada parent
rules), `test_reparent_rewrite.py` (the pure recursive prefix-rewrite). Extracted
the rewrite's pure core (`in_subtree`/`rewrite_alias`/`moved_child_new_prefix`/
`subtree_rewrite_map`) out of the session-coupled path in `authority.py` so it is
unit-testable.

**Why:** start the Layer-0 (unit, no-DB) tier of the dev-universe harness; the
naming + copper-sub-tree + reparent logic are pure and worth pinning before the
Postgres/broker layers. **Verified:** `pytest` green (17 passed).

## 2026-06-29 — Enforce Scada parent + CopperNode; bidirectional CopperNode SM (`78fcd92`)

**What (planned):** `gnr.db.validate` — named the `{ConnectivityNode, MarketMaker}`
set **`COPPER_CLASSES`** ("CopperNode" = the copper-topology backbone) and added the
**Scada parent rule** (a `g_node_class == "Scada"`, Logical-classed node must parent
a LeafTransactiveNode). `gnr.db.lifecycle` — the `base_class` SM now allows
**ConnectivityNode ⇄ MarketMaker both directions** (a constraint is relieved → an MM
demotes to a CN), per legacy Update Axiom 5. Plus a universe note in `README.md`.

**Why:** the GNode class rules Jessica named — the copper sub-tree is parent-closed,
a Scada hangs off its home LTN, and a CopperNode can lose its market role when grid
constraints relax. The `.ta`/`.scada` suffixes are already per-row `g.node.gt`
axiom 5, so they are not re-checked here. **Verified:** the new unit tests +
the live-Postgres validator proof both green.

## 2026-06-29 — Add transport-agnostic AuthoritySource handler core (`ef5a705`)

**What (planned):** `src/gnr/db/authority.py` — the `AuthoritySource` interface
(read by id/alias, `assert_active`, `fetch_edges`, `apply_reparent`) + a
`PostgresAuthority` implementation over `SessionLocal`. Sema types in/out
(`GNodeGt`, `ConnectivityEdgeGt`, `GNodeReparentCmd` → `GNodeTopologyBroadcast`).
The re-parent applies the recursive descendant alias rewrite + edge retire/create
+ alias-ledger claims + lifecycle, all in one transaction, and returns the
topology broadcast.

**Why:** build step 5 — the registry's logic lives in one transport-agnostic core
(the design's "one core, two thin adapters"); the rabbit consumer + FastAPI façade
are thin adapters that translate messages → these handlers. Building the core
first keeps it provable against Postgres before any transport. **Verified:**
against live Postgres (read/assert/edges; a re-parent rewrites a subtree and emits
the broadcast).

## 2026-06-29 — Vendor g.node.reparent.cmd + g.node.topology.broadcast into the snapshot (`ad6ead0`)

**What:** added `g.node.reparent.cmd` + `g.node.topology.broadcast` to
`gnr_seed_request.yaml` `initial_targets.types` (committed `3cb21c9`) and rebuilt
the vendored Sema snapshot (`build_gnr_snapshot.sh`), regenerating `src/gnr/sema/`
with the two new types' runtime classes (`g_node_reparent_cmd.py`,
`g_node_topology_broadcast.py`) + samples.

**Why:** build step 5 — the registry's runtime needs to decode/encode the
re-parent command and the topology broadcast. The words were released in `sema`
(branch `jm/gnr-commands`) so the snapshot could include them. **Verified:**
snapshot round-trip OK on all 5 samples, and both new types decode + re-encode
identically through gnr's codec (`GNodeReparentCmd`, `GNodeTopologyBroadcast`).

**What:** Added `src/gnr/db/lifecycle.py` — `check_status_transition` /
`check_base_class_transition` plus their `Illegal*Transition` errors and the
`ALLOWED_STATUS_TRANSITIONS` / `ALLOWED_BASE_CLASS_TRANSITIONS` maps. Pure
functions over the enums (no DB), to be called by the step-5 write handlers
before applying a status/class change.

**Why:** build step 4 — managed lifecycle. The status SM is legacy
`g-node-factory` Update Axiom 3 (`Pending→Active`, `Active→{Suspended,
PermanentlyDeactivated}`, `Suspended→{Active, PermanentlyDeactivated}`,
`PermanentlyDeactivated` terminal; identity is a no-op). The `base_class` SM is
the one sanctioned constrained-mutable upgrade `ConnectivityNode → MarketMaker`
(a CTN gaining authority to re-parent its sub-topology). **Verified:** pure-move
checks plus a live-Postgres apply path — a legal `Pending→Active` persists, and
an illegal `Active→Pending` is rejected with the row left unchanged.

## 2026-06-29 — Add whole-registry structural validator (`b18db84`)

**What:** Added `src/gnr/db/validate.py` — `validate_registry(session)` plus the
`Violation` record and three checks: `check_parent_closed_active` (active
non-root ⇒ active alias-parent), `check_edge_coverage` (active non-root ⇒ exactly
one active edge from its alias-parent), and `check_class_hierarchy` (parent class
legal for the node's class). Topology is derived from the dotted alias
(`parent_alias`).

**Why:** these are the registry's row-spanning invariants Sema can't express
per-row (build step 3). The class-hierarchy check is the new-class form of legacy
`g-node-factory` Creation Axiom 5 (ROLE), with the mapping `ConductorTopologyNode
→ ConnectivityNode`, `AtomicTNode`/`AtomicMeteringNode → LeafTransactiveNode`,
`Scada`/`Other → Logical` (confirmed by the `base.g.node.class` value-
descriptions); enforcing it also yields "active physical subtree parent-closed."
`validate_registry` is the audit pass; the step-5 write handlers will run the
relevant check on the affected subtree at write time. **Verified:** a live-
Postgres scenario — a clean 5-node tree (root→MM→CTN→LTN→TA) passes, and a
suspended parent, a missing edge, a wrong-source extra edge, and a TerminalAsset
under a ConnectivityNode are each caught.

## 2026-06-29 — Add alias_assignment ledger enforcing alias-uniqueness-through-time (`8960b6f`)

**What:** Added `AliasAssignmentSql` (`alias` PRIMARY KEY, `g_node_id` FK,
`first_assigned_at`) in `src/gnr/db/models.py`, the `claim_alias` write primitive
+ `AliasAlreadyOwned` error in new `src/gnr/db/alias_ledger.py`, and the
autogenerated Alembic migration creating the table.

**Why:** `g_nodes.alias UNIQUE` enforces only *live* uniqueness — a rename frees
the old value in that row, so a different `GNodeId` could later claim a vacated
alias. The registry's core invariant is stronger: an alias, once held, is
**permanently owned** by that `GNodeId` and must never rebind to another (the
alias is the routing handle for money + physical grid control). The ledger's
`alias` PK makes that permanent; `claim_alias` does `INSERT … ON CONFLICT
(alias) DO NOTHING` then asserts ownership (race-free via the unique index), so
the three cases — new alias claimed, same owner re-acquiring, different owner
rejected — are enforced in the same transaction as the GNode write. Build
step 2 (ledger half) of OPS-419; status/edge change-history is still open.
**Verified:** a live-Postgres scenario (create → rename → a different `GNodeId`
rejected with `AliasAlreadyOwned`, the original owner re-acquires, bindings stay
permanent).

## 2026-06-29 — Stand up dev Postgres + initial schema; load .env (`685ab81`)

**What:** Brought the registry to a working dev Postgres with the schema
generated (standup build step 1). Renamed `gnr.config` → `gnr.settings` and
switched it to `SettingsConfigDict(env_file=".env")` so `Settings()` actually
reads `.env` (it previously had no `env_file`, silently falling back to the
hardcoded default URL). Added `gnr.db.session` (engine + `SessionLocal` from
`Settings`). Repointed `docker-compose.yaml` to publish host port **5435** and
fixed `template.env` to the `+psycopg` (v3) driver. Committed the autogenerated
initial Alembic migration (all three tables). Updated `README.md` (dev
quickstart + step 0 marked done) and `alembic/env.py`'s import.

**Why:** the standup design's step 1 was blocked by three real defects, not one:
(1) a stale `gnr_pgdata` volume meant Postgres skipped `initdb`, so the `gnr`
role was never created; (2) a host-local Postgres holds `localhost:5432` and
macOS prefers `::1`, shadowing the container's `5432:5432` publish — hence "role
gnr does not exist" from the host while `docker exec` worked; (3) `Settings`
never loaded `.env`, so alembic connected to the default `:5432` regardless. Fix
unblocks history tables, invariants, lifecycle, and the query surface — and the
registry is the source of truth FIS needs for the summer mTLS+FIS auth work
(OPS-419). **Verified:** a `GNodeGt` round-trips against the live DB
(`gt → from_gt → commit → fresh-session → to_gt`, identical bytes); the sema
snapshot self-check stays green.

## 2026-06-28 — Drop vendored sema README; remove its rsync exclude (`77c876a`)

**What:** Removed `src/gnr/sema/README.md` (stale "Sema Module" boilerplate with
already-done integration steps) and dropped the now-unneeded `--exclude='README.md'`
from `build_gnr_snapshot.sh`.

**Why:** the snapshot's provenance lives in `build_gnr_snapshot.sh` +
`gnr_seed_request.yaml` + the design; a hand-written doc inside a regenerated tree
just rots. Decided with the OPS-419 open-question cleanup.

## 2026-06-28 — Reconcile to ids-only connectivity edges + regenerate snapshot (`ae3be8f`)

**What:** Regenerated the vendored Sema snapshot against the edited
`connectivity.edge.gt` (alias fields dropped) and `position.point.gt`, and dropped
the `from_g_node_alias` / `to_g_node_alias` columns and their `to_gt`/`from_gt`
references from `ConnectivityEdgeSql` (`src/gnr/db/models.py`). Imports clean;
snapshot round-trip green.

**Why:** the standup grill ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
settled that edges store **immutable ids only** — alias is derived on read, so a
rename touches zero edges. Mirrors the matching sema edit (see `wiki/sema/changelog.md`).

## 2026-06-27 — Regenerate gnr Sema snapshot off sim-vocab (g.node.gt v004); add seed request + build script (`8402df2`)

**What:** Regenerated the vendored `src/gnr/sema/` snapshot from the sema
repo's `jm/sim-vocab` branch, and added the reproducible regen path:
`gnr_seed_request.yaml` (targets `g.node.gt` · `connectivity.edge.gt` ·
`position.point.gt`; enums by closure) + `build_gnr_snapshot.sh` (drives
`sema snapshot prepare|build --package-name gnr`, rsyncs `output/sema/`
into `src/gnr/sema/`). `g.node.gt` is now **v004**: `GNodeClass` changed
from a closed enum to an axiom-governed open `str`, so the `g.node.class`
enum word dropped out of the closure. The snapshot is now self-describing —
it gained vendored `definitions/`, `indexes/`, `samples/`, `roundtrip.py`.

**Why:** The vendored snapshot dated to Feb and sema's vocabulary had moved
substantially since. Regenerating gives a clean baseline to build the
registry against, and checking in the seed request + build script settles
the "how does the vendored snapshot stay in sync" question (the gwta
pattern, homed in the consumer so the only sema-side write is its gitignored
scratch). Verified: the snapshot round-trip gate passed (3 samples), the
`gnr.sema` package imports cleanly, and no repo code referenced the dropped
enum. To redo once sema settles on `dev`.
