# Operational params cleanup (spoke)

Status: Draft · Pass 0 · Updated 2026-08-15 · Linear: OPS-392

> What this is: spruce-unlimbo spoke cleaning up the operational-params
> surface: the Nolan family gets its own word
> (`gw.nolan.operational.params`), and `gw.house0.operational.params`
> slims to fields that are actually tunable. Decisions settled with
> Jessica 2026-08-12; sema edits gated below.

## ▶ Next — coherence cleanup, handover 2026-08-15

Session deft-finch (Fable) reviewed the last 4 commits + the working tree
and audited the three scada designs, then ran out of budget; a fresh
session picks up here. Decisions taken with Jessica 2026-08-15:
**code cleanup first**, then one docs sweep against the committed tree;
**delete** `sim_boot.py`, `house0_bijection.py`, `layout_roundtrip.py`
and `sema_to_dc.diff_against_fixture` (unimported, read deleted fixture
shapes); **`scada.control.capabilities/001` is staging ⇒ edit it in
place, never a new version** (rule now in GridWorks_CLAUDE.md maxims).
Stance: address issues now, don't push off; ask before assuming; the
session is HIGHLY interactive.

Suite on the working tree: 193 passed, 1 skipped. HEAD alone is red;
`actors/leaf_ally/nolan.py` is UNTRACKED and required — `git add` it.

**Critical, in order (each = ask, fix, run suite):**

1. `layout_type_name` fell out of the collapse — no attribute on
   `HydronicLayout`; only `sema_to_dc.py:157` stamps it. `is_nolan`
   (`hydronic_layout.py:1721`), `required_node` (`:1729`),
   `_family_only` (`:1740`), `sh_node_actor.py:347` read it. Decide:
   loader-only construction (then `load`/`load_dict` take it as a
   required arg) vs class attr. Also unify the THREE family
   discriminators: `is_nolan`, `leaf_ally_loader.py:16` (hardcoded
   `"gw.nolan.layout"`), `local_control_loader.py:25` (`Hydronic.Strategy`
   string, `HouseStrategy` enum unused).
2. `nolan_operational_params.py:17-23` `⏳ TEMPORARY` prose in the
   sema docstring — violates "docstrings are `Sema: <url>` only"; move
   the note here. The two ops words are field-identical (intended start).
3. `scada.control.capabilities`: builder `scada.py:1680-1706` reads
   `H0N.relay_multiplexer` unconditionally (Nolan crash); word requires
   `I2cRelayComponent`, axiom 4a assumes one Krida board; gwsproto embeds
   `spaceheat.node.gt` 303 / i2c relay 005 that no longer exist (word pins
   302/004). Redesign family-neutral IN PLACE on 001 (sema word-gate:
   read `sema/spec/primary.md` + registry/authoring spokes, post summary,
   wait).
4. Nolan-wrong direct name reads: `sh_node_actor.py:1837`
   (`House0NodeNames.store_charge_discharge_relay` → `layout.…`), `:1156`
   (`zero_ten_out_multiplexer`), `scada.py:465-481,1273`,
   `relay.py:966-1021`, `tou_base.py:223`, `ltn.py:789`; layout
   system-actor props `hydronic_layout.py:1610-1706` still via `H0N`.
5. Actor↔layout duplicates: `sh_node_actor.py:222-274` (`ltn`,
   `primary_scada`, `derived_generator`, `hp_boss`, `sieg_loop`,
   `pico_cycler`, `dist_010v`, `store_010v`, `primary_010v`; `atomic_ally`
   / `home_alone` zero callers); `scada.py:1632-1672` redefines ten via
   `H0N`; `H0N` (`house_0_names.py:117-206`) duplicates Core+HSNN+House0
   names; `ZoneNodes` ≡ `HydronicSpaceheatZoneNodeNames`.
6. Collapse leftovers in `hydronic_layout.py`: `:680` double
   `load_derived_channels`; `:1508,1531` "overwrites base class";
   `:1435-1459,1587` unreachable legacy flat-key fallback (Hydronic
   required in both words; also dead `None` checks `house0_layout.py:122,158`,
   `sema_to_dc.py:196`); `_family_only` returns None always; unused
   `:1344 components`, `:1877 valid_keys`; House0-named validators/args
   (`:126,1230,1336,1441,1876`) run for every family; commented relay
   lists `:1355-1375,1463-1466`. `sema_to_dc.py:7,34` `House0Dc`/
   `House0Sema` aliases + "default oak"; `sh_node_actor.py:345`
   `"house0.layout"`; `config.py:135-141` false claim about `hp_model`'s
   only reader (`hp_boss.py:35`, `sh_node_actor.py:1338` read it).
