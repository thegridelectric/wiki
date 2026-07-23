# Rebuild from the persistent store

Status: Draft · Pass 0 · Updated 2026-07-20 · Linear: OPS-457

**EDD: yes** the verification IS the real-store experiment: a real ingest
witnessed by the live ear, then a scratch registry rebuilt from S3 alone —
identical, `validate_registry`-clean, checkpoints matching.

> What this is: make `gnr rebuild` restore from the **true persistent
> store** — the ear's S3 eventstore — replacing the provisional
> JSONL-file feed. The replay core is done and proven (OPS-419's
> dev-harness experiment: re-apply/re-refuse, FIFO broadcast checkpoints
> with current-state fallback for snapshots, deterministic forests); this
> design is the input side plus its proof. Until it lands, the JSONL
> rebuild (`gnr.rebuild` + the `gnr rebuild` CLI) stays **off dev**, held
> on the standup branch.

## Gates (both, before execution)

1. **The persistent store has its durable backup** (OPS-443 strand 2's
   second, non-hyperscaler sink). The store being restored *from* must
   itself be the crown-jewel copy; a rebuild path onto a single-sink store
   overclaims durability.
2. **Nodes are Active with TaValidator-authorized PositionPoints** — the
   activation mechanism has landed. This gate is also what closes the
   executor Durability "Open": positions ride outside the command stream,
   so rebuildability requires the activation command to carry them (or a
   restore from the TaValidator store); that decision is part of this
   design's scope, made when activation's shape is real.

## The store (facts, from gjk's importer)

- Bucket `gwdev`; keys
  `<world_instance>/eventstore/<YYYYMMDD>/<from-alias>-<type-name>-<persisted-ms>-<source>`.
- The **type name is in the key** → list cheaply, fetch only
  `g.node.create.cmd` / `g.node.reparent.cmd` / `g.node.forest`.
- `persisted-ms` is the ordering key (capture order), ascending across the
  date-prefixed listing.

## Plan

1. ✅ VERIFIED (2026-07-21, by the genesis itself) — **the live ear hears the
   registry**: the first real create (`hw1.isone`) landed in the S3
   eventstore as both witnesses — the raw command
   (`hw1.registrar-g.node.create.cmd-1784643507026-…`) and the registry's
   forest broadcast 123 ms later. No binding fix needed.
2. **Store adapter** — an `iter_s3_capture(bucket, world_instance, start,
   end)` source yielding capture lines to the existing `replay` core;
   injectable client so it unit-tests without AWS; `boto3` becomes a gnr
   dependency. CLI grows the source flag (`gnr rebuild --s3 …` with
   bucket/world/dates required, no defaults).
3. **Positions restoration** — per gate 2's decision: replay restores
   Active nodes' positions from wherever activation put them; the
   active-position invariant must hold on the rebuilt registry.
4. **The EDD experiment** — real ingest (or a staged mutation batch)
   witnessed by the live ear → wipe a scratch registry → `gnr rebuild
   --s3` from the store alone → identical forest, `validate_registry`
   clean. This experiment is the design's verification bar and the
   evidence for merging the rebuild surface to dev.

## Done-when

- `gnr rebuild --s3` restores a wiped registry from the S3 eventstore
  alone, positions included, proven by the experiment above.
- The rebuild surface (module + CLI) merges to dev with that proof.
- The executor Durability section's positions "Open" is resolved and
  rewritten to state what is.
