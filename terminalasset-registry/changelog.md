# Changelog

A reverse-chronological log of WHY we made each commit in the **`tlayouts`** code repo
(the precursor to the terminalasset-registry — see the stand-up-terminalasset-registry
design in this domain's `designs/`).
The matching git commit (in `tlayouts`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki repo's git history.

Newest at the top.

---

## 2026-07-13 — gen authors the operational-params control block (OpsSpec) (`b69e483`)

**What:** on `jm/spruce`. `House0SemaGenConfig` gains a required `ops: OpsSpec` — the
control/optimization block of `gw.house0.operational.params` (modes, COP + heating curve
coefficients, HP cycling / load-estimation knobs, FLO horizon, lat/lon), every field required
with no defaults. `gen_artifacts` emits the full artifact (CopCurve / HeatingCurve sub-types +
inline scalars); oak and house0-stub gens declare their blocks explicitly, currently the scada
`actors/config.py` defaults + the LTN's 48h horizon. Snapshot rebuilt on the extended
ops-params word; both homes regenerate and snapshot-validate.

**Why:** hardware-layout-pass-one (OPS-407) — the authoring side of the ops-params control
block. CAVEAT: oak's block carries the config.py DEFAULTS; the field-deployed per-home values
(the pile's `.env` overrides — notably the real lat/lon) still need confirming before the oak
artifact is treated as field truth. Companion sema + gwsproto commits.

## 2026-07-09 — names from gwsproto (temporary dep); krida record in DeviceTypes; snapshot rebuild (`d75cae0`)

**What:** on `jm/spruce`. Three moves. (a) The `src/tlayouts/names/` mirror is DELETED — names
import from `gwsproto.names` directly, and the gens run with the sibling scada venv
(`../gridworks-scada/gw_spaceheat/venv/bin/python gen_oak_sema.py`) rather than packaging gwsproto
as a dependency: names are mutating rapidly gwsproto-side and the venv already tracks them live.
Temporary until names live in sema; run instructions updated in the gen docstrings + pyproject.
The functional-relay-names flip rides in (`node = channel` in `emit_relays`, node-id continuity
via an `old_name` fallback keyed by the old positional `relay{idx}`). (b) `emit_relays` now
appends the `KridaDoubleRelayBoard16` device-type record to every House0 layout's `DeviceTypes` —
single-sourced from gwsproto's `scada_krida.py` constant (the two-board panel as one device,
RelayNames = basement markings `Relay1`–`Relay32`, first-bank inversion as pin data), re-decoded
through the snapshot so the artifact contract holds. (c) The sema snapshot rebuilt on the
capability round (`i2c.relay.capability` / `i2c.expander` / capability siblings, reshaped
`gw1.scada.device.type.gt`); round-trip green (43 samples). oak + house0-stub regenerated,
snapshot-validated; output byte-identical under the scada venv.

**Why:** hardware-layout-pass-one (OPS-407). Yesterday's double-edit of the same rename in two
name mirrors demonstrated the drift cost; one source now. The krida record puts the zone→relay
knowledge (formerly `krida_failsafe_relay_suffix` arithmetic) into the authored artifact where
scada and field support can read it. Companion commits: sema `3c7e3fb`, scada `4182d88c`.

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
place, e.g. `gw.house0.layout` fails 3399 runtime-decode errors) — tracked by OPS-442;
next is the `layout_gen` port (which regenerates those examples).
