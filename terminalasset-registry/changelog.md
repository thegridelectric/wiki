# Changelog

A reverse-chronological log of WHY we made each commit in the **`tlayouts`** code repo
(the precursor to the terminalasset-registry — see
[`designs/stand-up-terminalasset-registry.md`](designs/stand-up-terminalasset-registry.md)).
The matching git commit (in `tlayouts`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki repo's git history.

Newest at the top.

---

## 2026-07-03 — tlayouts: uv scaffold + sema snapshot build infra (`0cdf17f`)

**What:** made `tlayouts` a uv project and set up its vendored Sema snapshot pipeline —
`pyproject.toml` (src layout, name `tlayouts`, pydantic deps), `src/tlayouts/__init__.py`,
`tlayouts_seed_request.yaml`, and `build_tlayouts_snapshot.sh` (mirrors GNR's:
`sema snapshot prepare/build --package-name tlayouts` → rsync `output/sema/` →
`src/tlayouts/sema/`). Seed targets: the four released layouts (`gw.house0.layout`,
`gw.house0.operational.params`, `gw.nolan.layout`, `gw1.simple.sim.layout`) — which pull the
component / channel / config / `g.node.gt` closure, including the still-used older variants —
plus `i2c.relay.component.gt` + `gpio.relay.component.gt` listed explicitly (no layout
references them yet). `local_names` mirror gwsproto (`strip_prefixes: [gw1, gw]` +
`spaceheat.telemetry.name → telemetry.name` = `TelemetryName`).

**Why:** first step toward the terminalasset-registry (OPS-407 hardware-layout-pass-one +
the LTN-brokered app-comms transition, OPS-408): tlayouts becomes a standalone authoring repo
on a Sema snapshot — **no gwsproto, no scada venv** — that builds the two Sema layout artifacts
and writes them to `output/`. Infrastructure only this commit; the generator runs and computes
the closure. The snapshot build itself is **blocked** on stale layout `examples:` (reshaped in
place, e.g. `gw.house0.layout` fails 3399 runtime-decode errors) — tracked by
[`../sema/designs/example-runtime-validation.md`](../sema/designs/example-runtime-validation.md);
next is the `layout_gen` port (which regenerates those examples).
