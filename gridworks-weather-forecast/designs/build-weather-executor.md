# Build the weather executor

Status: Draft · Pass 0 · Updated 2026-10-18 · Linear: OPS-607

**EDD: yes** the trace replay is the verification: the weather executor
reaches Verified when every clause has a vector and every trace replays
green against the built service over the dev broker
(`experiments/traces/`).

> What this is: the weather forecast service as the second instance of
> the table-shaped executor convention
> (`conventions/executor-CLAUDE.md`). The markdown in `executor/` (a hub
> and three spokes, 627 lines) is pruned, then ported into the twelve
> tables, one YAML file each; the trace for every clause is found by
> the convention's iteration. The tooling the convention needs (the
> columns checker, the renderer, the settings generator, the replay
> harness) is built once under the alerter executor (OPS-605) and used
> here as it arrives; this design builds none of it.

## Where it stands

- The repo README is written to the README pattern: the summary for a
  person first, then what it speaks, its processes, its records, one
  pointer to `gridworks-infra`, and one Development section. The
  Domain Summary is its first two paragraphs. The seed names the
  station words, the create command and its two verdicts, and `glitch`;
  the legacy `weather` word left the seed with the README rewrite.
- `executor/` is pruned markdown (Plan step 1 done): `primary.md`
  (identity, source posture, six invariants, a glossary of the
  service's own terms), `vocabulary.md` (the service's obligations
  around the words, which the words themselves do not state),
  `delivery.md` (cadence, binding shape, the pull path) and
  `record-lifecycle.md` (minting, order, identity at boot). Word
  schemas, cross-service declarations, the registration procedure, the
  journaling gate and legacy narrative are out. Two sections of
  `delivery.md` keep their Verified stamps.
- No table exists yet, no seed copy, no trace.

Do this next: Plan step 2, the port, starting with the Concern split
against the code's seams.

## Plan

1. **Prune.** Read the four markdown files against the code at `main`
   and against the prose rules. Out: transition narrative (legacy
   retirement, the dated dev-DB resets), anything the repo README or
   the sema definitions already state (the word schemas in
   `vocabulary.md`, which restate the registry), cross-service
   declarations (what the LTN or the scada does with a forecast), and
   box facts. What stays is what a row will hold: an invariant, a
   guard, a trigger with its observable behaviour, a boundary.
2. **Port.** Write the twelve tables from the pruned prose. Hub Axiom 1
   is the sema axiom; the six invariants become hub axioms. One Concern
   per process-side rule set: observation delivery (latest-only, the
   three-hour gap fill), forecast delivery (the emission slot, fidelity
   per series, the stored and seasonal rungs), records (insert-only
   identities, the bundle's embedded copies, the refusal verdicts, the
   once-only record broadcast), the read API (byte-identical to the
   broadcast), and the sources (NWS and Open-Meteo as boundaries with
   their endpoints, the caching fetch, the glitch on a source that will
   not answer). Settings are generated from the settings class.
   Delete the markdown when the tables render it.
3. **Seed copy.** `executor/sema_seed_request.yaml`, byte-identical to
   the repo's.
4. **Traces.** Run the convention's iteration ("Finding the traces")
   until every clause has a vector. The journal holds the service's
   broadcasts, so delivery traces pull from it; the sources are
   boundaries the harness serves from their Form, so a source trace
   records the HTTP exchange as wire-in. Record traces are induced on
   the dev broker from `dev-records/`.
5. **Adversarial pass**, per Concern and at the Domain, then Accepted.

## To-do

- Decide the Concern split in step 2 against the code's own seams
  (`scheduler.py`, `record_broadcast.py`, `api.py`, the two adapters)
  before writing a row; the list above is the first cut.
- The clauses whose trigger is a source failure (NWS silent, Open-Meteo
  silent, a gap longer than three hours) have no field window pulled
  yet; the 2026-08-11 NWS update-time probe and the two gwwf round-trip
  experiments are the first places to look.
- Settings generation waits on the alerter's generator; until then the
  table is written by hand in the shape the generator will emit.

## Open

- Whether the two Verified sections of `delivery.md` keep their Reviewed
  stamps as rows. A row has no stamp; the experiment that verified it
  becomes the Vectors row's Path, and the stamp goes to the changelog.
- Whether a source adapter (one HTTP boundary, one fetch cadence, one
  caching rule) is a Concern of its own or a set of Boundaries rows read
  by the delivery concerns.
