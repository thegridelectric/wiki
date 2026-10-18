# The rulebook

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: the hub for the no-code half of GridWorks. The
> rulebook is the sema vocabulary (`sema/definitions/`) plus every
> domain's executor (`wiki/<domain>/executor/`); the code is a
> rendering of it. This folder holds the reasoning behind the executor
> recipe, the three patterns the recipe serves, and the survey of the
> wider field. The recipe itself, the obligations a session follows
> when it touches an executor, is `../conventions/executor-CLAUDE.md` and is
> stated there once; this folder cites it by header and does not
> restate it.

## The idea

A rulebook is tables with a schema and rows. Prose appears only in
the fields that name it, and anything a person reads as a document is
rendered from the tables. This is EJ's rulebook (the Effortless
Rulebook, the product of the CMCC, the Conceptual Model Completeness
Conjecture; [`cmcc.md`](cmcc.md) has his statement and the mapping). The GridWorks twist is sema:
the vocabulary is the first input to every executor, an executor never
restates a word, and one axiom per executor binds the two. A rule that
can be checked from one instance belongs to sema; a rule that needs
time, state, a second instance or a boundary that is not a word
belongs to the executor.

An executor is for an LLM: the reader that rebuilds the domain and
the reader that checks the code against it. Every table serves both
uses, and a check that can run rather than read does. The person who
wants to know what the domain does reads the repo README
(`../conventions/readme-pattern.md`), which comes first.

## The three patterns

- [`building.md`](building.md): building an executor for a system
  that already exists. The README comes first, then the seed copy,
  the tables, the clauses, and the traces found by iteration.
- [`drift.md`](drift.md): the automated check, periodic or triggered
  by a code change, that an executor has not gone stale against its
  code.
- [`rebuild.md`](rebuild.md): using an executor to build a new
  version of the domain, in any language, judged by the traces.

## The wider field

[`cmcc.md`](cmcc.md) sets the recipe against EJ's CMCC, primitive by
primitive, with the departures. [`provenance.md`](provenance.md)
names the traditions the recipe takes from. [`field.md`](field.md) is the survey of people and LLMs
trying this approach, what works and what does not.

## Designs

Improvements to the practice live in [`designs/`](designs/), one
file per design, under the wiki's design convention. The first
instance of the recipe is the alerter (OPS-605).

## Open

- The checker (`wiki/tools/`, hook-grade: files only, seconds, no
  credentials), the markdown renderer, the settings generator and the
  replay harness (`experiments/`: the dev broker, a built service,
  evidence kept as EDD requires) do not exist. The alerter is the
  first instance and builds them. The pull script exists and decodes
  through the executor's seed copy, reading a `decode:` line in the
  trace spec that stands in for the Words rows' ReadAs until that
  table exists; at the port the script reads ReadAs and the line goes.
- A database as an interface, which it becomes when a process from a
  second executor reads or writes it (the alerter's store, shared by
  its own three processes, stays internal). Two-sided: the owner
  (journalkeeper) lists the surface once in its Boundaries table as a
  store it serves, and each reader (web-backend on the journal) lists
  a Boundaries row of Kind store with OwnerExecutor the owner and Form
  the tables and columns it reads. It would make a
  trace possible for a DB-reading service, since the harness serves
  the row from its Form, and it would show meaning read off columns as
  rows citing the sema word that retires each. Fits the data
  sovereignty line in `../vision/primary.md`; runs counter to how
  analysis reads the journal today, which no executor binds. Settled
  when the first DB-reading service gets an executor.
- `wiki/tests/test_doc_health.py` and the hub line caps in
  `base-CLAUDE.md` "Wiki essentials" assume markdown executors;
  the stamp becomes the Domain row's Status and Pass columns.
- The effortless tooling is not reused (survey 2026-10-17): the CLI runs
  locally but every transpiler is hosted and closed, there is no
  rulebook schema or validator, no generic YAML round-trip and no docs
  emitter beyond RuleSpeak. The checker is our own script; the JSON
  shape and the Excel-style formula strings are kept so `effortless
  build` still accepts an instance later. Conventions adopted from the
  effortless skills: PascalCase plural table names, a raw `<Table>Id`
  first field with Name calculated, singular relationship fields with no
  `Id` suffix, one-to-many only so the tables form a DAG (Bindings has a
  Clause column and a Concern column; one polymorphic Target column
  would break this), every cross-table read one link deep, derived
  fields never stored, a Description on every table and field.
