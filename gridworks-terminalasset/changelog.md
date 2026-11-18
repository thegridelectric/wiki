# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-terminalasset` code repo**. The matching git commit (in
`gridworks-terminalasset`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-11-26 — minor doc fixes

`13e92bf`, branch `jm/intercept-relay`, OPS-721. The `state_effects` docstring and the
README said the intercept relay has no row because the model's boiler fires
on its own aquastat. That is true of a real Katahdin and of the Beech plant.
The Katahdin models' boiler is water and iron with no burner, which is the
reason the relay has nothing to switch. Both sentences now say so. Giving
the plant a boiler that fires and a relay that stops it is OPS-725.

## 2026-11-25 — The four fixtures follow tlayouts with updated GNodeIds from the grid node seed

`41949da`, branch `jm/intercept-relay`, OPS-721. Every layout in `tests/config` is a
byte copy of its `output/*-sim` file at tlayouts `d907d9e`, where the sim
houses take their d1 identity from the registry's export (OPS-720): larch,
hazel and orange get the registry's GNodeIds and PositionPointIds and
shorter display names ("Larch LTN", "Hazel1 Scada"), and beech1's display
names derive from the real house. Aliases unchanged; nothing the plant
reads changed.

## 2026-11-25 — The scada's clock cannot run the plant ahead; the fmu tests run in a Linux container

`0abd0a7`, branch `jm/intercept-relay`, OPS-721. Three asks of the PR 6 review, done
on our branch for the author to evaluate. An actuation is logged with its
stamp's offset from the plant's clock and warns over 2 s, so a run's log
shows whether the scada and the plant agree on the time. `actuate` takes
the plant's `now_ms` and the FMU runs no further than it: a scada whose
clock is ahead used to run the model into the future and the next flux
reported that future as now. `ci.sh` runs the host tests without the fmu
marker and the fmu tests in a Linux container (`scripts/test_fmu.sh`),
since an FMU's binary loads on Linux only; the script joins the dev
broker's container network on a laptop and the host's in CI.

## 2026-11-25 — The Beech fixture takes the registry's d1 identities

`1258637`, branch `jm/intercept-relay`, OPS-721. `tests/config/gw.house0.beech.layout.json`
is a byte copy of tlayouts `5313ab2` `output/beech1-sim/gw.house0.layout.json`:
the sim Beech is `d1.isone.me.versant.keene.beech1` with the GNodeIds of
the registry's dev seed, one source for d1 identity (OPS-720). Nothing
about the plant changed.

## 2026-11-25 — heat call on opto pin does not need a threshold; its boolan

`fc0f85e`, branch `jm/intercept-relay`, OPS-721. The Gw108 reads a zone's heat call
on an opto input: whether the thermostat circuit is closed, a digital
fact. The plant fed that pin from the wire's power in the model through a
hand-kept 0.5 W threshold, a trip level no hardware has and no word could
state. The three models gain a `zoneCall[nZones]` output, the zone valve's
0/1 position, and the pin reads it. A wire channel that is a power reading
(the House0 "power" source) keeps `zoneCallPower`; there the scada's own
`GreaterThanThreshold` derivation and its `Threshold` are in the layout.
Both adapters choose by the channel's telemetry, so `variable_by_channel`
takes the `PlantLayout`. FMUs rebuilt; checks green in the Linux
container.

## 2026-11-25 — The layouts are the generator's, and each relay's states are read from them

`8dc2f5d`, branch `jm/intercept-relay`, cut on top of `ow/beech-plant`
(685d1a5), OPS-711. PR #7 into `beech-plant`, a copy of the PR 6 head in
thegridelectric's repo. The scada and the layout generator moved to `gw.boiler.backup`
001 with `InterceptRelayName`, and a plant at 685d1a5 refused the layouts
they now write ("Version Input should be '000'"), so the simulated stack
could not start.

The snapshot is regenerated from sema dev `672c1aa`, where
`gw.boiler.backup` 001 is published. The regen script
called `sema snapshot prepare --allow-staged`, a flag the CLI no longer
has; the seed now states `package_name`, `vendor_dir` and the
`staging.allow` list, and the script runs `sema snapshot regen`.

The four layouts in `tests/config` are byte copies of tlayouts main
`bf2cb02` (beech-sim, hazel-sim, orange-sim, larch-sim). The Katahdin
layout made in this repo from hazel had a heat pump failsafe relay, which
`gw.katahdin.layout` axiom 32 refuses, so `katahdin_layout.py` and
`ta-katahdin-layout` are gone. A test that needs a house with no boiler
or with two zones adjusts larch's layout and decodes it again through
the word, the way the scada's layout tests vary a house.

The larch layout gives each valve relay a `valve.open.or.closed` config,
so the Katahdin relay table no longer keeps valve orientation by hand:
both families use one `StateEffect` table form and one `relay_effects`
lookup in `fmu_model.py`. With no failsafe relay the model's
`hpScadaControl` input stays at its start value of 1.

A Katahdin's zones are read by the board itself: the temperatures on the
Gw108's thermistor ADC and the heat calls on its opto pins. The scada
already takes those from the plant by channel name when the board is of
a simulated type, so the plant now shows them on the same rule: a
channel is the plant's when its sensor is a simulated device or an input
of a simulated board. The thermistor voltage uses the divider in the
board's `i2c.thermistor.interface.capability` and the beta in the
reader's config; the pin level follows the `Interpretation` of the heat
call derived from it (larch: `DigitalZeroIsActive`, so 0 while the zone
calls); `gw1.heat.call.interpretation` joins the seed for that.

