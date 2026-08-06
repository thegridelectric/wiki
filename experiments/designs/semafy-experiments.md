# semafy-experiments

Status: Draft · Pass 0 · Updated 2026-08-06 · Linear: OPS-490

**EDD: no** vocabulary/tooling build-out; verified by the pilot
experiment's instances passing `sema validate`, not a standalone
real-world experiment.

> What this is: experiment results become validated sema-typed
> instances instead of ad-hoc JSON, with vocabulary added
> BY SUB-FOLDER — each experiment kind brings its own few words.

## The shape

- **Per-kind vocabulary.** Each experiment kind authors the small set
  of words its results need: ads-noise → noise statistics (per-channel
  sd/p2p under a mode), pico-rejoin → join-timing traces, gap-analysis
  → gap/dropout summaries. Shared vocabulary (timestamps, channel
  names, units) is reused, never re-invented.
- **Instances live in the experiment folder**, named
  `<sema-type-name>.json` (TypeName verbatim, dots preserved), next to
  the README whose Found section they back. The README stays the
  canonical narrative; the instances are its machine-readable record.
- **The current state this replaces:** `results-summary.json` shapes
  invented per run — bare floats, no units, no validation
  (`experiments/2026-08-05-ads-noise/results-summary.json` is the
  live example).

## Display units

Depends on harmonize-units (OPS-489): affine metadata on gw1.units
values plus a generated `convert()`/`display()`. Until that lands, one
shared interim `display.py` at the experiments repo top (the
`convert_temp_to_f` shape from scada's
`gwsproto/conversions/temperature.py`, written from the enum
descriptions), deleted the day OPS-489 ships. Experiment words store
canonical scaled-int units where they quote fleet channels; whether
result *statistics* (a standard deviation in µV or °C) may be
`number`-typed is an open sema question below.

## Pilot

The ads-noise re-run with raw per-sample capture
(`experiments/2026-08-05-ads-noise/`) emits the first sema-typed
results. Its vocabulary sketch is the design's first concrete work.

## Gates

Sema word authoring follows the standing ritual: read
`sema/spec/primary.md` plus the registry/authoring spokes for the kind
being touched, summarize back, wait for confirmation. Anything
requiring a spec change (e.g. permitting `number` properties, if not
already allowed) is change-controlled — raise it, never fold it in.

## Open

- May result-statistic properties be `number`-typed, or does the
  vocabulary stay scaled-int with display left to OPS-489's
  projections? (Spec question; answer during the pilot's word
  authoring.)
- Which existing words cover experiment metadata (code-under-test
  commit, window, host) and which need coining.
- Whether the logbook entry format gains a pointer to the instances.

Next move: vocabulary sketch for the ads-noise pilot, at the re-run.
