# Rebuilding from an executor

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: the third pattern, using an executor to build a new
> version of the domain. The bar and the adversarial pass are in
> `../executor-CLAUDE.md` ("The bar", "Adversarial review"); this
> spoke says what the rebuilder is given, what it is denied, and what
> it hands back.

## The rebuilder's inputs

The executor, the vocabulary its seed names, and the executors its
Boundaries rows point at. No code and no conversation: a rebuilder
that can see the code reproduces it, and a rebuilder that can ask a
question in chat gets an answer that never reaches the executor.

## The README

The repo README is written in two parts (`../readme-pattern.md`): the
language-independent text first, one language-dependent section at
the end. A port copies the README verbatim up to that section and
rewrites only it.

## What it hands back

Two lists, each item a gap and each gap fixed by a row: every
question it needed answered before it could build, and every pair of
rows that cannot both hold, quoted. After the build, every diff
between its wire-out and the traces outside the Reproduce column's
allowance. A rebuild that replays green does not certify the
executor; it shows the executor was unambiguous to one reader.

## Open

- Whether a trace induced on the dev broker counts toward Verified,
  or only a window recorded from the field.
