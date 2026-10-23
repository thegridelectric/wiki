# Build the alerter executor

Status: Draft · Pass 0 · Updated 2026-10-23 · Linear: OPS-605

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
  copy (byte-identical to the repo's) and two traces from the field,
  `traces/2026-10-20-oak-silence/` (ScadaSilent moving to NoData under
  one AlertId after the Millinocket power cut) and
  `traces/2026-10-23-spruce-ltn-stop/` (LtnSilent raised and resolved
  across a stop of the LTN run on purpose), which
  `experiments/traces/pull_trace.py` materialises from the S3
  eventstore: the key alone gives arrival, sender and type, bodies are
  fetched for the types the spec keeps, and the window's `gw.alert`
  records are printed as the expected output. The journal supplies the
  forest only; it has no pings or acks, and it has journaled no
  `gw.alert` since 10-18 (the keeper's alert persistor has a 000 method
  and the alerter speaks 001). The port (Plan step 1)
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
   trace spec's `decode:` line, and drop the line. Reads the
   eventstore for messages (done); the forest still comes from the
   journal.
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
- Traces for the silence trio: `ScadaSilent` and the kind change to
  `NoData` are in the oak trace, `LtnSilent` in the spruce one. Expected output
  on `gw.alert` 001: the Firing kind names the party, the Resolved
  follows the first report back by at most one tick with that report's
  readings as evidence, and a layout is no sign of life. The
  eventstore's 10-20 to 10-22 windows (four houses at 14:20Z on 10-20,
  spruce on 10-21 20:30Z and 10-22 12:05Z) are further vectors for the
  same clauses if the replay wants more than one.
- A restart trace for the store axiom: one of those windows with a
  `restart` event between the Firing and the Resolved; expected output
  has one Firing and one Resolved.
- Two decisions from the detector port to write as axioms before the
  next kind is specified: **equipment is a layout fact** (a kind that
  needs a store pump, a distribution flow meter or a thermostat fires
  only for a house whose layout has that thing, and is absent for the
  rest; no per-house tables), and **the scada judges what it can see,
  the alerter relays it** (a condition the box can judge, a zone cold
  or at freeze risk, is a Critical glitch there and pages as
  `CriticalGlitch`; the alerter judges only what the box cannot see
  from inside: silence, a reboot loop, a fleet-wide pattern).
- gwalert's `check_no_data` still runs beside the silence trio, so a
  silent house pages twice. Switching it off waits on a shadow week of
  both outputs compared: every gwalert page should have an alerter
  Firing earlier or within one tick. Then comment the call out of
  `AlertGenerator.main` (the way `check_in_atn` already is), deploy by
  pull and restart, note it in the changelog.
- The counterexample for the sema axiom is in the spruce trace: its
  two `layout.lite` 013 bodies are refused by the seed snapshot (it
  stops at 012), the alerter logged and dropped them and went on to
  raise and resolve. The vector exists; the Vectors row for it does
  not yet. Separately, a refused layout is a layout the alerter never
  sees, so until the seed takes 013 every house on layout.lite 013 has
  no layout at the alerter: raise the seed through sema's change
  control before the detector port needs equipment facts.
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
