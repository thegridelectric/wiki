# The executor against the CMCC

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: EJ's Conceptual Model Completeness Conjecture (CMCC)
> as he states it, where each of its five primitives is in the
> executor recipe, and where the recipe departs from it on purpose.
> Rationale for a reader of the recipe and the page to hand EJ; a
> session building an executor does not need it. The conformance
> checks that keep an instance in the CMCC shape are in
> [`drift.md`](drift.md) "The checks".

## EJ's statement

The CMCC claims that "any domain-specific rule or business logic can
be fully captured using five foundational primitives": Schema, Data,
Lookups, Aggregations and Calculated Fields, held in a datastore
"designed to be ACID-compliant, ensuring that every update and query
maintains transactional integrity" (Alexandra, EJ, *The CMCC-Gated AI
Architecture*, Zenodo 14798982). The Effortless Rulebook is its
product. Nothing EJ publishes calls these rules; they are primitives.
The expansion of the acronym and the five are from his self-published
papers and are to be confirmed with him before this page leaves
Draft.

## Where each primitive is

| EJ's primitive | In the executor | `../conventions/executor-CLAUDE.md` |
|---|---|---|
| Schema | Each table has a `schema[]`; one schema for every domain, the twelve tables | "The form", "The tables" |
| Data | `data[]` rows; one instance per domain, one file per table | "The form" |
| Lookups | Relationship fields by name, an unresolved name a check failure; lookup fields such as InSeed read from SeedEntries | "The form" |
| Aggregations | The Computed column's counts over child rows: AxiomCount, ClauseCount, UnboundClauseCount, StepCount, BindingCount | "The tables" |
| Calculated Fields | The Computed column's booleans: IsPromotable, HasTest, HasCounterexample, Exists, Resolves, HasBindings | "The tables", the Status bullet |

Every rule in an executor is a row, every derived fact is a formula
over rows, and the prose fields are data in a column. IsPromotable is
the clearest case: a calculated field over five lookups and the
README match.

## Where the recipe departs

- **The datastore.** EJ's rulebook lives in a transactional store
  with its formulas evaluated live. An executor lives in YAML in git;
  the columns checker is the only evaluator and no derived field is
  stored. The JSON shape and the Excel-style formula strings are kept
  so `effortless build` can take an instance later. If the conjecture
  needs the store, GridWorks runs its authoring shape and the
  checker stands in for the store's integrity.
- **Declared against executed.** EJ keeps the two apart by the
  store's nature. The recipe does it by rule: "Prose rules" forbids
  implementation words, and Bindings are the only pointers into code.
- **Constructs EJ does not have.** The trace, the Boundaries row and
  the sema axiom are rows in CMCC shape with no counterpart in a
  rulebook. They are what makes an executor a specification of a
  running service rather than of a business domain, and they conform
  to the five without being derived from them.

## The relation

An executor conforms to the CMCC: every construct in it is one of the
five. It is one instance of the shape; a one-to-one mapping back is
the wrong test, since the constructs above have no counterpart.
Conformance is mechanical and belongs to the columns checker. The
adversarial pass (`../conventions/executor-CLAUDE.md` "Adversarial review") keeps
to the rebuild question; its first step catches the CMCC failure in
practice, a rule hiding in a Description or a Reason, by listing the
questions a prose answer settled.
