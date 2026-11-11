# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-terminalasset` code repo**. The matching git commit (in
`gridworks-terminalasset`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-11-11 — KatahdinComponents.mo: the Katahdin plant as connected components with a placed diagram (`cc3909a`, on `ow/katahdin-fmu`)

`Katahdin.mo` is one model of flat equations, so a Modelica tool shows its
variables and nothing of the pipework. A reader who wants to see the plant,
or to carry it into OMEdit or Dymola and rearrange it, needs components,
connectors and a placed diagram. This file is that, beside the flat model
and not in place of it.

Why its own connectors and no Modelica Standard Library: the reasons the
flat model gives hold here too (a build of seconds, zero flow and flow
reversal by construction). The grid is staggered: a body of fluid (a tank
layer, a header, a tee) carries a filled port that sets pressure and
temperature, a pipe, valve or pump carries a hollow port that sets flow,
and every joint holds exactly one filled port. No tool enforces that rule;
the model's documentation states it for whoever rewires the diagram.

`KatahdinComponents.Plant` keeps the inputs, outputs and parameter names
of `Katahdin.Plant`, so an FMU built from it runs under the adapter
unchanged. Checked by hand, not in ci: such an FMU passes the FMU tests,
and its temperatures stay within 0.0025 K of the flat model's over two
simulated days.

Open:

- The diagram has been parsed by omc (every placement and connection line
  reads) and has not been opened in OMEdit or Dymola.
- Two models of one plant drift. The FMU is built from `Katahdin.mo` and
  nothing in ci translates the component file; the choice is to build the
  FMU from the components and delete the flat model, or to add a ci check
  that the two agree.

## 2026-11-11 — ta-plant runs the physics of a Katahdin house from a Modelica FMU, on a generated Katahdin layout (`6dd37ce`, on `ow/katahdin-fmu`)

The drifting plant shows a scada plausible numbers that answer nothing it
does, so no control code can be exercised against it. A Katahdin house
(monobloc on glycol, plate exchanger, three-tank store, V1 to V5, zoned
distribution, boiler or elements) is where control work goes next, so that
is the first plant with physics.

Why Modelica compiled to an FMU, and not Python physics: the flows form
loops whose direction changes with the valves, the store carries the signed
difference of two pumped flows, and the answer must not move with the
caller's tick (1 s on a laptop, 60 s for a fleet). A variable-step solver
inside the FMU settles all three; Python only sets inputs and reads
outputs. The FMU carries CVODE, and the adapter still sub-steps at 5 s
because an OpenModelica co-simulation FMU checks its own events (a
thermostat, the compressor cut-out) only at the end of a step.

Why one self-contained model and no Modelica Buildings library: the build
is seconds, the export is reliable, and zero flow and flow reversal are
handled by construction (a linear pressure network, every mixing point a
small volume, upwind advection on signed flows). The cost is that every
component is ours to keep honest; the energy-balance test (heat in less
loss equals stored heat, across every mode) is the guard.

Why every coefficient is a placeholder parameter: the priority was the
right parts, wired as the D1116 schematic, running end to end. Pipe
resistances, pump curves, conductances and the heat pump tables are
overridable at start (`--fmu-overrides`) so tuning needs no rebuild.

Decisions a reader cannot see in the diff:

- The model follows the plumbing, not the operating-modes table: a valve
  combination the table never uses still gives the flows the pipework
  would.
- A relay acts through its contact. What a closed contact does is a
  hand-kept table in `katahdin.py` (a fed valve leaves its rest position;
  boiler house rests with the store valved off from the house and the
  boiler in circuit, a house with no boiler rests with the store heating
  the house); no word says what a valve does when fed. Which position
  closes the contact is read from the layout's `relay.control.config`, so
  the plant follows a rewired relay without a code change.
- The heat pump is called by a closed `hp-scada-ops-relay` contact, and
  only while the boiler backup's failsafe relay is energised. That is the
  scada's own usage (hp-boss sends `CloseRelay` to call; `gw.boiler.backup`
  defines the failsafe relay as giving the scada control when energised).
  The relay is normally closed in a House0 layout and larch keeps that, so
  a scada that takes the failsafe relay and does nothing else is calling
  the heat pump. De-energised, the heat pump is its aquastat's, and the
  model has the aquastat make no call.
- Tank 1 is taken as the hot tank; no word says it.
- Pump 0-10 V speed and outdoor temperature do not cross
  `sim.plant.actuation`, so they are FMU inputs that hold their start
  value. A scada that modulates a pump sees no change in flow.
- A simulated tank module and a flow meter report their own electrical
  reading (`-micro-v`, `-hz`) beside the quantity, so the plant encodes
  those as the device does (`sensing.py`); the divider constants and the
  sim sensor's gallons per pulse are hand-kept, each with a note naming
  what retires it.
- The FMU is generated, not committed: `scripts/build_fmu.sh` and the
  image both build it from the Dockerfile's `fmu` stage, and `ci.sh`
  generates it before the tests.

The layout the plant runs on is made here too (`ta-katahdin-layout`,
`tests/config/gw.katahdin.larch.layout.json`), because the plant cannot
boot or be tested without a word that passes `gw.katahdin.layout`'s
axioms, and no other repo makes one: `tlayouts` imports a `layout_gen`
that gridworks-scada no longer has. The generator draws from a House0
layout what the two kinds share and replaces the pipework, so a simulated
Katahdin house senses with the same simulated devices a simulated House0
house does. Larch is invented: the alias, the zone names, the valves'
places on the board's free relays and the secondary pump on `Dfr2` A are
nobody's wiring. The control box borrows `SimHpOdu`, there being no
simulated control box device type. A house with no boiler is generated
with no backup at all; a `gw.element.backup` house needs element relays
the generator does not make.

