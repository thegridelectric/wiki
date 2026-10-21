# GridWorks — working conventions for Claude

Status: Accepted · Pass 2 · Updated 2026-10-18

Paths are relative to the umbrella dir, the parent of `wiki/` and the sibling
code repos. The wiki is the entry point: `wiki/README.md`.

## Bearings (held at every altitude)

True in every session, whatever the Focus. One line each; full text at the
pointer.

- **The ambition:** a codebase that carries the vision by next winter
  (2026–27); 6 → 20 → 100 homes; none of it about expected outcome or
  accruing money or power. Full statement:
  [`wiki/vision/primary.md`](wiki/vision/primary.md) "The ambition".
- **Clear and present:** launch the **MarketMaker** and **Sema** before the
  next heating season; the hundred homes set this year's requirements and
  come first.
- **Operating stance:** align to the ambition; push back when the focus runs
  too small; plain working prose.
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

**Focus shorthand resolves to a design file first.** Kebab-case the words
and look in `wiki/designs/`, `wiki/<domain>/designs/` and hub folders; the
lookup and the spoke-naming rule are in
[`designs-process.md`](designs-process.md) "Focus shorthand". If all miss,
list candidates and ask; don't guess.

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
- **Sema:** before ANY sema edit, Read [`sema-CLAUDE.md`](sema-CLAUDE.md)
  and follow it: spec first with a read-receipt, spec change-controlled,
  registry rules. Any session kind takes it with `--include-sema`.
- **Executor:** before writing or editing any `wiki/<domain>/executor/`
  file, Read [`wiki/conventions/executor-CLAUDE.md`](executor-CLAUDE.md),
  the recipe: the bar (a rebuild from the executor plus the vocabulary
  alone), the tables, the prose rules, the trace iteration, the
  adversarial pass. A session whose Focus is an executor starts with
  `wiki/tools/build-executor.sh`, which appends it.
- **Scada:** before editing `gridworks-scada` (gwsproto above all), Read
  [`scada-CLAUDE.md`](scada-CLAUDE.md) and follow it. A session whose
  Focus is scada starts with `wiki/tools/scada.sh`, which appends it.
- **Session scripts:** `wiki/tools/session.sh <base|executor|scada>
  [--include-sema] [claude args]` starts a session with the matching
  protocol file(s) appended and permissions skipped; `base.sh`,
  `build-executor.sh` (always with sema) and `scada.sh` are its wrappers.

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
- **Dev broker = local `gw-dev-rabbit`**, one container, both faces:
  AMQP `localhost:5672` for gwbase actors, MQTT `localhost:1885` for the
  scada (TLS off; topic dots become slashes), mgmt UI `15672`. Creds live
  in each repo's `.env`; never hardcode them.
- **Journal DB first; eventstore by hand.** Consumers read fleet
  emissions from the journal DB (readings tables + `gridworks.messages`
  payloads, decoded through the codec). The S3 eventstore is the deep
  archive with more than the journal (unjournaled types, older windows):
  consult it by hand, and keep no S3 fallback code in pull paths until a
  consumer concretely needs an S3-only type. Session access is
  `DB_ANALYST_URL` in `experiments/.env`; how to pull is
  `experiments/spot-check-recipe.md`.
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
  another service does with it; such claims go stale silently. Illustrations
  ("e.g., journalkeeper") are fine; declarations live in the wiki or in the
  repo whose behavior they describe.
- **Sema is mandatory at every durable-data and inter-app boundary.**
  Whenever code uses or generates durable data, or communicates with
  another GridWorks app, it MUST speak sema: instances constructed and
  decoded through the generated snapshot classes, never hand-built dicts,
  never meaning read off database columns, filename conventions, or
  hand-kept copies. The default Python idiom (dicts, bare `str`,
  `hasattr`) reasserts itself where sema is the *medium* rather than the
  subject (pullers, emitters, display tooling), so counter it
  structurally: vendor the snapshot BEFORE the first consumer line;
  property formats, never bare `str`, wherever the value is
  vocabulary-shaped; dispatch with `isinstance`, never `hasattr`; narrow
  every codec decode (`expect=` or `assert isinstance`); pyright in the
  repo's ci.sh. Where no word covers a fact yet, hand-code it WITH a note
  naming the missing word that retires it, and "no word" is a checked
  fact: search `sema/definitions/` first. The tell that vocabulary is
  missing or unused: code that scrapes or hand-maps instead of looking up.
- **Sema gravity applies below the word layer.** Interior structures
  with no word yet (result files, analysis intermediates, provenance
  records) follow the same discipline one level down: every record is a
  typed structure (`NamedTuple` or equivalent) with a docstring; dict
  form appears once, at the serialization boundary. Property formats
  attach wherever a value is vocabulary-shaped: record fields, mapping
  keys, module constants (validated through a `TypeAdapter` at load).
  Timestamps take the coarsest sufficient time format (`UTCSeconds` when
  seconds are enough), never bare epoch floats. A boundary validator
  returns the format type, not `str`. Each such record names the missing
  word that retires it.
