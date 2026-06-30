# Changelog

A reverse-chronological log of WHY we made each commit **in the
`sema` code repo**. The matching git commit (in `sema`) holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-29 — Add capture.tuning/000 (per-channel operational capture tuning) (`c57df6e`)

**What:** new versioned type word `capture.tuning/000` (`literal`, owner
gridworks-energy): `ChannelName` + `CapturePeriodS` + `AsyncCapture` +
optional `AsyncCaptureDelta` + optional `PollPeriodMs`; one axiom
`CaptureAndPollingConsistency` (a: if `PollPeriodMs`, `CapturePeriodS`×1000 >
`PollPeriodMs`; b: when sub-10×, must be an integer multiple) — moved here from
`dfr.config`'s axiom 1, reshaped conditional on the now-optional `PollPeriodMs`.
Registry entry + `check_axiom_1` runtime template + regen; `metadata.last_updated`
bumped to 2026-06-29T19:40:00Z. Suite green (241).

**Why:** first word of the hardware-layout-pass-one operational-params reshape
(OPS-407). The per-channel capture params are *operational*, not topology — a
channel's poll/report cadence changes without rewiring — so they leave the static
`channel.config` family and live in operational-params as this per-channel
sub-type. The hardware floor stays on the device type (`MinPollPeriodMs`); the
`PollPeriodMs ≥ MinPollPeriodMs` check is an assembly-time concern
(`ops_and_sema_to_dc`), not an axiom here. Next: strip the capture params from the
specialty `*.channel.config` types and remove the bare `channel.config` base.

## 2026-06-29 — Release g.node.reparent.cmd + g.node.topology.broadcast (draft → released) (`7743882`)

**What:** flipped both words from draft to released — `$id` and registry
`schema_url` `/draft/types/…` → `/types/…`, removed `status: "draft"` — and
regenerated `indexes/` + runtime (released types now get their per-type runtime
classes). No change to the schema contract (fields/axioms/deps unchanged).

**Why:** the gnr snapshot build excludes draft words, so the registry could not
vendor or use them. Releasing (status only; the schema is identical) lets the
snapshot include them. They remain locally mutable until pushed to origin
(immutability tracks the push), so this is reversible until release.

## 2026-06-29 — Add gnr command words: g.node.reparent.cmd + g.node.topology.broadcast (`8a6202b`)