7. Dead modules: `orig_sieg_loop.py`, `show_settings.py`, `run_scada.py`,
   `getkeys.py`, `scratch{,2,3,4}.py`, four `drivers/multipurpose_sensor/*`,
   two `drivers/power_meter/egauge/*`; def-only `LayoutBucket`,
   `HouseStrategy`, `validate_api_tank_module_wiring`,
   `tank_device_temp_channels`, `deserialize_house0_load_args`,
   `is_buffer_full_alt`, `hp_relay_state`, `ZoneNodes.required_relays`,
   `House0RelayIdx`; unused imports `tou_base.py`, `store_pump_monitor.py`,
   `scada.py:17`, `scada_data.py:15`. Ask before each delete batch.
8. Half-done: `local_control/nolan.py:82-83` hardcodes `ONPEAK_WINDOWS`
   though ops carries `OnPeakWindows`; `sh_node_actor.py:119-127` a second
   schedule; NolanLocalControl has no `ServiceMode` gate. Fixture pair
   smell: house0 ops `ScadaAlias d1.bench.honeysuckle.scada` vs house0
   layout `…orange1.scada` — nothing checks ScadaAlias ↔ layout.
   `.ops` House0-only reads (break when the store knobs leave the Nolan
   word): `scada_data.py:93-112`, `scada.py:1727-1730,1326`,
   `sh_node_actor.py:1369,1388,1549,1563`, `derived_generator.py:746-943`,
   `leaf_ally_loader.py:19-29`, `local_control_loader.py:29`.
   Bench pi artifacts pair a nolan layout with the house0 ops word —
   `APPROVED_PAIRS` now refuses that; regenerate before the next box boot.

9. `sema_to_dc` ↔ `actors.scada_data` are circularly importable:
   `sema_to_dc.py:30` `from actors.config import DEFAULT_OPS_PARAMS_FILE`
   triggers `actors/__init__.py` (~20 actors), which chains to
   `actors/scada_data.py:29` `from sema_to_dc import OperationalParams,
   decode_operational_params` — a partially-initialized module. It only
   works today because `actors` is imported first in every live path;
   importing `sema_to_dc` first raises `ImportError`. The constant is used
   in exactly one place (`:273`, inside `diff_against_fixture`), so
   deleting that function per item 7 removes the import and dissolves the
   cycle. Confirm it stays dissolved rather than re-importing the constant.

**Docs sweep after the commit** (audit 2026-08-15, all verified):
stale sema pins post-squash everywhere (`gw1.device.type/001`, reader
`/003`, `node.gt/303`, `scc/002`, `layout.lite/015`, `channel.config/002`,
`actor.class/012`, i2c relay `/005`); `HardwareLayout`/`House0Layout`/
`SimpleSimLayout`-subclass narrative in `hardware-layout-pass-one/`
(`code-for-three-layouts`, `gen-pipeline`, `layout-boundary`, hub) →
one `HydronicLayout`; `gw1.simple.sim.layout` unloadable by scada
(`sema_to_dc.py:44`) vs `build-plant`/`axioms`/gleanings; 7 refs to
deleted `layout_gen/`; hardware hub `▶` still `operational-params.md`,
the most stale file (splice model, SystemMode/GNodes/Lat-Long,
`hp_max_kw_el` to layout, per-home fixture dirs) — its live thread is
this spoke; `layout-boundary.md:138` names nonexistent
`gw.house0.sieg.layout`; `axioms.md` C/D/F open → landed as house0
axioms 6/7/8; `universe-guardrail.md` lacks `Linear:`. Spruce hub:
`house0.layout` (→`gw.house0.layout`), 06-10 branch snapshot, chunks
A/B/D understated; `summer-local-control.md:64-66,298` system.mode
Cooling thread superseded; `spruce-relay-control.md:113-128` "what
remains" all done; zone spoke ▶ at done work (circuit FSM actor not
built); `admin-for-nolan.md:63-78,87-89` false post-squash/inverted;
this spoke's "Nolan word's contents" (§ below) contradicts the identical
words — rewrite. Sim hub `:162` "No code yet" false, TODO item 2 done,
▶ build-plant Phase A never started; `new-sema-words-to-review.md`
entirely stale.

