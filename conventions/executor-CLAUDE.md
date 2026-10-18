# executor/ — Claude protocol

Status: Draft · Pass 0 · Updated 2026-10-18

The idea this recipe applies is EJ Alexandra's: every rule a row in a
table with a schema, prose only in named fields, the running system a
rendering of the tables (the Conceptual Model Completeness Conjecture
and the Effortless Rulebook). Sema and the executors both grow from it;
`../rulebook/cmcc.md` has the mapping.

Before any executor work, and again when the executor is complete,
ask the user whether they want an analysis of the repo README
(`readme-pattern.md`); the Domain Summary is copied from it.

## The bar

An executor is judged by one test: given the executor, the sema
vocabulary its seed names, and the executors its boundary table points
at, and nothing else, an agent rebuilds the domain in a language of its
choosing and, fed the executor's traces, emits the same output. The
test is the metric; it is not written into the executor. The executor
never names a language, never says "any implementation", never
compares itself to another build.

## Sema first

The vocabulary is the first input to every executor and the executor
never restates it. `sema/definitions/` is the registry; the domain's
vendored snapshot seed (`sema_seed_request.yaml` in the repo) is the
list of words the domain speaks, at the versions it speaks them. The
executor folder SHALL hold a verbatim copy of that seed, byte-identical
to the repo's, and `sema snapshot prepare` on that copy is the
vocabulary a rebuild is given. A seed that names a staged word
describes a dev snapshot, which no executor describes. The definitions
and the registry are never copied into the wiki.

Sema owes the executor one example per word, in the word's own
`examples`; a word the domain emits with no example is a sema gap,
raised through sema's change control. The executor does not write an
instance by hand. The executor owes sema real instances: a trace row
is a candidate example for its word.

The executor's rules are axioms in sema's own grammar (`sema/spec/`
"Axioms"): numbered from 1, named, one normative statement, clauses
`a.` `b.` where the statement has independently testable obligations,
one mutation test per clause. The executor's test induces the clause's
trigger and asserts the observable behaviour, where sema's breaks one
field and asserts the refusal.

One axiom about sema, hub Axiom 1 in every domain, and no other: every
instance that crosses the boundary SHALL be a listed word at its
listed version, encoded and decoded through the vendored snapshot, and
a body the snapshot refuses SHALL be handled as the domain's clauses
state. Sema says what is refused; the executor says what happens next.
The sorting test for every other rule: checkable from one instance,
with no clock, no store and no second message, it is a sema axiom and
the executor never restates it; needing two instances, time, state, or
a boundary that is not a word, it is the executor's. An executor
clause that passes the one-instance test is a missing sema axiom,
raised with the human and moved.

## The form

An executor is structured data, authored as YAML and only YAML, in
the rulebook table shape (`sema/effortless-rulebook/README.md`: tables
with a `schema[]` of raw, calculated, lookup, relationship and
aggregation fields and `data[]` rows; the YAML loads to that JSON in
one call and nothing is ever authored as JSON). One schema for every
domain, below; one instance per domain, in `wiki/<domain>/executor/`,
one file per table named for it (`Clauses.yaml`), beside the seed copy
(`sema_seed_request.yaml`) and `traces/<name>/trace.yaml`.
Prose lives only in the fields that name it (Summary, Description,
Statement, Reason, Text) and is written to the prose rules below.
Markdown is rendered from the instance when someone wants to read it,
never authored. Relationships are by name; a name that does not
resolve is a check failure.

## The tables

| Table | A row is | Columns | Computed |
|---|---|---|---|
| Domain | the one hub row | Name, Summary, Repo, InfraPointer, Status, Pass, ReconciledAt | AxiomCount, UnboundClauseCount, IsPromotable |
| SeedEntries | one word the seed names | Word, Version | scanned from the seed copy |
| Words | one crossing of the sema boundary | Word, Version, Direction (in, out, stored), ReadAs, Process, Crossing (broker, http, file, store) | InSeed |
| Boundaries | the non-sema boundary | Name, Kind (transport, http, file, store, api, setting, text), Form, OwnerExecutor, Reproduce (exact, free) | |
| Settings | one configuration key | Key, Type, Default, Required | generated from the code, checked in |
| Processes | one runnable | Name, Summary | StepCount |
| Steps | one start or stop step | Process, Idx, Text, Blocks, Retried, AbandonedOnStop | |
| Concerns | one spoke | Name, Summary, Description, Process | AxiomCount, BindingCount, HasBindings |
| Axioms | one rule | Concern (blank for the hub), Number, Name, Statement, Reason | ClauseCount, UnboundClauseCount |
| Clauses | one obligation | Axiom, Label, Kind (unconditional, transition, failure), Condition, Obligation, Recovery, Boundary (blank when internal) | HasTest, HasCounterexample |
| Vectors | one fixture | Concern, Idx, Kind (example, counterexample, trace), Path, Clause | Exists |
| Bindings | one pointer into the code | Clause or Concern (one set), Kind (symbol, test, setting, cli), TargetName, File | Resolves |

