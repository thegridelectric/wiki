# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-terminalasset` code repo**. The matching git commit (in
`gridworks-terminalasset`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-15 — Regenerate sema snapshot: typed gw.house0.hydronic + conformant house0 example <!-- pending commit -->

**What:** Re-ran `build_gwta_snapshot.sh` to regenerate the gwta Sema snapshot from `sema`
`jm/sim-vocab`. Picks up the typed-hydronic promotion (`gw1.hvac.zone`, `gw.house0.primary.flow.source`
enum, `gw.house0.hydronic`; `gw.house0.layout.Hydronic` now `$ref`s the typed block) and the
fully-snapshot-conformant `gw.house0.layout` example (Hubitat poller PascalCase, real `DeviceTypes`
records, `derived.channel.gt → 002`). `house0_layout.py` regenerated with the reworked axioms;
new `gw_house0_hydronic.py` / `gw1_hvac_zone.py` / `gw_house0_primary_flow_source.py` + the
`non.negative.int` format added.

**Why:** keeps the snapshot the scada emits/decodes in sync with sema's source of truth. With it,
the scada↔gwta `layout_roundtrip.py` is green for `gw.house0.layout` and `gw1.simple.sim.layout`
(nolan still red on its pre-existing required-`Hydronic` minimal-instance issue). `mode="strict"`
snapshot gate green: 34 samples round-tripped. (hardware-layout pass-one, OPS-407.)

**What:** Regenerated the gwta Sema snapshot from current `sema` `jm/sim-vocab` via
`build_gwta_snapshot.sh`. Picks up the upstream sema changes (`mac.address` format → `hubitat.gt`
MacAddress + `property_format.is_mac_address`; `ads111x` `OpenVoltageByAdsRange` axiom) **and** adds
the three layout types `gw.house0.layout` / `gw.nolan.layout` / `gw1.simple.sim.layout` with short
local class names `House0Layout` / `NolanLayout` / `SimpleSimLayout` (set via `local_names.yaml`).
Adding the layouts pulled their full dependency closure into the snapshot (data.channel.gt,
derived.channel.gt, the `<family>.device.type.gt` records, gw1.unit/quantity/emission enums, the
unit/telemetry projections). Round-trip green (33 samples). Added `layout_roundtrip.py` — the gwta
side of the bidirectional layout round-trip (SENDS a layout, then verifies scada's returned form).

**Why:** Sema is the source of truth for the layout types; this snapshots them into gwta so the
scada↔gwta layout round-trip can run. The short local names are the agreed ergonomic class names.

## 2026-06-15 — Add g.node.gt to the gwta sema snapshot (`7c61c23`)

**What:** Added `g.node.gt` to the snapshot seed and rebuilt `src/gwta/sema` — now **28 types**
(its closure pulled in the `base.g.node.class` + `g.node.status` enums). 28/28 round-trip.

**Why:** the layout types need `g.node.gt` for their `GNodes`; this is the authoritative source
that was hand-ported into gwsproto (`GNodeGt`). Verified: gwsproto `GNodeGt` → `gwta.sema` decode.

## 2026-06-14 — Rebuild sema snapshot (realistic examples; full gwsproto round-trip) (`1ae4c2c`)

**What:** Regenerated `src/gwta/sema` from the current sema (with the 6 implemented axioms +
the realistic `hubitat`/`ads` example values). All 27 type samples round-trip both ways:
gwsproto emits → `gwta.sema` decodes = **27/27**, with no test patching.

**Why:** closes scada↔terminalasset parity — every snapshot type can be sent by scada over the
dev rabbit broker and decoded here. Pairs with the scada `gwsproto` version-alignment commit.

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
