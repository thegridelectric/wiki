# GridWorks — working conventions for Claude

Status: Accepted · Pass 2 · Updated 2026-08-10

> Canonical at `wiki/GridWorks_CLAUDE.md`; symlink setup in
> [`README.md`](README.md#setup). Paths are relative to the umbrella dir
> (parent of `wiki/` + the sibling code repos: `gridworks-base`,
> `gridworks-scada`, `sema`, …). The wiki holds the durable thinking and the
> **rebuild specifications** for each domain — start at
> [`wiki/README.md`](wiki/README.md). Coordination before editing is under
> Multi-session.

## Bearings (held at every altitude)

True in every session, whatever the Focus. One line each; full text at the
pointer.

- **The ambition:** a codebase that carries the vision by next winter
  (2026–27); 6 → 20 → 100 homes; none of it about expected outcome or
  accruing money or power. Full statement + the clear-and-present gates:
  [`wiki/vision/primary.md`](wiki/vision/primary.md) "The ambition".
- **Clear and present:** launch the **MarketMaker** and **Sema** before the
  next heating season; **teammates' gates first** — the flexible loads
  (thermal storage, SCADA, FLO) are the ground floor of everything.
- **Operating stance:** align to the ambition; push back when the focus runs
  too small; plain working prose — the deep river runs underneath, unquoted.
  See [`wiki/vision/claude/primary.md`](wiki/vision/claude/primary.md).
- **Session mix:** gate-work · larger-picture · outside world — pick the
  lane consciously at session open, with the Focus ask.

## Source precedence (when sources conflict)

1. **Your explicit instruction, now.** Always wins. If it contradicts the
   curated wiki, flag the divergence and offer to update the wiki — never let
   the record silently drift.
2. **Verified wiki specs (`executor/`, marked `verified`) + code/tests.** In a
   `verified` domain the spec is the contract and disagreeing code is the
   suspect; in an unverified domain code/tests win and the spec is corrected.
3. **Wiki research / `converging` / `inferred` content.** A hypothesis, not
   binding.
4. **Ad-hoc research (web, one-off code reads).** Label provenance; verify
   before relying or canonizing.
5. **My own earlier statements this session.** Lowest — re-derive; do not
   anchor on what I previously said.

## Weight signals

- **musing** → not a decision; don't act, don't record.
- **canonize** → durable; I write it to the wiki.

I proactively ask to canonize at real decision points; if I can't tell which
it is, I ask.

## Multi-session coordination

Several Claude sessions edit GridWorks at once. You MUST read
[`wiki/active-claims.md`](wiki/active-claims.md) before you edit and again
before extending into a new path. The SessionStart hook auto-claims your row;
the normative protocol lives below the table in that file.

**Focus shorthand — design lookup.** A Focus stated as loose words that read
like a design name resolves to a design file before anything else. Kebab-case
the words; try both, take whichever hits:

- **Cross-cutting:** whole phrase as slug in `wiki/designs/`
  ("mtls fis auth" → `wiki/designs/mtls-fis-auth.md`).
- **Per-domain:** first word a `wiki/` domain folder ⇒ remaining words as slug
  in `wiki/<domain>/designs/` ("sema snapshot improvement" →
  `wiki/sema/designs/snapshot-improvement.md`).

Don't assume the first word is a domain. Open the match as the session's
anchor; if both miss, list candidates and ask — don't guess.

**Focus stays the design, never a spoke.** The active-claims Focus cell names
the design and holds it all session; I SHALL NOT rewrite it to a spoke. The
design is the altitude; the spoke is only where today's work is.

**On taking a design (or restructuring a hub): read the loop, summarize it
back.** First read [`designs-process.md`](designs-process.md) §"The design
loop" and §"Hub `primary.md` layout", then reflect a short summary to the
user: the hub's `EDD:` bar, the capture → refactor → re-orient rhythm, and the
rule that the hub only *points* to the active spoke (the "do this next" lives
in the spoke). Reading-then-summarizing is the gate — it proves the convention
was loaded, not worked from memory. Ephemeral coordination (session names,
"BLOCKED") stays out of design docs.

## Domain protocol files

- **Do NOT create a new `CLAUDE.md` in a sub-repo or sub-folder unless the
  human asks.** They are operative protocol and burden every future session;
  the human decides when one is warranted. LLM-facing material lives in the
  wiki.
- **Sema:** before ANY sema edit, Read `sema/spec/primary.md`. Adding or
  modifying a vocabulary word: first read the `sema/spec/registry/` and
  `sema/spec/authoring/` spokes for the kind (format / enum / type) being
  touched, then post a summary of that kind's registry, authoring,
  dependency, and axiom/projection rules and WAIT for confirmation — the
  summary proves the spec was read this session, not recalled.
  **The sema spec (`sema/spec/`) is change-controlled: ANY change to the
  spec — however small, additions included — requires discussion with the
  human before editing.** Never fold a spec edit into another change; when a
  task appears to force one, stop and raise it. Prefer moving rapidly beyond
  an exceptional case over adding exception machinery to the spec.
- **Scada:** before editing `gridworks-scada` (gwsproto above all), Read
  [`wiki/gridworks-scada/CLAUDE.md`](wiki/gridworks-scada/CLAUDE.md) and
  follow it.

## ⏳ Until the proactor port — sema words are FLAT (REVERT note)

Sema vocabulary words do NOT inherit from one another: every type schema is
flat, every field spelled out. The scada `gwsproto` base classes
(`ComponentGt`, `ComponentAttributeClassGt`, `ChannelConfigBase`) *pretend*
sema types inherit — a flaw, not a pattern to mirror. When authoring a sema
type from a gwsproto class, **flatten** the base-class fields in and reference
other sema words only by `$ref` composition. Do NOT fix the gwsproto
inheritance now — the proactor port sweeps it up. (Added 2026-06-12; remove
when that port regenerates gwsproto flat.)

## Legacy first-pass code: vision, not how

Several repos hold first-pass simulation code that never ran in reality.
Treat it as design intent, not a template: mine the *what* and *why*; do NOT
carry its *how* (transport, serialization, naming, plumbing, simulation
shortcuts). When vision and legacy code conflict, the vision wins and the old
code is the suspect. Distinguish implementation from principle: dropping the
Algorand plumbing does not drop the cryptographic-veracity /
distributed-trust principle it served — that principle is core vision.

## Engineering maxims

- **If it flaps, skip the acks** — never report on a comm path with messages
  that demand acks on that path.
- **No phantom references** — cite only durable, openable things (file paths,
  real Linear ids, commit hashes). Ephemeral session task numbers are phantom.
- **References carry a small searchable quote** — a short verbatim snippet
  under the link that the reader can paste into the source's search box.
  Quote only text actually read this session (or in a cited extraction);
  otherwise mark "quote not captured; read before citing" — never paraphrase
  inside quote marks.
- **Sema regen touches more than you changed** — bumping one type's version
  rewrites the generated runtime of unchanged referrers (versionless class ref
  rebinds; old version gets an explicit `XxxNNN` class). Expected, not a stray
  diff.
- **Sema `status` decides edit-in-place vs new version — check it first.**
  `published` is IMMUTABLE: no functional change — fields, `$ref`/dependency
  versions, axioms, constraints, `required`, enum values — ever; that takes a
  NEW version (clarifying prose is fine). `staging` and `draft` are edited IN
  PLACE; NEVER add a new version of a word whose latest is staging or draft —
  a versioned staging word forks a mutable line that every mirror, fixture
  and pin then has to be squashed back. Asked to change a published version
  in place? Refuse and propose a new version. Asked for a new version of a
  staging word? Refuse and edit in place. (Bootstrap allowance, sanctioned
  per case and NOT in `sema/spec`: a version published before June 2026 MAY
  be corrected in place when shipped wire data proves the schema wrong.)
- **Timestamps are real wall-clock, rounded to 5 minutes** — sema registry
  `created` / `metadata.last_updated` use actual current UTC (`date -u`)
  rounded to the nearest 5 min, never a placeholder. Same-sitting versions MAY
  share the stamp; `created` unique only within a type; dependency ordering
  allows equal stamps; `last_updated` ≥ every `created`.
- **Dev broker = local `gw-dev-rabbit`** — one container, both faces: gwbase
  actors over AMQP (`localhost:5672`), scada over MQTT (`localhost:1885`, TLS
  off, Rabbit MQTT plugin — topic dots become slashes; payloads intact). Mgmt
  UI `15672`. Creds live in each repo's `.env`; never hardcode them.
- **Journal DB first; eventstore by hand.** Consumers read fleet
  emissions from the journal DB (readings tables + `gridworks.messages`
  payloads, decoded through the codec). The S3 eventstore is the deep
  archive and carries MORE than the journal — message types
  JournalKeeper does not journal, and windows beyond its retention.
  Consult it by hand for those; keep no S3 fallback code in pull paths
  until a consumer concretely needs an S3-only type. Session access to the
  journal DB: `GJK_DB_URL` in `experiments/.env`.
- **HTTP surfaces follow the house API pattern** — writes ride rabbit, reads
  ride a public read-only façade; the party segment is the hyphenated
  GNodeAlias for GNode services (the service name for non-GNodes); bodies
  and responses are sema words: [`api-pattern.md`](api-pattern.md).
- **GNode aliases carry their universe as segment 0** — the first dotted
  segment names the universe (`d1`, `hw1`, `w`), the broker vhost encodes it
  (`<universe>__<run>`), and a GNode talks only on its own universe's broker.
  A cloud GNode service that is not grid topology hangs directly under the
  universe root (`d1.weather` → `hw1.weather`); market/copper nodes carry
  their place in the tree. Authority: gnr executor "Universes".
- **No cross-service declarations in a repo.** A repo SHALL NOT state what
  another service does with it ("JournalKeeper overrides this hook as a
  permanent legacy_hack") — such claims go stale silently when the other
  repo moves. The filter: is this a declaration that can go out of sync,
  or an illustration? Illustrations ("e.g., journalkeeper") are fine;
  declarations live in the wiki or in the repo whose behavior they
  describe.
- **Sema is mandatory at every durable-data and inter-app boundary.**
  Whenever code uses or generates durable data, or communicates with
  another GridWorks app, it MUST speak sema: instances constructed and
  decoded through the generated snapshot classes — never hand-built
  dicts, never meaning read off database columns, filename conventions,
  or hand-kept copies. The failure mode this rule counteracts: an LLM's
  default Python idiom (dicts, bare `str`, `hasattr`) is prior gravity,
  and it reasserts itself precisely where sema is the *medium* rather
  than the subject — pullers, emitters, display tooling. Counter it
  structurally, not by intention: vendor the snapshot BEFORE the first
  consumer line; property formats, never bare `str`, wherever the value
  is vocabulary-shaped; dispatch with `isinstance`, never `hasattr`;
  narrow every codec decode (`expect=` or `assert isinstance`); pyright
  in the repo's ci.sh (the sema-aligned hook reminds at write time).
  Where no word covers a fact yet, hand-code it WITH a note naming the
  missing word that retires it — and "no word" is a checked fact, not
  an assumption: search the registry (`sema/definitions/`) first, since
  a word that exists gets vendored into the snapshot seed, never noted
  around. The tell that vocabulary is missing or unused: code that
  scrapes or hand-maps instead of looking up.
- **Sema gravity applies below the word layer.** Interior structures
  with no word yet — kind-specific result files, analysis
  intermediates, provenance records — follow the same discipline one
  level down. Every record is a typed structure (`NamedTuple` or
  equivalent) with a docstring saying what its fields hold; ad-hoc
  dict records are the antipattern, and dict form appears once, at
  the serialization boundary (`to_jsonable`/`to_dict`). Homogeneous
  mappings of typed values are fine. Property formats attach wherever
  a value is vocabulary-shaped — record fields, mapping keys, and
  module constants alike (`dict[LeftRightDot, WindowReport]`;
  constants validated through a `TypeAdapter` at load). Timestamps
  take the coarsest sufficient time format (`UTCSeconds` when seconds
  are enough), never bare epoch floats. A boundary validator SHALL
  return the format type: validating and then returning `str` strips
  the type at every call site. Each such record carries the note
  naming the missing word that retires it.
- **No dead code, no assumed defaults** — when a refactor orphans a symbol,
  delete it in the same change. Do not introduce a default that hides a value
  the caller must declare — make it required, sourced from a `names` constant.
- **Prod boxes run committed code only.** NEVER scp/edit uncommitted content
  into a repo checkout on a deployed box — not even "the same file that's
  about to be committed". The only path onto a box is land-in-git → push →
  pull on the box. Hand-deploys dirty the prod tree, block the next pull,
  and break the box-runs-a-pushed-SHA guarantee (gwbase executor
  `service-deployment.md`).
  Non-repo box state (a sudoers drop-in, a `.bashrc` line) is fine to place
  directly but MUST be recorded in the box's instance-README.

## Experiment-Driven Design (EDD) — the verification bar

Confidence comes from **experiments in close-to-real-world conditions** — a
real broker, real (or sped-up) timing — not from code analysis or in-process
unit tests. In-code tests are necessary, not sufficient: they share a backdoor
transport and a wall clock and go green while real-world behavior stays
invisible. A spec reaches `Verified` only when an experiment tests it against
reality. Keep the harness as a re-runnable reproducer (the evidence behind the
stamp); distill findings into scoped Verified claims with `Reviewed` pointing
at the experiment. Framework + conventions: the simulated-test-environment
design (`wiki/gridworks-scada/`); working rhythm:
[`working-with-llms.md`](working-with-llms.md#the-edd-working-rhythm--capture-refactor-re-orient).

**Every design hub self-declares EDD-or-not** on one line directly under the
`Status:` stamp — bold `**EDD: yes**` / `**EDD: no**` + the verifying clause,
no separator hyphen:

> **EDD: yes** the X harness *is* the verification; spokes reach Verified only
> when an experiment runs against it (`experiments/…`).

`yes` when confidence comes from an experiment; `no` for build-out work
(migration, integration, refactor), verified by the suite + the key test —
only the verification bar differs.

## Commit suggestions

Human does all `git commit`s; I suggest at logical units (path-scoped
`git add` + a one-line message) and never `git add -A` while other sessions
may be live (mirror my active-claims Scope).

## ⏳ scada renovation — logical-unit commits SUSPENDED there (REMOVE when the epic merges)

During the `jm/spruce-unlimbo` renovation, `gridworks-scada` changes land as
large multi-concern commits: the work is too interdependent to carve (one
file carries several concerns) and the branch is off `main`. The suite stays
green at each landing and the changelog still records what/why. Scada only;
every other repo keeps the logical-unit rule.

**Run the repo's CI entrypoint before suggesting a code-repo commit** — the
full gate (`ci.sh` or documented equivalent: lint, format, drift/codegen
checks), not just `pytest`; green `pytest` with red `ruff` still fails CI.
(`gridworks-base/ci.sh` needs the dev broker on `localhost:5672`.) No script ⇒
run the tests.

**Never edit or commit on a code repo's `dev`/`main`/`master`.** Cut a
`jm/<topic>` branch first, always — enforced by two hard-deny hooks
(`precheck-protected-branch.sh`, `precheck-protected-branch-git.sh`). The wiki
is exempt (main is normal). Check `git -C <repo> branch --show-current` before
any first edit in a repo.

## Working-tree hygiene

Code-repo edits are organised into **clusters**: one pending changelog entry
(`<!-- pending commit -->`) in `wiki/<domain>/changelog.md` = one cluster.
Wiki changes are not cluster-checked. Changelogs are per-domain ONLY —
cross-cutting wiki folders (`wiki/designs/`, `wiki/tests/`, `wiki/tools/`)
SHALL NOT have one; wiki-convention changes live in git history. Enforced by
hooks in `tools/` (`precheck-pending-changelog.sh`,
`precheck-claim-on-dirty.sh`, `precheck-bulk-on-dirty-tree.sh`,
`stop-cluster-coherence.sh`). If a hook fires: cache the in-flight plan to a
scratch note, surface the state; disposition is the user's. Before more than
~5 file edits in one cycle, ask whether to enable `bulk-on`; the user creates
the `~/.claude/.bulk-stop-override(.<session>)` file — I MUST NOT create it.

## Linear

**Keep Linear ↔ wiki in sync** — reconcile at session start and after
Linear-UI edits: bijection sweep + `tools/linear-snapshot.sh`; routine in
[`linear.md`](linear.md) "Keeping in sync". Renames touch both sides; the
wiki file is the canonical slug.

**Log hours on completion** — substantial task/design wraps get an hours note
on the Linear issue (total + per-day) AND a Harvest entry (`hv` workflow).
Confirm hours with the user before posting to Harvest — it's billable.

**Labels: reflect on every create, not from memory.** Call
`list_issue_labels` (Ops) each time; the live Linear set is the source of
truth. Tag at minimum component/domain AND work-kind (single-axis tagging is
the defect this rule prevents). The five axes + label semantics + when to
coin a new label: [`linear.md`](linear.md).

**No issue-to-issue relations.** I SHALL NOT add `blocks`/`blockedBy`/
`relatedTo`/`duplicateOf` or any other relation, via MCP or otherwise; the
human curates the graph (I MAY remove one when asked). Dependencies and
context go in the issue description prose.

**Shared-dependency work earns its own flat Linear issue.** Work depended on
by two or more larger designs becomes its own issue + design — never a
sub-issue; dependents name it in description prose. Scope it generously
enough to absorb honest creep — one coherent closeable unit, not a litter of
tiny issues.

## Status stamps

Every non-trivial wiki doc opens with:

`Status: <maturity> · Pass <n> · Updated <date>[ · Reviewed <date>@<commit>]`

- **Maturity** `Draft → Accepted → Verified` — the authority dial for Source
  precedence. `Verified` = validated against reality; `Reviewed` (date +
  commit) records the check. `Verified`-but-stale ⇒ re-verify before relying,
  then bump. `Accepted` docs stay living, kept current by freshness.
- **Pass `n`** — count of human–LLM review passes; `Pass 0` = Claude-solo.
  Increments ONLY when the user says so.
- **The doc-level stamp is a floor.** A `##` section MAY carry its own stamp
  only when *more* mature than the doc (else demote the doc); never deeper
  than `##`.

Exemptions + enforcement: `wiki/tests/test_doc_health.py`.

## Wiki essentials (the wiki's authoring conventions)

**Structure** — each `wiki/<domain>/` holds `research/` (pre-spec, not
normative), `executor/` (the faithful-rebuild spec — complete enough to
rebuild the domain from docs alone), and `changelog.md` (one entry per
corresponding code-repo commit; git = the *what*, changelog = the *why*).

**Hub-and-spoke** — every `executor/` hub is `primary.md`, short
(≤ ~250–300L): overview, cross-cutting invariants, glossary, TOC. Sub-specs
one concern each (~300–500L). No doc exceeds 1000L — split it.

**Living-spec discipline (while coding):**

- After each task, reconcile the relevant sub-spec with what you built —
  resolve "Open" markers, fix divergences; touch executor `primary.md` only
  for cross-cutting changes.
- **When the user lands a commit, ALWAYS add the matching `changelog.md`
  entry before considering the work done.**
- A spec may say "Open" — short, honest, current beats long and speculative.
- Holistic consistency pass at milestones.

**Commit + changelog convention:**

- Code-repo commits are **title-only**; the diff is the authoritative what.
- The changelog entry carries a brief what + the why; date + title mirror the
  commit.
- **Verify every changelog entry against the actual diff** (`git show`), not
  memory.
- Pending entries (`<!-- pending commit -->`) ONLY when the next planned
  commit is in the code repo; wiki-only edits earn none.

**Where to start** — a repo with substantial code but a poor `executor/`
gets its `primary.md` to an acceptable minimum first (overview + invariants +
glossary + TOC, rest "Open"); depth later.

**Where content lives** — canonical disambiguation in
[`glossary.md`](glossary.md) "Where content lives". The discriminator is
clarity: open questions → `explorations/`; settled patterns → `executor/`;
ratified change plans (full content) → `designs/`; workflow state → Linear.

**Design-specs (`designs/`)** — one fixed location per design
(`wiki/<domain>/designs/<slug>.md` or cross-cutting `wiki/designs/<slug>.md`);
files never move as status changes. **Linear is the authority on status**:
designs are Ops-team issues tagged `design`, created with assignee, state,
and priority set (hook-enforced). **cap-8** = personal WIP limit: at most 8
issues assigned to me in a started state. Every design file carries a stamp;
`Accepted` requires `Pass ≥ 1` and `· Linear: <id>` in the stamp
(doc-health-enforced). **On completion:** distill the durable content into
`executor/`; delete the design file; finalize the issue (strip the design
link, short final-writeup comment, Done). **Designs are ephemeral, so
NOTHING may link to or name a design file** (sole exception:
[`DESIGN_INDEX.md`](DESIGN_INDEX.md)); reference other work by its **Linear
issue**, where relationship narrative (depends-on, sequencing, supersedes)
also lives. Full convention: [`designs-process.md`](designs-process.md);
Linear interface: [`linear.md`](linear.md).

**Implementation gate** — no code-repo edits in a design's scope until EVERY
spoke (`primary.md` + all sub-specs) is `Accepted` with `Pass ≥ 1`. Hub >
spoke maturity is fine while drafting; the gate is where everything
converges. Writing code against a Draft spec is the antipattern this
prevents.

**Write boundary** — code repos are authoritative for the *what*; `wiki/` for
*why* + specs. Confirm before editing a code repo's non-wiki files when the
task is documentation.

**Repos do not know about the wiki.** The only references to wiki files
are in the wiki itself: a code repo's `README.md`, source comments,
docstrings, and configs SHALL NOT cite wiki paths, executor specs, or
design names. A repo's `README.md` additionally stands alone for a human.
Exempt: the wiki's own README and any `CLAUDE.md` (Claude-facing). The
wiki points at code (`file:line`); code never points back.

**Authoring** — capture *why* + design intent, not a restatement of code; pin
volatile specifics with `file:line`. One canonical doc — update it, don't
duplicate; delete what's wrong. Open every doc with a one-line "what this is".

**Durable prose earns its place by teaching the reader something they cannot
be presumed to bring or see** — not industry common knowledge, not what the
artifacts in front of them already show. Two kinds qualify: information that
exists nowhere else (decisions, intent, constraints, operational facts), and
GridWorks fundamentals (demand response as continuous transactive load, not
event curtailment; meaning living in Sema). The measure is the reader, not
the corpus: this is not DRY, though a restated fundamental converges on its
canonical home, never forks it. Everything else: don't write it; delete it
where found. And "omit needless words" — durable prose is loaded into every
future session, so each word costs tokens on every read.

**Headers are reference slugs.** In canonized locations (`executor/`,
`sema/spec`, other spec-grade docs) a `##` header is a near-immutable
reference slug: cite it as `file.md "Header text"`. Renaming one is a known
major cost — every reference (wiki, designs, protocol files) moves in the
same change. Get the name right by Accepted; deeper headers carry no such
weight. No global section numbers.

**Durable docs state what is, now.** Transition narrative — "retired X",
"was Y, now Z", dated "settled/canonized" asides, build-step
cross-references, or any mention of a thing that never shipped — does not
belong in `executor/` or `explorations/`; the domain `changelog.md` and git
history are its only homes. When work lands, rewrite the affected section to
present tense and put the what/why of the change in the changelog entry. A
design may track its own build status (✅/◐) while alive — designs are
deleted on completion. Comparisons to *legacy* systems are rationale, not
transition; those stay.

**Voice** — wiki prose is the developers' voice: plain sentences the team
can align to. DO NOT use the AI-cadence drumroll — an em-dash setup resolved
by a punchy verdict fragment ("there are only two honest options — X, or Y.
No incremental third path."). Same family, also banned: ", full stop", "— X
edition", one-fragment verdict sentences, antithesis flourishes ("saves
bytes, never trust"). Say the thing as an ordinary sentence. A developer's
verbatim phrases stay verbatim. Do NOT attribute notes or decisions to a
developer by name/date — no "(<name>, 2026-06-14)", no "<name>'s bar"; wiki
prose is the project's settled voice. A bare date is fine when useful; the
name is not.

**Sema-typed JSON files** — on-disk instance filenames are dash-separated
fields, each field internally LeftRightDot (a spaceheat.name subject swaps
dashes→dots), ordered `<subject>-<condition?>-<type.name>-<version>.json` —
the S3 eventstore key grammar; parsing is a bare split on dash
(`zone1.bedrooms.gw.microvolts-gw.channel.jump.stats-000.json`). TypeName
verbatim, dots preserved — never underscores. Dot↔underscore belongs at the
code boundary only (`g_node_gt.py` stays snake).
