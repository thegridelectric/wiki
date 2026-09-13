# snapshot-drift-check — vendored sema snapshots are provably unedited

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-538

**EDD: no** build-out of a CI check; verified by running it against a
deliberately hand-edited snapshot and against a clean one.

> What this is: the design for a mechanical guarantee that a consumer repo's
> vendored sema snapshot is byte-identical to what sema generates from the
> commit it was built from, without making consumer CI hostage to the pace of
> sema `dev`.

## The guarantee, and the one it is not

Two guarantees got tangled in the 2026-09-12 async.btu.params review, and
this design is about only the second:

1. *A hand-written gwsproto twin matches its sema word.* Specific to the
   pre-port scada world, where gwsproto is authored by hand; it disappears
   when the proactor port generates gwsproto from a snapshot. Its check is
   an authoring step, `uv run sema validate` from the sema checkout, with the
   `OK:` line pasted into the PR (scada protocol, "gwsproto rules").
2. *A vendored snapshot is what sema would generate.* Applies to every
   consumer, gwbase today and scada after the port, and survives the port.
   The failure it catches is a hand edit to generated vocabulary, which the
   sema-alignment rules forbid and nothing currently detects.

## Frame: pin, don't track

A check that rebuilds against sema `dev` HEAD makes every consumer's CI turn
red whenever sema moves. A check that rebuilds from the sema commit the
snapshot was built from is deterministic: dev can move all week and the
consumer stays green until someone bumps the pin. The pin bump is the one
deliberate act, and it is the moment new vocabulary enters the consumer.

Shape, per consumer:

- the consumer records the sema commit its snapshot came from;
- CI clones sema at that commit and runs the same regen the consumer's
  `scripts/regen_sema_snapshot.sh` runs (`sema snapshot prepare|build` under
  `uv run`, so nothing depends on sema being pip-installable);
- the rebuilt tree is diffed against the vendored one; any diff fails.

This is the closure-mirror check from spruce-unlimbo one level up: a vendored
copy, a named source, a deterministic rebuild, and a diff.

## Open — where the pin lives

The snapshot spec (`sema/spec/snapshot.md`, "Reproducibility") forbids
wall-clock data in a snapshot so that a rebuild over an unchanged registry is
zero-diff, and names the copied registry `last_updated` as the provenance
carrier. A commit hash inside the snapshot would break that rule the same
way a timestamp does: two commits with identical registry content would
produce different snapshots. So the pin has to live beside the snapshot, not
in it. Candidates:

- a lockfile in the consumer repo (`sema.lock` or a `sema_commit` field in
  the seed request), written by the regen script from `git rev-parse` and
  read by CI;
- the regen script already prints the commit it ran from
  (`regen_sema_snapshot.sh`, "sema repo: ... @ <sha>"); recording it is the
  missing half.

Resolve this first; everything else follows from it.

## Open — keeping it painless while dev moves fast

- A pin bump should be one command in the consumer (regen from a chosen
  sema ref, which rewrites the pin), never a hand edit.
- Staging snapshots (`indexes/staging.yaml`) are dev-only by spec; the check
  must not push consumers toward pinning published-only closures before
  they are ready. The check verifies reproducibility, not status.
- The sema CLI refuses to run from a dirty checkout; a CI clone is clean by
  construction, and the pinned commit must exist on the remote (a pin to an
  unpushed local commit is the failure to name in the error).
- The pin is a package version once sema is published from `main`
  (`consumer-conformance.md`), and the rebuild runs the installed tool.
  The clone-and-`uv run` route is the fallback only while no release
  exists.

## Do this next

Answer "where the pin lives" against the snapshot spec, then write the check
once for gwbase, whose snapshot and regen script already exist, and prove it
both ways: green on the clean vendored tree, red after a one-character hand
edit to a generated file.