## The word today

`gw.house0.operational.params/000` — **staging** (in-place edits legal,
dev-brokers only; `sema/definitions/registry.yaml:2276-2297`). Fields:
`GNodes`, `CaptureTuningList`, `SystemMode`, `SeasonalStorageMode`,
`CopCurve`, `HeatingCurve`, `HpTurnOnMinutes`, `ShortCycleBuffer`,
`LoadOverestimationPercent`, `OilBoilerBackup`, `HorizonHours`,
`Latitude`, `Longitude` — all required.

The Nolan fixture consumes the house0-named word today
(`tests/config/nolan-layout/gw.house0.operational.params.json`), and the
load path hardcodes the filename for every family
(`OPS_PARAMS_FILE_NAME = "gw.house0.operational.params.json"`,
`gw_spaceheat/sema_to_dc.py:115`).

## Decisions (2026-08-12)

1. **`gw.nolan.operational.params` is a new word.** A Nolan home does
   not tune itself through a word named house0. The load path resolves
   the ops filename from the layout family instead of one constant.
2. **`GNodes` leaves operational params.** GNode identity is not
   tunable; it mirrors the layout, which already carries `GNodes`
   (`nolan_layout.py:60`, `house0_layout.py:58`). Provably dead in the
   ops word: `assemble_runtime_layout` reads only `CaptureTuningList`
   (`sema_to_dc.py:57`), and no code reads `GNodes` off the ops object.
3. **`Latitude`/`Longitude` leave `gw.house0.operational.params`.**
   Site facts, not tunable. Sole consumer is the derived generator's
   weather fetch (`derived_generator.py:78-79`, used at `:952`); the
   LTN takes its own from settings (`ltn/config.py:50-51`). Where they
   land is Open below.
4. **`OilBoilerBackup` and `ShortCycleBuffer` stay, flagged.** Both
   look like implementation hacks rather than durable operational
   vocabulary; they keep their seats until the full House0 refactor,
   which owns their removal. Nothing else leaves the house0 word this
   pass.

## The Nolan word's contents — LANDED sema-side 2026-08-13

`gw.nolan.operational.params/000` (staging) carries: `ScadaAlias`
(identity pointer — stored/emitted instances self-identify; the
layout keeps the full GNodes), `CaptureTuningList` (the assembly
contract, both families), `ActuationAuthority` × `ServiceMode`,
`OnPeakWindows` (list of `gw.tou.window`: Start/End `hh.mm` +
explicit `Days`, so weekend exemption is mechanical absence), and
`HeldCircuitPositions`. Supporting words: `hh.mm` format
(published), `day.of.week` literal enum, `gw.tou.window/000`.

`gw1.system.mode` did NOT gain Cooling: it conflated actuation
authority with thermal service (Heating doubled as full authority),
so it split into `gw1.actuation.authority/000`
(Active/Standby/MonitorOnly, default MonitorOnly — unknown degrades
to non-actuation) and `gw1.service.mode/000` (Heating/Cooling,
inert outside Active). Both ops words carry the pair; system.mode
000 stays published with `replaced_by`. Both ops words also gain
`ScadaAlias`.

No `SeasonalStorageMode`, no store knobs. `CopCurve`/`HeatingCurve`
join when Nolan heating-season control needs them, not before.

## Gates and sequencing

- **Sema word-gate:** before authoring or editing either word, read
  `sema/spec/primary.md` plus the `registry/` and `authoring/` spokes
  for types, post the summary, and wait for confirmation.
- Both words ride staging until the epic-end promote, so the
  house0 field removals are in-place edits, no version bump.
- gwsproto mirrors (`gw_house0_operational_params.py`, the new Nolan
  type) and the fixtures move in the same cluster as the sema edits;
  `sema validate` on both fixture payloads proves the pair.

## ⚠️ TODO — the 4 fixtures are hand-touched; regenerate them from tlayouts