- **Summary** on the Domain row is the text for a person: what the
  domain does and where it sits in GridWorks, with no code words, no box
  names and no file paths. It is copied from the repo README
  (`readme-pattern.md`), which contains it verbatim. Where it runs and
  how it is operated is one pointer to `gridworks-infra`, in
  InfraPointer. Repo is the repo's folder name under the umbrella.
- **Words** and **SeedEntries** list the same words; a word in one and
  not the other is drift. A word the domain needs and sema lacks is a
  Words row with the hand-coded stand-in named in Boundaries. A row is
  one word at one version in one direction through one process: a word
  that goes in and out is two rows, and a domain that accepts three
  versions of a word has three inbound rows. ReadAs, on an inbound row,
  is the version the domain holds the instance at after decode: blank
  means as sent; a value is a listed inbound version of the same word
  and means the decode upgrades to it. One inbound row with ReadAs blank
  is a domain that parses one version and refuses the rest. The trace
  puller decodes each body the way this column says, and only that way.
  Process is the process that makes the crossing; on a stored row, the
  one that writes. Stored means the instance is kept whole and read back
  as the word; anything else the store keeps (a value unrolled from an
  instance, a field lifted out as a key) is the store's Boundaries row's
  Form. A word that reaches the domain only inside another word (the
  closure the seed pulls in) is not a crossing and has no row.
- **Boundaries** is everything that crosses the edge and is not a word:
  the transport (exchanges, bindings, queue properties, the routing-key
  grammar), HTTP calls made and served, files read and written with
  their paths, the store file, external APIs with their endpoints, and
  the text a person reads (summaries, notes, log lines). Form is the
  exact form or OwnerExecutor points at the executor that owns it.
  Reproduce says whether a rebuild matches it byte for byte or may
  change it: this column is the observable surface, and a trace diff is
  judged against it. A boundary in no row is a gap.
- **Settings** is generated from the code's settings class and checked
  in; the check is that regeneration changes nothing. A clause names the
  key its Condition reads and a Binding of kind setting ties them; a
  constant that is not a setting is a value in the Condition.
- **Steps** are ordered by Idx within their Process, start steps then
  stop steps. Blocks means the next step waits for this one; Retried
  means the step repeats until it succeeds; AbandonedOnStop means a stop
  interrupts it rather than waiting for it.
- **Axioms** are numbered from 1 within their Concern, the hub counted
  as one Concern, and hub Axiom 1 is the sema axiom. A clause is cited
  as Concern, Number and Label (`no-data 3a`).
- **Concerns** belong to the one process that enforces their clauses. A
  rule two processes meet at (one raises a condition, the other holds
  off while it is open) is two clauses in two concerns, each stating its
  own process's obligation; the shared fact they read is a store
  Boundaries row, named in both.
- **Clauses** are one thing in three kinds. Unconditional; a transition,
  whose Condition is the guard; a failure, whose Condition is the
  trigger (input late, malformed, duplicated, absent; store unavailable;
  a dependency unreachable) and whose Obligation and Recovery are the
  observable behaviour. Boundary names the Boundaries row the obligation
  crosses (the exchange a record goes out on, the file read, the text
  produced), so a boundary no clause crosses and a clause whose effect
  nothing can observe are both listed. A rendered state table or
  trigger-behaviour-recovery table is a presentation of Clauses rows.
- **Vectors** live in the executor folder; Path is relative to it. An
  example of a word is sema's, by reference: its Path is
  `<word>/<version>` and Exists is the word having an example. A
  counterexample is a trace that triggers one clause; a trace is a
  recorded window of real wire-in and the wire-out it produced. A
  trace that exercises several clauses is one Vectors row per clause at
  one Path.
- **Bindings** point into the code and nowhere else. A symbol is
  qualified (`module.Class.method`) with its File; a test binds a Clause
  by its test name and File; a setting binds a Clause to a Settings Key;
  a cli binds a Concern to a command. File is what the reconcile reads.
