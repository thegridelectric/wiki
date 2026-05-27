# Concern: what should "vocabulary" actually mean in sema?

Status: Draft · Pass 0 · Updated 2026-05-26

> An open modeling question, separated from the surface-level
> Words→Types rename design
> ([`designs/web-app-words-to-types.md`](../../designs/web-app-words-to-types.md)).
> That design *removes* the Vocabulary framing from EJ's dashboard
> without proposing a replacement. This concern holds the deeper
> question: if vocabulary is ever reintroduced as a first-class concept,
> what is it?

## What we know

- **EJ's current model** (in the dashboard, not in the rulebook):
  "vocabulary" ≈ "the words an owner created." Routes are
  `/v/<owner>/words` etc. Authorship grouping is treated as the
  vocabulary axis.
- **Jess's objection** (live, 2026-05-26): this conflates *authorship*
  with *use*. A vocabulary is the set of words an *application* needs
  / consumes / shares — not the bag of things one curator authored.
- **Snapshot is already the right object.** `sema snapshot prepare`
  takes a structured seed request and computes the transitive closure
  of words an application needs. That closure IS a vocabulary in any
  reasonable sense. The rulebook + CLI already produce this object;
  the dashboard simply isn't surfacing it that way.

## Working theses (to grill, not to commit)

1. **Vocabulary is application-scoped, not owner-scoped.** An
   application (gridworks-scada, gridworks-base, gridworks-ear, …) has
   a vocabulary. Owners do not — they have *contributions*.
2. **Every snapshot is a vocabulary.** The seed-request +
   transitive-closure machinery already in `src/sema/interfaces/cli/snapshot.py`
   is the production mechanism. A vocabulary is a snapshot, possibly
   with a published name / version.
3. **Semantic tagging cross-cuts owners.** Tags are an orthogonal
   classifier. An application's vocabulary may include words from
   multiple owners and exclude others. Tags let an application say
   "these are *my* words" without re-implementing curation.
4. **Authorship stays where it belongs — on owner.** Owner is a
   provenance / curation attribute. It is not a usage attribute.
   Removing the Vocabulary framing from the per-owner page is the
   surface fix; preserving Owner as "who curated this" is the
   load-bearing part.

## What this isn't yet

- A schema. Whether vocabulary becomes a rulebook table, a tag set,
  a snapshot row with a publication artifact, or something else is
  *open*.
- A UI shape. Whether the dashboard gains a `/vocab/<application>/...`
  navigation, an inline filter on the existing pages, or something
  else is *open*.
- A migration path. Whether existing snapshots auto-promote into
  vocabularies, whether the seed request gains a `vocabulary_name`
  field, whether the dashboard reads vocabularies from a new table or
  derives them on-the-fly from snapshots — *open*.

## Open questions to grill (when the concern matures)

- Does "vocabulary" need a rulebook table at all, or is it just
  "a snapshot with a name + version", purely a labeling convention
  over existing snapshot rows?
- If a table: PK shape? Does a vocabulary point at a single seed
  request, or can it cherry-pick across multiple?
- If semantic tags: where do tags live (rulebook table, free-form
  string column, controlled-vocab enum)? Who can add a tag? Is it
  owner-scoped, application-scoped, or global?
- How does a *consuming* application register its vocabulary?
  - Today: by maintaining its own seed request file.
  - Future shape: by checking in a `<app>.vocab.json` to its repo, and
    sema discovers it? Or by a row in a sema table that the app
    points at?
- Versioning: do vocabularies version like types/enums (bump on
  change)? Or are they snapshots, identified by content hash?

## Why this stays a concern, not a design

Because we don't yet have the right shape to ratify. The pieces
(snapshot machinery, owner provenance, tag possibilities) exist; how
they compose into a "Vocabulary" concept is unclear and benefits from
deferring until there's a real consumer (gridworks-scada wanting to
publish its sema dependencies, an external integrator asking for
"sema's published vocabulary," etc.). Premature ratification risks
inventing a Vocabulary table that doesn't match the consumer's actual
need.

## Trigger conditions to graduate to a design

Any one of:

- A concrete consumer (gridworks-scada team, an external integrator,
  a sema docs site) asks for a way to identify "my vocabulary" that
  the seed-request file alone doesn't answer.
- The dashboard gets a publish decision (per the words-to-types design
  prerequisite) and a consumer-facing nav needs *something* in the
  vocabulary-shaped slot.
- A tagging requirement lands from another direction (e.g., axiom-DSL
  work needs to scope axioms to a subset of types).

## Related

- [`designs/web-app-words-to-types.md`](../../designs/web-app-words-to-types.md)
  — the surface refactor that *removes* the current Vocabulary framing
  without proposing a replacement.
- `src/sema/interfaces/cli/snapshot.py` — the seed-request +
  transitive-closure machinery that's the most likely substrate for
  whatever Vocabulary turns into.
- [`research/erb-md-mirror.md`](../erb-md-mirror.md) — sema's
  rulebook is the SSoT; any new Vocabulary concept lives in the
  rulebook first, dashboard second.
