# Checking an executor for drift

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: the second pattern, the check that an executor and its
> code still agree, run on a schedule or on a code change: the four
> checks, what each catches and misses, why they are ordered as they
> are, and who acts on a finding.

## The checks

Spec and code drift unless something looks. The checks, cheapest
first; each names what it catches and what it misses. The checker
lives in `wiki/tools/`, wired as the other hooks are (Open: it does
not exist yet).

1. **Columns** (pre-commit, seconds): the seed copy byte-identical;
   Words against SeedEntries; Settings regenerated unchanged; every
   Binding resolving and every Vector existing; the README containing
   the Summary verbatim; IsPromotable. And the rulebook shape
   ([`cmcc.md`](cmcc.md)): every schema field one of raw, calculated,
   lookup, relationship or aggregation; every relationship resolving;
   no derived field stored; the tables a DAG. Catches renames,
   deletions, moves, an unenforced clause, a stale key list, an
   instance `effortless build` would refuse. Misses behaviour changes
   under the same name.
2. **Trace replay** (per merge, decisive): the harness replays every
   trace against the built service over the dev broker and diffs the
   wire-out within the Reproduce column's allowance. Spec moves without
   code, or code without spec, and the replay is red. Catches real
   behavioural drift on covered paths. Misses whatever has no trace.
3. **Changed code names its docs** (CI, seconds): for each code file
   in a diff, the Bindings that cite it must be touched in the same
   change or acknowledged. Catches silent behaviour edits in cited
   code. Misses code nothing cites; that list is the coverage report
   and is not a gate.
4. **Periodic reconcile by an agent** (per merge or weekly): the
   bound files changed since ReconciledAt, read against the clauses
   they bind; divergences listed, each with the clause and one quote
   from the code; ReconciledAt moved. This check is a work list for a
   human and is not a gate: published detectors of this kind recover
   about half of real divergences and raise false ones.

Freshness dates and documentation-coverage percentages are not drift
checks; a date says nothing about whether the content is right.

## Why four checks

Each check is cheap in proportion to what it can see. The column
check runs in seconds on files alone and catches renames, deletions
and unbound clauses. The trace replay needs a built service and a
broker and is the only check that sees behaviour. The changed-code
check ties a diff to the Bindings that cite it. The periodic agent
read is the most expensive and the least reliable, so it produces a
work list and never a gate.

## Who fixes what

A finding names a divergence; the domain's Status says which side is
the suspect. In a Verified domain the executor is the contract and
the code is corrected. In a Draft or Accepted domain the code wins
and the executor is corrected. This is the umbrella's source
precedence (`../conventions/base-CLAUDE.md` "Source precedence") applied to
one finding.

## Open

- The checker and the replay harness do not exist; the alerter builds
  them (OPS-605).