- **Context is a budget: read sections, not files.** A file over ~300
  lines is never read whole for orientation, even when the ask says "read
  X": list its `##` headers, read the stamp, the "what this is" line and
  the sections the Focus names, and say which were skipped. Asked to read
  a huge file end to end, push back with its line count and section list.
- **Harness and log output comes back as a verdict, not a transcript.**
  Run suites and harnesses with stdout to a file and return ONE line
  (PASS/ABORT, counts, the file path). Grep a log with a line cap, never
  dump it. A run that must be read closely goes to a subagent that returns
  the conclusion.
- **No dead code, no assumed defaults** — when a refactor orphans a symbol,
  delete it in the same change. Do not introduce a default that hides a value
  the caller must declare — make it required, sourced from a `names` constant.
- **Prod boxes run committed code only.** NEVER scp/edit uncommitted
  content into a repo checkout on a deployed box, not even "the same file
  that's about to be committed". The only path onto a box is commit →
  push → pull on the box; a hand-deploy dirties the prod tree and breaks
  the box-runs-a-pushed-SHA guarantee (gwbase executor
  `service-deployment.md`, which also covers full clones and the `main`
  norm). Non-repo box state (a sudoers drop-in, a `.bashrc` line) is fine
  to place directly but MUST be recorded in the box's instance-README.
- **Box and journal-DB operations start in gridworks-infra.** Before
  deploying, restarting, migrating or picking a DB login, read the box's
  `gridworks-infra/<box>/instance-README.md` and, for the journal DB,
  `gridworks-infra/databases/journaldb.md`. Not the box itself, the wiki
  or `~/.ssh/config`.
- **A TLS cert belongs to one program.** Each client cert on a box is the
  identity of the one service deployed to use it; the FIS gate leases that
  identity to one running instance, and any other process presenting the
  cert supersedes the deployed service, which is then refused for life.
  NEVER load a cert, or a `.env` that names one, into anything but its own
  program without asking the human first; a listener or experiment gets its
  own principal and cert, minted with consent.
- **In-field pico firmware upgrades are allowed this year and will be
  retired before scaling.** Build nothing durable on the upgrade path (the
  `code-update` post): no sema word, spec or scada feature depends on it.

- **Sema-typed JSON filenames** are dash-separated fields, each internally
  LeftRightDot, ordered `<subject>-<condition?>-<type.name>-<version>.json`
  (the S3 eventstore key grammar; a spaceheat.name subject swaps dashes to
  dots). TypeName verbatim, dots preserved, never underscores; dot/underscore
  conversion belongs at the code boundary only.

## Experiment-Driven Design (EDD) — the verification bar