The four `tests/config/` artifacts — `gw.house0.layout.json`,
`gw.house0.operational.params.json`, `gw.nolan.layout.json`,
`gw.nolan.operational.params.json` — are the frozen authored pairs the
suite loads. The BLESSED path is that every one of them is **regenerated
from its tlayouts sema generator** (`house0_sema_gen` / `nolan` etc.), not
hand-edited here. Right now they are being hand-touched to keep the suite
loadable, which is a stopgap:

- `gw.house0.operational.params.json` had a mis-copied **Nolan**
  `CaptureTuningList` and a bench `ScadaAlias`; its capture tunings were
  re-authored (34 from the pre-consolidation `house0-layout/` ops at git
  `f15f7dd7^`, `primary-flow` + `zone1-main-whitewire-pwr` from the real
  `beech` fixture) and `ScadaAlias` set to the layout's Scada gnode.
- `gw.house0.layout.json` was missing the `transactive-power`
  `derived.channel.gt` its own axiom requires; one was hand-added
  (`CreatedByNodeName=power-meter`, `InputChannelNames=[hp-odu-pwr]`) — a
  real House0 (beech) sums `hp-odu-pwr`+`hp-idu-pwr`, but this fixture has
  no `hp-idu-pwr` channel, so the hand-add is a minimal placeholder.

**Retire all of this by regenerating the four from tlayouts.** Until the
house0 sema generator produces a complete, axiom-valid pair (transactive
channel, full capture tuning, correct GNode aliases), the fixtures drift
from what a real home would author. Do NOT keep hand-patching past the
point the generator can emit them — the hand-edits are the debt this note
exists to pay down.

## Bring House0 up to snuff

House0 must reach parity with Nolan so the merge gate ("both cases work") is
real. Landed/known items live elsewhere (the hand-touched fixture pair — see
the fixtures TODO above; "Test House0" — wire conftest to run both families —
in the Cleanup queue). This section is the home for the rest.

**Thermostat concepts expand to state machines — for BOTH layouts.** The zone /
circuit / thermostat model (`zone-relays-and-thermostat-model.md`) grows to carry
the zone and circuit finite state machines. Consequence for sim coverage: once
House0 is fully on that model, **GPIO opto sensors and the thermostat/hubitat
integration are no longer needed on House0** — a heat call is sensed through the
(already derived-sim) power meter / whitewire path, and the thermostat behavior
lives in the state machine, not a Hubitat poll. So do NOT invest in a simulated
GPIO opto sensor or a simulated Hubitat/Honeywell for House0: both are slated to
retire as House0 comes up to snuff. (Left 2026-08-16, per Jessica.)

## Cleanup queue

- **Test House0** — `conftest.py` still pins the Nolan pair only, so the
  now-loadable `gw.house0` pair (layout ⊕ ops, completed 2026-08-15) is
  never exercised by a test. An axiom that has never rejected anything is a
  claim, not a check. Wire the suite to run BOTH families (the merge gate's
  "both cases green"), accepting it will surface House0-specific failures to
  work through. This is the payoff of the dual-layout gate.

