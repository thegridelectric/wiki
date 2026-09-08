# main-changes

Status: Draft · Pass 0 · Updated 2026-09-08 · Linear: OPS-392

> What this is: the commits that landed on `main` after `jm/spruce-unlimbo`
> branched, to be read and carried across before the branch replaces
> `main`. Not designed here; the task is the review itself.

The branch will become `main` when spruce-unlimbo finishes. `main` has
kept moving under it, and the boxes run `main`, so anything that landed
there is a fix the fleet relies on. Before the swap, read each commit
below against the branch: carried already, carry now, or superseded by
the renovation. Record the verdict per commit here.

Commits on `main` not on `jm/spruce-unlimbo` (as of 2026-09-08):

  - `2ed4466a` Fixing Standby mode and adding to docs (#567)
  - `d565c46b` Merge pull request #561 from thegridelectric/dev
  - `3d83bfdc` Debug failed transition to BufferOnly (#560)

The same review applies to `actual-spruce` and `jm/spruce` if either
carries a box-only fix that never reached `main`.
