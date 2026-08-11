# experiments — executor spec

Status: Draft · Pass 0 · Updated 2026-08-10

> What this is: the faithful-rebuild spec for the `experiments` repo —
> how GridWorks experiment records are structured, semafied, and
> verified. The repo's README documents the layout for a human
> reader; this spec holds the architecture and the why.

## Overview

The experiments repo is the durable home of EDD evidence: one folder
per experiment run, a chronological logbook index, shared
pull/display tooling at the root, and a vendored sema snapshot.
Every machine-readable result is a validated sema instance; every
folder README is the canonical narrative those instances back.

## The three-layer data model

1. **Immutable store** — the journal DB (readings tables +
   `gridworks.messages` payloads, decoded through the codec). The S3
   eventstore is the deep archive behind it and carries more than
   the journal (store policy: GridWorks_CLAUDE "Journal DB first;
   eventstore by hand"). Access path + key tables:
   [`journal-db-access.md`](journal-db-access.md).
2. **Validated instances** — experiment folders hold sema-typed
   instances constructed through the vendored snapshot, so schema
   and axioms validate at construction; they are the machine-readable
   record behind each README's Found section. Files a run generated
   that no store can re-supply (harness captures, logs) are verbatim
   evidence, never edited.
3. **Derived display** — human views (display CSVs with natural-unit
   floats) regenerate on demand from the instances and stay out of
   git.

Meaning never comes from layer 1's columns or filenames: the DB's
unit column is read only as a drift tripwire against the channel
word.

## The pull path (`pull_readings.py`)

Three stages: (1) channel words from the scada's own `layout.lite`
emission — latest at-or-before the window end, from
`gridworks.messages` — decoded through the codec and upgraded to
current versions; (2) values and timestamps only from the readings
tables; (3) assembly into one validated `gw.readings` instance per
pull, named in the dash grammar with an optional condition field.
Display CSVs derive from the instance alone, no store access.

## Vocabulary

Five published words (000): `gw.experiment.run` (run metadata),
`gw.readings` (channel words + their readings, one pull), and the
per-channel window statistics `gw.channel.gap.stats` /
`gw.channel.jump.stats` / `gw.channel.noise.stats`. The principles
behind them:

- **A word serves multiple experiment kinds.** Kind-specific
  structure (a run's mode knobs, board constants) stays in plain
  result files described by the README and coins no words.
- **Channel statistics travel with the channel's own word**
  (`ChannelTypeName`/`ChannelVersion`) and speak its serialized
  units, declaring none of their own — a restated unit is drift
  waiting to happen (the ads-noise harness's hardcoded 5.65 kΩ
  against the schematic's 5k6 is the cautionary example: use the
  words the data already has).
- **Statistics may be float-typed** — `positive.float` is the
  precedent that formats refine `number`.
- New experiment words enter the registry as **staging** and are
  promoted once several experiment kinds exercise them; published
  words are immutable.

## Conventions

- **Instance filenames use the eventstore key grammar**:
  dash-separated fields, each internally LeftRightDot,
  `<subject>-<condition?>-<type.name>-<version>.json`; parsing is a
  bare split on dash.
- **Pin-by-hash.** A harness reads each canonical artifact in place,
  records its sha256 (+ mtime for live files) in the result's
  provenance, and archives the exact bytes consumed.
- **HARD RULE.** Experiment data rides sema-typed instances through
  the snapshot, never ad-hoc dicts — a one-off exception requires
  explicit human authorization. Below the word layer the sema-gravity
  maxim applies (GridWorks_CLAUDE).
- **`future/<slug>/`** holds queued experiments undated; a
  `<date>-<slug>/` date is the first run.
- **`ci.sh` is the gate and covers new work by default**: pyright
  over every script (find + commented deny-list for environment-bound
  and archived scripts); every folder emitter, via the
  `*/emit_instances.py` naming convention, reproducing committed
  instances byte-for-byte; `sema validate` over every instance.
  Context-dependent-upgrade instances get an own-version decode
  check instead (the validate CLI always upgrades to latest).
- **The snapshot is seeded** (`src/gwexp/sema_seed_request.yaml`) and
  regenerated only from a clean sema checkout; `--allow-staged`
  stays while any seeded word is staging. A registry word a script
  needs gets vendored via the seed, never noted around.

## Operational facts

Journal-DB creds live in `experiments/.env`; pulls run from a
workstation, never a prod box. The sema CLI runs from the sema repo,
not from experiments.

## Open

- Whether the logbook entry format gains a pointer to the instances.
- `mac.address` format vendoring (link-census wants it) waits for
  the next snapshot regen.
- Interim display conversion (`unit_encodings.py`) is replaced when
  unit harmonization ships `convert()`/`display()`.