- **`whitewire_threshold_watts` belongs in operational params; which
  circuits are power-metered belongs in the layout** (settled
  2026-08-14; still `ScadaSettings.whitewire_threshold_watts`
  meanwhile). A heat call is sensed either by opto-coupler or by power
  meter: Nolan wires opto (`zone1-bench1-opto-input`, `BinaryState`,
  interpretation `DigitalZeroIsActive`), House0 meters the call wire
  (`zone1-main-whitewire-pwr`, `PowerW`, needing
  `GreaterThanThreshold`). Which of the two a circuit uses is a wiring
  fact and stays with the layout — `gw1.zone.call.circuit` already
  binds circuit to channel via `WhitewireChannelName`, and the
  heat-call `derived.channel.gt` already carries
  `Parameters["Interpretation"]`. The *threshold* is a tunable and
  belongs in ops. Note it is already modelled as
  `derived.channel.gt.Parameters["Threshold"]`, so the settings field
  is a duplicate of a fact the vocabulary holds — the move is out of
  `Parameters`, not out of nowhere.
  Proposed shape: a `gw1.heat.call.tuning` word (`ChannelName` +
  `ThresholdWatts`) carried on both ops words as `HeatCallTuningList`,
  keyed by **ChannelName, not CircuitPosition** — matching the
  `CaptureTuningList` precedent, so ops stays a tuning table and never
  restates circuit identity the layout owns. Only power-metered
  circuits get an entry; Nolan's list is empty. Add the matching
  assembly-coverage check (mirroring capture tuning's) so a
  `GreaterThanThreshold` channel without a tuning entry fails the boot
  instead of taking `derived_generator.py`'s silent `return 0`.
  Cost to weigh first: removing `Threshold` changes
  `derived.channel.gt`'s Strategy-conditional `Parameters` axiom, so
  that word needs a version bump unless still `staging`.

- **The heat pump belongs in the layout as components + device-type
  records** (settled 2026-08-14; `ScadaSettings.hp_model` stays
  meanwhile). The layout is the fleet's record of what is installed at
  each house, so heat-pump type is tracked there whether or not
  control code branches on it — a bare `hp_model` enum in deployment
  config cannot serve that. The Nolan layout is wrong twice today: it
  has no heat-pump component at all (its `DeviceTypes` are only
  `gw1.scada.device.type.gt` and `electric.meter.device.type.gt`), and
  it carries an `hp-idu` node that should be `hp-ctrl-box`. Target:
  `hp-odu` gains a component pointing at an `hp.device.type.gt`
  record, and `hp-ctrl-box` a component pointing at
  `hp.control.box.device.type.gt` (both words already exist in sema).
  `hp_model` then leaves settings because the device-type record
  supersedes it. Separately and on its own merits,
  `actors/orig_sieg_loop.py` is dead — nothing imports it — and is
  `hp_model`'s only reader today.
  **Sequencing, settled 2026-08-14:** this is not an in-place edit of
  the Nolan layout file. Layouts are authored in tlayouts as sema
  layout words, and `layout_gen` is deleted, so every layout change now
  arrives by regenerating the home from its sema-authored generator.
  Four homes have one (honeysuckle, house0-stub, oak, spruce); seven do
  not (almond and beachrose and orange were deleted as not real; beech,
  elm, fir, maple remain, with oak and spruce keeping their old
  generators commented as the worked translation pairs). The same
  regeneration carries House0's functional relay names — `relay1` →
  `vdc-relay` and the rest, which changes channel names by dropping the
  krida index suffix (`vdc-relay1` → `vdc-relay`) and so splits fleet
  relay-state history at the cutover. Do the heat-pump components, the
  relay renames, and any other layout change in ONE regeneration per
  home: each one costs a coordinated redeploy, and paying that twice
  for changes that could have shipped together is the thing to avoid.

- **MonitorOnly means absolutely nothing changes — including board
  initialization** (settled 2026-08-13). Under MonitorOnly the scada
  performs no physical write of any kind: the bus actor does not
  initialize expanders (no adopt-or-init, no POR clear-then-configure),
  relay actors do not boot-assert no-readback boards, the enforce loop
  does not re-assert, reset repair does not re-drive pins, and admin
  actuation is refused. Read-only telemetry (gw108 pin adoption is a
  read) continues. Nothing enforces this today — `scada.py` and
  `relay.py` never read the mode — so the actuator/bus actors learn
  the authority word when it lands, and their write paths gate on it
  at boot.
- **Retire `layout.lite`'s field-projection: send the raw
  layout + ops sema types instead** (queued 2026-08-13, after the
  `.ops` union-typing item above lands — both touch `ScadaData`'s
  `.ops` consumers, do it once). `layout.lite` exists to give
  `report.event`/`snapshot.spaceheat` consumers structural + modal
  context, but every field it carries duplicates something the two
  authored artifacts already say: `SeasonalStorageMode` /
  `ActuationAuthority` / `ServiceMode` / curves live on ops;
  `TotalStoreTanks` is already a direct `Hydronic` field on both
  layouts, and `ZoneList`/`CriticalZoneList` are derivable from
  `Hydronic.ZoneCallCircuits` (`ServesZone`/`Role`) — exactly what
  `House0Dc.zone_list`/`.critical_zone_list` already compute. No new
  sema "envelope" type is needed: `Message` (gwproactor's transport
  wrapper) already carries `Header.Src`/`Dst`/`MessageId`, so
  `NolanLayout`/`House0Sema` and `GwNolanOperationalParams`/
  `GwHouse0OperationalParams` can ride as `Message.Payload` directly,
  self-identifying via their own `GNodes`/`ScadaAlias`. The
  third-shape drift `layout.lite` kept falling into this session
  (013 stuck two versions behind 015, `SystemMode` baked in stale) is
  structural to having a third shape at all — retiring it removes the
  bug class, not just this instance of it. Scope: `scada.py` (2 send
  sites), `ltn/ltn.py` (`process_layout_lite` → receive/cache two
  payloads, re-derive zone/store facts from the raw layout the same
  way `House0Dc` does), `ltn/data.py`. Real behavior change on a
  message other components depend on — verify against this design's
  EDD bar (bench/box boot), not just pytest.
- **Mirror-before-artifact ordering for the new words**: gwsproto
  mirrors must deploy to scada AND LTN (the value rides `LayoutLite`)
  before any ops artifact speaks the new vocabulary — unknown enum
  values silently coerce to the default at decode, and a coerced
  authority/mode value is a lie with actuation consequences.
- **`.ops` is typed `GwHouse0OperationalParams` everywhere and is
  wrong now that `gw.nolan.operational.params` exists** (flagged
  2026-08-13): `scada.py:253`, `sh_node_actor.py:189`, and
  `ScadaData.__init__`/`self.ops` (`scada_data.py`) all declare the
  single house0 type. `ScadaData.__init__` unconditionally builds
  `ha1_params` off `ops.HeatingCurve`/`ops.CopCurve`/
  `ops.LoadOverestimationPercent`/`ops.HpTurnOnMinutes` at
  construction — no branch, every boot — so decoding a Nolan-shaped
  `ops` through this path crashes immediately, before `LocalControl`
  ever sees it. 20+ more sites read `self.ops.SeasonalStorageMode` /
  `.ShortCycleBuffer` / `.OilBoilerBackup` / `.HpTurnOnMinutes`
  unconditionally: `scada.py`, `derived_generator.py`,
  `local_control/*.py`, `leaf_ally*.py`, `sh_node_actor.py`. Take each
  one and allow BOTH types (`GwHouse0OperationalParams |
  GwNolanOperationalParams`), guarding every house0-only field access
  — this design's own EDD bar (bench/box harness, not just pytest)
  applies to verifying it. Until this lands, spruce's actual runtime
  boot keeps decoding through `GwHouse0OperationalParams` (the
  slimmed shape); `gw.nolan.operational.params` fixtures exist and
  are sema-validated but are not yet load-bearing for a real boot.

- **The House0 structural axioms have landed; the Python validators
  they replace have not been deleted** (axioms landed sema-side
  2026-08-14, `5aba5be`). `gw.house0.layout/000` now carries axiom 6
  `SiegManifoldChannels`, axiom 7 `SiegActorConsistency` and axiom 8
  `SystemModelEnergyChannels` — the three live validators, promoted so
  every consumer gets them at decode rather than only the application
  that runs the loader. The two dead brainstorms
  (`required_topology_nodes`, `required_system_actor_nodes`) and
  `optional_channels` are deleted.
  What remains is the other half: `check_house0_sieg_manifold`,
  `check_actors_when_using_sieg_loop` /
  `check_actors_when_not_using_sieg_loop` and
  `validate_house0_system_models` still sit in `hydronic_layout.py`,
  now duplicating the axioms. Deleting them is not unconditional — a
  layout reaching `HydronicLayout.load_dict` directly never passes
  through its sema word, so the Python check is the only guard on that
  path. The order is: make the sema word the only way in (every load
  goes through `sema_to_dc`, which does `model_validate` before
  `load_dict`), then delete. Deleting first silently drops the
  constraint for direct-`load_dict` callers.
  Note axiom 8 needed vocabulary that did not exist:
  `gw0.usable.energy.layered` and `gw0.required.energy.layered` are now
  registered and published (parameterless markers), because an axiom
  may not lean on undeclared vocabulary.

- **Layout variants that prove the axioms actually fire** (queued
  2026-08-14). An axiom that has never rejected anything is a claim,
  not a check. Sema's authoring spec already names the shape: one
  counterexample fixture per axiom, `axiom_<n>.json`, and
  `axiom_<n>_<label>.json` per clause where an axiom carries several
  independently testable obligations. Neither `gw.house0.layout` nor
  `gw.nolan.layout` has any today — both carry live axioms with no
  `examples:` block at all, so nothing exercises them and a wrong
  axiom would pass silently. The work: a positive example per layout
  word (the bijection harness can generate a real one) plus a
  negative per axiom clause — for the House0 Sieg axioms that means
  variants with `UseSiegLoop` true and no SiegLoop node, with a
  SiegLoop node of the wrong ActorClass, with `UseSiegLoop` false and
  a SiegLoop node present, and with `SiegLoopPlumbed` true missing
  each of the two hp-loop relay channels. Worth doing as the House0
  fleet is regenerated, since each home's artifact is being rebuilt
  anyway and the variants fall out of that work.

## Open

- `Latitude`/`Longitude` return to scada settings (.env), restoring
  the dev pattern (`config.py:51-52` on dev), until the TaValidator
  owns site facts. Scada-side change pending in this cluster.
- Whether the ops filename constant becomes per-family
  (`gw.<family>.operational.params.json` derived from the layout
  TypeName) or the layout folder simply names its ops file. Coupled to
  the `.ops` union-typing item above — making the filename default
  family-smart before the decode class is family-smart would make a
  future bare Nolan boot silently reach for the Nolan-shaped file and
  crash at decode for a more confusing reason. Resolve together.
- The full House0 refactor owns: `OilBoilerBackup`,
  `ShortCycleBuffer`, and a fresh look at `LoadOverestimationPercent`
  / `HpTurnOnMinutes` / `HorizonHours` as curve-vs-knob vocabulary.

## Layout collapse — LANDED in the working tree 2026-08-14, uncommitted

The layout data class is now one class, `HydronicLayout`, and the relays
live on it rather than on the actor. Suite green at 193 passed, 1
skipped; nothing staged.

**The hierarchy collapsed.** `HardwareLayout` and `House0Layout` merged
into `hydronic_layout.py` (git-tracked as a rename off `hardware_layout.py`,
so history follows); `house_0_layout.py` is gone. The family never
belonged in the class: a Nolan layout already loaded as `House0Layout`,
so the name was the only House0 thing about it. What the class earns its
place for is unchanged and has nothing to do with families — id-to-object
resolution, derived indexes, and the mutable command tree that
`set_command_tree` rewrites. The base `load` / `load_dict` went with the
merge: `House0Layout` overrode both without calling `super()`, so after
the merge they were shadowed.

**Three dead members went first** — `required_topology_nodes`,
`required_system_actor_nodes`, `optional_channels`, all uncalled and
self-documented as enforced nowhere. 90 lines, and 45 of the 99 `H0N`
references in that file. Their content is not lost: the Sieg half became
`gw.house0.layout` axioms 6-8, and the rest is in this queue.

**All 17 relay concepts moved onto the layout**, ~110 call sites
repointed to `self.layout.X` across 8 files. Resolution now happens in
exactly one place. The actor keeps `required_node` as its Glitch-emitting
wrapper for `REQUIRED_NODES` checks; the layout raises `DcError`, because
a Glitch needs `_send_to` and that is actor machinery. `ProceduralHost`
stopped declaring two relay properties — it declares `layout`, which is
enough.

Two smells fixed at their root rather than worked around. The layout
type-names are now asked of the sema words (`type_name_literal`) instead
of being a second copy of the strings, and they live in the protocol
package so `sh_node_actor` no longer imports them from an app module.

Verified behaviourally, not just by the suite: a Nolan layout resolves
`iso_valve` to `iso-valve-relay` and `store_charge_discharge_relay` to
`discharge-valve-relay` (House0 gives the same node for both), and asking
a Nolan plant for `hp_loop_on_off` raises "a gw.nolan.layout plant has no
hp loop on/off relay".

Still to do here: the non-relay duplication is untouched —
`derived_generator`, `dist_010v`, `ltn`, `pico_cycler`, `primary_010v`,
`primary_scada`, `store_010v` and `hp_boss` are still defined on both the
actor and the layout, and the actor's `atomic_ally` / `home_alone` are
aliases for `layout.leaf_ally` / `layout.local_control` under the retired
ATN and HomeAlone names. Then the `H0N` sweep: 54 references left in the
merged file, ~590 repo-wide, and `H0N` is an instantiated class carrying
`self.tank` / `self.zone`, so those parts need a home before the constants
can follow.