Confidence comes from **experiments in close-to-real-world conditions** (a
real broker, real or sped-up timing), not from code analysis or in-process
unit tests, which share a backdoor transport and a wall clock and go green
while real-world behavior stays invisible. A spec reaches `Verified` only
when an experiment tests it against reality; the harness stays as the
re-runnable reproducer and `Reviewed` points at it. Rhythm:
[`working-with-llms.md`](working-with-llms.md#the-edd-working-rhythm--capture-refactor-re-orient).

**Every design hub self-declares EDD-or-not** on the line under its
`Status:` stamp: `**EDD: yes**` / `**EDD: no**` + the verifying clause.
`yes` when confidence comes from an experiment; `no` for build-out work
(migration, integration, refactor), verified by the suite + the key test.

**A field bug gets its local test first.** A bug found running live SHALL
get a local test that reproduces it and fails before the fix goes in. Where
no local test can reach the bug, the missing simulation (a settable sim
pin, a sim driver value) is the first change. A fault the scada can know
before any relay actuates fails the boot. A fault it can only learn after
actuation has begun (a pico's params arrive seconds after the cycler
toggles the 5 V bus) is a glitch, and the test asserts the glitch.

## Commit suggestions

Human does all `git commit`s; I suggest at logical units (path-scoped
`git add` + a one-line message) and never `git add -A` while other sessions
may be live (mirror my active-claims Scope). Code-repo commits are
title-only; the diff is the authoritative what.

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

**Read the diff for context-dependent prose before suggesting a commit.**
Docstrings, comments, field descriptions and sema word prose SHALL state
what is, now. Sweep every changed file for transition narrative ("used to",
"was X, now Y", "no longer", dated asides), rationale that only makes sense
against the old code, and enumerations of things that will move (the
readers of a field, the consumers of a message). Rewrite each to present
tense and to the thing's own meaning; the why goes in the changelog entry,
the list goes nowhere (the code is the list).

**Before proposing a code change, scan the docstrings in the changed files
and the repo README against [`documentation.md`](documentation.md) and refactor
what fails or went stale.**

## Working-tree hygiene

- One **cluster** of code-repo edits = one pending changelog entry
  (`<!-- pending commit -->`) in `wiki/<domain>/changelog.md`. Wiki edits
  are not cluster-checked; cross-cutting wiki folders have no changelog.
- Hooks in `tools/` enforce this. When one fires: cache the in-flight plan
  to a scratch note, surface the state; disposition is the user's.
- Before more than ~5 file edits in one cycle, ask whether to enable
  `bulk-on`; the user creates the override file, I MUST NOT.

## Linear

- **Keep Linear and wiki in sync** at session start and after Linear-UI
  edits: bijection sweep + `tools/linear-snapshot.sh`
  ([`linear.md`](linear.md) "Keeping in sync"). The wiki file is the
  canonical slug.
- **Log hours on completion**: an hours note on the issue (total +
  per-day) AND a Harvest entry (`hv`). Confirm hours with the user before
  posting to Harvest; it is billable.
- **Labels: call `list_issue_labels` on every create**, never from memory.
  Tag at minimum component/domain AND work-kind; axes and semantics in
  [`linear.md`](linear.md).
- **No issue-to-issue relations.** The human curates the graph; I MAY
  remove one when asked. Dependencies go in the description prose.
- **Shared-dependency work gets its own flat issue + design**, never a
  sub-issue; dependents name it in prose. Scope it as one coherent
  closeable unit.

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

**Structure.** Each `wiki/<domain>/` holds `research/` (pre-spec, not
normative), `executor/` (the faithful-rebuild spec: complete enough to
rebuild the domain from docs alone) and `changelog.md` (one entry per
code-repo commit; git is the *what*, the changelog the *why*). Every
`executor/` hub is a short `primary.md` (≤ ~300L: overview, invariants,
glossary, TOC); sub-specs one concern each (~300–500L); no doc over 1000L.
A repo with code but a poor `executor/` gets its `primary.md` to that
minimum first, the rest "Open".

**Living-spec discipline.** After each task, reconcile the relevant
sub-spec with what you built; touch executor `primary.md` only for
cross-cutting changes. A spec may say "Open": short and current beats long
and speculative. **When the user commits, ALWAYS add the matching
`changelog.md` entry before considering the work done**, verified against
`git show`, not memory; date and title mirror the commit. Pending entries
(`<!-- pending commit -->`) only when the next planned commit is in the
code repo.

**Where content lives**: open questions → `explorations/`; settled
patterns → `executor/`; ratified change plans → `designs/`; workflow
state → Linear ([`glossary.md`](glossary.md) "Where content lives").

**Design-specs (`designs/`)** have one fixed location each
(`wiki/<domain>/designs/<slug>.md` or `wiki/designs/<slug>.md`) and never
move. **Linear is the authority on status.** On completion, distill into
`executor/`, delete the design file, finalize the issue. **Designs are
ephemeral, so NOTHING may link to or name a design file** (sole exception:
[`DESIGN_INDEX.md`](../DESIGN_INDEX.md)); reference work by its Linear
issue. Full convention: [`designs-process.md`](designs-process.md).

**Implementation gate.** No code-repo edits in a design's scope until EVERY
spoke is `Accepted` with `Pass ≥ 1`. Writing code against a Draft spec is
the antipattern this prevents.

**Write boundary.** Code repos are authoritative for the *what*, `wiki/`
for the *why* and specs. Confirm before editing a code repo's non-wiki
files when the task is documentation.

**Repos do not know about the wiki.** A code repo's README, comments,
docstrings and configs SHALL NOT cite wiki paths, executor specs or design
names; a repo README stands alone for a human. The wiki points at code
(`file:line`); code never points back. Exempt: the wiki's own README and
any `CLAUDE.md`.

**Authoring.** Capture *why* and design intent, not a restatement of code;
pin volatile specifics with `file:line`. One canonical doc: update it,
don't duplicate; delete what's wrong. Open every doc with a one-line "what
this is".

**Durable prose earns its place by teaching the reader something they
cannot be presumed to bring or see.** Two kinds qualify: information that
exists nowhere else (decisions, intent, constraints, operational facts)
and GridWorks fundamentals (demand response as continuous transactive
load, not event curtailment; meaning living in Sema). Not industry common
knowledge, not what the artifacts in front of them already show. A
restated fundamental converges on its canonical home, never forks it.
Everything else: don't write it, delete it where found. Durable prose is
loaded into every future session, so each word costs on every read.

**Headers are reference slugs.** In spec-grade docs (`executor/`,
`sema/spec`) a `##` header is cited as `file.md "Header text"` and renaming
one moves every reference in the same change. Get the name right by
Accepted. No global section numbers.

**Durable docs state what is, now.** Transition narrative ("retired X",
"was Y, now Z", dated asides, build-step cross-references, things that
never shipped) does not belong in `executor/` or `explorations/`; the
changelog and git history are its homes. When work merges, rewrite the
section to present tense and put the what/why in the changelog entry. A
live design may track its own build status. Comparisons to *legacy*
systems are rationale, not transition; those stay.
