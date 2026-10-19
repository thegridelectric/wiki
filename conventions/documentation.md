# Documentation

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: how a GridWorks code repo describes itself, in its
> docstrings and beside its executor.

A docstring does not narrate the code, list callers or consumers,
describe what other modules do, or name counts, identifiers or literal
values. Those go stale, and the data says they stay stale. Comments
change with the code they describe in 7% of method changes and 13% of
class changes (Wen et al. 2019, 1,500 Java systems). References to
functions in other files rot the fastest (869 stale function references
in Linux v6.18-rc1 comments, ReCite 2026). Whatever has to be said about
a line goes next to that line as a comment.

## The module docstring

A few sentences, before the code, on what the module is for: the
conditions it watches, the decision it makes, the thing it produces.
Written for a person who has not read the code and may not read it.

Sample, the alerter's `no_data.py`:

```python
"""Checks for three conditions, all having to do with no readings making
it up to the journalDB from a particular scada. These readings come from
report.events. The scadas will stop sending report.events (but will keep
sending snapshots) if they are not communicating with their LTN. So there
are three types of alerts:

  - ScadaSilent: nothing heard from the scada inside the fresh window.
  - LtnSilent: scada speaking, LTN not. The scada sends no reports
    without an LTN.
  - NoData: both speaking, no reports arriving.
"""
```

A new or rewritten module docstring is reviewed by the human before the
branch merges to the long-running branch.

## Method docstrings

One or two sentences on the contract: what the caller gets, the
precondition, the unit, the failure behavior. Present tense, the thing's
own meaning. No history ("used to", "no longer"), no rationale that only
makes sense against earlier code. Not reviewed by the human.

## Docstrings beside an executor

A domain with an executor (`executor-CLAUDE.md`) has three kinds of
prose, each answering one question. A method docstring states the
contract a caller needs. An executor row states the rule a rebuild
needs: the condition, the obligation, the threshold's setting key, the
boundary crossed. The wiki states the why. A sentence belongs in one of
the three.

So a docstring never restates a clause, and never names a threshold or
a value a Settings row owns. The Bindings table is the pointer from a
row to the symbol, so a docstring never names its clause or axiom. When
a docstring and a clause describe the same behaviour, the clause is
the rule and the docstring shrinks to the contract. The sign of
drift is the two disagreeing, which the reconcile against the bound
files catches.
