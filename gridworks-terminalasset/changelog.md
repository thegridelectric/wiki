# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-terminalasset` code repo**. The matching git commit (in
`gridworks-terminalasset`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-16 — house0.layout - entries are required (`2f6c4f8`)

**What:** Rebuilt the gwta sema snapshot (`src/gwta/sema/`) from the sema source after
`gw.house0.layout/000` promoted all six collections + `Hydronic` from optional to `required`
(sema `dc7877f`). Regenerated `house0_layout.py` now declares `g_nodes: list[GNodeGt]` …
`hydronic: House0Hydronic` (no `| None = None`), and the mirrored `definitions/` +
`indexes/` reflect the new `required` block and version summary. Five files: the layout
type, its definition, the registry, `seed_expanded.yaml`, `versions.yaml`. Snapshot
round-trip green (34 samples); gwta suite passes.

**Why:** Keep the gwta decode side in lockstep with the sema source of truth — a House0
layout is a complete, deployable artifact, so the snapshot must reject partial ones too.
Mechanical regen via `sema snapshot prepare/build` from `seed_request.yaml`; no hand edits.

## 2026-06-16 — rebuild sema snapshot for gw.house0.hydronic Cardinality axiom (`748f5d4`)

**What:** Rebuilt the gwta sema snapshot (`src/gwta/sema/`) from the sema source after
`gw.house0.hydronic/000` gained axiom 2 `Cardinality` — `house0_hydronic.py` now carries
`check_axiom_2` (1 ≤ TotalStoreTanks ≤ 6; 1 ≤ |Zones| ≤ 6).

**Why:** keep terminalasset enforcing the same layout invariants as sema — step 2 of the layout
working loop (sema edit → snapshot to gwta). The scada↔gwta layout round-trip stays green for all
five House0 fleet layouts. (OPS-407.)

## 2026-06-15 — patch layout roundtrip test (`a83b8614`)

**What:** Flipped the gwta side of the layout round-trip to the **returner** role: removed the old
gwta-driver (`layout_roundtrip.py`) and added `layout_roundtrip_return.py` — decode a sema layout
through the gwta snapshot and re-encode it.

**Why:** scada now originates the round-trip from a real dc layout; gwta's job is just the
decode + re-encode return leg. Pairs with gridworks-scada `e48393be`.

## 2026-06-15 — SpaceheatTelemetryName -> TelemetryName (`564298c`)

**What:** Regenerated the gwta snapshot with one added local-name override:
`spaceheat.telemetry.name` now generates class `TelemetryName` (`enums/telemetry_name.py`) instead
of `SpaceheatTelemetryName`. `spaceheat.unit` deliberately stays `SpaceheatUnit` (the override is
scoped to telemetry.name only). The rename ripples through every type referencing the enum
(`data.channel.gt`, `maker.api.attribute.gt`, the device-type records, the telemetry-quantity
projection, …) plus the recorded `local_names.yaml` / `seed_request.yaml`. Wire identities unchanged.

**Why:** shorter, cleaner name for the most-referenced enum; the seed-request `overrides` mechanism
keeps it distinct from `spaceheat.unit`. Generated from the sema `gwta_seed_request.yaml` override via
`build_gwta_snapshot.sh`.

## 2026-06-15 — using local names (`dfbca74`)

**What:** Regenerated the gwta Sema snapshot with de-prefixed local (Python) class/module names —
`Gw1Unit → Unit`, `Gw1Quantity → Quantity`, `Gw1ScadaDeviceTypeGt → ScadaDeviceTypeGt`,
`Gw1UnitQuantityProjection → UnitQuantityProjection`, `GwHouse0Hydronic → House0Hydronic`, … with
`gw108.*` left intact — driven by the seed request's `local_names` rule (`strip_prefixes: [gw1, gw]`).
The snapshot also picks up `derived.channel.gt/002`'s repointed enum deps (`gw1.unit/001` +
`gw1.quantity/001`, so `SecondsX10`/`Time` are representable) and now records the original
`seed_request.yaml`. Dotted `TypeName` wire identities are unchanged.

**Why:** settle the cleaner de-prefixed class names now, before terminalasset code is written against
them (no later rename churn), and make the scada↔gwta layout round-trip lossless for the sieg
time-unit derived channel. Generated from sema `14fdfbc` via `build_gwta_snapshot.sh`.

## 2026-06-15 — layout_roundtrip: accept a full layout JSON file (`8e79caa`)

**What:** `layout_roundtrip.py` now takes either a type name (minimal `{TypeName, Version}` stub, as
before) or a path to a `.json` file holding a full layout, which it sends gwta → scada → gwta.

**Why:** to round-trip a **real** sema layout (e.g. maple's full `gw.house0.layout` from the dc→sema
bijection) end-to-end, not just the minimal stub — "the round-trip works for the sema layouts."
(hardware-layout pass-one, OPS-407.)

## 2026-06-15 — create gw.house0.hydronic; fix hubitat snake case (`37d811f`)

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
