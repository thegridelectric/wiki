# Findings register

Status: Draft · Pass 0 · Updated 2026-05-22

Actionable backlog for `gridworks-base`: bugs, smells, and small/medium
cleanups. Append-only IDs (`F-NNN`), never reused. Big/cross-cutting work
lives as an epic in [`concerns/`](concerns/) (create as needed).

Provenance: findings raised from reading source without tracing all callers
are marked **(inferred)** — confirm before acting.

---

## Area: transport portability

These three findings are framed by the question *"what's the cheapest set of
changes that keeps a future transport swap (NATS JetStream, Kafka, AMQP 1.0,
…) tractable without doing the swap now?"* The codebase today is
**architecture-aware** (clean `RoutingEnvelope`, portable routing-key helpers
in `transport_encoding.py`, transport-neutral heartbeat content) but
**pika/AMQP is wired directly into `ActorBase`** — the handshake (declare,
bind, qos, consume) **is** the actor lifecycle, not a layer beneath it.

The long-term move that matters most is **F-009 signed-handshake** (see
[`../../gridworks-scada/research/findings.md`](../../gridworks-scada/research/findings.md))
— once liveness/contract guarantees live in cryptographic state instead of
broker semantics, transport becomes commodity. Until then, the goal is just
to **not ossify** AMQP assumptions further.

### F-001 — `amq.topic` is hardcoded in `ActorBase`
- **Type:** coupling leak
- **Severity:** med
- **Effort:** small (~1 day)
- **Location:** `gwbase/actor_base.py:638, 665` (inferred)
- **Concern:** —
- **What:** The string `"amq.topic"` — RabbitMQ's built-in MQTT-plugin
  bridge exchange — is baked into actor code, and the public method
  `subscribe_amq_topic()` exposes the broker brand in the API surface.
  This is the one place where the choice of RabbitMQ leaks past the
  `topology.py` layer into per-actor code.
- **Fix idea:** Move the exchange name into settings (e.g.,
  `settings.wrapped_exchange = "amq.topic"`) and rename the method to
  `subscribe_wrapped()` (or `subscribe_edge_bridge()`). Preserves the
  MQTT↔AMQP seam without naming the broker in the API.
- **Why now:** Cheap, isolated, and locks no future decisions. The rename
  alone makes the seam legible.
- **Status:** open

### F-002 — Replace `pika.BasicProperties` with a neutral `MessageMetadata`
- **Type:** coupling leak
- **Severity:** med
- **Effort:** small–med (~1–2 days)
- **Location:** `gwbase/actor_base.py:675–688` (inferred)
- **Concern:** —
- **What:** Outgoing message metadata (`reply_to`, `app_id`, `type`,
  `correlation_id`) is constructed directly as `pika.BasicProperties` at the
  publish site. Other transports (NATS headers, Kafka headers, AMQP 1.0
  application-properties) carry the same conceptual sidecar in different
  envelopes; today we have no neutral representation of *what metadata the
  application actually needs*.
- **Fix idea:** Introduce a small `MessageMetadata` dataclass
  (`correlation_id`, `reply_to`, `app_id`, `category: MessageCategory`,
  optional `transport_headers: dict`). Publish/subscribe paths use the
  dataclass; the transport boundary translates to/from
  `pika.BasicProperties`. No abstract `Transport` interface yet — just one
  dataclass and two translation functions.
- **Why now:** Documents the actual metadata contract (currently implicit in
  pika types), and is the single most useful preparatory step for any
  future transport without committing to one.
- **Status:** open

### F-003 — Stand up an in-memory `MockTransport` for tests
- **Type:** test-infrastructure gap
- **Severity:** med
- **Effort:** med (~2–3 days)
- **Location:** `tests/_stubs.py`, `tests/conftest.py` (inferred)
- **Concern:** —
- **What:** All tests provision a live RabbitMQ (`declare_topology` /
  `provision_topology` call pika directly). This makes unit tests slow,
  parallelism awkward, and — most importantly — makes any future transport
  experiment expensive: there's no way to prototype a Kafka or NATS adapter
  as a weekend spike because tests can't run without Rabbit.
- **Fix idea:** Implement an in-memory broker that models queues,
  exchanges, bindings, and routing-key matching (topic wildcards `*`/`#`).
  Tests pick it via fixture. Live-Rabbit integration tests stay, but become
  a smaller, slower tier.
- **Why now:** Pays back continuously regardless of any transport decision.
  Also tightens the implicit contract about what the transport must
  provide, which is the precondition for ever swapping it.
- **Status:** open

---

## Explicitly NOT recommended right now

- **Extract a full `MessageTransport` ABC.** Premature — the actor
  framework is young, F-009 signed-handshake work is ahead of it, and
  abstracting before a second concrete implementation is in sight tends to
  fossilize the wrong interface.
