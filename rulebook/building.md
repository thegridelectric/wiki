# Building an executor

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: the first pattern, describing an existing system as an
> executor. The obligations are in `../conventions/executor-CLAUDE.md` ("README
> first", "Sema first", "The form", "The tables", "Prose rules",
> "Finding the traces"); this spoke says why the recipe runs in that
> order.

## The order

The README is finalized before the executor starts, because the
Domain Summary is copied from it and a Summary written first pulls
the README toward the executor's vocabulary instead of a person's.
The seed copy comes next, because every later row names a word at a
version and the seed is the only list of them. The tables follow,
clauses before vectors, because the Vectors table with a row per
clause and no Path is the work list that drives the trace iteration.

## What the builder reads and writes

The builder reads the code, the journal and the repo's settings
class, and writes the wiki. It writes into the repo in one case: a
clause with no test is either given one or leaves the executor Draft,
since IsPromotable requires every clause bound to a test.

## Open

- Whether a Clauses row needs a Reads column beside Boundary, so the
  store row a condition reads is a relationship the checker follows.
  Raised by the alerter's NoData cause clauses (OPS-605).
