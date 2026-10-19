# Build the alerter executor

Status: Draft · Pass 0 · Updated 2026-10-19 · Linear: OPS-605

**EDD: yes** the trace replay is the verification: the alerter executor
reaches Verified when every clause has a vector and every trace replays
green against the built service over the dev broker
(`experiments/traces/`).

> What this is: the alerter as the first instance of the table-shaped
> executor convention (`conventions/executor-CLAUDE.md`). The pruned markdown in
> `executor/` (four files, 448 lines) becomes the twelve tables, one
> YAML file each; the tooling the convention lists as missing is built
> here; and the trace for every clause is found by the convention's
> iteration. The convention is settled first and is not this design.

## Where it stands

- `executor/` holds the twelve tables, one YAML file each, the seed
  copy (byte-identical to the repo's) and one trace,
  `traces/2026-10-15-oak-ltn-stop/`, which
  `experiments/traces/pull_trace.py` materialises from the journal,
  reading a `decode:` line in the trace spec. The port (Plan step 1)
  is done: 7 hub axioms, 4 concerns (listener, no-data,
  broker-unreachable, tap), 27 axioms, 65 clauses, 137 bindings. The
  Settings table is written by hand from the settings class in the
  shape the generator will emit, inherited keys included.
- The repo README holds the Domain Summary verbatim.
- An ad-hoc columns check (relationships, seed drift, bindings
  resolving against the code, README match) passes except for the
  missing `gw.opsgenie.alert` example. 8 clauses have no test binding;
  54 vectors have no path.
- Nothing in the convention's Open list exists: the columns checker,
  the markdown renderer, the settings generator, the replay harness.

## Plan

1. **Port.** Write the twelve tables from the markdown. Hub Axiom 1 is
   the sema axiom; the seven invariants become hub axioms; each spoke
   becomes a Concern with its axioms and clauses. The three-row cause
   table in `no-data.md` becomes three transition clauses under one
   axiom (NoData names its cause), each with a text Boundaries row for
   its summary template. Settings are generated, not written. Delete
   the markdown when the tables render it.
2. **Checker.** `wiki/tools/`, hook-grade: the columns check from
   `wiki/rulebook/drift.md` "The checks", wired as the other hooks are.
3. **Renderer.** Markdown from the instance, on demand; the rendered
   hub replaces `primary.md` for a reader.
4. **Settings generator.** From the alerter's settings class to the
   Settings table; the check is that regeneration changes nothing.
5. **Pull script.** Read ReadAs from the Words table instead of the
   trace spec's `decode:` line, and drop the line.
6. **Replay harness.** `experiments/traces/`: replay a trace against
   the built service over the dev broker, clock driven from the trace,
   diff the wire-out within the Reproduce column's allowance. The
   harness serves every Boundaries row of Kind http or api from its
   Form (the registry read, Opsgenie) and records the calls as
   wire-out; the build reaches nothing else, so a journal read fails
   the trace. Drives the trace's events, `restart` first. Evidence
   kept as EDD requires.
7. **Traces.** Run the convention's iteration ("Finding the traces")
   until every clause has a vector; see To-do for the ones already
   known to be missing.
8. **Adversarial pass**, per Concern and at the Domain, then Accepted.

## To-do

- `gw.opsgenie.alert` 000 has no `examples:` in sema, so its Vectors
  row of kind example does not exist. The real instance is one item of
  the tap's listing on the alerts box; pull one once the read-back is
  deployed and raise it through sema's change control.
- Clauses with no test binding: hub 4a, 4b, 5b; listener 3c, 4c, 5b;
  no-data 2b; tap 5b. Each needs a repo test named for it.
- Traces for no-data axiom 3 (the kind names the cause) clauses a and
  c: scada
  not speaking; scada and LTN both speaking. Clause b has the oak LTN
  stop. Neither a nor c can be pulled from the journal today, since
  the LTN's pings are not journaled; they come from the eventstore by
  hand or are induced on the dev broker, and a field window replaces
  them once JournalKeeper journals the LTN's pings (OPS-392, the
  layout.lite 013 release).
- Redo the oak LTN stop trace's expected output against the no-data
  rule as it now stands: the Firing kind is `LtnSilent` on `gw.alert`
  001, and the Resolved follows the 19:01:07Z report's arrival by at
  most one tick, with that report's readings as evidence, since the
  rule resolves from the store on the tick and a layout is no sign of
  life. The two layouts at 19:01:16Z exercise nothing.
- A restart trace for the store axiom: the oak LTN stop window with a
  `restart` event between the Firing and the Resolved; expected output
  has one Firing and one Resolved.
- A counterexample for the sema axiom: a body the snapshot refuses,
  logged and dropped, the consumer still consuming.
- A counterexample for tap 4b from the field: Opsgenie answers some
  listings with a 429 rate limit at the ten-second cadence (first seen
  2026-10-18 20:45Z, about one listing in seven on 2026-10-19), and the
  told set stands as the clause says. The window is in the alerter-tap
  journal on the box. The cadence itself is a follow-up: a longer
  `tap_reconcile_s`, or a listing on every nth pass.
- Vectors for the broker-unreachable concern: the prober's three
  failures with the fleet unheard, and the fleet-heard override.

## Open

- Whether the Clauses table needs a Reads column beside Boundary, so
  the store row a condition reads is a relationship the checker can
  follow rather than a name in prose. The port names the store row in
  the Condition text (the cause clauses read arrivals); a Reads column
  is a convention change and waits on the convention.
- Whether a dev-broker induced trace counts toward Verified or only a
  field window does.
- Whether ReadAs belongs on a stored Words row. The store on the box
  has `gw.alert` records written at 000 that the codec reads back as
  001, so Words has a stored row for 000 with ReadAs 001; the recipe
  defines ReadAs for inbound rows only. Either the recipe's ReadAs
  sentence widens to stored rows, or the row goes and the 000 records
  are a changelog fact a rebuild is not told.