- **Generalize pika callback signatures across the board.** Big surface,
  small payoff until there's a real second transport.
- **Build a second transport adapter speculatively.** Wait for a forcing
  function (scale, federation pain, or a concrete blockchain-integration
  requirement from the market-maker work).

## Area: identity & path conventions for non-GNode services

Both findings below were surfaced by the 2026-05-23/24
gridworks-journalkeeper → base 0.4.0 refactor (session bright-frost).
Journalkeeper is the test case: a service that consumes off the broker
and persists to postgres, but is **not a GNode actor** (no GNode role
on the grid, no heartbeat/time-coordinator participation). The
refactor exposed two related friction points.

### F-004 — `ActorBase` requires GNode identity even for non-GNode services

**Symptom:** `ActorBase.__init__` reads three fields (`Alias`,
`GNodeId`, `GNodeClass`) from `settings.g_node_path` on disk
(`actor_base.py:89-93`) and stores them as `self.alias` /
`self.g_node_id` / `self.g_node_class`. `GNodeSettings.g_node_path`
defaults to `/etc/gridworks/g_node.json`
(`config/g_node_settings.py:21`). A service that isn't a GNode (e.g.
journalkeeper, ear, future analytics consumers) still has to provide
a `g.node.gt`-shaped file just to construct the actor — and the on-disk
JSON is **fake**: ActorBase reads three strings and never validates
the file as a real `GNodeGt` (the full `GNodeGt` Sema type at
`sema/types/g_node_gt.py` has eight fields + five axioms, none of
which ActorBase touches). Journalkeeper had to synthesize
`{"Alias": "d1.journal.dev.bright-frost", "GNodeId": "00000…0001",
"GNodeClass": "journalkeeper"}` to get the constructor to run.