Open: the scada reads no Katahdin layout, so the plant has run on larch on
the dev broker and not yet beside a scada.

## 2026-10-17 — A test that dev ships no staging word (OPS-473, `5c7a5ca`)

`tests/test_sema_snapshot_published.py` reads the snapshot's own
`definitions/registry.yaml`, where every word and version it ships has a
status, and fails on `dev` when one is not published; off `dev` it reports
the words and skips. Nothing outside the repo is read, so the test runs the
same on a laptop and on GitHub (where a pull request is judged by its
target branch). A regen with `--allow-staged` is the only way a staging
word enters, and this is the gate that keeps such a snapshot off `dev`.

## 2026-10-09 — Track gwbase 0.5.15; the dev g.node.gt.json is written at 006 (`93f52d2, on `dev``)

The floor was 0.5.2; the lock resolves to 0.5.15 so the simulated terminal asset runs on the same gwbase as the fleet. The self-minted dev identity was still a `g.node.gt` 004, which gwbase has rejected since 0.5.10 (it vendors 006 only); the record already carried every 006 field, so only the version string moves. As a `GridworksActor` it gains the alias self-heal; with `gnr_url` unset in the dev rung the lookup is off and the boot log says so (OPS-579).

## 2026-08-22 — take ownership of snapshot seed and regen (`86ee3f2`)

(Squashed in: the README's Sema note rewritten in the sema README's own
canonical words — vocabulary registry, boundary contracts, mechanically
verifiable, plus the boundary-scoping sentence — and the snapshot refresh
that puts the same language in the generated snapshot README.)

gwta's snapshot regen lived as untracked one-off files in the sema *checkout*
(`build_gwta_snapshot.sh` + `gwta_seed_request.yaml` — never committed
anywhere), so the recipe existed on one machine only and a session hunting
for "how does a consumer regen its snapshot" could not find it from this
repo. The seed moves in as `src/gwta/sema_seed_request.yaml` and the script
becomes the standard `scripts/regen_sema_snapshot.sh` (instance of sema's
`template_regen_snapshot.sh`, keeping the `--allow-staged` flag the staging
layout closure needs); the sema-checkout one-offs are deleted. Two stale
seed entries surfaced on the first run — `i2c.adc.config` and
`i2c.dac.config` no longer exist in the registry (that vocabulary evolved
into `i2c.dac.channel.config` etc.), are absent from the snapshot, and are
referenced by no gwta code — dropped from the seed. The regen then ran
clean against sema dev, catching the vendored snapshot up across months of
sema movement (channel-config overhaul, new enums, the generated snapshot
README); suite + import green after. The top-level README gains the
standard Sema pointer (canonical repo, schema-id namespace, snapshot
location + regen path).

## 2026-07-15 — snapshot rebuild: capability words + catch-up to current sema (`0a18bd7`)

**What:** on `jm/delete-cac-id`. The gwta sema snapshot (`src/gwta/sema/`) rebuilt from current
sema `jm/i2c-relay-capability` (~96 files). Two things at once: (a) the capability round — the
seed's explicit i2c targets swap `i2c.{adc,dac,relay}.config` → `i2c.{adc,dac,relay}.capability`
+ `i2c.expander`, and the reshaped `gw1.scada.device.type.gt` (Expanders, ExpanderMembership
axiom) comes through the layout closure; (b) a catch-up across the rounds since the last rebuild
(2026-06-22) — the channel-config overhaul (`capture.tuning` replacing the `channel.config`
family, specialty configs stripped of capture params), `g.node.gt/005`, the operational-params
words, and the current layout shapes. The seed request now records `--allow-staged` (the layout
closure is staging under OPS-445). Snapshot round-trip green (47 samples); gwta suite green.

**Why:** hardware-layout-pass-one (OPS-407) — gwta decodes what scada emits, so its snapshot must
track the vocabulary the tlayouts gen now authors (functional relay names, the krida
`KridaDoubleRelayBoard16` record in `DeviceTypes`). The stale i2c words would have rejected the
new-shape board records at decode.
## 2026-06-22 — refactor snapshot w improved components; also i2c vocab (`7909c37`)

**What:** Rebuilt the gwta sema snapshot (`src/gwta/sema/`) from the current sema source —
picking up the improved component schemas (the `ChannelNameUniqueness` axiom across all
components, `web.server`'s `EmptyConfigList`) — and added the gw108 board descriptor
(`gw1.scada.device.type.gt` → local `ScadaDeviceTypeGt`) plus the full generic `i2c.*`
family (`i2c.bit.address`, `i2c.reg.address`, `i2c.bus`, the four configs, the five bus-op
types, the enums) to the snapshot via `gwta_seed_request.yaml`. 80 files; snapshot round-trip
green for the 34 example-bearing samples.

**Why:** stage the codegen'd decode oracle for the broker round-trip EDD sweep that aligns the
hand-written gwsproto i2c/board types to these sema words — gwta decodes what scada publishes,
proving the hand-port matches the schema. The i2c vocabulary is expected to be **removed from
gwta** once the sweep is done (it doesn't belong in the terminalasset snapshot long-term). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

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
five House0 fleet layouts. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

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
(hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407).)

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
snapshot gate green: 34 samples round-tripped. (hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407).)

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

**Why:** the hello-world design ([OPS-404](https://linear.app/gridworks/issue/OPS-404), Accepted · Pass 1) — prove
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