**What:** two new **draft** versioned type words (v000) on `jm/gnr-commands` for
the Grid Node Registry's mutation contract — `g.node.reparent.cmd` (`NewNode:
g.node.gt/004` + `MovedChildGNodeIds: [uuid4.str]`) and
`g.node.topology.broadcast` (`UpdatedNodes: [g.node.gt/004]`). Kept minimal for
now (edge retire/create set deferred). Plus registry entries (draft status,
`gridworks-energy` owner, `created` 2026-06-29T04:50Z, `direct_dependencies.structural`
= `{g.node.gt:004, uuid4.str}` / `{g.node.gt:004}`), `last_updated` bump, and
regenerated `indexes/` + runtime (`validate.py`; drafts get no per-type runtime
class in the main repo — they generate into the consumer snapshot).

**Why:** build step 5 of the grid-node-registry standup (OPS-419) — the two
Sema messages a re-parent mutation rides on (command in, topology broadcast out),
authored extremely-simple first, to be fleshed out with the handler core. The
example round-trip is exercised when these are vendored into the gnr snapshot.
**Verified:** `pytest` green (177 passed) incl. registry validation.

## 2026-06-29 — Ignore per-consumer snapshot build tooling (`6759f9f`)

**What:** `.gitignore` — generalized the existing `seed_request.yaml` ignore to
`*_seed_request.yaml` + `build_*_snapshot.sh`.

**Why:** per-consumer snapshot build tooling (e.g. `build_gnr_snapshot.sh` +
`gnr_seed_request.yaml`, tracked in the consumer repo) leaves stray artifacts in
a sema checkout when run from here; ignoring them keeps the sema tree clean.

## 2026-06-28 — connectivity.edge.gt ids-only; position.point.gt footprint + immutable semantics (`565d9d0`)

**What:** `connectivity.edge.gt` — dropped `FromGNodeAlias` / `ToGNodeAlias`
(and the now-unused `left.right.dot` dependency); edges carry only the immutable
`From/ToGNodeId`. `position.point.gt` — `extended_description` now prescribes
accuracy by intent (a point falls within the footprint of the GNode's building),
declares the point **immutable** (a location change is a TaValidator
re-certification, not an in-place edit), and notes a per-fix R95 accuracy field is
deferred to the TaValidator/deed machinery. Indexes + runtime regenerated;
`pytest` green (241). Both types are draft/unpushed, so edited in place (no bump).

**Why:** the grid-node-registry standup grill ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
converged the registry's data model: edges key on the **immutable** id and derive
alias on read (a pure rename then touches zero edges and the edge-alias-consistency
invariant disappears); and a GNode's location anchors its TaDeed/TaTradingRights, so
it must be immutable with corrections handled as a certified re-visit.

## 2026-06-26 — Add transactive-power axioms to layout words (`0946021`)

**What:** Added the `TransactivePowerChannel` axiom to both layout words — `gw.house0.layout`
(axiom 5) and `gw.nolan.layout` (axiom 1, its first): exactly one DerivedChannel with Strategy
`transactive-power`, whose `InputChannelNames` resolve to existing `PowerW` DataChannels each of
whose about-node carries `NameplatePowerW`. Executable validators ported into the axiom templates
(no `NotImplementedError` stub left), and the house0 embedded example gained a transactive-power
DerivedChannel so it satisfies the axiom. Regen green (241).

**Why:** Once `InPowerMetering` was dropped from `spaceheat.node.gt`, its `⟹ NameplatePowerW`
obligation had nowhere to live — it folds into this layout-level axiom, which also makes the metered
transactive set singular and auditor-legible. Mirrors the gwsproto
`check_transactive_metering_consistency`. ([OPS-427](https://linear.app/gridworks/issue/OPS-427).)

## 2026-06-26 — Channel-config overhaul: drop Unit/Exponent + InPowerMetering (`1920240`)

**What:** Sema half of the channel-config-overhaul ([OPS-427](https://linear.app/gridworks/issue/OPS-427)),
items 2 + 3. New versions dropping the redundant `Unit` + `Exponent` from every
ChannelConfigBase-family config: `channel.config/001`, `ads.channel.config/001`,
`i2c.thermistor.channel.config/002`, `electric.meter.channel.config/001`, `dfr.config/001`, and
`relay.actor.config/004` (the sixth config-family type — a flat sibling that the channel.config
reverse-dep closure missed). New versions dropping `InPowerMetering` + its axiom:
`spaceheat.node.gt/303` (drops `InPowerMeteringRequiresNameplate`, keeps `NameplatePowerW`) and
`data.channel.gt/003` (drops `PowerMeteringConstraint`). Most referrers repointed in place (unpushed,
no version bump): the 15 component `ConfigList` `$ref`s, the 4 relay components, `layout.lite/015`,
`new.command.tree/002`, and `gw.house0.layout/000` (embedded-example rewrite of 83 nodes / 76 channels /
6 configs / 16 relay configs). `gw.nolan.layout/000` left as-is. **`scada.control.capabilities`** is the
exception: it is published-immutable per its owning design (admin-for-nolan / OPS-394), so instead of an
in-place repoint it gets a clean new **`scada.control.capabilities/002`** (RelayNodes/DacNodes →
`spaceheat.node.gt/303`, ControlChannels → `data.channel.gt/003`); `/001` is restored to `/300`+`/001`
and backfilled with the now-required superseded example.
22 referrer `created` stamps moved forward to satisfy the dependency-timestamp ordering rule. Axiom
validators ported to the new versions; upgrade templates added (`*_to_*`, each dropping the retired
keys); runtime regen deterministic; 240 sema tests green. `egauge.register.config` (modbus register
descriptor) and `maker.api.attribute.gt` (the functional Hubitat scaling exponent) deliberately left
out of scope.

**Why:** a channel's unit and scaling are carried by its identity — `TelemetryName` (data channel) or
`OutputUnit` gw1.unit (derived channel) — so the per-config `Unit` (the old `spaceheat.unit` enum) and
`Exponent` are redundant, and a survey confirmed no driver reads them to scale a reading. `InPowerMetering`
was a source-side copy of routing the consuming transactive declaration owns; it goes from
`spaceheat.node.gt` and `data.channel.gt`. Done now while the carrying component versions are still
unpushed, so the configs are clean version bumps and the components are cheap in-place repoints. Item 4
(the first-class transactive audit-declaration word that replaces `InPowerMetering`'s role) is deferred to
a later pass. The gwsproto/scada side (ChannelConfigBase + RelayActorConfig + SpaceheatNodeGt +
DataChannelGt + ScadaControlCapabilities bumps, removing the two `config.Unit` validation readers, and
computing metering routing from `InputChannelNames`) follows in the scada repo. ([OPS-427](https://linear.app/gridworks/issue/OPS-427).)

## 2026-06-23 — house0 layout axiom 3 → ZoneHeatCallChannel (`b716f75`)

**What:** Replaced `gw.house0.layout/000` axiom 3 `ZoneWhitewirePwrChannel` with `ZoneHeatCallChannel`:
each zone SHALL have a `zone{i}-{name}-heat-call` DerivedChannel (Strategy `heat-call`) plus a per-zone
source DataChannel — `whitewire-pwr` (power-sourced) or `opto-input` (opto-sourced). Schema statement
updated; runtime jinja2 `check_axiom_3` template + regen to follow in this cluster.

**Why:** require the semantic signal (heat-call) the control logic needs, not a specific sensor —
parallel to heat-pump-power and the PrimaryFlowSource agreement. The source is a per-zone hardware
choice (power ⇒ eGauge whitewire, opto ⇒ gw108), so whitewire-pwr drops from always-required to
required-only-when-power-sourced. `gw.house0.layout/000` is unpushed → mutable in place. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — gw108 board example + BusMembership counterexample (`1a1e031`)

**What:** Added the validated gw108 board as the `examples` of `gw1.scada.device.type.gt/000` — the exact
payload the hand-written gwsproto `ScadaDeviceTypeGt` emits, confirmed by `sema validate`. Added a
`BusMembership` (Axiom 1) counterexample fixture + test: a minimal board whose relay references an
`I2cBus` name absent from `BusList`, asserted to be rejected by the runtime codec.

**Why:** closes the Batch 3 (board) leg of the gwsproto→sema conformance sweep — the example pins what a
conformant board looks like, the counterexample pins that the runtime enforces bus membership (accept +
reject, both sides). Indexes regenerated. `pytest` green (232 passed, 1 xpassed). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — add axiom tests and more examples (`bf41287`)

**What:** Added axiom counterexample fixtures + tests for the i2c bus-op types — one
fixture per axiom, each an otherwise-valid payload with a single field mutated to violate
exactly one axiom, asserted to be rejected by the runtime codec:
`i2c.write.bit` (Axiom 1 `BitValueRange`, Value=2), `i2c.read.reg` (Axiom 1 `NumBytesRange`,
NumBytes=3), `i2c.write.reg` (Axiom 1 `NumBytesRange` NumBytes=3, Axiom 2 `ValueFitsNumBytes`
NumBytes=1/Value=300), `i2c.result` (Axiom 1 `ErrorIffFailure`, Success=false with no Error).
Also added gwsproto-validated `examples` to the four config schemas
(`i2c.relay.config`, `i2c.adc.config`, `i2c.dac.config`, `i2c.thermistor.interface.config`).

**Why:** the counterexamples are the other half of the EDD bar — the example proves the runtime
*accepts* a conformant payload, the fixture proves it *rejects* one that breaks the axiom, so each
schema axiom is pinned from both sides. Mirrors the `check_axiom_n` methods on the hand-written
gwsproto producers (a gwsproto axiom dropped → sema still catches it). `pytest` green (231 passed,
1 xpassed). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — add i2c examples, registry alphabetized (`15d94e7`)

**What:** Added gwsproto-validated `examples` to the i2c.* type schemas (Batches 1–2 of the
gwsproto→sema conformance sweep: `i2c.bit.address`, `i2c.reg.address`, `i2c.read.bit`/`write.bit`,
`i2c.read.reg`/`write.reg`, `i2c.result`, `i2c.relay.config`, `i2c.adc.config`, `i2c.dac.config`,
`i2c.thermistor.interface.config`) — each example is the exact payload its hand-written gwsproto type
produced, confirmed by decoding it through the sema runtime (`sema validate`). Also alphabetized the
entries within each section (`formats`/`enums`/`types`) of `definitions/registry.yaml` by key — the
i2c.* words now cluster correctly (they had been inserted in the "g" area); a pure byte-for-byte
reorder, indexes regenerated.

**Why:** the examples document the wire form and are exercised by the snapshot round-trip; the registry
alphabetization is hygiene (entries findable by name). `pytest` green (226). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — sema validate: CLI + API (`40f7643`)

**What:** Added a first-class validation surface. API: `sema.runtime.validate.validate(data)`
→ `ValidationResult{ok, type_name, version, error}` — wraps `default_codec.from_dict` and
returns a structured result instead of raising, so callers can branch; `expected_type=` asserts
the decoded `TypeName`. CLI: a `sema validate [file]` subcommand (file or stdin; exit 0 valid /
2 invalid; `--type` to assert), registered alongside reverse/runtime/snapshot. 6 tests.

**Why:** validating a payload against the Sema vocabulary should be a first-class, shell-usable,
cross-venv operation — decode-through-the-runtime *is* the validation, and Sema is the source of
truth (not a downstream codegen'd copy). This is the per-type tool for the gwsproto→sema
conformance sweep (gwsproto emits JSON → `sema validate`), replacing the indirect gwta-snapshot
proxy. Built on `jm/cli` off `dev` so it merges independently of the in-flight vocab work.

## 2026-06-22 — pin strict-lint test to a committed seed fixture (`1da1c7b`)

**What:** `tests/test_snapshot_strict_lint.py` pointed `prepare_snapshot` at the
repo-root `seed_request.yaml`, which is gitignored (a locally-generated artifact),
so the test raised `FileNotFoundError` on any fresh checkout that lacks it. Copied
the production seed targets into a committed fixture
`tests/fixtures/strict_lint_seed.yaml` and repointed the test at it.

**Why:** The strict-lint guard needs to run for everyone, not just on a machine
that happens to have generated `seed_request.yaml`. The fixture pins the same
targets (notably `scada.params` all-versions, the enums hitting the legacy
GwStrEnum index API, and the typed-map types) so the regression paths the guard
protects stay exercised. Reported by Joe.

## 2026-06-22 — adjust axioms for all the components (`2823a2b`)

**What:** Added the `ChannelNameUniqueness` axiom (axiom 1: "Channel names SHALL be
unique across the ConfigList") to every `*.component.gt` schema + its runtime axiom
template, matching the gwsproto runtime. The 11 axiom-free components got it as their
sole axiom; the 5 with existing axioms had those renumbered up by one
(`ads111x` OpenVoltageByAdsRange→2; `i2c.multichannel` ActorAndRelayIndexUniqueness→2;
`pico.flow` HwUidPattern→2; `pico.tank`/`sim.pico.tank` the three Pico axioms→2,3,4).
`web.server.component.gt` is the exception — it's a software service, not telemetry
hardware, so instead of ChannelNameUniqueness it got an `EmptyConfigList` axiom
(`ConfigList` enforced empty at decode, since the runtime ignores `maxItems`) plus a
"dangler" note in `extended_description`. `electric.meter` already had the axiom. 47
files; runtime regenerated; `pytest` 220 passed.

**Why:** sema is the source of truth for the component axioms, so the schemas must
declare what the gwsproto runtime enforces — Channel-Name uniqueness on every
component's ConfigList. Surfaced that `web.server` is a misuse of the component
concept (no channels) and constrained it honestly. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — gw108 board descriptor + generic i2c bus vocabulary (`dc6800e`)

**What:** Built out the gw108 board descriptor (`gw1.scada.device.type.gt/000`) and a generic `i2c.*`
hardware vocabulary. New types: `i2c.bit.address`, `i2c.reg.address`, `i2c.bus`, `i2c.relay.config`,
`i2c.adc.config`, `i2c.thermistor.interface.config`, `i2c.dac.config`, `i2c.read.bit`, `i2c.write.bit`,
`i2c.read.reg`, `i2c.write.reg`, `i2c.result`, and `gw.native.gpio.pin`; new enums `i2c.adc.type`,
`i2c.dac.type`, `i2c.operation`. The board descriptor gained `BusList`, `NativeGpioInputs`/`Outputs`,
`I2cRelays`, `CtAdc`, `ThermistorAdcs`, `Dacs`, `TelemetryNameList`, and a `BusMembership` axiom (every
device `I2cBus` ∈ `BusList`). String→int maps became typed arrays; silk-screen names are `pascal.case`,
addresses are bus-relative `non.negative.int`. Bus ops compose the address words and carry the `I2cBus`
actor name; `i2c.result` widens `Value`, correlates by `TriggerId`, and enforces `ErrorIffFailure`;
`i2c.read.reg`/`write.reg` enforce `NumBytes ∈ {1,2}` and value-fits-in-NumBytes. Also added the
`ChannelNameUniqueness` axiom to `electric.meter.component.gt` and folded in in-flight `ads111x`/`dfr`
edits. 52 files; runtime + indexes regenerated; `pytest` 220 passed.

**Why:** Make the board the single source of physical truth (resolved via `BoardComponentId`) and give
the I²C layer a generic, composable vocabulary, so board-resident components stay thin references and
all bus traffic can route through one serializing `I2cBus` actor. `i2c.*` is generic; only the board
descriptor and the Broadcom-pin word are `gw*`. Full design + rationale live in the
hardware-layout-pass-one design ("The Sema I²C vocabulary" section). Words authored/edited in place
(unpushed, mutable). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-16 — gw.house0.layout: require all collections + Hydronic (`dc7877f`)

**What:** Promote every collection field (`GNodes`, `ShNodes`, `DataChannels`, `DerivedChannels`,
`Components`, `DeviceTypes`) plus the `Hydronic` block from optional to `required` in
`gw.house0.layout/000` (unpushed → mutable in place, no version bump). Drops the v000 "optional-first
bootstrap" allowance, mirroring the sibling `gw.nolan.layout/000` which already requires all nine
fields. Updated the schema description + registry version summary to match, regenerated runtime
(`g_nodes: list[GNodeGt]` … `hydronic: GwHouse0Hydronic`, no more `| None = None`) and rebuilt indexes.

**Why:** A layout is a complete, deployable artifact, never a partial one — the optional-first shape
was scaffolding to keep the round-trip green while the collections were populated, and they now are.
The codegen was faithfully emitting `Optional[List[...]] = None` because the schema's `required` block
still listed only `TypeName` + `Version`; making the fields required is the real fix, not a codegen
patch.

## 2026-06-16 — start adding house0 layout axioms (`899f79b`)

**What:** Added axiom 2 `Cardinality` to `gw.house0.hydronic/000` (unpushed → mutable in place, no
version bump): (a) `1 ≤ TotalStoreTanks ≤ 6`, (b) `1 ≤ |Zones| ≤ 6`. Implemented `check_axiom_2` in
the runtime axiom template (`templates/axioms/gw_house0_hydronic_000.py.jinja2`) and regenerated
runtime + indexes; aligned the `TotalStoreTanks` field description (was "0..6") to the enforced
1..6.

**Why:** first slice of hardware-layout pass-one Task a — porting the scada dc loader's structural
validations (`house_0_layout.py:100–103`, the 1–6 tank/zone guards) into sema axioms so sema is the
source of truth. Bare `minimum`/`maxItems` are forbidden by sema's primitive-constraint rule, so an
axiom is the carrier. Verified: sema suite green (220 passed), and all five House0 fleet layouts
(maple/beech/elm/oak/fir) still round-trip scada→gwta→scada unchanged with the axiom enforced. A
generated counterexample test (proving the axiom *catches* a violation) is owed once the sema-native
layout gen (Task b) lands. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-15 — fixing local names and patching derived channel (`14fdfbc`)

**What:** (1) **Local names** — replaced the snapshot CLI's clobbering local-names writer with a
declarative mechanism. The seed request now carries a `local_names` block (`strip_prefixes` +
per-type `overrides`); `prepare` materializes `local_names.yaml` from it via
`render_local_names_yaml` (with collision detection), instead of a private `_write_local_names_yaml`
that unconditionally overwrote the file. `prepare` also now records the original `seed_request.yaml`
in the snapshot for provenance. README updated to the new flow. (2) **Derived channel** — reconciled
the in-place `/002` edit (see `4adb357`): registry `direct_dependencies` `gw1.quantity:000 → :001`,
fixed the `gw1.qauntity` summary typo, and made the `001 → 002` upgrade-template docstring mirror the
summary; regenerated indexes + runtime.

**Why:** the old `prepare` reimplemented the local-names emitter and dropped the idempotent helper's
preserve-if-exists guard, so every rebuild clobbered hand-edited local names — the gwta de-prefixing
never survived. Declarative rules in the seed request express the intent (drop `gw1.`/`gw.` prefixes;
keep `gw108.*`) without hand-editing and survive regeneration. The derived-channel reconciliation makes
the kept in-place `/002` internally consistent — the full sema suite is green (220 passed).

## 2026-06-15 — patch derived channel (`4adb357`)

**What:** Repointed `derived.channel.gt/002`'s `OutputUnit` `$ref` to `gw1.unit/001` and
`OutputQuantity` to `gw1.quantity/001` (was `/000` for both) — an **in-place edit of `/002`**.
(The registry/index/upgrade-template reconciliation this required landed in `14fdfbc`.)

**Why:** the scada↔gwta layout round-trip (`maple.json → dc → sema → gwta → scada`) was
silently degrading the sieg `hp-keep-seconds-x-10` channel: scada emits `OutputUnit=SecondsX10`
→ `OutputQuantity=Time`, but `gw1.unit/000`/`gw1.quantity/000` (the versions `/002` originally
pinned) lack `SecondsX10`/`Time`, so gwta decoded them to `Unknown`. Pointing the fields at the
v001 enums (which carry the time values) makes the round-trip lossless.

**Why in-place rather than a new `/003`:** `/002` had been pushed to `origin/dev`, which our
push-based immutability rule treats as frozen — but that freeze is considered premature, and the
schema is **not published** anywhere (nothing resolves on `schemas.electricity.works` yet), so
there is no live contract to protect. A clean `/003` would have cascaded version bumps across the
layout types that embed the channel, for no pre-publication benefit. The edit is also temporally
clean: `gw1.unit/001` and `gw1.quantity/001` share `/002`'s exact `created` stamp
(`2026-03-04T19:00:00Z`), so dependency ordering already holds. Decision: **keep `/002`.** One
carry-forward: this branch's `/002` now differs from `origin/dev`'s; reconcile that at merge.

## 2026-06-15 — freeze and replace spaceheat.make.model (`9430e8c`)

**What:** Marked `spaceheat.make.model` frozen in the registry — added `replaced_by:
[gw1.device.type]` and `frozen_at: "2026-06-15T20:05:00Z"`, and noted the supersession in its
description. Advisory metadata only (no validation/lifecycle/closure change); the enum's published
versions are untouched. `metadata.last_updated` bumped; indexes rebuilt.

**Why:** `MakeModel` is being retired across summer 2026 (the `jm/delete-cac-id` work); device
identity moved to the open `DeviceType` (`gw1.device.type`). The `replaced_by`/`frozen_at` markers
make that migration legible to humans + tooling while keeping `spaceheat.make.model` as frozen base
vocabulary. Part of the wiki MakeModel→DeviceType sweep. `pytest` green (220).

## 2026-06-15 — minor adjustment gw.house0.layout (`70c3dab`)

**What:** Brought the `gw.house0.layout/000` example up to the versions/shape its schema
`$ref`s so the gwta snapshot round-trip gate (`mode="strict"`) passes: (1) the Hubitat `Poller`
sub-objects' keys snake_case → PascalCase (they `$ref` `hubitat.poller.gt` / `maker.api.attribute.gt`,
which require PascalCase — the example was simply wrong); (2) `DeviceTypes` rebuilt from 11 legacy
`cac.gt` / `component.attribute.class.gt/002` stand-ins down to the 2 real specialized records the
schema's `oneOf` allows (`ads111x.based.device.type.gt/000` for the TSnap board with real
`AdsI2cAddressList`/`TotalTerminalBlocks`/`TelemetryNameList`, `electric.meter.device.type.gt/000`
for the eGauge); per the model the other 9 device categories carry no specialized record (their
`DeviceType` lives on the component); (3) the 14 `derived.channel.gt` instances upgraded `001 → 002`,
adding the required `OutputQuantity` (`Temperature` for the FahrenheitX100 depth channels, `Energy`
for the WattHours energy channels, per the unit→quantity projection). Also guarded axiom 2
`EssentialNodesExistence` to skip when `ShNodes` is empty — so the optional-first minimal layout
(`TypeName`+`Version` only) the round-trip script sends validates, while real layouts still enforce.

**Why:** the snapshot round-trip gate (and the scada↔gwta `layout_roundtrip.py`) demand a fully
conformant example; the example had been lagging the schema's referenced versions (a known scaffold).
With this, the gwta snapshot builds and the house0 + simple.sim round-trips are green. `pytest` green
(220). (hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-15 — add gw1.hvac.zone and gw.house0.hydronic (`32540ef`)

**What:** Promoted `gw.house0.layout`'s freeform `Hydronic` block (`additionalProperties: true`)
into typed sema vocabulary, and made the measured-vs-derived `primary-flow` topology explicit:
- **`gw1.hvac.zone/000`** (new shared type) — one heating zone (`Name`, `Critical` bool,
  `KwhPerDegF`); replaces the former parallel `ZoneList` / `CriticalZoneList` /
  `ZoneKwhPerDegFList`, so their subset / equal-length invariants are now structural.
- **`gw.house0.primary.flow.source/000`** (new versioned enum) — `Measured` | `DerivedSiegSum`.
- **`gw.house0.hydronic/000`** (new type) — typed hydronic: `Zones` (list of `gw1.hvac.zone`),
  `TotalStoreTanks` (`non.negative.int`), `UseSiegLoop`, `SiegLoopPlumbed` (replacing the bare
  `FlowManifoldVariant`), `PrimaryFlowSource` (`$ref` the enum), `Strategy`; axiom 1
  `SiegLoopControlImpliesPlumbed` (`UseSiegLoop ⟹ SiegLoopPlumbed`).
- **`gw.house0.layout/000`** — `Hydronic` now `$ref`s `gw.house0.hydronic`; the unconditional
  hand-axioms (old 2 `HydronicStructure`, 5 `FlowTopologyDeclaration` shape) became structural;
  axioms renumbered to 1 `GlobalIdUniqueness`, 2 `EssentialNodesExistence`, 3
  `ZoneWhitewirePwrChannel` (now over `Zones`), 4 `PrimaryFlowSourceChannelAgreement`
  (`Measured ⟺ a primary-flow DataChannel`; `DerivedSiegSum ⟺ a primary-flow `sum`
  DerivedChannel`). `TankTempCalibrationMap` dropped from the layout (derived channels are the
  calibration source of truth). Runtime + indexes regenerated. v000 edited in place (unpushed).

**Why:** the measured-vs-derived `primary-flow` choice is a real physical-topology fact (a flow
meter at the primary pump or not) that was implicit in which gen builders ran. Making it explicit —
and typing the hydronic block — follows the sema rule that a known, axiom-constrained shape belongs
in the schema, not in a freeform object + hand-axioms (`spec/authoring/types.md` Inline Objects /
Open Containers). `gw1.hvac.zone` is shared so Nolan can adopt it when its hydronic is promoted
(hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407)). `pytest` green (220).

## 2026-06-15 — gw1.tank.temp.calibration + .map → v001 (integer B in FahrenheitX100) (`efeafc0`)

**What:** Bumped `gw1.tank.temp.calibration` and `gw1.tank.temp.calibration.map` to v001, mirroring
`linear.one.dimensional.calibration/001`: `Depth{1,2,3}B` changes `number → integer`, where `B` is
now an offset in the consuming derived channel's OutputUnit (FahrenheitX100) scaling rather than a
°F float. Added the 000→001 upgrade templates (the upgrade is the `round(B × 100)` reinterpretation,
°F → FahrenheitX100; the map lifts its nested Buffer/Tank via their own `.upgrade()`), examples on
the now-superseded v000 schemas, and bumped `metadata.last_updated`.

**Why:** the in-field tank calibration `y = M·x + B` is applied in the FahrenheitX100 output domain
(see `wiki/gridworks-scada/executor/hardware-layout.md` "In-field tank-temp calibration"); making
`B` an integer in that domain removes the float/°F ambiguity that had `B` mis-scaled across the
dev → jm/spruce transition. `pytest` green (220).

## 2026-06-15 — WIP: enforce gw.house0.layout axioms (4 + validator template + beech example) (`3422ca9`)

**What:** WIP toward axiom enforcement on `gw.house0.layout/000`: lifted 4 of the stashed axioms
(GlobalIdUniqueness, HydronicStructure, EssentialNodesExistence, ZoneWhitewirePwrChannel) into
`x-gridworks.axioms`, authored the validator template
(`templates/axioms/gw_house0_layout_000.py.jinja2`), and embedded a real bijection-generated **beech
example** (~3.6k lines) so the snapshot round-trip can validate the axioms.

**Why:** subset-first proof of the sema→gwta→scada axiom-enforcement loop. **Caveat — incomplete:**
this is the active axiom-loop WIP; the snapshot build is currently **blocked** by this embedded
example until the bijection adapter serializes the poller with `by_alias` (the on-disk fixtures are
already PascalCase). Resume here for the axiom loop.

## 2026-06-15 — Stash gw.house0.layout axioms; gitignore gwta snapshot tooling (`273815e`)

**What:** Added `definitions/types/gw.house0.layout/stash_axioms.md` — the gw.house0.layout axiom
catalog (22 axioms), ported from the live `gwsproto/data_classes/house_0_layout.py` +
`hardware_layout.py` validations (GNode set, id uniqueness, device-type membership, hydronic
structure, essential + required topology nodes, tank-temp-calibration, system-model energy channels,
sieg manifold, base-layer integrity) plus zone axioms (MVP per-zone whitewire-pwr channel; a
connect-everything zone structure adapted from the nolan stash, using gwsproto/names house0 naming).
Kept as a stash (markdown, deferred enforcement) like gw.nolan.layout. Also gitignored the local-only
`gwta_seed_request.yaml` + `build_gwta_snapshot.sh`.

**Why:** the goal for gw.house0.layout is to carry the data-class validations as sema axioms; this
records the full catalog ahead of wiring enforcement (which needs a real bijection-generated example).

## 2026-06-15 — Add gw.house0.layout + gw1.simple.sim.layout; lay out House0 shape (`470d6db`)

**What:** Created two new layout vocabulary types — `gw.house0.layout` and `gw1.simple.sim.layout`
(`gw.nolan.layout` already existed), with registry entries + `direct_dependencies`. Both began as
minimal `TypeName`+`Version` stubs; then `gw.house0.layout/000` was laid out with the full property
set mirroring `gw.nolan.layout` (new DeviceType model): GNodes, ShNodes, DataChannels,
DerivedChannels, a `Components` oneOf for the House0 set (eGauge `electric.meter`, `ads111x.based`
TSnap, Krida `i2c.multichannel.dt.relay`, `dfr`, `pico.flow.module`, `pico.tank.module` +
`sim.pico.tank.module`, `hubitat.component` + `hubitat.poller.component`, `web.server`), a
`DeviceTypes` oneOf, and a freeform `Hydronic` block — optional-first (only TypeName+Version
required). Indexes + runtime regenerated; `metadata.last_updated` bumped. (The snapshot tooling
`gwta_seed_request.yaml` + `build_gwta_snapshot.sh` — prepare → remap the three layout local names
to `House0Layout`/`SimpleSimLayout`/`NolanLayout` → build → copy to gwta — is kept as local,
untracked tooling in the sema repo, deliberately out of this commit.)

**Why:** Sema is the source of truth for the three mutating layout types; this lays the House0 shape
down so it can be built up bit by bit and round-tripped against scada. `pytest` green (218).

## 2026-06-15 — Add mac.address format; ads OpenVoltageByAdsRange axiom (`abbc250`)

**What:** Added a `mac.address` format (six lowercase hex octet pairs, colon-separated;
`^([0-9a-f]{2}:){5}[0-9a-f]{2}$`) + its runtime validator template, and pointed
`hubitat.gt`'s `MacAddress` at it (`type: string` → `$ref formats/mac.address`, edited in place
— pushed to git but not web-published, so still mutable this session). Added an
`OpenVoltageByAdsRange` axiom to `ads111x.based.component.gt` (each element in [4.5, 5.5]) and
implemented its template. Bumped the `created` of `hubitat.gt` + `hubitat.component.gt` (dep
ordering) and `metadata.last_updated`; added `mac.address` to the property-format test map.
Regenerated; `218 passed`.

**Why:** closes the two "sema looser than gwsproto" divergences from hardware-layout-pass-one —
MacAddress now carries the lowercase-hex constraint (was a plain string), and the OpenVoltageByAds
"near 5V" range is a sema **axiom** (rather than a gwsproto-only Near5 validator or a speculative
format). gwsproto mirrors both (it already used a strict MacAddress type; the Near5 field-validator
became `check_axiom_1`). Snapshot not rebuilt — gwta will be re-snapshotted as a batch.

## 2026-06-15 — Un-draft device-type records + gw.nolan.layout; stash nolan axioms (`7d4f634`)

**What:** Un-drafted the three specialized device-type records (`ads111x.based.device.type.gt`,
`electric.meter.device.type.gt`, `gw1.scada.device.type.gt` — they were never meant to be
drafts) and `gw.nolan.layout/000`. Moved the layout's ~40 axioms into
`gw.nolan.layout/stash_axioms.md` (a markdown file the yaml-globbing tooling/tests skip) and
stripped them from `000.yaml`, so the type generates a runtime **without** axiom validators.
Dropped the `gw108.gpio.relay.component.gt` placeholder from the layout's Components oneOf (the
real relay is `gw108.vdc.relay`, already present), rewrote `direct_dependencies` to the actual
schema $refs (no axiom-only / transitive deps), and bumped `created`. Regenerated; `216 passed`.
`gw.nolan.layout` now has a sema runtime class.

**Why:** the hardware-layout-pass-one branch is building the full layout types now (axioms
implemented later — `gw1.simple.sim.layout` + `gw.house0.layout` to follow the same pattern).
Immutability is push-to-origin this session, so these unpushed un-drafts are still mutable.
`gw1.scada.device.type.gt` stays a partial stub by design (built out as we go). Next: add the
layouts to the gwta snapshot + gwsproto.

## 2026-06-14 — Guard test: every superseded upgrade is defined (no stubs) (`b38e628`)

**What:** Added `tests/runtime/test_superseded_upgrades_defined.py` — for every superseded
published type version that carries an example, decoding it with `auto_upgrade` must reach the
latest version or deliberately raise `UpgradeRequiresContext`; a `NotImplementedError` fails
the test. 44 cases (21 real upgrades, 23 context-dependent refusals). Full suite `216 passed`.

**Why:** an audit prompted by the hardware-layout version bumps found **no** dangling/stub
upgrades — every transition has a defined `upgrade()` (real, or an explicit
`upgrade_requires_context` for cac→DeviceType / FlowMeterType / layout aggregates that need the
source layout). But the scaffold tool seeds new upgrade templates as `raise NotImplementedError`
stubs and nothing caught a left-behind one. This guard closes that gap — the same way examples
and axioms are now enforced. Companion to the gwsproto version-alignment work ([OPS-407](https://linear.app/gridworks/issue/OPS-407)).

## 2026-06-14 — Fix 2 example values to round-trip through gwsproto (`698b1b3`)

**What:** `hubitat.gt` + `hubitat.component.gt` example `MacAddress` `"example"` →
`"34:e1:d1:82:22:22"`; `ads111x.based.component.gt` example `OpenVoltageByAds` `[0.0]` →
`[4.95]`. Non-normative (example-only); no version bump. Regenerated runtime; `172 passed`.

**Why:** sema is looser than gwsproto on these two fields (plain string vs gwsproto
`MacAddress`; bare number vs gwsproto `Near5`), so the auto-generated minimal examples were
sema-valid but gwsproto-invalid. Realistic values let the snapshot's own samples round-trip
through gwsproto unchanged (27/27, no patching). Open question recorded in the
hardware-layout-pass-one design: whether sema should add `mac.address` / `near5` constraints to
close the looseness (that would be a version bump, and gwsproto would follow).

## 2026-06-14 — Implement 6 stubbed axiom validators + add examples to 25 schemas (`a8a7f25`)

**What:** Implemented six axiom-validator templates that were `NotImplementedError`
stubs: `dfr.config`/`ads.channel.config` `CaptureAndPollingConsistency`;
`pico.flow.module.component.gt` `HwUidPattern`; `pico.tank.module.component.gt` +
`sim.pico.tank.module.component.gt` `PicoHardwareIdentityXor` /
`PicoKOhmsConsistency` / `SensorOrderPermutation`;
`i2c.multichannel.dt.relay.component.gt` `ActorAndRelayIndexUniqueness`. Added a
minimal, axiom-satisfying `examples:` entry to 25 schemas (the terminal-asset
snapshot closure) that lacked one. Regenerated runtime + indexes; `172 passed`.

**Why:** the gwta terminal-asset snapshot's round-trip gate could only exercise 2
of 27 types — the rest lacked examples, and 6 also decoded through stub axiom
validators that raise. With the validators implemented (the axiom *statements*
were already published; this only fills in the generator, not a contract change —
permitted as a runtime-consistency fix) and examples added (non-normative,
permitted on published versions), a rebuilt snapshot now reports
"Round-trip OK: 27 sample(s)". `layout.lite/015`'s axiom remains a stub (not in
the terminal-asset closure; its layout-wide invariant is a larger, separate
implementation). The axiom logic is new — flag for JM review against the stated
semantics.

## 2026-06-14 — Add the Hubitat component pair (sema gap-fill complete) (`b7d2cae`)

**What:** Authored the last five beech/house0 component words sema lacked, bottom-up and flat:
`maker.api.attribute.gt/000` (one MakerAPI device attribute → SCADA channel; all `snake_case`
fields re-cased to CamelCase, refs `spaceheat.telemetry.name:007` + `spaceheat.unit:001`);
`hubitat.gt/000` (hub connection settings) and `hubitat.poller.gt/000` (poller settings, a
`ConfigList`-style array of `maker.api.attribute.gt`); and the two flat component shells
`hubitat.component.gt/000` (`Hubitat` → `hubitat.gt`) and `hubitat.poller.component.gt/000`
(`Poller` → `hubitat.poller.gt`), both carrying `DeviceType` (open `pascal.case`) and a
`channel.config` `ConfigList`, mirroring the dfr/ads shells. `MacAddress` modeled as a plain
string (already normalized lowercase-colon at the SCADA boundary; a `mac.address` format was
deliberately NOT added — speculative vocabulary on legacy-only words). Registry + indexes +
runtime regenerated; `172 passed`; the three top-level types decode + re-encode against real
new-shape instances (sema decoder cross-check).

**Why:** closes the component gap-fill — every `*.component.gt` a beech/house0 layout names now
exists in sema. The MakerAPI URL/REST helpers are computed in app code, not serialized, so they
are excluded from the contract and called out in each word's `extended_description` (this
vocabulary serves the five legacy House0 homes with no forward expansion). Shape follows the
migrated sema patterns; the old scada types were a field reference only.

## 2026-06-14 — Begin adding remaining components needed for house0 (`64bce72`)

**What:** Filled four `*.component.gt` types (+ sub-types) that a beech/house0 layout uses but
sema lacked: new `dfr.config/000` → `dfr.component.gt/000`; `ads.channel.config/000` (with
`ThermistorDeviceType` — an open `pascal.case` `gw1.device.type` value, replacing the old
`ThermistorMakeModel` enum field) → `ads111x.based.component.gt/000`; and a new versioned enum
`thermistor.data.method/000` (`SimpleBeta` / `BetaWithExponentialAveraging`). All born flat and
migrated (carry `DeviceType`, no cac). Registry + indexes + runtime regenerated; `172 passed`.

**Why:** Phase 1 added some device-type *records* to sema but missed these *components* and their
channel configs — so a real production (beech) layout could not be fully expressed in the sema
vocabulary. Shape follows the migrated sema patterns; the old scada types are a field reference
only (possibly stale). `near5` deliberately not added as a format (`OpenVoltageByAds` is a bare
number array). Remaining: the Hubitat component pair (needs `snake_case → CamelCase` re-casing).

## 2026-06-14 — Adjusting pico btu and flow meters v 001 (`abc369f`)

**What:** `pico.flow.module.component.gt/001` and `pico.btu.meter.component.gt/001` (both
draft/unpushed — revised in place, no new version): `FlowMeterType` moved from
`$ref spaceheat.make.model` to `$ref formats/pascal.case` (an open `gw1.device.type`
string). Dropped the `spaceheat.make.model` dependency from both `001`
`direct_dependencies`; added an `extended_description` to each; recorded the FlowMeterType
delta in the `000→001` upgrade docstring + the registry summary (kept mirrored);
regenerated indexes + runtime.

**Why:** retiring `make_model` across the hardware-layout vocabulary — device identity is
the readable `gw1.device.type` `DeviceType`. Keeping `FlowMeterType` an open `pascal.case`
string (not an enum `$ref`) keeps the component type version-stable as device types grow;
the enum membership is articulated by the hardware layout that composes the type. Mutated
in place (version `001` preserved) so the aggregate layout words (`gw.nolan.layout`,
`layout.lite`) that compose these types do not rebind.

## 2026-06-14 — Aggregate rebind: gw.nolan.layout DeviceTypeMembership axiom + new layout.lite/015 (cac-free) (`0cd2175`)

**What:** Two aggregate hardware-layout types reconciled to the cac-free `DeviceType`
vocabulary. (1) `gw.nolan.layout/000` (draft): `Components` oneOf rebound to the new
`DeviceType` component versions; `DeviceTypes` swapped from CAC refs
(`component.attribute.class.gt`, `electric.meter.cac.gt`) to the specialized records
(`electric.meter` / `ads111x.based` / `gw1.scada` `.device.type.gt`); the old
`DeviceTypeReferenceIntegrity` axiom reworked into **`DeviceTypeMembership`** (every
Component's `DeviceType` ∈ `gw1.device.type`, and any category needing a specialized record
has a matching `<family>.device.type.gt` in `DeviceTypes`); stale
`DeviceType.ComponentAttributeClassId` dropped from `GlobalIdUniqueness`; `gw1.device.type:000`
added as an axiom dep. (2) **New `layout.lite/015`** — `/014` rebound to the cac-free embedded
component versions (`pico.tank.module` 011→012, `sim.pico.tank.module` 000→001,
`pico.flow.module` 000→001, `i2c.multichannel.dt.relay` 004→005). The `014→015` upgrade is
`UpgradeRequiresContext` (the embedded components migrate cac_id→DeviceType, which needs the
source layout); `/014` gained a compact example (now superseded); the real beech/spruce
upgrade-to-latest tests now assert the context-dependent refusal.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407), hardware-layout pass one (1.5 tail). The authoritative hardware layout now
expresses the device-type model (components key into specialized records by `DeviceType`,
membership a layout invariant). `layout.lite` needed a NEW version rather than an in-place
rebind: it has a live upgrade chain over real field projections, and the scada emits a
`layout.lite` on boot — `/015` keeps that emission coherent with the migrated components while
old projections (with cac components) refuse to auto-upgrade without context.

## 2026-06-13 — Drop cac_id from all emitted component types → gw1.device.type DeviceType; add draft `<family>.device.type.gt` records (`2d55705`)

**What:** Every emitted component type drops `ComponentAttributeClassId` (the cac UUID)
and gains `DeviceType` (an open `pascal.case` string, a `gw1.device.type` value) as a new
version — `electric.meter` (→002), `gw108.gpio.sensor/relay/vdc.relay` (→002),
`i2c.multichannel.dt.relay` (→005), `i2c.thermistor.reader` (→002), `pico.btu.meter`
(→001), `pico.flow.module` (→001), `pico.tank.module` (→012), `web.server` (→002),
`sim.pico.tank.module` (→001, `SimulatesVersion` 011→012). The two never-emitted sim
types (`sim.sensor`, `sim.relay`) are mutated in place at `/000`. Each new version's
upgrade is `UpgradeRequiresContext` (DeviceType lives on the referenced cac, not the
component); each now-superseded version carries a field-sourced `examples:` block.
Added three **draft** specialized records — `electric.meter.device.type.gt`,
`ads111x.based.device.type.gt`, `gw1.scada.device.type.gt` (minimal stub) — keyed by
`DeviceType`. Froze `component.attribute.class.gt` (`replaced_by: gw1.device.type`) and
`electric.meter.cac.gt` (`replaced_by: electric.meter.device.type.gt`). Also fixed the
generated `new_command_tree` upgrade's mypy typing at its template source.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407), hardware-layout pass one. Replaces UUID `cac_id` device identity with a
readable `DeviceType`; a plain device is now fully described by its `DeviceType` value +
its own component fields. A CAC that carries real category-level data does not vanish — it
becomes a per-family `<family>.device.type.gt` joined by the shared `DeviceType`.
Immutability is gated on real-world emission in gridworks-scada (spruce/field layouts), so
every emitted type earns a new version; only the never-emitted sim types mutate in place.

## 2026-06-13 — gw1.device.type: drop UnknownDeviceType + GridworksSimMultiTemp, add AbstractWebServer (`d4a3e26`)

**What:** `gw1.device.type/000` now 20 values. Dropped `UnknownDeviceType` (no
"unknown" device type — the scada loudly refuses unknown hardware instead) and
`GridworksSimMultiTemp` (superseded by `GridworksSimSensor`, which is fully configured
from its Component `ConfigList`). Added `AbstractWebServer` — a generic web-server
*service* component (not hardware), replacing the old `UNKNOWNMAKE` web-server hack.
`default` is now `EgaugePowerMeter` — **vestigial**: `DeviceType` is required on every
component, so the enum default is never exercised.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407). Removing the "unknown" sentinel forces every component to name a real
device type; `AbstractWebServer` keeps the model uniform (every component carries a
`DeviceType`) while honestly marking the web server as a generic service, not a make/model.

## 2026-06-13 — Trim gw1.device.type to referenced device types (47 → 21) (`3c88996`)

**What:** Pruned `gw1.device.type/000` from 47 to 21 values, dropping device types whose
old `MakeModel` had no live reference in `gridworks-scada` (only the CACS tables / enum
def / comments). Kept the device types actually used in `layout_gen` / drivers / real
layouts / tests (incl. both thermistors and `UnknownDeviceType` at that point).

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407) — the enum should carry the device types we actually use, not the full
legacy `spaceheat.make.model` set. Removals verified by searching scada+tlayouts per
make.

## 2026-06-13 — Add gw1.device.type enum (device category replacing make/model-as-CAC) (`a8e0401`)

**What:** New `gw1.device.type/000` enum — 47 PascalCase device-category values (46
device types + an `UnknownDeviceType` sentinel/default), migrated from
`spaceheat.make.model` (each value's description notes its old MakeModel). Registry
`metadata.last_updated` bumped to cover the new `created` date.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407) (hardware-layout-pass-one) replaces UUID `cac_id` device identity with a
`gw1.device.type` key: a device *category* (PascalCase, the `pascal.case` format), NOT a
make+model — several eGauge models map to one `EgaugePowerMeter`. Components will carry
`DeviceType` as an open `pascal.case` string (version-stable); the hardware layout
enforces membership in this enum. `spaceheat.make.model` is frozen at `/008`. (The
UUID-valued enum + projection was abandoned — sema string-enum values must be Python
identifiers.)

## 2026-06-13 — adjust sema spec rules for enums (`0283544`)

**What:** Added a "String Enum Value Constraints — values are Python identifiers"
section to `spec/authoring/enums.md`.

**Why:** Document the hard constraint the runtime generator already enforces —
`GwStrEnum` sets a string enum's wire value *equal to* its Python member name (via
`auto()` + `_generate_next_value_`), so every value must be a valid Python identifier;
`regenerate_runtime.py` rejects anything else. Surfaced the hard way when a UUID-valued
`gw1.device.type.id` enum + projection (for the device-type bijection) failed to
generate. The note also records the projection corollary (source and target enums must
both have identifier values) and the PascalCase value convention. Lineage: [OPS-407](https://linear.app/gridworks/issue/OPS-407)
(hardware-layout-pass-one), which dropped UUID device ids for a `gw1.device.type` enum.

## 2026-06-13 — Add strict-lint regression test for the generated runtime (`189ec23`)

**What:** New `tests/test_snapshot_strict_lint.py` — prepares the full
`seed_request.yaml` and runs `build_snapshot_runtime("gjk", strict_lint=True)`,
which raises `LintGateError` on any ruff/mypy violation in the generated tree.

**Why:** the existing snapshot-build tests run with the default `strict_lint=False`,
which only *prints* lint violations, so the generator could emit ruff/mypy-dirty
runtime and the suite stayed green — exactly how the gjk-snapshot failures reached a
human (Joe) instead of CI. Verified the guard bites: reverting the three generator
fixes (enum index API, scada.params upgrade typing, typed-map `Any`) makes this test
fail with 7 errors; with them in place it passes. Pairs the three preceding commits
with the test that would have caught them.

## 2026-06-13 — Stop emitting unused `Any` import for typed-map types (`d4b4892`)

**What:** Removed a spurious `ctx.needs_any = True` from the type generator
(`runtime_generation/types.py`) on the typed-`additionalProperties` branch, which
renders `dict[str, <resolved-type>]` (e.g. `dict[str, Gw1TankTempCalibration]`) and
never uses `Any`. Regenerated `runtime/types/gw1_tank_temp_calibration_map.py`.

**Why:** the generator imported `typing.Any` but left it unused for map types, a
ruff `F401`. When the value annotation genuinely needs `Any`, the recursive
`_annotation_for_schema` call sets the flag itself, so the explicit flag was
redundant. Clears the last generator lint violation under the snapshot gate.

## 2026-06-13 — Drop unused `GwStrEnum` index API (`to_index`/`from_index`) (`bf4914c`)

**What:** Removed `to_index`, `from_index`, `_init_index_maps`, and the
`_index_to_value`/`_value_to_index` maps from the generated `GwStrEnum` base
(`runtime_generation/enums.py` literal); regenerated `runtime/enums/gw_str_enum.py`.
Also widened `_missing_(value)` to `object` to match `Enum`.

**Why:** legacy carry-over from gwproto's positional index / symbol wire-encoding —
not part of the Sema enum contract (enums are closed value sets; `spec/authoring/enums.md`
has no index concept) and with zero callers across sema, scada, base, journalkeeper.
Cleared five mypy errors (dynamically-set attrs mypy can't see + the `_missing_` LSP
override). Removes the notion of assigning indices to enum values.

## 2026-06-13 — Type `scada.params` nested-upgrade loop vars as `SemaType` (`863f171`)

**What:** Annotated the `new_params`/`old_params` loop variables in the
`scada.params` 004→005 upgrade template (`upgrades/scada_params_004_to_005.py.jinja2`)
as `SemaType`; regenerated `runtime/types/old_versions/scada_params_004.py`.

**Why:** `scada.params:004` carries `NewParams`/`OldParams` as a `oneOf` of
`ha1.params` 004|005, lifted to 006 via a multi-step `while … .upgrade()` loop (the
only upgrade body that loops). mypy narrowed the loop var to the field union on first
assignment, then rejected the broader `.upgrade()` result. Annotating to the base
`SemaType` (which carries `.version` and `.upgrade()`) lets the polymorphic loop
typecheck. Loop preserved; runtime behavior unchanged — round-trip was always green.
Surfaced only by the snapshot mypy gate.

---

## 2026-06-13 — Draft `MakeModelCacIdConsistency` axiom on `gw.nolan.layout` (`ee9d267`)

**What:** Added a draft (documentation-only) axiom `MakeModelCacIdConsistency` to the
draft `gw.nolan.layout/000`: a DeviceType with a known MakeModel must use that
MakeModel's canonical `ComponentAttributeClassId`; `UnknownMake__UnknownModel` may use
any UUID. No deps added (prose statement); the layout is draft so it generates no
runtime.

**Why:** the in-canon home for the MakeModel↔CAC-id bijection — resolved design:
enforce on the **layout** (self-validating; device-type + components stay
version-stable), not the device-type. Enforcement stays scada-side
(`CACS_BY_MAKE_MODEL`) until the `gw1.cac.id` enum + `gw1.make.model.cac.id`
projection land and the layout publishes. Resolution in
`executor/hardware-layout.md`.

## 2026-06-13 — Reconcile `gw.nolan.layout` draft to the new vocabulary (`38e5129`)

**What:** Updated the (still-draft) `gw.nolan.layout/000` refs to the shared layout
words: `data.channel.gt` 001→002; `i2c.multichannel.dt.relay.component.gt` 003→004;
`pico.tank.module.component.gt` 000→011; the Components `oneOf` now carries the real
nolan set (`gw108.vdc.relay`, `i2c.thermistor.reader`, `sim.pico.tank.module`, plus
the `gw108.gpio.relay` draft); dropped `gw1.scada.device.type.gt` from DeviceTypes;
relay axiom pins `relay.actor.config` 002→003; `heatcall.interpretation` →
`gw1.heat.call.interpretation`. Bumped `created` so it is ≥ its new deps.

**Why:** close the loop on the layout-vocabulary sweep — the draft now references
words that exist. **Kept draft** (publishing/de-drafting deferred; nothing emits a
`gw.nolan.layout` yet).

## 2026-06-13 — Phase-A sim enablers: `make.model/008` + `sim.relay.component.gt/000` (`af2bf49`)

**What:** New enum version `spaceheat.make.model/008` adds `GRIDWORKS__SIM_SENSOR`
+ `GRIDWORKS__SIM_RELAY_BANK` (additive). New non-draft `sim.relay.component.gt/000`
— the flat sim-marker relay component the scada-side `SimRelayActor`'s relay node
uses (`ConfigList` of `relay.actor.config/003`), parallel to
`sim.sensor.component.gt`.

**Why:** Phase-A sema enablers (build-plant "Sema changes needed for Phase A").
Two makemodels because sensor vs relay are distinct device classes (`layout_gen`
dispatch + the `CACS_BY_MAKE_MODEL` bijection key on MakeModel). **Still needed for
sim CACs:** `component.attribute.class.gt/002` (refs `make.model/008`) so a CAC
carrying the sim makemodels decodes — deferred (task #6), along with the complex
`gw1.scada.device.type.gt` (name kept; nested config needs ~5 promoted sub-types).
`pytest` green; no sim-layout fixture yet.

## 2026-06-12 — Add nolan-layout shared vocabulary to sema (flat, non-draft) (`6f73174`)

**What:** Swept most of the shared layout-manipulation vocabulary into sema as
**flat** types — every field spelled out, no base-class inheritance (the gwsproto
`ComponentGt` / `ComponentAttributeClassGt` / `ChannelConfigBase` inheritance is a
flaw, not mirrored; `ConfigList`s compose real config types by `$ref`). New
non-draft words: CACs `component.attribute.class.gt/001` + `electric.meter.cac.gt/001`;
configs `egauge.register.config/000` + `electric.meter.channel.config/000`;
components `electric.meter.component.gt/001`, `gw108.gpio.sensor.component.gt/001`,
`gw108.vdc.relay.component.gt/001`, `web.server.component.gt/001` (inline
`WebServer`), `pico.btu.meter.component.gt/000`, `sim.sensor.component.gt/000` (the
`sim.*`-named simulated-sensor component a SimSensorActor uses); enum
`gpio.sense.mode/000`. `i2c.thermistor.channel.config` and
`i2c.thermistor.reader.component.gt` were **restarted at `001`** — the never-emitted
sema `000`s were dropped (the field only ever emits `001`). `gw108.gpio.relay.component.gt/001`
added as a **draft** placeholder (no gwsproto class). All new types are
**structural-only** (gwsproto axioms deferred).

**Why:** so the plant (`gridworks-terminalasset`) can read and process the *same*
`hardware-layout.json` the scada runs from — the layout's composing types must live
in sema. En route to spruce-unlimbo; reused for sim components.

**Verified (EDD, cross-carrier):** real scada-format instances decode clean through
the sema runtime — `component.attribute.class.gt`,
`electric.meter.{cac,channel.config,component}`, `egauge.register.config`,
`web.server.component.gt` (house0/oak); `gw108.{gpio.sensor,vdc.relay}` +
`i2c.thermistor.{channel.config,reader}` (nolan); `pico.btu.meter.component.gt`
(tlayouts/beech). `component.attribute.class.gt` also confirmed via a **live gwsproto
emit → sema decode**. `sim.sensor.component.gt` has no fixture yet (sema
generated-sample round-trip only). Harness:
`sim-time-experiment/layout_roundtrip_check.py`.

**REVIEW (Jessica):** (1) CACs are structural-only — the `MakeModel↔CAC-id` mapping
is GridWorks deployment policy, not a sema cross-system contract, so the axiom was
dropped. (2) gwsproto emits `null` for absent optionals (sema tolerates it; a design
to stop emitting None is queued). (3) `gw.nolan.layout` draft ref-reconciliation is
still pending. (4) `gw1.scada.device.type.gt` intentionally dropped (CAC→device-type
transition not happening yet).

## 2026-06-12 — Finish the ActorClass cascade + fix an immutability slip (`cc3fac8`)

**What:** New versions `layout.lite/014` and `new.command.tree/002` re-point ShNodes
to `spaceheat.node.gt/302` — `new.command.tree/002` **drops the multi-version
`oneOf`** for a single clean `/302` (upgrade lifts old nodes). **Reverted** the
in-place edit to non-draft `scada.control.capabilities/001` (immutability
violation); its `/302` bump is deferred to the planned admin-for-nolan v002. Added
an `extended_description` "back-dated-traffic anti-pattern" note to 6 old `oneOf`
schemas (`new.command.tree/000`, `layout.lite/009/010/011`, `scada.params/004`,
`report/002`).

**Why:** complete the actor-class ripple through the published embedders while
respecting immutability (non-draft schema = no functional change → new version).
The old `oneOf` unions are flagged as a sema-bring-up lenience, not propagated.

## 2026-06-12 — `spaceheat.node.gt/302` + ActorClass cascade (`2b9e099`)

**What:** New `spaceheat.node.gt/302` re-points `ActorClass` to `gw1.actor.class/012`
(picks up `SimSensorActor`/`SimRelayActor`); trivial 301→302 upgrade, axiom
implementations ported, hand-written tests bumped + a v302 fixture. The two
embedders re-pointed **in place** (unpublished/draft): `scada.control.capabilities/001`
and `gw.nolan.layout/000` → `/302` (their `created` bumped to 2026-06-12 to satisfy
causal-timestamp ordering).

**Why:** the ActorClass cascade — adding the two sim actor classes forces a
`spaceheat.node.gt` bump and everything embedding it. `data.channel.gt` /
`derived.channel.gt` reference nodes by *name*, so they don't ripple. Remaining
embedders `layout.lite` + `new.command.tree` (both published) are separate version
bumps, still pending.

## 2026-06-12 — Add `gw1.actor.class/012` — `SimSensorActor` + `SimRelayActor` (`a7aa496`)

**What:** New enum version `gw1.actor.class/012` appends `SimSensorActor` and
`SimRelayActor` (`011` preserved under `old_versions/`); registry + indexes +
runtime regenerated. (The commit title reads "v011"; the diff adds `012`.)

**Why:** The two scada-side actors of the simulated test environment need
actor-class identities — `SimSensorActor` reads `sim.plant.flux` →
`synced.readings`, `SimRelayActor` sends `sim.plant.actuation`. First step of the
`ActorClass` cascade; the `spaceheat.node.gt/302` bump that picks up `012` follows.

## 2026-06-12 — Mint `sim.plant.actuation/000` + `change.relay.pin/000` enum (`81005bc`)

**What:** New type `sim.plant.actuation/000` — the actuation *event* a SimRelayActor
sends to the plant: `RelayName` + `Action` (Energize/DeEnergize via the new
`change.relay.pin` enum) + `ActuationTimeUnixMs` (sim time) + `ActualTimeUtc`
(human-readable). New string enum `change.relay.pin` (DeEnergize/Energize),
mirroring gwsproto's `ChangeRelayPin`. Regenerated indexes + runtime.

**Why:** The inverse boundary of `sim.plant.flux`: a simulated relay sends its
energize/de-energize event — the i2c multiplexer's atomic pin action, *not* the
closed/open interpretation (which depends on wiring) — into the plant, which
resolves the physical effect from the layout. Modeled as an event, not a state,
because actuation is an event. `change.relay.pin` was minted because sema had only
`change.relay.state` (CloseRelay/OpenRelay = the wiring-dependent closed/open
framing) and `relay.energization.state` (a state).

## 2026-06-12 — Mint `sim.plant.flux/000`, the simulated plant's source emission (`386ea55`)

**What:** New versioned type `sim.plant.flux/000` (+ registry entry, regenerated
indexes/runtime, filled `ListLengthConsistency` axiom template). Fields:
`ChannelNameList` + `ValueList` (index-aligned), `ScadaReadTimeUnixMs` (sim time,
`utc.milliseconds`), `ActualTimeUtc` (wall-clock, human-readable
`utc.iso8601.millis`). No `Simulates*` identity fields. Bumped
`metadata.last_updated` to 2026-06-12.

**Why:** The simulated terminal asset (gwta) emits its physical state as
`sim.plant.flux`; the scada-side sim sensor reads and *interprets* it into
`synced.readings` (and electrical/other derived signals later). It is the
plant-emits/sensor-reads boundary word of the SCADA simulated test environment
([OPS-40](https://linear.app/gridworks/issue/OPS-40)). Two timestamps because under sped-up coordinator time the sim clock
outruns the wall clock — `ActualTimeUtc` is human-readable provenance for CSVs,
not consumed downstream. `Simulates*` was dropped deliberately: the plant's raw
emission must not presume its destination.

## 2026-06-10 — Runtime ruff-clean at source: generator formats, drift guards compare formatted (`cdeba05`)

**What:** `generate_runtime_from_dag` now runs `ruff format` (`format_in_place`)
as its final pass, so the committed `src/sema/runtime` is ruff-clean. The four
`test_runtime_generation_*` drift guards format the generated output before
comparing (so canonical = formatted on both sides). Regenerated the runtime —
45 files reformatted once — and updated `regenerate_runtime.sh`'s header to
state the new canonical (ruff-formatted) and that its `ruff format --check` now
passes clean ("157 files already formatted").

**Why:** Permanently closes the *format* half of the `regenerate_runtime` trap.
Previously canonical was the *raw* generator output, so `ruff format` diverged
from it — the reason an in-place format in the `.sh` broke the drift guards.
Making ruff the single source of style (templates need not match it) means
`--check` is green and the format trap cannot recur; it also unifies the in-repo
runtime with the snapshot path, which already treated ruff-formatted as
canonical. This is the deferred follow-up to `a4a8b83`. The remaining `ruff
check` + `mypy` findings (over-/under-tracked typing imports; pydantic/enum
dynamics) are a *separate* report-only generator-cleanup follow-up, untouched
here.

## 2026-06-10 — new.command.tree/000 axiom: PrefixClosedHandles via effective handle (`668f00f`)

**What:** Rewrite `new.command.tree/000` axiom 1 from `PrefixClosedHierarchy`
(two-part: ShNode `Handle` *and* `ActorHierarchyName` each prefix-closed) to
**`PrefixClosedHandles`** — a single prefix-closure rule over each node's
*effective handle* (its `Handle` if present, else its `Name`). Rewrites the
axiom template + regenerated runtime enforcement, enriches the
`extended_description` (command-authority chain, runtime bossable-actor
`FromHandle`/`ToHandle` checks → `bad_boss` Glitch, dynamic handle reassignment,
dormant/root nodes), and adds a real-world `real_maple.json` fixture + test. The
`ShNodes` `oneOf [200, 300, 301]` widening was already on dev, so this commit is
axiom-only (no registry/index change).

**Why:** Captures what the SCADA↔LTN command tree actually does in the field.
The effective-handle convention lets a root node omit `Handle` on the wire (its
`Name` anchors children) while still participating in prefix-closure, and the
single-rule axiom matches the runtime enforcement bossable actors already
perform. **Modified `000` in place rather than bumping to `001`** — a deliberate
source-precedence call (rule 1, explicit instruction): field reality before sema
was well-structured is the higher truth, overriding the additive/version-bump
MUST, since `000` is pre-production. Faithful replay of `jm/fix-new-command-tree`
onto current dev: that branch forked from an ancient dev (~150-file divergence),
so the substantive delta was replayed on a clean branch + regenerated, not
merged.

## 2026-06-10 — gw1.unit/002 + regenerate_runtime.sh hygiene-report (`a4a8b83`)

Landed as one commit ("Various — gw1.unit/002 from Joe and various cleanups").
Two distinct changes:

**(1) Add `gw1.unit` version 002** (`DollarsX1000`, `MilesPerHourX1000`,
`KilowattHoursX1000`). `registry.yaml` (`latest_version: 002` + the `002` entry)
and the new `definitions/enums/gw1.unit/002.yaml`, then regenerated indexes +
runtime. Additive only; `000`/`001` preserved verbatim (frozen
`runtime/enums/old_versions/gw1_unit_001.py`). The runtime regen wired the new
member into the three types that reference `gw1.unit` (`derived_channel_gt`,
`gw1_unit_quantity_projection`, `synced_readings_bundle`).

*Why:* makes those 3 members canonical, so the gridworks-journalkeeper snapshot
regen ([OPS-386](https://linear.app/gridworks/issue/OPS-386)) no longer drops units its persistors use — they had been
hand-patched into JK's old snapshot. This *replays* Joe's reviewed schema delta
(`jds/dollarsX1000`) onto current `dev` rather than merging his stale branch;
merging the 29-commits-behind branch produced generator/formatting drift (4
`test_runtime_generation_*` failures), whereas replaying the delta and
regenerating with `dev`'s own generator is clean.

**(2) `regenerate_runtime.sh` reports hygiene, never mutates the runtime.**
Change `ruff format` from an in-place rewrite to `ruff format --check` (report
only), alongside the already report-only `ruff check` / `mypy`; `--strict` still
makes any finding fatal.

*Why:* the canonical runtime is the *raw* `regenerate_runtime.py` output — what
the committed tree is and what the `test_runtime_generation_*` drift guards pin.
The in-place `ruff format` rewrote the runtime into a *different* form (it wraps
the over-long `e.compile(...)` line in `property_format.py`), so a regen via the
`.sh` silently diverged from canonical and turned the drift guards red — a trap
that cost real time. Report-only converges the `.sh` with the `.py` (the
generator is deterministic, so no formatting step is needed for zero-diff), so
**either entrypoint is now safe.** Making the generated runtime ruff-clean *at
the source* (so `--check` passes clean and the trap cannot recur) is the next
step.

## 2026-06-09 — Merge pull request #21 — jm/ops-380-snapshot-improvement (`8293b4e`)

**What:** Merge landing the [OPS-380](https://linear.app/gridworks/issue/OPS-380) snapshot-improvement branch on `dev`. The
constituent commits each have their own entries below (`bea9846`, `ee5bd53`,
`0169b47`, `653a152`, `701495c`, `be72b40`, `6f68508`).

**Why:** Collectively: snapshot builds became deterministic (zero-diff regen
via canonical formatting + stable ordering), atomic (failed gate = no-op), and
gated (round-trip over generated samples, with the context-dependent-upgrade
exemption), with the contract canonized in `spec/snapshot.md`. Consumers
regenerating a snapshot no longer fight cosmetic formatter drift — this
resolves the 2026-05-25 finding where ~75% of a gjk snapshot-refresh diff was
ruff-format noise.

## 2026-06-08 — feat: UpgradeRequiresContext for context-dependent upgrades (`701495c`)

**What:** New `UpgradeRequiresContext(SemaError, ValueError)` in the
runtime base (`templates/base.py.jinja2`) + a `SemaType.upgrade_requires_context()`
factory so an upgrade body raises it via the already-imported `SemaType` (no new
per-file import). The three upgrades that legitimately cannot run on a standalone
instance — `scada.control.capabilities/000→001`, `send.layout/000→001`,
`linear.one.dimensional.calibration/000→001` — now raise it instead of a bare
`ValueError`. The shipped round-trip gate (`templates/roundtrip.py.jinja2`) and
the build-time check catch `UpgradeRequiresContext` in the decode-old→upgrade
step and treat it as an **expected pass** (the sample still must round-trip at its
own version). Runtime regenerated; spec `authoring/type-semantics.md` Upgrade
Discipline documents the contract.

**Why:** [OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4 mandates an example on every superseded version and the
gate upgrades each sample to latest — but some `old→new` transforms need
out-of-band context (layout handles/ids, source message) an isolated message
can't carry, so their `upgrade()` correctly refuses. A bare `ValueError` made
"refuses by design" indistinguishable from "broke." The typed exception lets the
gate exempt exactly those versions from the upgrade round-trip while keeping the
example mandate + decode-own-version coverage (the `atn.bid`-class check) intact.
`scada.control.capabilities/000` (in the thread-4 backfill set) is the version
that forced this.

## 2026-06-09 — drop rolled-back structured-enum residue (`6f68508`)

**What:** `CLAUDE.md` Universal MUSTs — removed the `(for structured enums this
extends to attribute rows/columns…)` parenthetical from the enums-are-additive
bullet. Structured enums were rolled back (`0bf8f0f`), so the clause referenced a
capability that no longer exists.

**Why:** Stale residue left by the structured-enums rollback; surfaced while
closing out the `untangle-market-type-name` design ([OPS-378](https://linear.app/gridworks/issue/OPS-378)). Keeps the operative
instructions honest.

## 2026-06-08 — backfill: examples on 20 superseded versions, flip gate, fold snapshot spoke (`be72b40`)

**What:** (1) A minimal, schema-valid, axiom-consistent `examples:` block on each
of the 20 superseded type versions that lacked one (enumerated by
`tests/registry/test_superseded_examples.py`): `channel.readings/001`,
`flo.params.house0/003-006`, `fsm.full.report/000`,
`i2c.multichannel.dt.relay.component.gt/002-003`, `layout.lite/007-012`,
`report.event/002-003`, `scada.control.capabilities/000`, `scada.params/004`,
`spaceheat.node.gt/200,300`. Each round-trips at its own version and, where the
upgrade is runnable, along `decode-old → upgrade() → decode-current`
(`scada.control.capabilities/000` is upgrade-exempt via `UpgradeRequiresContext`,
`701495c`). Several were mined from existing field/test fixtures (the `layout.lite`,
`report.event`, `i2c`, `spaceheat.node.gt/300` instances); the rest authored
minimal. (2) The `xfail` marker is removed from `test_superseded_examples.py`,
promoting it to a hard gate. (3) Folds the design's durable architecture into a
new language-neutral `spec/snapshot.md` spoke (determinism/zero-diff, atomic
build, `samples/`, the round-trip gate + context-dependent-upgrade exemption),
linked from `spec/primary.md`; Python tool specifics stay in the
`src/sema/tools/` docstrings per the in-repo-spec / wiki-pointer split.

**Why:** [OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4 — completes the mandate landed in `ee5bd53` so the
snapshot round-trip exercises every old version along the upgrade path where
restricted-snapshot bugs concentrate (the `atn.bid` class; this same pass already
surfaced the `layout.lite/007→008` ShNodes-lift bug fixed in `0169b47`). Folding
the durable architecture into `spec/` is the prerequisite to deleting
`wiki/sema/designs/snapshot-improvement.md` (per designs-process); the design
file is removed once this lands.

## 2026-06-08 — test: enforce upgrade docstring ↔ registry summary mirror (`653a152`)

**What:** New `tests/registry/test_upgrade_summary_matches_template.py` asserts
that for every `templates/upgrades/<type>_<a>_to_<b>.py.jinja2`, the upgrade
docstring equals `registry.yaml` → `types.<type>.versions.<b>.summary` (modulo
whitespace) — true for all 30 upgrade templates today. Plus a `CLAUDE.md`
"Upgrade deltas live in three coupled places" note naming the
template-body+docstring / registry-summary / `direct_dependencies` triple and
pointing at the spec's "Nested Upgrades" rule.

**Why:** The `007→008` ShNodes omission drifted silently because the prose
summary and the upgrade docstring (mirror copies) were maintained by hand with
no gate, while the machine `direct_dependencies` stayed correct. The test turns
that mirror into an enforced invariant — editing one side without the other now
fails CI — and the `CLAUDE.md` note makes the coupling discoverable so a future
session checks the registry when it touches an upgrade.

## 2026-06-08 — fix: layout.lite 007→008 upgrade lifts ShNodes 200→300 (`0169b47`)

**What:** `templates/upgrades/layout_lite_007_to_008.py.jinja2` (and its
regenerated output `runtime/types/old_versions/layout_lite_007.py`) now lifts the
embedded `ShNodes` list through `spaceheat.node.gt` `200 → 300` during the
`007 → 008` upgrade: `data["sh_nodes"] = [node.upgrade() for node in self.sh_nodes]`,
plus the matching docstring line. The same change-line was missing from the
registry's prose record, so `registry.yaml` → `layout.lite.versions.008.summary`
gains `- ShNodes[]: spaceheat.node.gt:200 -> 300` (the version's
`direct_dependencies` already carried `spaceheat.node.gt:300` — only the summary
had drifted); `indexes/public_registry.yaml` + `indexes/versions.yaml` rebuilt to
match. (No version bump — completing a non-normative summary is a permitted
descriptive correction.)

**Why:** `layout.lite/007` declares `ShNodes: spaceheat.node.gt/200`, but
`LayoutLite008` accepts only `300` — the `007 → 008` upgrade bumped the version
and added the new top-level fields yet never lifted the embedded nodes, so any
`007` instance carrying nodes raised a `literal_error` on upgrade. The gap had
gone unnoticed because no old-version `layout.lite` fixture exercised the chain
(fixtures start at v011, whose nodes are already `301`). Surfaced by the [OPS-380](https://linear.app/gridworks/issue/OPS-380)
thread-4 backfill: a realistic `layout.lite/007` example must round-trip
`decode-old → upgrade() → decode-current`, which is exactly the path this gate
exists to protect (the `atn.bid` class). The sibling steps in the chain
(`009→010` ha1 guard, `011→012` sub-type lifts, `012→013` i2c None-guard) were
audited against the per-version field types and are correct.

## 2026-06-08 — spec: superseded type versions MUST carry examples (`ee5bd53`)

**What:** Two spec edits + a new (xfail) enforcement test, no schema/data
changes. `spec/registry/types.md` "Permitted Changes (All Types)": added a
bullet explicitly permitting *addition or improvement of non-normative
`examples`* on a published version (same family as "clarification of descriptive
text" — alters no validation behavior). `spec/authoring/types.md`: retitled
"Examples (Optional)" → "Examples" and added a "Superseded versions" rule — a
type version that has a successor MUST carry at least one `examples:` entry;
latest versions and versionless types stay optional. New
`tests/registry/test_superseded_examples.py` enforces the mandate by walking
`definitions/types/`; marked `xfail` (non-strict) until the one-time backfill of
existing old versions lands ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4), at which point it xpasses and
the marker is removed.

**Why:** Superseded versions exist to be **upgraded**, and the
`decode-old → upgrade() → decode-current` path is where restricted-snapshot bugs
concentrate (the `atn.bid` class). The snapshot round-trip can only exercise a
version it has a fixture for, and the fixture is the authored `examples:` entry
(→ a generated sample). So every superseded version needs an example for
old-version round-trip coverage to be total. Permitting examples on published
versions removes the immutability grey area that would otherwise block the
backfill — examples are non-normative guidance, not validation behavior. Part of
[OPS-380](https://linear.app/gridworks/issue/OPS-380) (thread 4, spec half; the example backfill itself follows separately).

## 2026-06-08 — snapshot: round-trip gate + generated samples + lint-gated atomic build (`bea9846`)

**What:** Reworked `sema snapshot build` (`src/sema/interfaces/cli/snapshot.py`)
to generate into a **staged** tree, gate it, and swap into place only on green —
a failed gate is a no-op (the previous snapshot is left untouched), replacing the
old clear-then-write that could half-write on failure. New gates:

- **`samples/`** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 3) — `src/sema/tools/snapshot_check.py` runs in a
  subprocess against the staged package and, for every type version under
  `definitions/` with an `examples:` block, feeds the first example through the
  snapshot codec (`from_dict → to_dict`) and writes the canonical serialized form
  to `samples/<type.name>[.<version>].json` (old versions included). Writes a
  coverage `samples/README.md`. Samples are the exact wire bytes the runtime
  emits, so they double as the round-trip's expected output and don't churn.
- **Round-trip gate** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 2) — a new shipped, pydantic-only
  `roundtrip.py` harness (`templates/roundtrip.py.jinja2`, emitted by
  `generate_runtime.py`) walks `samples/`, decodes each at its own version,
  re-encodes (deep-equal), and upgrades superseded versions to latest. Run
  build-time over the staged tree (raises → no-op) and re-runnable consumer-side.
  This is the check that catches a word missing only from the *restricted*
  snapshot (the `atn.bid` class). `tests/test_snapshot_roundtrip.py` proves it
  flags a non-decoding sample.
- **Lint gate** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 1) — `src/sema/tools/snapshot_lint.py` runs
  `ruff format` in place (the generator already sorts output, so format makes a
  re-build a zero diff) and reports `ruff check` / `mypy` (fatal only under
  `--strict-lint`, because the generator emits known pre-existing violations
  that are a tracked cleanup). New `scripts/regenerate_runtime.sh` applies the
  same gates to the in-repo runtime.

Stopped vendoring `tests/` into snapshots: removed the `write_tests` path
(`generate_runtime.py`, `formats.py` — deleted `generate_property_format_test`)
and its emission at the build call site; snapshots now ship `samples/` +
`roundtrip.py` instead of generated test code. Updated `test_snapshot_cli.py`
(asserts no `tests/`, presence of `samples/` + `roundtrip.py`) and dropped the
obsolete `write_tests` unit test.

**Why:** Standing up the gridworks-journalkeeper snapshot surfaced four
frictions: formatting-only regen churn that buries real diffs; generated test
*code* leaking into the consumer package; no per-type decode test (the gap that
let the `atn.bid` closure bug ship); and no ready JSON fixtures per type. The
round-trip gate makes "does the emitted runtime decode its own types" a
build-time invariant against the *restricted* vocabulary — exactly where a
sema-runtime test can't see the bug. Atomic staging means a failing gate can
never corrupt a consumer's snapshot. `ruff format` + the generator's existing
sorting make a second regen a zero diff. Part of [OPS-380](https://linear.app/gridworks/issue/OPS-380) (threads 1–3).

---

## 2026-06-08 — drop snapshot.built_at from the restricted registry (`c1d9dad`)

**What:** Removed the wall-clock `built_at` field (and the now-empty `snapshot:`
section) that `build_restricted_registry` injected into the snapshot's
`registry.yaml` (`src/sema/tools/build_seed_definitions.py`); dropped the
now-unused `datetime`/`timezone` import; updated `_is_top_level_sections_mapping`
to expect `[metadata, formats, enums, types]`.

**Why:** `built_at` was non-deterministic — it made every snapshot regen diff on
`registry.yaml` regardless of generated-code formatting, blocking the zero-diff
goal ([OPS-380](https://linear.app/gridworks/issue/OPS-380), thread #1). Nothing reads it; snapshot provenance is already
carried by the copied `metadata.registry_version` + `last_updated`. Dropping the
`snapshot:` key also makes the restricted registry conform to the spec's
top-level structure — `metadata/formats/enums/types`, which has no `snapshot`
section (`spec/registry/structure.md`). Part of [OPS-380](https://linear.app/gridworks/issue/OPS-380).

---

## 2026-06-08 — remove structured enums. market slots must be divisible by 300 (`0bf8f0f`)

**What:** Removed the unpublished structured-enum capability from the prior
commit. Reverted `spec/authoring/enums.md`, `spec/registry/enums.md`, and the
`spec/primary.md` enum-glossary line (drops the "Structured Enums" section +
`value_attribute_schema`/`value_attributes` rules); restored the codegen path
(`src/sema/tools/runtime_generation/enums.py`) and runtime base
(`src/sema/runtime/enums/gw_str_enum.py`) to pre-capability; demoted
`gw.market.product.name` to a plain versioned enum (`value_descriptions` only).
Kept the rest of the untangle — the `market.type.name → gw.market.product.name`
rename, the `market.product` type, the pure-pattern `market.slot.name` format,
and `frozen_at`. Added a one-line clarification to `spec/authoring/formats.md`
that the no-reference rule binds a format's validation behaviour / generated
validator, not just its schema `$ref`. Same cluster, two additions: (1) enrich
`market.product` with the name-encoded fields it now carries as validated data —
`SlotDurationMinutes`, `GateClosingSeconds`, and `QuantityUnit` (`$ref`
`market.quantity.unit`, a power unit so quantities compare across slot
durations); `Timeframe` deferred. (2) Bake the 5-minute grid invariant into the
`market.slot.name` validator (slot start MUST be divisible by 300) — a
vocabulary-free arithmetic check, so it does not reintroduce the format→enum
edge the gjk fix removed.

**Why:** `market.slot.name` became a pure structural pattern (the real gjk fix),
removing the slot-start/period alignment check — the only in-vocabulary consumer
of the structured enum's per-product `slot_minutes`. With no consumer left, the
capability was complexity for nothing: a fragile hand-rolled codegen path (its
integer case stubbed with a `raise`) and a third home for semantics with weaker
guarantees (primitive-only, unvalidated free-text units). Name-decodable
semantics belong on the `market.product` **type** (real `$ref`'d fields) and in
axioms — mirroring the legacy `MarketTypeGt` and the market-product taxonomy's
"name + rich type" verdict. Unpublished, so the rollback is clean. See [OPS-378](https://linear.app/gridworks/issue/OPS-378) +
`wiki/sema/designs/untangle-market-type-name/rollback-structured-enums.md`.

## 2026-06-08 — Untangle market.type.name into structured gw.market.product.name + market.product type (`8190fdb`)

**What:** The complete `untangle-market-type-name` work ([OPS-378](https://linear.app/gridworks/issue/OPS-378)), squashed.
Two reusable Sema capabilities applied to the market vocabulary, while keeping
the universal market messages uniform across makers:

- **Structured enums** (`spec/authoring/enums.md` "Structured Enums") — enum
  values may carry a fixed, typed row of primitive attributes
  (`value_attribute_schema` + `value_attributes`), codegen'd as a frozen
  `…Attrs` dataclass + a `.attrs` accessor (deferred module-level table so the
  Enum metaclass doesn't absorb it). Zero closure edges (attributes are
  primitives, never `$ref`). Authored `enums/gw.market.product.name/000.yaml` —
  GridWorks's product vocabulary; each token decodes to
  `timeframe / slot_minutes / gate_minutes / quantity_unit`; `unknown` is the
  row-less default sentinel.
- **`market.product` type** — an open, maker-agnostic product object
  (`MarketProductId` uuid · `ProductNameEnum` left.right.dot · `Name` bare
  token). It names *which* maker's product vocabulary a token belongs to without
  pinning one, so one shared type scales across thousands of makers; the decode
  is opt-in, consumer-side.
- **`frozen_at` word-status** (`spec/registry/structure.md`) — a word-level
  RFC-3339 marker closing a version lineage (no new versions), orthogonal to
  `replaced_by`. Used to retire-in-place: `market.type.name` →
  `replaced_by gw.market.product.name`; `atn.bid` → `replaced_by bid`. Legacy
  words stay valid and decodable forever; they are not deleted.
- **`market.slot.name` kept maker-agnostic & shape-only** — de-tangled to a
  self-contained, versionless leaf whose single regex enforces commodity
  `[erd]` · a `spaceheat.name`-shaped product token · a `left.right.dot` maker
  alias · 10-digit slot start. It no longer reaches any enum. So `bid` and
  `latest.price` stay **uniform across all market makers** (no per-maker bid
  types); product-token validity and slot-start alignment are decoded opt-in,
  receiver-side, against that maker's structured product enum.

**Why:** `market.type.name` conflated a market *product* (a named, decodable
thing) with the *type of market*, and the legacy `market.slot.name` validator
reached the `MarketTypeName` enum through an edge the dependency closure couldn't
see — the gridworks-journalkeeper `ModuleNotFoundError`. The fix puts product
semantics in a structured enum (decodable in the vocabulary, not a side table),
keeps the shared slot-name format shape-only so it carries no hidden vocabulary
edge (that class of bug is gone **by removal**), and retires the old words in
place via `frozen_at`/`replaced_by` rather than deleting them. Keeping the slot
format maker-agnostic is what lets `bid`/`latest.price` stay a single shared
contract; each market owner instead publishes its own
`<ns>.market.product.name` structured enum (see
`wiki/gridworks-marketmaker/explorations/market-product-and-uniform-bids.md`).

Note: an interim "versioned property formats" approach (a slot-name format
declaring a registry axiom dependency on the product enum) was prototyped and
then reverted in favor of this simpler maker-agnostic shape-only format — it
nets to zero in this squash. `gw.market.product.name`'s `rt60gate30b` row uses
the design's decode (60-min slot / gate 30 / AvgkW); MarketMaker remains the
source of truth — confirm before relying on that token's decode.

---

## 2026-05-29 — Adjust GNodeClass concepts (`b843710`)

**What:** Two enum edits:

- `definitions/enums/gw.g.node.class/000.yaml` — remove
  `TimeCoordinator` from the enum AND its value-description block.
  The enum is unpublished, so removal is permissible (per Sema's
  "enums are additive only" MUST, which binds only after publication).
- `definitions/enums/base.g.node.class/000.yaml` — port the
  `ced7cec` tightening of the `Logical` value-description from the
  `jm/effortless` branch onto `dev`. Replace
  *"purely logical or service-level nodes such as SCADA, forecasting
  services, market-maker actors, simulation nodes, or organizational
  microservices..."* with *"Used by GridWorks for SCADA and forecasting
  services."*

**Why:** Both edits land the same architectural distinction that's
emerging in `gridworks-base`: GNodes are grid entities (physical +
logical) participating in the production control plane; system
services (Supervisor, TimeCoordinator, journalkeeper, ear actor-side)
are NOT GNodes even if they ride the same rabbit+sema toolkit.

TimeCoordinator specifically: its role is "maintaining simulation
time or orchestrated test time across actors." That's a system
service, not a grid entity. The tightened `base.g.node.class/Logical`
explicitly excludes "simulation nodes" and "organizational
microservices." TimeCoordinator fits both excluded categories.
Symmetry with Supervisor (also non-GNode but a control-plane
orchestrator) becomes clean after this change.

The base.g.node.class fix-forward closes a branch-discipline issue:
the tightening was made on `jm/effortless` (which hasn't merged to
dev) but the lexicon-level distinction is dev-applicable.

Supports the in-flight
`wiki/gridworks-base/designs/support-non-gnode-actors/` design —
specifically the `orchestrator.md` (formerly `control-plane-tier.md`)
sub-spec, which lifts the heartbeat + sim.timestep machinery into a
middle `Orchestrator` tier that both Supervisor and TimeCoordinator
can extend without GNode identity.

## 2026-05-29 — ignore top level seed_request.yaml (`ce5e770`)

**What:** Add `seed_request.yaml` to the repo-root `.gitignore`.

**Why:** The repo-root `seed_request.yaml` is a scratch seed for exercising
`sema snapshot prepare` locally (e.g. validating that the
gridworks-journalkeeper closure pulls `market.slot.name` → `market.type.name`).
It is distinct from the canonical per-consumer seed
(`gridworks-journalkeeper/src/gjk/sema_seed_request.yaml`) and the committed
`template_seed_request.yaml`; ignoring it keeps ad-hoc snapshot experiments out
of version control.

## 2026-05-27 — tweak base g node class (`ced7cec`)

**What:** Narrow the `Logical` value description in
`definitions/enums/base.g.node.class/000.yaml`. Replace
*"purely logical or service-level nodes such as SCADA, forecasting
services, market-maker actors, simulation nodes, or organizational
microservices..."* with *"Used by GridWorks for SCADA and forecasting
services."* Removes "market-maker actors", "simulation nodes", and
"organizational microservices" from the named examples.

**Why:** Aligns Sema's lexicon with the architectural distinction
emerging in `gridworks-base`: GNodes (Physical + Logical) are
production control-plane participants; services that use the gwbase
rabbit+sema toolkit without joining the production GNode system
(journalkeeper, ear's actor-side, future analytics consumers) are
explicitly NOT Logical GNodes. The prior description's
"organizational microservices" phrasing invited the journalkeeper-
as-Logical-GNode reading the design is moving away from. Narrowing
to *only* SCADA + forecasting services removes the ambiguity.
Supports the in-flight `wiki/gridworks-base/designs/support-non-gnode-actors/`
design (ServiceSettings vs GNodeSettings split).

Side-effect to track separately: Supervisor and TimeCoordinator —
both in `TransportClass`, both control-plane participants, neither
in `base.g.node.class` — are now also outside Logical's scope. They
were never strictly GNodes, but the design implications surface
during the gwbase refactor (see `wiki/gridworks-base/designs/support-non-gnode-actors/`).

## 2026-05-26 — merge dev (`0d07927`)

**What:** Merge commit `0d07927` bringing `origin/dev` into the local
`ej-dev` line. Brings in a large batch of dev-landed changes:
`active`→`published` lifecycle rename, new format definitions
(`non.empty.string`, `positive.int.as.str`), several type-version
adjustments, the new top-level `spec/` folder, deletion of the old
`docs/` tree (content relocated to wiki), regenerated indexes, and
the dev-branch sema-vocabulary CLAUDE.md.

**Why:** Sync point so the `jm/effortless` work (port move, swap
claudes, eventual web-app refactor) sits on top of current dev rather
than the older ej-dev branch base. Brings the dev-lens authoring
conventions into reach on this branch — required for the two-lens
CLAUDE.md pattern (effortless_CLAUDE.md committed + gitignored
personal CLAUDE.md) to be meaningful.

## 2026-05-26 — swap claudes

**What:** Pure rename (R100, 0 line changes) of the committed
`sema/CLAUDE.md` to `sema/effortless_CLAUDE.md`. The file content — EJ's
ERB-lens framing of sema (rulebook-as-SSoT, `effortless build` discipline,
effortless skill suite) — is unchanged. Done on the `jm/effortless`
branch.

**Why:** sema's `.gitignore` already ignores `CLAUDE.md`, so renaming the
committed copy out of that slot lets each developer keep their preferred
*local* `CLAUDE.md` (a personal working-frame override) without touching
the team-shared recipe. The team-shared recipe for the ERB-pipeline side
now lives at the explicit name `effortless_CLAUDE.md`, and individual
devs (jess, ej, …) can layer their own gitignored `CLAUDE.md` on top —
e.g. jess's local copy uses the dev-branch sema-vocabulary lens (axiom /
registry / `/make-sema-word` discipline). See
the "Integrate the two sema
CLAUDE.mds" for the integration plan.

## 2026-05-26 — move sema-pg from host port 5433 to 5434

**What:** Eight files in sema/ updated to point local Postgres at host port
5434 instead of 5433 (and unify the lingering 5432 defaults that drifted
from the script): `start-db.sh` (PORT + header rationale),
`postgres/init-db.sh` (DEFAULT_CONN), `app/api/db.py` (default fallback),
`app/api/.env.example`, `app/README.md` (rationale paragraph + Docker
snippet + DB-connection blurb), `DEPLOY.md` (two URL references),
`postgres/migrations/README.md`, and `CLAUDE.md` (DB connection line +
note on what occupies 5432/5433).

**Why:** First step of harmonizing ej-dev sema with the rest of the
GridWorks dev fleet. `gw-data-pg` (the analytics TimescaleDB container,
see `gridworks-data/README.md`) holds host port 5433 unconditionally; a
dev who runs both gets a port collision today. The two systems are
sufficiently separate (different code paths, different teams, sema doesn't
need TimescaleDB) that consolidating into one container is the wrong
move — see Brian's earlier pushback. Moving sema to 5434 lets a native
Homebrew Postgres (5432), gw-data-pg (5433), and sema-pg (5434) all
coexist on one dev box. While in there, swept the stale 5432 defaults
that the original f34a4e4 script-add missed.

## 2026-05-22 — add a script for starting postgres in docker

**What:** New top-level `start-db.sh` (+69 lines, no other files touched).
Idempotent orchestration of a local `sema-pg` container (`postgres:16`)
mapped to host port **5433** → container 5432, with `POSTGRES_DB=sema` and
`POSTGRES_HOST_AUTH_METHOD=trust`. Waits on `pg_isready`, then dispatches
to `postgres/init-db.sh` based on flag (default: init if schema absent;
`--no-init` skips; `--reinit` rebuilds). Fails fast if Docker isn't running.

**Why:** Local dev needed a one-command DB bring-up that plays nicely with a
native Homebrew Postgres on 5432 (hence 5433) and is safe to re-run — the
prior workflow was hand-rolled `docker run` invocations, which drifted
between developers and silently re-created containers under varying flags.
Centralising the container shape here also gives the ej-dev/dev
harmonization a single chokepoint to edit when the port or image moves.

## 2026-05-26 — Wrap-up: highlight bijective MD↔ERB thesis (sema-specific) + queue ERB practice finding

**What:** Two wiki/sema/research/ doc updates closing this investigation
as work-in-progress.

`erb-md-mirror.md` — new §"Core thesis (sema-specific)" lifted to the
top of the doc. Makes three properties of the proposed refactor
explicit and load-bearing: *bijective* (round-trip exact, CI-gated),
*code-gen only* (mechanical, no curated translation), and
*sema-specific* (a general ERB-refactor pipeline would be infeasible;
sema's per-word + axioms + upgrades shape admits a clean hub-and-spoke
decomposition that a generic rulebook does not). Adds the motivation:
the load-bearing requirement is **unbounded ability to add new
axioms** (and probably upgrades) over sema's lifetime — axioms-as-
prose-in-28K-JSON does not scale, and a bijective MD mirror keeps
axiom authoring inside the git-native hub-and-spoke workflow without
giving up ERB's queryable DAG. Bumped Updated stamp to 2026-05-26.

`findings.md` — new dated entry: "Practice ERB pair-programming with
Claude before resuming the audit." Action: load full effortless
toolchain (CLI + MCP + Postgres mirror + Postgres GUI) and pair on
small rulebook touches so jess internalizes the ej + Claude rapid-
rulebook loop firsthand before continuing the audit threads (F5, F6,
p, r). Rationale: jess doesn't yet have a firsthand feel for the
workflow that produced ej's 28K-line rulebook so quickly; until she
does, she can't properly calibrate the strong CMCC thesis or judge
whether to drive vs consume ej's pipeline. Entry references the
queued-next-session-effortless-setup memory.

**Why:** The investigation hit a natural pause point with the
`active` → `published` rename landed and the audit's first-pass
findings recorded. Jess's stated next move is to set up tooling and
practice the workflow before pushing further on synergy analysis; the
remaining open audit threads (F5 TypeHelpers alignment, F6 Templates
table, p axiom-DSL feasibility, r round-trip empirical run) are best
re-engaged after that calibration. These two doc updates capture the
sharpest distillation of the thesis we have today (bijective refactor
+ unbounded axioms) and the explicit next-step action (practice
before more theory), so the work picks up cleanly in the next
session.

---

## 2026-05-26 — sema lifecycle: rename `active` → `published` (`fa42333`)

**What:** Replace the lifecycle status word `"active"` with `"published"`
across `spec/` and the Python tooling that reads/writes the `status:`
field. Touches:

- `spec/primary.md` glossary entry (draft vs published, with cleaner
  "mutable vs immutable" framing).
- `spec/registry/structure.md` §Status Field — full section rewritten:
  allowed values, defaults, lifecycle prose, `created`-after-promotion
  rule. Drops "under active development" phrasing (mutability is the
  property that matters, not "active development").
- `spec/registry/types.md` — status field schema and 5 references.
- `src/sema/tools/build_public_registry.py` — `is_active()` →
  `is_published()` (renamed; all 5 call sites updated), `active_versions`
  variable → `published_versions`, docstring updates.
- `src/sema/interfaces/cli/snapshot.py` — comment update.
- `tests/registry/test_registry_status_consistency.py` — `ALLOWED` set,
  `DEFAULT_STATUS` constant, `_schema_status()` default, docstrings.
- `tests/registry/test_registry_schema_file_layout.py` — `_registry_*_status()`
  defaults, `expected_*_id_line()` default-arg values.
- `tests/registry/test_registry_yaml_correctness.py` — literal `"active"`
  occurrences, variable names (`active_version_keys` →
  `published_version_keys`, `active_versions` → `published_versions`,
  `latest_active` → `latest_published`), test function name
  (`..._matches_latest_active_schema` → `..._matches_latest_published_schema`),
  error message strings.
- `tests/registry/test_public_registry_consistency.py` — literals + 2
  comments.
- `tests/registry/test_structural_dependency_consistency.py` — 2 literals.
- `tests/registry/test_identity_consistency.py` — 1 default value.
- `tests/registry/conftest.py` — 2 docstring lines.

`definitions/registry.yaml` and `definitions/*` schema files needed no
edits: pre-rename, no entry carried the literal word `"active"` —
status was always default-via-absence. Post-rename, the default value
is now `"published"` but the registry data is unchanged.

Three sema source files contain `active` in **non-lifecycle**
contexts and are deliberately left alone: `spec/primary.md:11`
("in active context" = LLM working context), `spec/authoring/types.md:384`
("under active schema evolution" = ongoing), and the runtime axiom
templates for `layout.lite/*` and `fis.authority.manifest/000`
("active ActorClass", "active count" = SCADA runtime semantics).

Full `pytest` run: 159 passed, 1 xpassed (pre-existing, unrelated).

**Why:** "Published" is unambiguous (committed to
`https://schemas.electricity.works/...` and immutable). "Active" was
overloaded — read as "currently used," "not deprecated," or "latest"
depending on context, and the spec text already said "active is
published and immutable," which itself signals the better word. The
rename aligns sema's vocabulary with ej's ERB out of the box (his
`TypeVersions.Status` already uses `'published' | 'draft'`), with
industry norms (npm, crates, PyPI, semver tooling), and with the
mutable-vs-immutable dichotomy that is what the lifecycle is actually
*about*. Migration cost was zero in registry data because the old
`"active"` value was default-via-absence — no entry needed touching.
The reason for the full clean (renaming the internal `is_active()`
function, the test variable names, etc.) rather than a literal-only
replacement: leaving `is_active()` as a function name when the value
it tests is `"published"` would be a permanent semantic landmine.

This commit lands per the queued
`queued-sema-active-to-published-rename` memory from the prior
(tame-raven) session.

---

## 2026-05-25 — `new.command.tree/000`: allow union over multiple `spaceheat.node.gt` versions (`3286294`)

**What:** `definitions/types/new.command.tree/000.yaml` —
`ShNodes.items` changed from a single
`$ref → spaceheat.node.gt/200` to a `oneOf` over `/200`, `/300`, and
`/301`. `registry.yaml` structural deps for `new.command.tree:000`
extended to include `spaceheat.node.gt:300` and `:301`. Indexes regen
(`dependency_closure`, `public_registry`, `reverse_dependencies` —
also picks up `gw1.actor.class:009` and `:011` as transitive enum deps
via the new node-gt versions). Runtime regen
(`src/sema/runtime/types/new_command_tree.py`, `reverse_query.py`,
`type_helpers/__init__.py`).

**Why:** `new.command.tree:000` was pinned to a single
`spaceheat.node.gt` version (`/200`) but real-world command-tree
payloads now need to carry nodes spanning multiple node-gt versions
during the SCADA rolling-version window. Widening via `oneOf` rather
than version-bumping `new.command.tree` itself is the right move
because the envelope semantics are unchanged — only the per-item union
shape needs to admit the additional versions. Pre-publication
in-place edit (no version bump) per `feedback_schema_fix_protocol`.

---

## 2026-05-25 — Add weather type v000 (`656c3c0`)

**What:** New `definitions/types/weather/000.yaml` (literal versioning).
`registry.yaml` entry added with `latest_version: 000`, deps closure
(`spaceheat.name`, `utc.seconds`, `non.empty.string`, `unitless.float`,
etc.). Indexes regenerated (`dependency_closure`, `lookup`,
`public_registry`, `reverse_dependencies`, `versions`). Runtime
generated (`src/sema/runtime/types/weather.py`) and an empty axiom
template stub created (`templates/axioms/weather_000.py.jinja2`).
`registry.yaml.metadata.last_updated` bumped to `2026-05-24T17:00:00Z`.

**Why:** Registers the legacy weather observation type (single-instant
outside-air-temperature + wind-speed from a third-party source,
identified by a weather channel name like `weather.gov.kmlt`) so that
journalkeeper can persist messages emitted by the new
gridworks-weather-forecast service. Closes the `queued-sema-add-weather-v000`
memory item. Stub axiom template lands ahead of axiom logic; the type
ships usable without it (the axiom slot is reserved for a future
"WeatherChannelNameInRegistry" or similar constraint, currently empty).

---

## 2026-05-26 — Three new research docs: MD↔ERB mirror + no-degradation audit + findings log

**What:** Three new docs under `wiki/sema/research/`, all Pass 0 Draft.

`erb-md-mirror.md` — proposes a small bidirectional tool that emits the
rulebook schema as a wiki-style hub-and-spoke MD tree under
`wiki/sema/erb-mirror/` and accepts schema-level edits back as JSON
patches against the rulebook. Data rows stay in JSON; only the schema
round-trips. Two-emitter design + CI gate + day-one pilot scope + open
questions. Names the downstream extension: same tooling enables
Karan-style ERB-as-functional-spec convergence on production repos like
gridworks-scada (with the structural-~50% / behavioral-~50% fit caveat).

`erb-no-degradation-audit.md` — catalogs every operation sema supports
today (authoring, indexes, runtime gen, tests, publishing) and
classifies each under the working thesis (ii): YAML-leading, granular
bidirectional, no degradation. Surfaces 6 specific findings for ej
(granular emit not yet implemented; upgrades are a second source-of-truth
in Python modules not in YAML; coverage gap from unfinished migration;
TypeHelpers rule alignment to verify; Templates table empty;
axioms/combinators round-trip as opaque blobs). F3 (lifecycle/publication
Status) was initially scoped as a degradation risk; corrected during
review (jess caught the error — sema does carry explicit `status:`) and
dissolved. Closes with a 9-item acceptance checklist plus 5 open
questions for ej.

`findings.md` — new running log of actions WE (jess + Claude) will take
on sema or sema-adjacent tooling. First entry: drop ERB's `PromotedAt`
column (redundant with sema's `created` per
`spec/registry/structure.md:100-103`). Distinct from the audit, which
lists items for ej to satisfy.

**Why:** The trio forms the load-bearing artifact set for evaluating
ej's ERB integration. The mirror tool addresses how the team and Claude
reason about the rulebook itself (the meta-work case ej's
LLM-friendliness story does not optimize for, per the working
`erb-is-an-llm-interpretation` C-reading: rulebook-as-generative-prior).
The audit converts the abstract "no degradation" goal into a concrete
checklist for ej. The findings log separates *our* action items from
ej-facing recommendations so the audit stays scoped to its actual
audience. Together they surface that several pieces ej presents as
working — notably granular bidirectional emit — are aspirational
rather than current code. Output of `/grill-me` thread item q (audit)
and the MD-mirror brainstorm; sets up p (axiom DSL feasibility) and r
(round-trip empirical run) as smaller follow-on investigations.

---

## 2026-05-24 — Typed Maps construct & applications (`f2472ba`)

**What:** Add `spec/authoring/types.md` §Open Containers and §Typed
Maps; add Composition Rule paragraph permitting multi-version `oneOf`;
add Referencing Other Vocabulary header requiring canonical
`https://schemas.electricity.works/...` URLs for every `$ref`. New
format word `positive.int.as.str` (int-keyed-map blessed key format)
+ registry entry. `gw1.tank.temp.calibration.map/000` Tank restored
to typed-map shape using the new construct; the redundant
`ContiguousTankIndexConstraint` axiom is dropped (subsumed by
structural enforcement; orphan runtime axiom template removed).
`gw.nolan.layout/000` GNodes refactored from
typed-dict-without-propertyNames to a typed array; axiom 1 restated
for arrays. New `test_typed_maps_have_blessed_propertynames` enforces
the binary key-format rule.

This commit also carries the cross-cutting state that earlier commits
in the series deferred: `registry.yaml` reconciliation (adds
`non.empty.string` and `positive.int.as.str` format entries, deletes
the `analytics.channel.gt` type entry, adds typed-map structural deps
for calibration.map), all `indexes/*` regen, runtime regen for
`property_format.py`, `relay_actor_config.py`,
`old_versions/relay_actor_config_002.py`, and
`gw1_tank_temp_calibration_map.py`, plus the new
`positive.int.as.str` runtime template.

**Why:** "Keyed dicts of typed values" is a standard pattern (per
user) and the orig spec was silent on it. Formalizing as the Typed
Map construct gives the pattern a single, mechanically-checkable
shape with a tight binary key-format choice (string XOR int) — wider
than "forbid all typed dicts" but narrower than "any propertyNames
goes." GNodes was the smell case (keys redundant with `GNodeClass`
field on the value); Tank was the legitimate case (keys are tank
indices, genuine semantic content). The new test mechanically
distinguishes them via the propertyNames signal. Open Containers
section codifies the "no unconditional axioms on `type: object`
contents" rule — the conditional-discriminator pattern in
`derived.channel.gt`'s `Parameters` axioms 3+4 remains permitted as
the spec-can't-express exception. Cross-cutting state lands here
because earlier commits intentionally deferred registry/indexes/regen
to keep their own diffs minimal and reviewable; the cost is that the
suite was partially red between commits 3 and 7 inclusive, fully
green again at this commit.

---

## 2026-05-24 — Identity-field consistency tests and title typo fix (`150b01a`)

**What:** New `tests/registry/test_identity_consistency.py` with three
functions: `title` matches the name segment of `$id`; `TypeName.const`
matches the same; Version field shape matches the current
`versioning_strategy` (`const` for the latest of a literal-strategy
type; `type: string` for all versions of a string-strategy type).
`gw1.telemetry.name.quantity.projection/000`: title was
`telemetry.name.quantity.projection` (missing the `gw1.` prefix);
fixed.

**Why:** The existing `test_registry_schema_file_layout.py` checked
the `$id` line against the canonical URL but never compared it to the
schema's inner `title` field. Drift between them was silently OK. The
title typo on `gw1.telemetry.name.quantity.projection` had been
shipped that way; pure metadata typo (runtime gen derives the class
name from `$id`, so zero runtime impact). The strategy-aware Version
check matters because a type whose `versioning_strategy` evolved from
`string` to `literal` keeps the original `type: string` shape on
older versions — a naive "Version must always be const" test would
false-positive on legitimate legacy versions.

---

## 2026-05-24 — Type-schema examples MUST be JSON document strings (and valid JSON) (`ab218db`)

**What:** New `tests/registry/test_example_format.py` with two
functions: entries under `examples:` MUST be strings (not YAML maps),
and if strings MUST parse as valid JSON. Four example blocks fixed:
`channel.readings/002` and `channel.readings.list.item/000` (YAML
maps rewritten as JSON strings); `relay.actor.config/002` example
(missing comma after `WiringConfig`, trailing comma after `Version`);
`derived.channel.gt/002` (missing comma after `OutputUnit`). This
commit also folds in the `relay.actor.config/002` minLength → `$ref →
non.empty.string` swap (parallel to commit 4091454's swap on `/003`),
since the file was already being touched here for the example fix.

**Why:** `sema/spec/authoring/types.md` §Examples already says
"Examples SHALL be serialized JSON documents, not YAML object
representations," but no test enforced it. YAML-map examples
masquerade as valid (they're parseable YAML) while telling consumers
the wrong format. Examples don't affect runtime validation, but they
ARE used by integrators to seed code and as IDE/CI fixtures — wrong
or malformed examples mislead. Folding the `/002` minLength swap into
the same commit avoided touching `relay.actor.config/002` twice.

---

## 2026-05-24 — Extend Primitive Constraint Rule to all string-constraint keywords; add non.empty.string (`4091454`)

**What:** New format schema `non.empty.string` (type: string,
minLength: 1). `tests/registry/test_primitive_constraints.py`
extended to cover all forbidden constraint keywords (`pattern`,
`minLength`, `maxLength`, `multipleOf`), not just numeric ones.
Recursion stops at `propertyNames:` (blessed by Typed Maps). Six
fields swapped from `type: string + minLength: 1` to `$ref →
non.empty.string`: four on `relay.actor.config/003` (event / state
names), two on `fis.instance.authorization.event/000` (peer address,
connection handle). The parallel four-field swap on
`relay.actor.config/002` is folded into commit `ab218db` (the example
fix touched the same file). Runtime tightens `str` → `NonEmptyString`
once commit `f2472ba` regenerates.

This commit ships the format schema YAML only; the corresponding
`registry.yaml` entry (and runtime regen + indexes) land in commit
`f2472ba`.

**Why:** The Primitive Constraint Rule already said primitive
constraints must be wrapped in named formats; the test only enforced
the numeric subset. The minLength fields had been shipped with
inline `minLength: 1` — a workaround for not having a "non-empty
string" format word. Adding the format and enforcing the rule for
ALL constraint keywords closes the gap. Runtime tightening means
empty strings, which the old `str` type accepted, now hard-fail at
deserialization. `non.empty.string`'s `created` is back-dated to
2024-12-31 so dep timestamps order correctly against the older
consumer types it now serves (see
`wiki/sema/research/format-created-must-be-real.md` for the follow-up
rule-tightening proposal).

---

## 2026-05-24 — $ref values must be canonical Sema URLs (`372f73f`)

(Commit subject as recorded by git is ` values must be canonical Sema URLs` —
leading space, missing `$ref` prefix — because the shell ate the `$ref`
substring at commit time. Intended subject was "$ref values must be canonical
Sema URLs"; flagged here for accuracy.)

**What:** New `tests/registry/test_ref_values.py`: every `$ref` value
in a type or enum schema SHALL be a canonical Sema schema URL
(`https://schemas.electricity.works/{formats,enums,types}/...`).
`definitions/types/analytics.channel.gt/000.yaml` deleted (had
`$ref: string` — not a valid URL); references to it removed from
`synced.readings.bundle/{001,002}` prose. `src/sema/tools/build_seed_dag.py`
tightened: `normalize_ref` no longer silently passes through non-canonical
refs (`/types/...`, `types/...`, `enums/...` shorthand branches deleted —
no schema used them); the main DAG loop's `if dep is None: continue`
defensive skip replaced with `raise`.

This commit ships the schema file deletion + prose updates + the
tightening + the new test. The matching `registry.yaml` deletion of
`analytics.channel.gt`'s entry, and the indexes regen that follows,
land in commit `f2472ba`.

**Why:** `analytics.channel.gt` was a draft Joe didn't end up using
(user direction: delete rather than fix). The two defensive
fallbacks in `build_seed_dag.py` existed only to tolerate exactly the
kind of malformed `$ref` that analytics.channel.gt had — with the
test now catching them and analytics.channel.gt gone, both
workarounds are dead code. Hard-raise replaces silent-skip so future
schema authors can't reintroduce the pattern by accident.

---

## 2026-05-24 — Fixture broadens coverage (`0802853`)

**What:** `tests/registry/conftest.py` `all_schemas` fixture now
walks `definitions/{formats,enums,types}/` on disk and loads every
schema file directly. Previously loaded only via
`indexes/lookup.yaml`, which filters drafts and keeps only
`latest_version` per type. Fixture keys switched from `title` to
short canonical id derived from `$id` (`bid:000`, `uuid4.str`);
duplicate keys hard-error.

**Why:** Older immutable versions and draft schemas were silently
out of scope under the lookup-based fixture — a regression edit on
either was invisible to the suite. Walking the filesystem brings
every schema file in scope. The keying change ensures failure
messages include the version (e.g., `relay.actor.config:002`
rather than just `relay.actor.config`) so it's obvious which file
broke. This commit lands ahead of the rule-enforcement commits
below it in the changelog because those rules need the broadened
fixture to see all the schemas they're meant to catch.

---

## 2026-05-24 — Retire orig-spec.md (`6decb38`)

**What:** Delete `spec/orig-spec.md` (the pre-hub-and-spoke
monolithic spec, 2006 lines).

**Why:** Bakeoff complete; the hub-and-spoke spec
(`spec/primary.md` + `spec/registry/` + `spec/authoring/`) is the
canonical source. The orig was preserved per `sema/CLAUDE.md` for
transitional reference; that transition is now done. The orig
content lives forever in git history if needed for archaeology;
keeping it in-tree creates dual-source-of-truth drift risk and
~2000 lines of read-burden for anyone scanning `spec/`.


## 2026-05-23 — Dissolve sema/docs: relocate GridWorks context to wiki, merge motivation into README (`f377e76`)

**Why:** With the spec promoted to `sema/spec/`, `sema/docs/` had no
load-bearing job left — orig-spec.md moved to `sema/spec/`, and the
remaining files were either GridWorks-flavored context (wrong repo) or
overlapped with the README. A single-file `docs/` folder is overhead;
the README is THE standalone landing page per wiki convention and the
right home for motivation.

GridWorks-flavored context moved out (wrong repo):

- `scada-layout-concerns.md` (SCADA-side critique of the
  `gw.nolan.layout` word framed in LLM-comprehension terms — concerns
  *about* a Sema word, not the spec) → moved to
  `wiki/gridworks-scada/research/concerns/layout-axiom-complexity.md`
  with light rephrasing (header, attribution, typo fixes).
- `sema-and-domain-protocols.md` (framing on how Sema relates to OpenADR
  and similar) → moved to `wiki/sema/research/sema-and-domain-protocols.md`
  with a status stamp and a one-line "what this is" opener.
- `where-meaning-lives-in-gridworks.md` (GridWorks-architecture position
  paper naming Sema as the semantic authority, written in the first
  person) → moved to `wiki/sema/research/where-meaning-lives-in-gridworks.md`
  with a status stamp; cross-refs in `wiki/gridworks-scada/research/`
  updated to the new path.

Repo-level reshuffles:

- `motivation.md` merged into `README.md` as a new "Why this matters"
  section (the README already covered most of the framing; the unique
  bits — the four-point benefits list and the vision line — fit cleanly
  there). Also fixed a misplaced-bold typo from the original
  (`i**ndependent teams and organizations**` →
  `**independent teams and organizations**`) en route.
- `index.md` deleted: with everything either in `README.md` or in
  `spec/`, the navigation file was pure overhead.
- `docs/` folder deleted entirely.
- `README.md` also fixed a pre-existing broken link to
  `docs/rules_and_guidelines.md#vocabulary-registration-process` →
  `spec/governance.md#vocabulary-registration-process`.
- `sema/CLAUDE.md`: `docs/orig-spec.md` → `spec/orig-spec.md` (you
  moved orig-spec to spec/ between turns).

## 2026-05-23 — Promote sema/spec/ to the top level alongside definitions/ and indexes/ (`bfc7c21`)

**Why:** Primary motivation is to make the spec **digestible for LLMs** —
a 2006-line monolith forces every AI session to skim or partial-load,
making "Read the spec" a wishful directive rather than a real verification
step. Bundles two moves: (1) split `docs/sema-specification.md` into a
hub-and-spoke layout (`spec/primary.md` + `spec/registry/` +
`spec/authoring/` + `spec/governance.md`) so an agent under
`/make-sema-word` can pull the ~200-line spoke for the kind it's touching
and actually load it in full; (2) elevate `spec/` out of `docs/` to sit
beside `definitions/` and `indexes/` because the spec is the canonical
rebuild artifact, not background reading. The split also let us fold
language-neutral runtime upgrade discipline into the spec
(`authoring/type-semantics.md#upgrade-discipline`, replacing lore that had
been hiding in `sema/CLAUDE.md`) and fix two latent issues in the source:
a duplicated Change Process section and the `report v002`
`Version: const "003"` mismatch with its `$id`/title.

## 2026-05-23 — Update regular sema CLAUDE.md (`87cae7c`)

**Why:** Slimmed `sema/CLAUDE.md` to invariants only — dropped stale
`Coding/...` paths, dropped pydantic-emitter lore that doesn't belong on
every sema session, added the regen commands by path
(`scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`), pointed at
`/make-sema-word` for the per-word ritual. Loaded on every sema work session,
so keeping it dense saves tokens and concentrates attention on the MUSTs
that actually bind.

## 2026-05-21 — Add gw / gridworks.header envelope Sema types; fix Dst; regenerate

**Why:** Register the GridWorks application-layer **envelope** as Sema
vocabulary. `gridworks.header/001` (literal) captures the delivery metadata
(`Src`, `Dst`, `MessageType`, `MessageId`, `AckRequired`) exactly as emitted by
the field-deployed gwproto Header wire format; `gw` (versionless) is the
envelope = header + an opaque `Payload` (any registered Sema type, matched by
`TypeName`). These are the types the gridworks-base **codec layer** wraps for
multi-hop traversal (see
`wiki/gridworks-base/executor/codec.md`). Fixed a schema bug — `gridworks.header/001`'s
`Dst` had no `type` (added `type: string`). Also removed an orphaned
`heartbeat_a_000_to_001` upgrade template left behind by the heartbeat change
below (it referenced the deleted v001 and failed two tests). Full suite green.
The header doc records a deliberate v002 evolution path (drop empty-string
sentinels, drop redundant `MessageType`, constrain `Dst`, add instance
provenance / signing).

## 2026-05-21 — heartbeat.a: delete unpublished v001, revert latest_version to 000, document supervisor use (`359f5b5`)

**Why:** An unpublished `heartbeat.a/001` had *deleted* the `MyHex`/`YourLastHex`
pair. That pair is the supervisor-tier liveness/continuity primitive — the names
are **sender-relative** (`MyHex` = sender's fresh token, `YourLastHex` echoes the
peer's last), so one type serves both the supervisor and the supervised actor;
it must not be dropped, and must not be renamed to a role-specific "SuHex."
Pre-publication revise-in-place is sema-legal, so v001 was deleted,
`latest_version` reverted to `000`, and v000's docs improved to state the
supervisor health-monitoring purpose. This is supervisor liveness, distinct from
the cross-party SCADA↔LTN contract heartbeat — see
`wiki/gridworks-scada/research/concerns/liveness-and-sla.md`.