This is two problems wearing one hat: (a) the *concept* "every actor
is a GNode" is wrong, and (b) even if it were right, the file isn't
serving its stated purpose (the docstring at `actor_base.py:86` calls
it "durable GNode identity provisioned on disk as a g.node.gt JSON,"
but ActorBase doesn't use the GNode-ness — just three opaque strings).

**Tentatively proposed direction — `ServiceSettings`:**

Split the settings shape so identity scope matches base-class scope.

```python
# ServiceSettings: minimum to be an actor on the broker
class ServiceSettings(BaseSettings):
    rabbit: RabbitBrokerClient = RabbitBrokerClient()
    alias: str                  # service identity (e.g. "journalkeeper-bright-frost")
    instance_id: str | None = None  # auto-uuid per boot if None
    log_level: str = "INFO"

# GNodeSettings: extends ServiceSettings with GNode-only durable identity
class GNodeSettings(ServiceSettings):
    g_node_path: Path = Path("/etc/gridworks/g_node.json")  # for now; see F-005
    transport_class: TransportClass = TransportClass.Scada
    # alias/g_node_id/g_node_class still loaded from g_node_path on construction
```

Then:

- `ActorBase` takes `ServiceSettings`; reads `self.alias` from
  `settings.alias` directly (no file). Drops `self.g_node_id` and
  `self.g_node_class` — those are GNode-only concepts.
- `GridworksActor` takes `GNodeSettings`; loads the on-disk
  `g.node.gt` and asserts the fields. `self.g_node_id` and
  `self.g_node_class` live there.
- Existing code that subclassed `ActorBase` while passing a
  `GNodeSettings` keeps working (covariant), so this is additive.
- Caller migration is one line per subclass: change the type hint on
  `settings` if the service is non-GNode.

Notes on the proposal — needs more thought:

- The FIS handshake sends `client_properties` derived from
  `g_node_id` / `g_node_class`. Does FIS care if those are absent for
  a non-GNode service, or do we want a separate non-GNode handshake?
- `queue_name = self.alias + adder` (`actor_base.py:103-104`) still
  works for any alias; no change needed.
- `TransportClass` belongs on `GNodeSettings`, not `ServiceSettings`
  — a non-GNode service doesn't have a TransportClass at all (it
  isn't one of the listed GNode roles).

Alternatives we considered and rejected:

- *Make `g_node_path: Path | None`.* Solves the file requirement but
  not the conceptual lie (the GNodeId/GNodeClass storage on every
  actor remains as a half-populated artifact for non-GNode actors).
- *Read identity from env vars only, no file.* Loses the
  "out-of-band durable provisioning" property that the file form
  gives prod ops for GNodes. Worth keeping for `GridworksActor`.

### F-005 — Hardcoded `/etc/gridworks/` path doesn't follow XDG; proactor already has the right shape

**Symptom:** `GNodeSettings.g_node_path` defaults to
`/etc/gridworks/g_node.json` (`config/g_node_settings.py:21`).
System-level path, requires root to provision, doesn't follow the
XDG Base Directory spec, and doesn't compose with per-service config
directories. Compare to `gridworks-proactor`'s `Paths` class
(`gwproactor/config/paths.py:70-185`), which already implements the
right pattern for scada and other proactor-based services:

- `base = "gridworks"`, `name = "scada"` (or other service name)
- `config_dir = xdg.xdg_config_home() / base / name` → typically
  `~/.config/gridworks/scada/`
- `data_dir`, `state_home`, `log_dir`, `event_dir`, `certs_dir`,
  `hardware_layout` all cascade from those three.
- Test fixtures override one root (XDG_CONFIG_HOME) and everything
  else moves together
  (`gwproactor_test/clean.py:116`).
- Per-service customization via the `name=` argument.

The proactor `Paths` model is good and **the indirection earns its
keep** — separating XDG roots from service-relative offsets makes
test isolation trivial, and the all-paths-in-one-place self-documents
which files the service touches. The thing to fix is just that
**gridworks-base doesn't share it**, so anything based on
`gwbase.ActorBase` (rather than `gwproactor`) reverts to ad-hoc
absolute paths.

**Tentatively proposed direction:**

Lift `Paths` (or an equivalent) into `gridworks-base`. Then:

- `GNodeSettings.g_node_path` default becomes
  `paths.config_dir / "g_node.json"` — under
  `~/.config/gridworks/<service>/g_node.json` rather than
  `/etc/gridworks/g_node.json`.
- `ServiceSettings` (from F-004) carries `paths: Paths = Paths(name=<service>)`
  so non-GNode services land in `~/.config/gridworks/<service>/` too.
- `proactor` continues to use the same `Paths`, either by importing
  from gwbase or by gwbase taking the abstraction and proactor
  consuming it (single source of truth).

Open question: where does the abstraction live? Three options:

1. **In gridworks-base.** Adds an `xdg` dependency to base. Most
   natural home — base is the foundation everyone consumes.
2. **In a new tiny shared package** (`gw-paths` or similar). Avoids
   adding xdg to base for services that don't need it; but a new
   package just for path conventions is overkill.
3. **Keep it in proactor; have base import proactor.** Inverts the
   dependency direction (today proactor consumes base, not the
   other way). Probably wrong.

Option 1 looks best to me. The xdg dep is tiny and every gw service
already uses paths.

**Together F-004 + F-005 land:**

```python
# Today (broken for non-GNodes, system-path for everyone)
class GNodeSettings(BaseSettings):
    rabbit: RabbitBrokerClient = ...
    g_node_path: Path = Path("/etc/gridworks/g_node.json")
    transport_class: TransportClass = TransportClass.Scada
    log_level: str = "INFO"

# Proposed (non-GNode-friendly + XDG-aligned)
class ServiceSettings(BaseSettings):
    rabbit: RabbitBrokerClient = ...
    paths: Paths = Paths()  # name overrideable per service
    alias: str
    log_level: str = "INFO"

class GNodeSettings(ServiceSettings):
    g_node_path: Path = ""  # validator: paths.config_dir / "g_node.json"
    transport_class: TransportClass = TransportClass.Scada
```

ActorBase consumes `ServiceSettings`; GridworksActor consumes
`GNodeSettings`. Journalkeeper (and ear, future consumers) inherits
`ServiceSettings` cleanly with no fake GNode identity.

### F-007 — `RoutingClass` enum doesn't match production wire conventions

**Symptom:** ActorBase 0.4.0's registered `RoutingClass` set is
`['ta', 'cn', 'ltn', 'mm', 'scada', 'price', 'weather', 'time',
'super']`. Production routing keys use **`ws`** for the weather
service and **`s`** for what looks like "scada-short" — neither
appears in the registered set. Concrete prod examples observed
during the 2026-05-24 journalkeeper-on-base-0.4.0 prod-broker
integration test (`wiki/gridworks-journalkeeper/research/refactor-to-base-0.4.2.md`):

- `rjb.hw1-isone-ws.ws.weather` — weather service broadcast,
  every ~10 minutes
- `gw.<scada-alias>.to.s.gridworks-ping` — wrapped ping addressed
  to scada-short, fires constantly
- `gw.<scada-alias>.to.s.slow-contract-heartbeat` — heartbeat
- `gw.<scada-alias>.to.s.gridworks-ack` — acks

Every one of these gets dropped at ActorBase's parse step with
"Unknown routing class". In a 5-minute prod run, 48 messages were
dropped this way — and weather messages (which fire every ~10
minutes per the operator) were never captured even once across two
runs totaling > 5 minutes inside the expected window.

The bug isn't in production: production traffic predates this
ActorBase 0.4.0 codification and uses its established short forms.
The bug is that the codification only enumerates the long forms.

**Tentatively proposed direction:**

Either (a) add the short forms as aliases in the `RoutingClass`
enum (`ws` aliases `weather`; `s` aliases `scada`; maybe others
once their producers are identified), or (b) migrate production to
the long forms (a breaking wire change affecting every existing
deployment — far larger blast radius).

(a) is the obvious move. Audit production routing keys (via the
mgmt API or by widening a journalkeeper consumer) to enumerate
the actual short-form set, then extend the enum to accept both.
Routing-key build functions can keep emitting the long forms; only
the parse needs to be tolerant.

**Discovery note:** this finding was only visible because the
prod-broker run bound `#` (catch-all) on `ear_tx` — production
journalkeeper at `hw1.isone.journal-F6c6` binds narrow keys
(`#.atn-bid`, `#.energy-instruction`, …) so it never sees these
drops. Worth re-checking with a wider audit binding before the
gwbase migration of the LTN (Stage 1 of
`wiki/gridworks-ltn/executor/primary.md`'s cleanup epic), because
the LTN's wire vocabulary likely uses some of these short forms.

### F-006 — Initialization JSON is a boundary; `g_node.json` should be Sema-validated there

**Principle:** every JSON file loaded into the runtime at startup
crosses a trust boundary — its contents come from disk (or env, or
the network) and the only thing standing between a typo / malformed
provisioning / drifted schema and a confusing mid-run crash is
**boundary validation**. Sema types exist exactly for this. Any
init-JSON the runtime depends on should be parsed *via the matching
Sema type*, not via raw `json.loads` + dict-key access.

**Concrete instance — `g_node.json`:**

`ActorBase.__init__` does `json.loads(settings.g_node_path.read_text())`
and then `g_node_data["Alias"]`, `g_node_data["GNodeId"]`,
`g_node_data["GNodeClass"]` (`actor_base.py:89-93`). The full
`GNodeGt` Sema type (`sema/types/g_node_gt.py`) has eight fields
plus five axioms — including "Alias ends with `.scada` iff GNodeClass
is Scada," "GNodeClass is non-empty and whitespace-free," and
"Physical GNodes (non-Logical) must have a PositionPointId." None of
these are enforced at boundary today. Failure modes that get past
ActorBase silently:

- Typo'd JSON key (`"alias"` instead of `"Alias"`) → KeyError mid-run
  with no schema context.
- `GNodeClass = "Scada"` with `Alias = "d1.journal"` (no `.scada`
  suffix) → ActorBase happily constructs; the misalignment surfaces
  when something downstream cares.
- Missing `BaseClass` / `Status` (required in GNodeGt) → not noticed.
- Drifted file from an old schema version → not noticed.

The journalkeeper-on-base-0.4.0 refactor (this finding's source) used
a hand-synthesized `g_node.json` with exactly the three fields
ActorBase reads. That file would **fail** real `GNodeGt` validation
(missing `BaseClass`, `Status`, `TypeName`, `Version`). That's the
point: if the boundary were Sema-validated, the contradiction this
service hits — "I'm not a GNode but I'm presenting a fake
g_node.json" — would be caught at construction time and force the
F-004 (`ServiceSettings`) split that's actually correct.

**Proposed direction:**

```python
# In ActorBase.__init__ (after F-004 split: only for GridworksActor):
from gwbase.sema import SemaCodec, GNodeGt

g_node_data = json.loads(settings.g_node_path.read_text())
sema_obj = SemaCodec().from_dict(g_node_data, mode="strict")
if not isinstance(sema_obj, GNodeGt):
    raise ValueError(
        f"g_node.json at {settings.g_node_path} is not a valid GNodeGt: "
        f"got {type(sema_obj).__name__}"
    )
self.alias = sema_obj.alias
self.g_node_id = sema_obj.g_node_id
self.g_node_class = sema_obj.g_node_class
```

The principle generalizes. Other init-JSON instances worth auditing:

- `hardware-layout.json` (scada / proactor) — loaded at startup, drives
  actor topology, no Sema type that I could find. Probably should be
  one. (Cross-cutting with F-005 / proactor `Paths`.)
- Any `.env`-style file that goes through pydantic-settings already
  has typed validation, so those are fine — pydantic is the boundary
  enforcer there.

**Interaction with F-004 / F-005:**

The three findings interlock. Solved together:

- F-004 (`ServiceSettings`) — non-GNode services don't carry GNode
  identity at all.
- F-005 (XDG `Paths`) — `g_node.json` lives at
  `~/.config/gridworks/<service>/g_node.json`, not
  `/etc/gridworks/g_node.json`.
- F-006 (Sema validation) — the file at that path is parsed AS a
  `GNodeGt`, with axiom enforcement, and only by `GridworksActor`.

The fake `g_node.json` hack journalkeeper uses today wouldn't be
necessary, wouldn't pass the boundary check if it were, and wouldn't
*exist* once `ServiceSettings` is the correct base.
