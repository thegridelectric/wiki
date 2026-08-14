# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-base` code repo**. The matching git commit (in
`gridworks-base`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-08-14 — demo smoke test + pyright gate (`409e36b`)

Branch `jm/pyright-gate` — the two guards the hello_rabbit break showed were
missing. `tests/test_demo_script.py` imports the demo, so a root-level file
referencing a moved or deleted symbol fails the suite instead of surviving
until GitHub's linter. And `ci.sh` + the lint workflow gain a pyright step,
per the house sema-alignment discipline: an unresolved import is what a type
checker catches with no test at all. The generated snapshot tree is excluded,
same reasoning as the ruff exclusion.

The gate opened at 29 findings, all resolved. The demo was worse off than
the import error suggested — it had drifted since May and could not have
run: `transport_class` had moved from settings to a constructor argument,
`service_alias` had become required, and it still wrote `g.node.gt/004`
identity files, unreadable since the 006 bump. It is now a
LeafTransactiveNode + Supervisor pair writing valid 006 identities (physical
class ⇒ matching BaseClass + PositionPointId, mirroring the test fixture),
and it was run end to end against the dev broker: ping, pong, broadcast, and
`gw` wrap/unwrap all witnessed.

Two real latent bugs in library code: both `subscribe_*` helpers called
`queue_bind` on `_single_channel` without checking it exists, so calling one
before the channel opened would have raised `AttributeError: 'NoneType'`
instead of saying what was wrong — now routed through a `_live_channel()`
accessor that names the contract. And the log-file header wrote to
`handler.stream` on the same assumption (safe here — a non-delayed
`RotatingFileHandler` always has its stream — now asserted rather than
assumed).

The rest were typing gaps, not defects: `_RecorderMixin` gets a
`TYPE_CHECKING`-only actor base so borrowed attributes resolve while the
runtime MRO stays free, `declare_topology` is typed `BlockingChannel` (what
callers pass), and one parse result is narrowed by `isinstance` per the
house rule. Five `pyright: ignore`s remain, each commented: four are
pika-stubs gaps around the credentials extension mechanism (it omits
`compat.as_bytes` and types `VALID_TYPES` as a union where the runtime is a
mutable list — pika's documented way to register a mechanism), and one marks
a deliberate static violation a test asserts at runtime.

## 2026-08-14 — hello_rabbit off the deleted module; uncached ruff in ci.sh (`6109ecc`)

Branch `jm/hello-rabbit-lint`. GitHub failed `ruff check --no-fix` on
`hello_rabbit.py` while a green `ci.sh` said otherwise — and the lint error
was the shallow symptom of a real break. The demo still imported
`gwbase.sema.wrapped`, deleted when the envelope helpers moved to
`gwbase.wrapped` (the import-fix sweep covered `src/` and `tests/` and
missed the root-level script; nothing imports the demo, so the suite never
noticed). The import now points at the module's home and the demo
import-resolves again.

Why ci.sh lied: a stale `.ruff_cache` verdict kept replaying "clean" for
bytes GitHub's cache-less run rejected. Both ruff steps in `ci.sh` now run
`--no-cache` — the script exists to predict CI, and a verdict that can
drift from GitHub's on identical content is worse than the second it
saves.

## 2026-08-14 — claims connect wiring; 0.5.12 (`58da31f`)

Branch `jm/claims-connect-wiring` (OPS-496). The last gwbase piece of the
cert-plus-claims gate: an actor whose settings carry a `rabbit.tls` block
(three required paths — `ca_cert_path`, `cert_path`, `private_key_path`,
mirroring the proactor's field names) connects over amqps with
`GridworksClaimsCredentials` supplying `_connect_claims()`; without the
block, password connect is untouched. The per-actor mTLS migration is now
pure config — three env lines per service, no gwbase code change
mid-rollout.

The `Run` claim derives from the broker URL's vhost rather than being a
second declared setting that could drift: the vhost IS the universe run.
With that comes the universe made first-class in code (`Universe` in
`transport_format.py`, parsed off the vhost) and two boot-time checks on
every broker URL, claims path or not, from the gnr executor's "Universes"
ladder: the universe token must be d-kind, h-kind, or exactly `w` (the
single production universe — deliberately narrower than the ladder's
first-letter rule, which would admit a `w1`); and the URL host is
localhost/127.0.0.1 **iff** the universe is d-kind — the dev ladder rung's
"all comms go through localhost brokers" isolation guarantee, enforced
instead of trusted. A vhost that is not a `universe.run` (e.g. Rabbit's
bare `/`) now fails at boot on every gwbase actor. The kind rule is
hand-coded with a note naming the missing sema word (a `universe` format)
that retires it.

The spike harness gains the end-state witness: a real `ActorBase` actor,
configured only through settings, connecting through the mounted plugin to
the stub FIS with claims built from its live state. The harness moves to
`d1__1` to conform to the localhost rule it now exercises.
## 2026-08-14 — the GridWorks SASL mechanism plugin (`f44dd45`)

(The commit title names the OPS-496 deliverable this cluster serves; the
gwbase diff is the client half — connect claims, the credentials class, and
the snapshot regen — described below. Bumps to 0.5.11.)

Branch `jm/sasl-claims-credentials` (OPS-496). gwbase gets the client half
of the broker's certificate-plus-claims gate: `credentials.py` holds a pika
credentials class advertising the `GRIDWORKS` mechanism and answering with a
`fis.connect.claims` word, and `ActorBase._connect_claims()` builds that word
from the actor's live alias and instance id (`GridworksActor` adds
`GNodeClass`, whose presence is the gate's GNode discriminator). It carries
no secret — the private key proving identity lives in the TLS layer — so
`erase_on_connect` is False and the claims stay readable across reconnects.
A broker not yet switched over answers as an ordinary negotiation miss
rather than a crash.

This forced the full snapshot regen the entry below deliberately deferred,
because the claims word has to be vendored before the first line that builds
it. The debt that made regen impossible is now paid structurally: the repo
gains `scripts/regen_sema_snapshot.sh` + `src/gwbase/sema_seed_request.yaml`
(previously there was no seed request — the snapshot could only be
regenerated by guessing its inputs), and the vendored tree is ruff-excluded
(linting generated code means hand-editing it, and those edits vanish at
the next regen).

The `GwBaseSemaCodec` / `GwBaseSemaType` / `GwBaseSemaError` names are
deliberate, not drift, and they survive the regen: gwbase is a library, and
the applications built on it each vendor their own snapshot whose generated
runtime uses the same generic names — exporting a second `SemaCodec` from
gwbase would erase the transport-vs-application layer from every import
line. What was wrong was HOW the names were applied (by hand, inside the
generated tree — which is why regenerating would have destroyed them and so
never happened). The regen script now applies the rebrand itself after the
stock build and asserts no generic name survives, so the decoupling is
enforced by the pipeline instead of defended by not running it. One
generated local name is accepted as-is: `sim.ready`'s class was hand-named
`Ready`, and the generator's `SimReady` is better (6 call sites).

The seed pins every existing type to the version gwbase already speaks
rather than letting them float to latest, so a regen is never a silent
protocol change for actors on the bus; only `fis.connect.claims` is new. It
is a `staging` word, so the build takes `--allow-staged` and the snapshot is
dev-only until that word is published — the flag comes out then.

`sema/wrapped.py` moves to `gwbase/wrapped.py`. It was never generated:
it was hand-written into the generated tree the day after that tree was
built, so every regen would have silently deleted it. Its new home is
outside the tree the generator owns.

## 2026-08-13 — g.node.gt vendored to 006, 004 rejected; 0.5.10 (`cbba178`)

GridworksActor strict-Sema-validates every identity file at boot
against gwbase's own vendored `GNodeGt` — but that vendored copy was
hand-frozen at v004 since first vendoring and never touched again
(no regen tooling, no old_versions/ entry, discovered while
registering the weather service's GNode: the registry's canonical
record is v006). Hand-patched the vendored copy to 006 — the actual
schema change, not just a version string: axiom 2
(PhysicalGNodeLocations) is now Active-conditioned (a Pending
physical GNode may be locationless), and axioms 3–6 (alias-transition
consistency, GNodeClass namespacing, `.ta`/`.scada` alias-suffix
rules, minimum alias depth) are new. 004 is no longer decodable —
by construction, not a special case; any identity file still
declaring `"Version": "004"` now fails validation at boot instead of
silently drifting further behind the registry.

Deliberately NOT a full regen (`GwBaseSemaCodec`/`GwBaseSemaType`
stay as found, the other six vendored types — `g.node.instance.gt`,
`gridworks.header`, `gw`, `heartbeat.a`, `sim.ready`, `sim.timestep`
— untouched): the standard tooling has no way to touch one vendored
type without regenerating the whole tree, which would have also
surfaced this directory's other drift (never ruff-excluded, a
hand-renamed codec class the regen would silently overwrite) — real
technical debt, but a bigger and separately-scoped fix. Test fixtures
in `conftest.py`/`test_tiers.py` bump `Version` 004→006 (no shape
change needed — the required-field set is identical). Bumps to
0.5.10.

## 2026-08-12 — weather self-edge for the create round; 0.5.9 (`49a403f`)

The weather service's create-command round (records enter by
`gw.weather.create.cmd` over the bus, OPS-436 step 7) needs a fabric
path for the operator↔service exchange, and `ROUTING_EDGES` had no
path into or out of WeatherForecastService — the command died in the
sender's mic exchange. One new SELF-edge, (weather, weather): the
minter is a weather-class operator identity (`<universe>.weatherminter`),
so the command and the verdict both ride the single edge and the
semantics stay inside the weather domain. Deliberately NOT the gnr
operator shape (operator rides MarketMaker, piggybacking on the real
mm↔gnr edges) — weather has no real MarketMaker relationship, and
inventing one to carry operator traffic would pollute the fabric.
Regenerates the baked broker definitions; bumps to 0.5.9. Deploying
consumers means the prod broker fabric gains the one binding
(generated definitions are the source; apply is idempotent).