With no failsafe relay nothing drove the model's `hpScadaControl` input,
so it is removed from `Katahdin.mo` and `KatahdinComponents.mo`.

`ci.sh` runs the snapshot's staging check after pyright.

The FMU binaries are for Linux, so `./ci.sh` cannot pass on an Apple
silicon laptop. Its steps were run by hand: the FMU build on the laptop,
then in a Linux container on the dev broker's network ruff, pyright, the
staging check and pytest with the `fmu` and `live` tests (97 passed, 1
skipped).

## 2026-11-18 — Beech's zones are fitted to the house: cycling thermostats, emitters the water passes along, rooms of air and fabric (`910b09e`)

The simulated Beech's two zones were one placeholder twice: a deadband
thermostat on a single lump of room, which called for an hour or more at
a time and held both zones on the same sawtooth about 20 °C. The house
does nothing like it. Its report.events for the night of 17 November 2026
(journal DB, 20:00 to 08:45 ET) show thermostats that cycle: the down
zone, set to 67 °F, called for 5.3 to 7.7 minutes every 50 or so, and the
up zone, set to 63 °F, for 5 minutes every 200 to 217. Both fit a
cycle-rate thermostat at three cycles an hour (a call of 5 min / (1 - x)
at load x). A call put about 6 MJ into the down zone (2.0 US gpm, supply
near 77 °C) and 4.4 MJ into the up zone (1.5 US gpm), with the return
cool until the hot water had crossed the emitter. The up zone's air rose
about 3 K over the half hour after a call and fell back over the next
three hours; the down zone's moved under 0.5 K.

`Hydronic.Zones` is now that: a cycling thermostat, an emitter in four
lengths, air and fabric, each zone with its own coefficients, and
`Beech.Plant` holds the fitted values. On the bench (no scada, the boiler
holding the buffer at 77 °C, -5 °C outdoors) the down zone calls for 5.2
minutes every 48 and the up zone for 5 minutes every 218, with 0.4 K and
3 K of air swing, and `test_the_thermostats_call_as_beechs_did_with_its_buffer_hot`
holds that.

Two things the fit stands on that the house's data does not give. The
outdoor temperature of that night is in no channel, so the losses are
fitted at the plant's own -5 °C. The plant's distribution pump runs at
full speed where the house's runs at a `dist-010v` of 35, so the zone
resistances are fitted to the house's flows against the full-speed pump.

A calling zone's wire now reads 175 W, as Beech's meter does. At the
placeholder's 10 W a scada whose heat-call threshold is "greater than 10"
never saw a call from the simulated house.

## 2026-11-08 — Snapshot adds gw.katahdin.layout and catches up to sema dev

The seed gains `gw.katahdin.layout`, the layout of the first simulated
plant, and drops `sim.relay.component.gt`, a word the registry no longer
has (the seed had gone stale against it, so `prepare` refused). The regen
runs with `--allow-staged` against sema `dev` at `862b7c1`, so the
snapshot is dev-only: it vendors the staging layout words and the
published-only test skips off `main` and would fail on it, by design. The
rest of the diff is the catch-up to every word that moved in sema since
the August regen. Nothing in `gwta` outside the snapshot changes; the
gate stays green.

## 2026-11-08 — ci.sh is the one gate; the workflow runs it against the dev-rabbit image

The pattern sema set and gwbase and gjk follow: `ci.sh` owns the steps
(locked `uv sync`, `ruff check --no-fix`, `ruff format --check`, pyright,
then pytest with the `live` marker lifted), and `.github/workflows/tests.yml`
is checkout, setup-uv and `./ci.sh` with `ghcr.io/thegridelectric/dev-rabbit`
as a service container, so the live heartbeat test runs in CI on the same
broker image developers use. pyright joins the dev group and excludes the
generated snapshot at `src/gwta/sema`, as gwbase and gjk do: checking it
means editing it, and edits vanish at regen. Set up before Olly's first PR
so every change to the simulated plant goes through the same gate.

## 2026-11-08 — Track gwbase 0.7.3: GwGNodeClass, header in process_message, GWTA_ settings (`4a54837`, on `jm/gwbase-0-7-3`)

The floor moves from 0.5.15 to 0.7.3 so the terminal asset builds on the
same gwbase as the FLO, the time coordinator and the LTN before Olly
starts the simulated plant here. Three gwbase changes reach the actor:
`GridworksActor.__init__` takes `g_node_class=GwGNodeClass.TerminalAsset`
and derives the transport class itself (0.7.0, 0.7.1); `process_message`
receives the unwrapped body plus a `GridworksHeader | None` (0.6.0); and
settings follow the one-prefix-per-service pattern, so `GwtaSettings`
(`gwta/config.py`) replaces the bare `GNodeSettings` with the `GWTA_`
prefix, the dev alias, and the supervisor and time-coordinator aliases
as settings rather than constructor defaults. Verified: ruff clean, the
offline suite and the `live` test pass, and `ta-hello` beats on the dev
broker. A laptop that still has the June 004 dev identity at
`~/.config/gridworks/terminalasset/g.node.gt.json` fails at boot by
design; move the file aside and the next run mints a 006.

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
