# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-terminalasset` code repo**. The matching git commit (in
`gridworks-terminalasset`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-14 — Add sema snapshot at gwta/sema (`b264c6a`)

**What:** Generated a restricted sema runtime snapshot into `src/gwta/sema/`
(import root `gwta.sema`): the codec + base + property_format + the type/enum
runtime for the closure of every **published** `*.component.gt` (16 of them) plus
`spaceheat.node.gt`, expanded to their dependency closure (27 types + enums +
formats). Built with `sema snapshot prepare <seed> && sema snapshot build
--package-name gwta`; the build's round-trip gate passed. `SemaCodec` imports and
decodes from the terminalasset venv.

**Why:** the terminal asset needs to decode/encode the latest component vocabulary
without depending on the full sema registry. This snapshot is the authoritative
reference for the latest component shapes/versions (it is what gwsproto should
match). Drafts (`gw108.gpio.relay.component.gt`) are excluded by the snapshot
builder. Caveat: only 2 of the seeded types carry schema `examples`, so the
build-time round-trip self-test exercised 2 samples — broaden by adding examples
to the component schemas in sema.

**What:** uv project scaffold (src layout, hatchling, pytest + ruff,
`gridworks-base>=0.5.2` from PyPI — no pin needed, gwbase dev == v0.5.2)
and `gwta.hello`: a `GridworksActor`-based TerminalAsset GNode that
provisions the exchange fabric, connects, and broadcasts `heartbeat.a`
at a fixed cadence (`uv run ta-hello`). Smoke tests offline; one
live-marked test, verified green against a local rabbit broker.

**Why:** the hello-world design (OPS-404, Accepted · Pass 1) — prove
the comms plumbing of the simulated-terminal-asset comms rig before any
physics or new sema words; existing gwbase types only.

## 2026-06-11 — MIT license

**What:** MIT LICENSE, Copyright (c) 2026 GridWorks — matching the
sibling repos (gridworks-base, gridworks-scada).

**Why:** Open-source from birth, same terms as the rest of the fleet.

## 2026-06-11 — adding readme

**What:** Standalone README — what a terminal asset is, the
simulated-first scope (synthetic telemetry + comms-test knobs), dev
quickstart.

**Why:** Repo created today as the home for the terminal asset GNode
actor — its own repo on gridworks-base (the MarketMaker pattern: gwbase
stays the base library, domain GNode actors get their own repos),
starting with simulated terminal assets as the comms rig for the scada
simulation harness.