## 2026-08-11 — document the per-service settings + logging pattern (`69919d4`)

The README's Settings section and the `ServiceSettings` docstring read
as "your service uses the `GWBASE_` prefix", but the settled convention
is the opposite: each service subclasses `ServiceSettings`/
`GNodeSettings` with its own env prefix (`GJK_`, `GWWF_`, …), a
dev-default `service_alias`, and its own `service_name` — one `.env`,
one prefix per service — and logs through the actor's `self.logger`
rather than configuring logging itself. The gwwf standup tripped on
exactly this gap (inherited the generic `gridworks` XDG segment,
added a `basicConfig`), so the pattern is now stated where a service
author will actually look. Doc-only: README + docstring.

## 2026-07-23 — Strip wiki and downstream-service references (`af6e83b`)

**What:** every wiki citation in the repo is gone — nine source/test files
plus `for_docker/dev_rabbitmq.conf` (a comment in the baked image config).
Module docstrings drop their `Spec: wiki/…` pointers; docstring
parentheticals citing the executor spec are removed with the substantive
sentence kept in place; the two design-name references
(`'ltn-sends-gw-wrapped'`, `'must-accept-current-ltn-messages'`) are
dropped — design files are deleted on completion, so a code comment naming
one is a dangling pointer by construction. Also gone: every mention of a
downstream inheriting service (JournalKeeper's `legacy_hack`, the
journalkeeper/ear tier examples, the README's named-consumer list —
now "non-GNode consumers" generically) and the `d1.journal`/
`journalkeeper` test fixture strings (now neutral `d1.tap1`/`tap1`) —
what a downstream repo does with a hook goes stale here. The "ear-tap"
metaphor and the `ear_tx` fabric entity stay: gwbase's own vocabulary.
Comment-only plus fixture renames; no behavior change.