- **ReconciledAt** is the commit of the last reconcile. The periodic
  read is the bound files changed since it, against the clauses they
  bind, and nothing else.
- **Status** is Draft, Accepted or Verified and **IsPromotable** is
  computed: every Words row InSeed, every Clause with a test, every
  Concern with bindings, every Binding resolving, every Vector existing,
  the README match holding. Accepted requires IsPromotable; Verified
  additionally requires every Clause with a Vector and every trace
  replayed green.

## Prose rules

For every prose field.

- Present tense, what is now. No transition narrative, no dates of
  settlement; the changelog has those.
- Reason is one clause on the axiom it belongs to.
- No implementation words. Thread, lock, transaction, tuple, instance,
  class, a migration tool, a library or module name: each describes one
  build. The Statement says what is guaranteed (atomic, ordered,
  survives a restart) and the Binding names the symbol.
- Meaning that affects a rebuild lives in a Clause, a Vector or a
  Boundaries row. Description is for the sequence of a flow and nothing
  a row can hold.
- A prose field says what the reader cannot see in the rows or bring
  as common knowledge, and nothing else.
- No legacy system. An executor never names a system the domain replaces
  and never compares itself to one. The wiki-wide allowance for legacy
  comparison as rationale (`base-CLAUDE.md` "Wiki essentials") does not
  reach an executor; the comparison goes in the changelog.

## Traces

The wiki holds the trace spec, `traces/<name>/trace.yaml`, and nothing
else: the window; the senders; the tracked set as a forest fixture;
which types keep their bodies; the expected output with its timing
tolerance; what the window does not contain that the clause would
need; whether the window was recorded from the field or induced on the
dev broker; and the events the harness drives during replay, each an
instant and a kind, `restart` the first kind (the service is stopped
and started again at that instant). The input is materialised under
`experiments/traces/<domain>/<name>/` by
`experiments/traces/pull_trace.py` from the journal, decoded through a
snapshot built from the executor's seed copy, with every body either
decoded or recorded as a refusal, each body decoded the way its Words
row's ReadAs says.

A trace is as long as the slowest clause it exercises and names only
the senders that clause needs. It orders and times by arrival at the
broker; a message's own time does not set its order.

Traces replay through a harness under `experiments/`, over the dev
broker, against any build in any language, the clock driven from the
trace; the replay is the EDD evidence. The build's whole world at
replay is the trace's wire-in, the Settings table, and the Boundaries
rows, each served by the harness from its Form or recorded as
wire-out; an edge in no Boundaries row is unreachable, and a build
that needs one fails its traces. The repo's own tests bind to
clauses by name and keep their own fixtures. Text a person reads is
in a trace's expected output or is a Boundaries row marked free; it
is never described.

## Finding the traces

One vector per clause, its kind set by the clause's. A
transition needs a trace in which its guard goes from false to true,
and each guard of an exclusive set under one axiom needs its own; a
failure needs a counterexample that induces its trigger; an
unconditional clause is covered by any trace that crosses its
Boundary. A clause with Boundary blank has no observable of its own
and is covered through the clauses it feeds.

The set is found by iteration:

1. Write the clauses first. The Vectors table with a row per clause
   and no Path is the work list.
2. For each clause, find a window in the archive where the condition
   held. A field incident is the best trace; every incident on the
   domain yields its trace before the fix goes in.
3. Where the journal lacks a type the condition reads, the trace spec
   says so. Then pull the window from the eventstore by hand, or raise
   the journaling gap with the journal's owner so the next incident is
   pullable, or both.
4. Where reality has not produced the condition, induce it on the dev
   broker against the built service and record the window; the spec
   marks it induced, and a field window replaces it when one comes.
5. Replay everything. Each diff is a row fix; the adversarial pass
   lists the clauses no trace reaches; repeat until the Vectors table
   has a Path on every row.

## Adversarial review

An executor reaches Accepted only after this pass, run per Concern
and again at the Domain, on top of IsPromotable:

1. A fresh agent gets the executor, the vocabulary and the executors
   the Boundaries rows point at, no code and no conversation. It lists
   every question it would need answered before it could build the
   concern, and every pair of rows that cannot both hold, quoted.
   Each is a gap. The fix is a row in the executor; an answer given
   in conversation does not close it.
2. The same agent builds the concern from the executor and replays
   the traces and vectors against the result. Each diff outside the
   Reproduce column's allowance is a gap.

Repeat the pass after each material change.
