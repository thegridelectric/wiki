# Build the journalkeeper executor

Status: Draft · Pass 0 · Updated 2026-10-18 · Linear: OPS-606

**EDD: yes** the trace replay is the verification: the journalkeeper
executor reaches Verified when every clause has a vector and every
trace replays green against the built service over the dev broker
(`experiments/traces/`).

> What this is: the second instance of the table-shaped executor
> recipe (`../../conventions/executor-CLAUDE.md`), after the alerter
> (OPS-605), and the first for a domain whose main boundary is a store
> it serves to other services. The markdown executor in `../executor/`
> (five files, 737 lines) becomes the twelve tables; the channel
> registry comes out as rows, which is where the port bites.

## Where it stands

- `../executor/` holds a markdown executor with a hub and four spokes
  (persistor, captured types, operational, S3 backfill); no seed copy,
  no traces.
- The persistor spoke already states the crux: data and derived
  channels take their meaning from sema through `layout.lite`; pseudo
  channels (price, weather, machine states, the per-site heat-call
  synthesised from whitewire power) take theirs from literals in gjk
  code.
- The journal is read by web-backend, gridworks-data and the alerts
  page, so it is an interface by the rule in `../../rulebook/primary.md`
  "Open": the owner lists the surface once, the readers cite it.
- Starts after the alerter port has settled the recipe.

## Plan

1. **README first.** Ask for the README analysis; the Domain Summary
   is copied from it.
2. **Seed copy.** The journalkeeper's `sema_seed_request.yaml` into
   `executor/`, byte-identical.
3. **Port.** The twelve tables from the markdown. Hub Axiom 1 is the
   sema axiom; the capture contract's four gates and the invariants
   become hub axioms; each spoke becomes a Concern.
4. **The channels as rows.** Every channel kind is a Words row.
   Data and derived channels are rows at their words. Each pseudo
   channel is a Words row with no word, with its hand-coded stand-in
   named in Boundaries and the sema word that retires it named in the
   row; the heat-call synthesis is a Concern with its per-site
   thresholds as Settings. The executor cannot reach Accepted while
   those rows are unbound, so the list is the cleanup, in the open.
5. **The served store.** The journal's tables and columns as a
   Boundaries row of Kind store the journalkeeper serves, the surface
   every reader's executor cites.
6. **Traces.** The recipe's iteration; the archive is the
   journalkeeper's own output, so a trace's expected output is journal
   rows and the harness diffs the store.
7. **Adversarial pass**, per Concern and at the Domain, then Accepted.

## To-do

- Decide whether the heat-call synthesis stays in the journalkeeper
  as a Concern or moves behind a sema word the scadas emit; the design
  does not decide it, the Words rows make the choice visible.
- A trace whose expected output is store rows rather than broker
  messages: the recipe's Traces section assumes wire-out, and the
  journalkeeper's wire-out is a database. Raise in the rulebook before
  the port.

## Open

- Whether web-backend's executor follows this one or waits for the
  pseudo channels to be retired.