**Why:** the canonized principle (GridWorks_CLAUDE.md "Repos do not know
about the wiki"): the only references to wiki files are in the wiki
itself — the wiki points at code (`file:line`); code never points back.
Supersedes the interim § → header-slug rewrite from earlier the same day,
which had turned the citations into slug form before the principle removed
them outright.
**Verified:** grep-clean for wiki/executor/design references; offline
suite 52 passed; pre-commit run (pyupgrade/ruff-format flip-flop
pre-exists on clean `dev`, unrelated).

## 2026-07-23 — Improve README, make sure it stays current w routing keys (`6dfa8ad`)

**What:** a "Message transport" README section (linked from the repo
intro): the three live category shapes with real fleet examples (beech
LTN `bid` → keene MarketMaker; keene `latest.price` broadcast; beech
scada `gw.….to.ltn.power-watts` — MQTT-plugin-bridged, key carries the
**inner** payload's TypeName), the dots-render-as-dashes rule, a
**routing-class table** (the closed `RoutingClass` taxonomy of
`transport_encoding.py`), and a "How messages move" subsection — the
`<rc>mic_tx` / `<rc>_tx` pairs, the direct fabric's
`*.*.<src>.*.<dst>.*` bindings, broadcast subscriber-binding, the MQTT
seam, the ear taps — ending in a `bid`'s end-to-end journey, with
RabbitMQ doc links (topic exchanges, e2e bindings, MQTT plugin). New
`tests/test_readme_transport.py` fails the suite if the README table
drifts from the enum. Rides along (squashed in): the pre-commit and Black
badges dropped (the repo is ruff-formatted), and `rabbit/README.md`
rewritten from its 2023 fossil state (retired EC2 recipe, `jessmillar`
Docker Hub per-arch builds as "LATEST VERSIONS") to what the directory is
today — the GHCR image Dockerfile + `build-and-push.sh` tag convention
and the generated `rabbitconfig/` artifacts; the legacy Docker Hub images
are recorded in gridworks-infra's `legacy-infra.md`.

**Why:** the transport grammar was documented nowhere outside
`wiki/gridworks-base/executor/`; the repo README must stand alone, and
the ear README now leans on this pattern (its object keys are built from
the routing key's from-alias + TypeName), so the public home for the
grammar is gwbase's own README — with the class tokens finally named as
routing classes rather than left vague.
**Verified:** `test_readme_transport.py` green; shapes and mechanics
checked against `parse_routing_key`, `gwbase.topology`, and the scada's
actual uplink topic (`H0N.ltn`, `MQTTTopic.encode`).

## 2026-07-22 — Declarative debug queue + cap policy (0.5.8) (`62e165d`)

**What:** `gwbase.topology` gains `QueueSpec`/`PolicySpec` + `queues()`/
`policies()`; the definitions builder emits them. First entries: the
standing `debug` queue (durable, deliberately unbound — which slice it taps
is investigation state, hand-bound per session) and its `debug-cap` policy
(`^debug$`, max-length 1000, drop-head). Artifacts regenerated; version
0.5.8.

**Why:** first slice of the definitions-complete broker (OPS-459): a
container recreate reproduces the debug tap from files, no hand recipe. The
users tier (password hashes — must never enter this public artifact) stays
OPS-459's remaining scope via a box-side render step.
**Verified:** full ci.sh green incl. the new topology test.

## 2026-07-21 — gnr_ear_tx: the registry's scoped audit exchange (0.5.7) (`87fa950`)

**What:** new internal exchange `gnr_ear_tx` + two fabric bindings
(`gnr_tx → gnr_ear_tx`, `gnrmic_tx → gnr_ear_tx`, both `#`) in
`gwbase.topology`; definitions artifacts regenerated (dev + hybrid);
topology tests assert the pair; version 0.5.7. Rides along: a README "How
to commit changes" section (`pre-commit run --all-files`, `./ci.sh`, the
regenerate-definitions step, the stray-`SSL_CERT_FILE` TLS gotcha) — the
commit gates existed but were undocumented, and this change hit two of them
blind.

**Why:** the registry's meaning-bearing slice — everything said to it and by
it (forest broadcasts AND write verdicts, which ride the registry's own mic)
— gets a fabric-defined audit feed for the seed-store capture. The slice
lives in git and boots with the broker, never in a tap's runtime binding.
**Verified:** full ci.sh green (ruff, format, drift-guard, 58+ tests incl.
the updated topology contract).

---

## 2026-07-04 — gnr broadcast bridge to amq.topic; rename prod->hybrid definitions; 0.5.6 (`a657b92`)

**What:** two changes in one commit (PR #170).
- **Bridge:** `gwbase.topology` gains a `gnrmic_tx → amq.topic` binding (`rjb.#`,
  broadcasts only — the TimeCoordinator-bridge precedent) so MQTT-native actors
  (scadas) can hear the registry's `g.node.forest` broadcasts; regenerated broker
  definitions; `test_topology` bindings count +1 and an explicit bridge assertion.
  The `TransportClass` docstring now maps classes to runtime tiers (Orchestrator
  non-GNode: Supervisor/TimeCoordinator/GridNodeRegistry; GridworksActor:
  TA/LTN/MM/Price/Weather; no gwbase runtime: Scada (MQTT-native),
  ConnectivityNode (passive)).
- **Rename:** `rabbit/rabbitconfig/prod_definitions.json` → `hybrid_definitions.json`
  (git mv + `DEFINITION_ARTIFACTS` + the drift-guarded regen;
  `test_prod_definitions_have_no_baked_credential` → `test_hybrid_definitions…`).
  Version **0.5.6**, relocked.

**Why:** the registry's root-keyed forest broadcasts (radio_channel = the
audience-known alias) are how every GNode passively hears ancestor renames;
without the bridge the MQTT side is deaf to them (forests carry aliases +
immutable ids only — never coordinates — so crossing is safe). And `hw1` is a
**hybrid** universe — calling its definitions "prod" misnamed the artifact; the
single production `w` universe doesn't exist yet. Canonized alongside in
`executor/provisioning.md`: vhost = **`<universe>__<run>`**, uniform across all
kinds (`d1__1`, `hw1__1`, `w__1`); for a real universe the run number is the
fabric generation; "live" is a provisioning pointer, never a name. **Verified:**
`./ci.sh` fully green (lint, format, definitions-drift, 60 tests against the
live dev broker).

## 2026-07-02 — Revert FleetIndexService transport class; 0.5.5 (`02cd709`)

**What:** removed `TransportClass.FleetIndexService` (+ its `RoutingClass`
`"fis"` and the map entry), dropped `FleetIndexService` from `topology.AMQP_ACTOR_CLASSES`
and the two `ROUTING_EDGES` to/from `GridNodeRegistry`, regenerated the broker
definitions (dev/prod lose the `fis_tx`/`fismic_tx` exchanges + FIS↔gnr bindings),
reverted the `test_topology` expected set, bumped **0.5.4 → 0.5.5**, relocked.

**Why:** forward-revert of 0.5.4 (published, so not rewritten). The registry's FIS
read path was reconsidered and settled as **HTTP + a broadcast subscription**, not
rabbit request-reply: FIS is a pure `g.node.topology.broadcast` **subscriber** (a
`ServiceSettings` tap — subscribing needs no transport class), event-sourced from the
bus, and reads/bootstrap go over the API. Nothing sends direct messages to FIS, so the
transport class + routing edges had no consumer — dead fabric, removed per no-dead-code.
**Verified:** `./ci.sh` green (lint + format + definitions-drift + tests, 60).

## 2026-06-30 — Add FleetIndexService transport class + registry routing edges; 0.5.4 (`af239fb`)

**What:** added `TransportClass.FleetIndexService` (+ `RoutingClass`
`"fis"` and the transport↔routing map entry) so FIS is a routable gwbase citizen;
added `FleetIndexService` to `topology.AMQP_ACTOR_CLASSES` (it gets a `fis_tx`
consume / `fismic_tx` publish pair) and the two `ROUTING_EDGES`
`FleetIndexService → GridNodeRegistry` and `GridNodeRegistry → FleetIndexService`;
regenerated the committed broker definitions (`dev_definitions.json` /
`prod_definitions.json` gained the `fis_tx`/`fismic_tx` exchanges + the FIS↔gnr
bindings); updated the `test_topology` expected class set; bumped the version to
**0.5.4** and relocked.

**Why:** the grid-node-registry standup (OPS-419) needs FIS to read the registry
over **rabbit request-reply as a gwbase citizen** — which requires FIS to be a
class in the closed transport taxonomy with a consume/publish exchange pair and
direct-routing edges to/from the registry. Reply addressing is carried by the
request **envelope's `from_alias`/`from_class`** and correlation is **app-specific**
(a `request_id` in the Sema payload), so `on_message` continues to drop AMQP
`reply_to`/`correlation_id` — no `actor_base` change needed. **Verified:** full
suite 60 passed, incl. the definitions-drift guard (committed JSON matches the
generator). NB: the running `gw-dev-rabbit` needs a definitions reload to gain the
new exchanges; tests provision the fabric from `gwbase.topology` directly.

## 2026-06-30 — Remove dead Optional imports; CI ruff check --no-fix (`de9a582`)

**What (planned):** removed unused `Optional` imports from `actor_base.py`,
`orchestrator.py`, `tests/_stubs.py` (F401) + reformatted; changed the CI/`ci.sh`
lint step to `uv run ruff check --no-fix .`. Also **removed the per-repo
`CLAUDE.md`** (the umbrella `wiki/GridWorks_CLAUDE.md` is the only Claude-facing
doc — no sub-repo CLAUDE.md) and moved the `fix=true` / run-`ci.sh` note into the
README's "Environment gotchas".

**Why:** CI's `ruff check .` was failing on the dead imports — and because the
repo config sets `fix = true`, CI *auto-fixed* (mutated) the files, after which
the format step failed on the mutation (the confusing "`_stubs.py:10` would be
reformatted" that local couldn't reproduce). `--no-fix` makes CI fail loudly on
lint errors instead of mutating. **Verified:** `ruff check --no-fix .` →
"All checks passed!" and `ruff format --check .` → all formatted.

## 2026-06-30 — Pin ruff; document dev workflow (README + CLAUDE.md) (`f38a2ec`)

**What (planned):** pinned `ruff==0.15.14` in `pyproject.toml` (was `>=0.5.6`,
the latent-drift source) so the dev dep, `uv.lock`, and the `.pre-commit-config`
ruff `rev` are all explicitly equal; relocked. Added a README "Environment
gotchas" subsection and a repo `CLAUDE.md` covering: always `uv run` (never a
hand-activated venv), the stale-`VIRTUAL_ENV` fix, repo-based pre-commit usage,
the three-places ruff pin, and the topology→definitions regen.

**Why:** a CI ruff-format failure that local couldn't reproduce traced to a
stale `VIRTUAL_ENV` (old `~/Coding` path) + a loose ruff constraint that could
drift from the pre-commit pin — confusing and unwritten. This makes the toolchain
deterministic and the workflow explicit for humans and Claude. **Verified:**
`uv run ruff format --check .` passes on the locked env; pre-commit passes with
no venv on PATH.

## 2026-06-30 — Make pre-commit hooks repo-based (PATH-independent) (`3bb9f80`)

**What (planned):** `.pre-commit-config.yaml` — moved the standard hooks
(`check-added-large-files`, `check-toml`/`yaml`, `end-of-file-fixer`,
`trailing-whitespace`, `pyupgrade`) from `repo: local` + `language: system` to
the canonical `repo:` form (pre-commit-hooks v5.0.0, pyupgrade v3.19.1). Kept the
gwbase-specific `rabbit-definitions-drift` + `ci` local hooks and the ruff repo.
Also dropped the deprecated `stages: [commit, push]` (→ default / `pre-push`).

**Why:** the `language: system` hooks resolved their executables off the shell
PATH, so a bare `git commit` (venv not active) failed with `Executable …
not found`. Repo-based hooks install in pre-commit's own isolated envs and need
no PATH. **Verified:** `pre-commit run` passes with the project venv NOT on PATH.
(The `pre-commit-hooks` / `pyupgrade` dev deps are now redundant — a later tidy.)

## 2026-06-29 — Add GridNodeRegistry transport class + broker exchanges (`3bb9f80`)

**What (planned):** added `TransportClass.GridNodeRegistry` + `RoutingClass.gnr`
(+ the map entry), opted it into `topology.AMQP_ACTOR_CLASSES` (so it gets
`gnr_tx`/`gnrmic_tx`), and added the `MarketMaker ⇄ GridNodeRegistry` routing
edges (a MarketMaker sends the re-parent command and gets the reply). Regenerated
the committed `rabbit/rabbitconfig/{dev,prod}_definitions.json` and updated
`tests/test_topology.py`'s actor-class assertion. Bumped the package version
`0.5.2 → 0.5.3` (additive, backward-compatible) for the PyPI release.

**Why:** the grid-node-registry needs a routable identity on the rabbit fabric so
FIS / a MarketMaker can reach it (OPS-419). `TransportClass` is deliberately not a
Sema enum — transport routing is decoupled from message decoding. **Verified:**
`pytest` green (60); `gnr_tx`/`gnrmic_tx` render in the definitions and were
imported live into `gw-dev-rabbit`.

**What:** README "Dev Rabbit Broker" — note that `gwbase.topology` bridges the
TimeCoordinator publish exchange to the MQTT plugin's `amq.topic` (the `rjb.#`
broadcast tap), so an MQTT-native service (scada) subscribed to
`rjb/<tc-alias>/time/sim-timestep` receives `sim.timestep`.

**Why:** the README's "SCADA is MQTT-native, no AMQP exchanges" line predated
the bridge tap (`3139f34`, PR #158); it now correctly reflects that a
MQTT-native scada *can* receive TimeCoordinator broadcasts. Surfaced while
exercising the crossing in the scada sim-time experiment.

## 2026-06-11 — Topology: timemic_tx -> amq.topic MQTT bridge tap (`3139f34`, PR #158)

**What:** One new binding in
`gwbase.topology.exchange_bindings()` — the time coordinator's publish
exchange (`timemic_tx`) binds to `amq.topic` (the MQTT plugin's
exchange) with routing key `rjb.#` (broadcasts only; direct traffic
stays on the AMQP fabric). Topology tests updated (binding-count
formula + explicit assertion); committed dev/prod definitions
regenerated via `gen_definitions.py --write-all` (the drift test
enforces this). Verified live on gw-dev-rabbit: an MQTT subscriber on
`rjb/d1-tc/time/sim-timestep` received the tc-hello timesteps with
advancing TimeUnixS — the first witnessed AMQP→MQTT crossing.

**Why:** the sim-time bridge (scada simulated-test-environment design,
sim-time spoke, [OPS-40](https://linear.app/gridworks/issue/OPS-40)): MQTT-native actors (scadas) can only hear the
time coordinator's `sim.timestep` broadcasts if they cross to
`amq.topic`. The fabric is the authoritative "who may talk to whom",
so the crossing is declared in the shared topology source, not in
per-experiment harness glue. Rides along: `.pre-commit-config.yaml`
ruff pin v0.5.6 → v0.15.14 — the stale pin could not parse the newer
rule selectors in pyproject.toml and blocked commits.

## 2026-06-10 — version 0.5.2 (bump + uv.lock relock)

**What:** Bump gwbase `0.5.1 → 0.5.2`, plus a `uv lock` relock so CI's
`uv sync --locked` accepts the new version (the bump alone left `uv.lock`
pinning `0.5.1`, failing the locked sync).

**Why:** Cut the release that carries the tolerant routing-key parse +
`on_routing_key_parse_error` hook (`724ea52`, design `must-accept-current-ltn-messages`,
[OPS-388](https://linear.app/gridworks/issue/OPS-388)) so downstream consumers can adopt it — JournalKeeper's `legacy_hack`
(`2156a31`) and the scada `ltn-sends-gw-wrapped` ([OPS-387](https://linear.app/gridworks/issue/OPS-387)) both wait on this
publish ([OPS-389](https://linear.app/gridworks/issue/OPS-389)). Backward-compatible patch: the hook is additive and the
routing-key envelope API is consumed, not constructed, outside gwbase.

## 2026-06-09 — Tolerant routing-key parse: accept short-form class tokens; on_message parse-error hook (`724ea52`)

**Why:** a gwbase consumer was **silently dropping** current-production messages
whose routing-key class slot carries a proactor **short_name** (`s`=scada,
`a`=atn, `ws`=weather) instead of a long-form `RoutingClass`. `parse_routing_key`
ran the class token through the closed `RoutingClass` enum, raised `ValueError`,
and `on_message` (which acks *before* parsing) then `return`ed — ack-then-drop,
silent data loss (48 msgs lost in one 5-min prod run; weather forecasts never
captured). The two namespaces — proactor short_names and gwbase `RoutingClass` —
are independent; their overlap (`ltn`, `scada`) was coincidental, so anything
addressed to `s`/`a`/`ws` died. The proactor grammar can't change, so the fix
lives entirely in gwbase: parse the class slot as an **opaque token**, derive
`from_class`/`to_class` best-effort (`TransportClass | None`, `None` when
unresolvable) — safe because a message already reached *this* consumer's queue,
so its own class is redundant for dispatch (it's never needed for routing nor to
disambiguate partners). Build still emits long forms via `*.from_classes(...)`.
`on_message` now routes a parse failure to an overridable
`on_routing_key_parse_error(routing_key, body, error)` hook (default = log+drop)
instead of an inline silent `return` — the seam a consumer (JournalKeeper) can
override to salvage the body. The parser deliberately does **not** learn the
LTN's legacy `broadcast.*` keys as a category — that is fixed at the source
(scada design `ltn-sends-gw-wrapped`) plus a permanent JK `legacy_hack` for
replay. Design `must-accept-current-ltn-messages`. Not yet distilled into
`executor/transport.md` (lands when this merges).

## 2026-06-09 — Thread-safe ActorBase.send: marshal publishes onto the ioloop (`0f0dc28`)

**Why:** lands as its **own patch release** (`0.5.0 → 0.5.1`), separate from the
0.5.0 non-GNode-actors work — a focused thread-safety fix. `ActorBase.send`
called `basic_publish` on the *caller's* thread, but
pika is not thread-safe and the `SelectConnection` + channel are owned by the
consumer thread's ioloop. So any send off the ioloop thread (an actor's timer /
sensor loop, a Supervisor initiating heartbeats, a main-thread caller) raced the
loop on the shared socket — corrupting the connection under load and breaking
*consuming* too, not just the one publish. The fix routes **every** publish onto
the ioloop via `connection.ioloop.add_callback_threadsafe` (single connection;
canonical pika guidance — the rejected alternative, a second publisher
connection, re-adds the lifecycle surface behind the original instability). The
cheap pre-checks (STOPPED/STOPPING, NO_PUBLISH_EXCHANGE, a sync channel-open
pre-check) stay synchronous; the scheduled callback re-checks open + publishes;
both the schedule call and the callback are guarded so `send` never raises
(invariant #9). `send` is now genuinely fire-and-forget — `MESSAGE_SENT` means
*scheduled*. Distilled into `executor/transport.md` §3.8 + `primary.md`
invariant #9. Design `pika-thread-safe-publish` (Accepted, [OPS-383](https://linear.app/gridworks/issue/OPS-383)) was ratified off this; its
distillate now lives in the executor spec, so the `designs/` file is deleted when
this fix merges (and [OPS-383](https://linear.app/gridworks/issue/OPS-383) moves to Done) per the designs-process.

**Validated** by a throwaway pressure harness (built, run, then deleted in this
same change — never committed, never in CI): on the pre-fix code, 48 non-ioloop
threads × 128 KB–512 KB bodies × a 10 µs GIL switch interval gave **~100 %
delivery loss** with a pika-internal `AttributeError` inside `basic_publish` and
a forced reconnect; the identical concurrency on the fixed code delivered
**72 000 / 72 000** with zero errors / zero reconnects.

**Caveat recorded** (transport.md §3.8): marshaling removes the inline
backpressure synchronous publish gave, so a sustained publish rate above the
ioloop drain rate grows the callback queue (frames buffer in memory). Bounded by
gwbase's low-rate traffic; if it ever bites, the answer is a *bounded* publish
queue, not a different threading model.

## Roadmap — gwbase 0.5.0: support non-GNode actors

> Lands across the five commits below (one PR). Each carries its own dated
> entry; this block is the motivating roadmap. As-built spec distilled into
> `wiki/gridworks-base/executor/` (actors.md §5 + primary.md §2).

## 2026-06-06 — version 0.5.0 (`64bd1ba`)

**Why:** release commit for the support-non-gnode-actors PR — bumps the
package version `0.4.2 → 0.5.0`. Also lands the README's "Actor tiers,
settings & file locations" section (tier table, `GWBASE_` settings, the XDG
path layout incl. the Pi log path, and a runnable `uv run python` snippet) —
standalone, no wiki references.

**Why:** `ActorBase` forced *every* gwbase consumer to present a
`g.node.gt`-shaped JSON at construction, even when the service is not a
GNode — so `gridworks-journalkeeper` had to synthesize a fake 3-field
`g_node.json` just to start. The Sema tightening of `Logical` means
journalkeeper et al. cannot be GNodes even in principle. The fix is to stop
requiring the file: split the class hierarchy and the settings shape so
identity scope matches base-class scope, and land four interlocking
sharpenings that touch the same constructor (XDG paths, Sema-validated
`g.node.gt.json`, the FIS handshake, a logging substrate).

## 2026-06-06 — Migrate tests to three-tier API + add tier showcase tests (`41de4a0`)

**Why:** fixtures/stubs move to the new constructor shapes; the Supervisor
and TimeCoordinator stubs become `Orchestrator`-based with `ServiceSettings`
(no `g.node.gt.json` — the exact fake-GNode antipattern this work removes),
while only the real GNode stays a `GridworksActor`. Fixtures now emit
Sema-valid `GNodeGt` files. New `test_tiers.py` documents the three tiers as
runnable examples: a tap built with no GNode file, an Orchestrator
class-routing without GNode identity, and `GridworksActor` validation with
drift / malformed / missing-file all rejected at boot.

## 2026-06-06 — Three-tier actors: ActorBase ear-tap, Orchestrator, GridworksActor sema-validate (`b3fa2c4`)

**Why:** refactor into `ActorBase → Orchestrator → GridworksActor` so
non-GNode rabbit+sema consumers ride the base deliberately. `ActorBase` is
now a passive ear-tap (consumes `ear_tx`, no auto-bind — subclass binds its
slice, no `mic_tx`, `ServiceSettings`, no GNode file read); it sends wrapped
to `amq.topic` but returns the new `NO_PUBLISH_EXCHANGE` diagnostic for a
Direct/Broadcast it cannot class-route. `Orchestrator` adds class-routing
(`transport_class` as an `__init__` param → `<rc>_tx`/`<rc>mic_tx` + a
direct-to-me bind) plus the heartbeat / sim-timestep rhythm moved down from
`GridworksActor`. `GridworksActor` loads + **Sema-validates** its
`g.node.gt.json` as a `GNodeGt` at boot (axioms fire) and asserts
`GNodeGt.alias == service_alias` (provisioning-drift guard). FIS handshake
renamed: `ServiceAlias` + `ServiceInstanceId` always, `GNodeClass` iff GNode.

## 2026-06-06 — Add per-actor logging substrate (`f6f1ea8`)

**Why:** `ActorBase` gains a contextualized `RotatingFileHandler` logger
that writes a bijective human-readable format to the XDG state-home,
designed to map 1:1 onto a future `observability.log-entry/000` Sema type so
a downstream broker-forwarding handler can attach without any actor-side
code change. Substrate only — no broker forwarding, no verbosity hooks
(downstream concern).

## 2026-06-06 — Split settings (ServiceSettings/GNodeSettings) + XDG paths + transport_format (`c2a6cca`)

**Why:** identity scope now matches base-class scope. New `ServiceSettings`
holds the generic rabbit+sema fields (`service_alias`, `instance_id`,
`service_name`, `log_*`); `GNodeSettings` extends it adding only
`g_node_path`. One unified `GWBASE_` env prefix for every service. Default
file locations move from system `/etc/gridworks/...` to per-service XDG
directories via a small inline `config/paths.py` helper (the `g_node_path`
default derives from it) — provisioning no longer needs root.
`transport_class` is removed from settings — it is intrinsic to an actor's
role, not deployment config, and becomes an `Orchestrator` `__init__` param.
New `transport_format` provides `LeftRightDot` / `UUID4Str` so the
config/transport layer types aliases without importing the sema codec
(mirrors `property_format`; sema stays the authority). Adds the `xdg`
dependency.

## 2026-05-22 — release 0.4.2: fix CI publish step + bump version (`50633e8`)

**Why:** the release CI was wedged. `pypa/gh-action-pypi-publish@v1.10.0`'s
bundled twine cannot parse the Metadata-Version 2.4 that `uv build` now
emits (`"Metadata is missing required fields: Name, Version"`), which
is why both 0.4.0 and 0.4.1 CI publishes failed — 0.4.0 had to be
published by hand, 0.4.1 was tagged but never reached PyPI. Swapping
publish from the gh-action to `uv publish` lands on a path that
handles 2.4 natively. Bumped to 0.4.2 (skipping 0.4.1's unreached
slot).

## Roadmap — Drift-proof generated rabbit topology; infra owns the exchange fabric

> Lands across several commits (the `uv` migration below was the first).
> Each commit gets its own dated entry as it merges; this block is the
> motivating roadmap.

**Why:** The broker topology was hand-maintained
(`rabbit/rabbitconfig/rabbit_definitions_dev.json`) and baked into a
*manually* rebuilt image — so it drifted badly: the live image was stuck at
commit `fee74a3` with the pre-refactor token namespace (`atomictnode`,
`gnode`, `timecoordinator`, …) while the code had moved to `RoutingClass`
(`ltn`, `mm`, `super`, `time`, …). Actors also declared their own exchanges
— a second source of truth that risks `PRECONDITION_FAILED` mismatches. This
work makes the topology code-derived and drift-proof:

- **Single source of truth** in `gwbase/topology.py`: the exchange set is
  derived from `RoutingClass` (an opt-in `AMQP_ACTOR_CLASSES` set), and a
  direct-only `ROUTING_EDGES` list + `direct_binding_key` drives the
  cross-class bindings. A generator renders per-vhost definitions JSON
  (`d1__1` dev, `hw1__1` prod); the broker *and* `tests/_stubs.py` consume
  the same source, so they can't diverge.
- **Infra owns the fabric.** Actors only *passively* assert their consume
  exchange exists and declare their own ephemeral queue + direct binding;
  they never declare `mic_tx` or cross-class bindings — killing the
  dual-source mismatch.
- **Identities in the definitions** (users/vhosts/permissions), not
  `default_*` conf lines: dev hash committed (non-secret), prod hash
  injected at deploy.
- **`scada` is MQTT-only** (reached via `amq.topic`, no AMQP exchanges);
  `cn` is passive (opt in later). Broadcasts stay subscriber-bound (not in
  the static fabric); reserve an AMQP↔MQTT bridge so a simulated `ta` can
  talk to scada.
- **Delivery:** CI regenerates-and-diffs the JSON and builds/publishes a
  **GHCR** dev-broker image, so other repos (marketmaker, scada) can run a
  dev broker with no gridworks-base checkout, and the image can't lag the
  repo.
- **Dev rabbit → 4.x** (prod upgrade deferred until a first gwbase actor is
  "tire-kicked" in dev; prod target is also 4.x). mTLS + FIS are a separate
  later track.

See `wiki/gridworks-base/executor/transport.md` §3.5 +
`provisioning.md` §3.6 (hub: `primary.md`),
`wiki/ear/executor/broker-tap.md`, and
`wiki/rmqbot/research/broker-todos.md`.

## 2026-05-22 — fix dev broker conf for RabbitMQ 4.x; document GHCR image (`aa2a368`)

**Why:** The first 4.x dev-broker boot crashed
(`failed_to_prepare_configuration`) — `dev_rabbitmq.conf` still carried 3.x
MQTT keys that 4.x removed:

- `mqtt.default_user` / `mqtt.default_pass` → replaced by the global
  `anonymous_login_user` / `anonymous_login_pass`.
- `mqtt.subscription_ttl` (ms) → `mqtt.max_session_expiry_interval_seconds`
  (s).

Validated by mounting the conf on `rabbitmq:4.1-management` (boots clean;
definitions import into `d1__1`). Also documents the GHCR build/publish flow
and a corrected `rabbitmqctl … -p d1__1` verify step in the README, and
removes the stale cookiecutter footer. **Lesson:** `docker build` only
`COPY`s the conf, so a bad conf surfaces at *container boot*, not build —
always run the image after pushing. (A follow-up fixes `arm.sh`/`x86.sh` to
pull the moving `:latest` and start from a fresh data volume.)

## 2026-05-21 — dev broker: official 4.x + baked GHCR image; retire jessmillar build infra (`4d3f414`)

**Why:** Topology-roadmap commit #6 (final) — replace the hand-built,
drift-prone per-arch broker images with one generated, CI-built artifact.

- **`rabbit/Dockerfile`** bakes `enabled_plugins` + `dev_rabbitmq.conf` +
  `dev_definitions.json` onto the official **multi-arch
  `rabbitmq:4.1-management`** (one image serves arm64 + amd64; Docker
  auto-selects the host's arch on pull).
- **`for_docker/{arm,x86}.yml`** pull `ghcr.io/thegridelectric/dev-rabbit:latest`
  (definitions baked in, no mounts). `dev_rabbitmq.conf` switches to the 4.x
  `definitions.import_backend` / `definitions.local.path` keys and drops the
  `default_*` identity lines (identities come from the baked definitions).
- **`.github/workflows/broker-image.yml`** + **`rabbit/build-and-push.sh`**
  build and push the image (CI gated by `gen_definitions.py --check`; both
  tag `:latest` and `:chaos__<short-sha>__<date>`).
- **Deleted** the superseded dev build infra: `DevRabbit{Arm,X86}Dockerfile`,
  `build-dev-broker-{arm,x86}.sh`, stale `rabbit_definitions_dev.json`. Prod
  track (`broker_arm.yml`, prod `rabbitmq.conf`, hybrid/analytics defs) left
  untouched — prod upgrade is deferred.

Remaining (TODO.md): one-time GHCR push + public visibility, and the
multi-arch smoke test (arm64 local; x86 deferred) before the prod upgrade.

## 2026-05-21 — add definitions drift guard (test + pre-commit + CLI --check) (`232b063`)

**Why:** Topology-roadmap commit #5 — keep the committed broker-definitions
JSON from silently drifting away from `gwbase.topology` (the artifacts are
hand-committed but generator-produced, so they could go stale).

- `gwbase.rabbit_definitions`: add `DEFINITION_ARTIFACTS` (the canonical
  render set), `dumps()` (one canonical serializer), and
  `rendered_artifacts()` — a single source the generator and the guard both
  use, so they can't disagree on form.
- `for_docker/gen_definitions.py`: `--write-all` (render the artifacts) and
  `--check` (exit 1 on drift) modes.
- `tests/test_definitions_drift.py`: the guard, parametrized over the
  artifacts — runs in the normal `uv run pytest` / CI, so an un-rendered
  topology change fails the build.
- `.pre-commit-config.yaml`: a drift hook scoped to the topology/definitions
  files.

## 2026-05-21 — generate rabbit definitions from topology; render dev + prod JSON (`575681f`)

**Why:** Topology-roadmap commit #4 — the broker fabric becomes a
*generated* artifact instead of the hand-maintained
`rabbit_definitions_dev.json`.

- **`gwbase.rabbit_definitions.build_definitions`** renders a RabbitMQ
  management-plugin definitions dict from `gwbase.topology` (exchanges +
  bindings), parameterized by vhost. **Dev** includes the non-secret
  `smqPublic` user with a deterministic (fixed-salt) sha256 password hash +
  full permissions; **prod** omits users/permissions (injected at deploy,
  never baked). Output is deterministic (sorted keys) so CI can
  regenerate-and-diff.
- **`for_docker/gen_definitions.py`** — the thin CLI the image build / CI
  guard call.
- Rendered **`rabbit/rabbitconfig/{dev,prod}_definitions.json`** (`d1__1` /
  `hw1__1`; 15 exchanges, 17 bindings each).

The stale multi-vhost `rabbit_definitions_dev.json` (+ hybrid/analytics
files) are left in place for the docker rework (next), which repoints the
build off them.

## 2026-05-21 — infra owns the exchange fabric (passive declare + provisioned tests) (`ce9b79f`)

**Why:** Topology-roadmap commit #3. Actors stop creating the routing
fabric — it is provisioned out-of-band from the shared `gwbase.topology`
source; the actor only owns its ephemeral endpoint.

- **`actor_base`:** assert the consume exchange with a *passive*
  `Exchange.Declare` (existence check, fail-fast) instead of defining it;
  still never declares `mic_tx` or cross-class bindings. Adds
  `subscribe_broadcast` (bind own queue to a publisher's `mic_tx`) and
  `subscribe_amq_topic` (the AMQP↔MQTT/scada seam). Drops the
  `LeafTransactiveNode` gate on `GridworksWrapped` sends — any actor may
  send wrapped (e.g. a simulated `ta` reaching scada).
- **`gridworks_actor`:** a `heartbeat.a` from `my_super_alias` is still
  handled internally (pong + `on_supervisor_heartbeat`); a `heartbeat.a`
  from any *other* sender now falls through to `process_message`, so a
  supervisor can observe its subordinates' heartbeats.
- **tests:** `_stubs` gains `declare_topology` / `provision_topology`
  derived from `gwbase.topology` (replacing the hand-coded bindings);
  `test_actor_base` and `test_hello` provision the fabric *before* starting
  actors and use a `LeafTransactiveNode` actor (`scada` is MQTT-only, has
  no AMQP exchanges). Full suite green against a live broker.

## 2026-05-21 — add shared broker topology source (`dd2faf8`)

**Why:** Topology-roadmap commit #2 — the single source of truth the rest
of the work derives from. Adds `gwbase/topology.py`:

- `AMQP_ACTOR_CLASSES` — the opt-in set of routing classes that get
  `<rc>_tx` (internal) + `<rc>mic_tx` exchanges (`scada` excluded as
  MQTT-only, `cn` excluded as passive; a new class gets nothing until
  added).
- `ROUTING_EDGES` — the direct-only cross-class routing edges (broadcasts
  are subscriber-bound, not here).
- `direct_binding_key(src, dst)` + `exchanges()` / `exchange_bindings()`
  derivations that the definitions generator *and* `tests/_stubs.py` will
  both consume, so test / dev / prod topologies can't diverge.

`tests/test_topology.py` locks the invariants — and caught a spec typo:
the MarketMaker publish exchange is `mmmic_tx` (`mm` + `mic_tx`), not
`mmic_tx`; the transport spec is corrected to match.

## 2026-05-21 — poetry -> uv (`a64b3c0`)

**Why:** First commit of the topology roadmap above — the toolchain
foundation, since the upcoming definitions generator, CI drift-guard, and
GHCR image build all run under `uv`. Migrated packaging/deps/CI off poetry
to `uv` (matching the `sema` sibling): `[tool.poetry]` → PEP 621
`[project]` + `[dependency-groups]` + hatchling build backend;
`poetry.lock` → `uv.lock`; the `nox-poetry` noxfile became a lean
uv-backed one (`venv_backend="none"`, sessions shell to `uv run`); both
GitHub workflows now use `astral-sh/setup-uv` + `uv run` / `uv build` /
`uv version` (dropping the pip-constraints + nox-poetry machinery and the
dead `constraints.txt`). Behavior preserved: `uv sync` resolves, the full
non-broker suite passes, the package builds.

## 2026-05-19 — WIP decouple transport from codec (`00f96b54`)

**Why:** `ActorBase` mixed RabbitMQ plumbing with Sema type-handling — it
imported message types, encoded/decoded inside its receive loop, and
exposed typed-message send helpers. That blocked reusing the transport with
a different codec, reusing Sema over a different transport, and
per-application codec ownership (a shared global codec forced every actor to
know every type). This single WIP commit bundled three connected changes
toward a clean transport/codec boundary (separated here for the record):

1. **Decouple codec from transport.** Introduce a `RoutingEnvelope` value
   object (a discriminated record whose `routing_key`/`category` are
   derived, not stored) as the single boundary artifact. `ActorBase` now
   deals only in `(RoutingEnvelope, bytes)`; the application owns its own
   `SemaCodec`.

2. **Disambiguate routing vs. application envelopes; add wrap helpers.**
   The transport `Envelope` collided with `gw`, which is *also* an envelope
   (the application-layer wrapper carrying `GridworksHeader` + `Payload`
   across hops). Renamed the transport classes to `RoutingEnvelope` /
   `DirectRoutingEnvelope` / `BroadcastRoutingEnvelope` /
   `WrappedRoutingEnvelope`; restored the convention that a wrapped routing
   key's `type_name` slot carries the **inner** type (enforced in
   `WrappedRoutingEnvelope.__post_init__`); added `gwbase.sema.wrapped` with
   pure `wrap_bytes` / `unwrap_bytes` that depend only on `GridworksHeader`
   / `Gw` (no codec registry), so apps build/parse `gw` envelopes without
   the private codec in scope.

3. **Collapse `ActorApplication`; rename `SupervisableActor` →
   `GridworksActor`.** Dropped the one-method `ActorApplication` ABC
   (`ActorBase` already enforced the contract). Renamed
   `SupervisableActor` → `GridworksActor` (it talks to both a supervisor
   *and* a time coordinator — the canonical default actor). The transport
   hook is now `dispatch_message` (on `ActorBase`); the application hook is
   `process_message` (on `GridworksActor`, was `process_app_message`).

See `wiki/gridworks-base/executor/` — `transport.md` §3.4, `codec.md`
§4.7, `actors.md` §5.1–§5.2 (hub: `primary.md`).
