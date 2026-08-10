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

## Vocabulary sketch — ads-noise pilot

Drafted at the 2026-08-06 re-run; names provisional, authoring gated
on the sema ritual below.

- `experiment.run` (shared word) — the metadata every experiment
  result carries: experiment slug, host, start/end unix ms, pointer
  to the code that ran. (Open below: which existing words already
  cover parts of this.)
- `ads.noise.channel.stats` — one channel under one mode: channel
  name, sample count, mean/sd/p2p voltage, mean/sd temperature.
- `ads.noise.mode.result` — the mode knobs (in-chip data rate SPS,
  poll period ms, EMA alpha if any, cycles), elapsed time, errors,
  and its list of channel stats.
- `ads.noise.result` — the run: the read-path board constants (beta,
  series resistance, reference voltage), the `experiment.run`
  metadata, the mode results.
- `channel.jump.stats` — one fleet channel over one archive window:
  window bounds, reading count, the jump threshold and max-gap
  parameters, spike count, max and median consecutive-reading jump.
  The archive-derived sibling of the bench stats — the canary view
  (daily spike counts flagged spruce's ADS corner three days before
  the 07-29 incident) is a list of these.

Scaled-int units fine enough for the statistics (nanovolts for
voltage sd, micro-°C for temperature sd) would keep this vocabulary
integer-typed and sidestep the `number` question for the pilot;
whether that generalizes to other experiment kinds stays open. The
raw per-sample JSONL stays a plain evidence file next to the
instances, referenced from the README — not sema-typed in this pass.

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
