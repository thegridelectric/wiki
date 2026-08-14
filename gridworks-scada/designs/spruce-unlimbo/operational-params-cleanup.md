# Operational params cleanup (spoke)

Status: Draft · Pass 0 · Updated 2026-08-12 · Linear: OPS-392

> What this is: spruce-unlimbo spoke cleaning up the operational-params
> surface: the Nolan family gets its own word
> (`gw.nolan.operational.params`), and `gw.house0.operational.params`
> slims to fields that are actually tunable. Decisions settled with
> Jessica 2026-08-12; sema edits gated below.

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

## Cleanup queue

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

- **House0 structural validation moves from the data class to
  `gw.house0.layout` axioms** (queued 2026-08-14). Structural
  constraints on a layout belong in the layout word, where they are
  enforced at decode for every consumer, not in a Python class only
  the scada loads. Three live validators still sit in the data class
  and are the migration: `check_house0_sieg_manifold` (the Sieg
  manifold's channel set), `check_actors_when_using_sieg_loop` /
  `check_actors_when_not_using_sieg_loop` (which actor nodes the
  `FlowManifoldVariant` implies), and
  `validate_house0_system_models`. Each becomes an axiom or is shown
  to be a genuine runtime check and stays.
  Alongside them go two dead design brainstorms —
  `required_topology_nodes` and `required_system_actor_nodes` — whose
  own docstrings say they are enforced nowhere and are to become
  per-layout axioms. They are worth carrying into the axiom work as
  the first-draft content (`required_topology_nodes` is already known
  too strict: it lists `hp-idu`, but maple runs `hp-odu`-only and is
  still House0), then deleting. They hold 45 of the 99 `H0N`
  references in `house_0_layout.py`, so deleting them roughly halves
  that file's H0N surface before any repointing starts.
  Note `validate_house0`'s own essential-node list has already been
  commented down to the five system-actor nodes that are exactly
  `gw.house0.layout` axiom 2 `EssentialNodesExistence` — the
  migration is underway and the class is holding the fossils.

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
