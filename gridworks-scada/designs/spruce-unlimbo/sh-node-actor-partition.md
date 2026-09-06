# sh_node_actor partition (spoke)

Status: Draft · Pass 0 · Updated 2026-09-05 · Linear: OPS-392

> What this is: the agreed rework of `sh_node_actor.py` (1852 lines, five
> concerns, inherited by every node actor — the relay actor carries
> `turn_on_HP`, the thermistor reader carries `is_buffer_full`). Grilled
> 2026-08-31; decisions below. Break first, upgrade second: each function
> family also needs improvement, and the partition is itself the first
> upgrade (it ends family-blind inheritance).

## The tiers

- **A — actor infrastructure** stays in `sh_node_actor.py`: identity
  accessors (`services`/`node`/`layout`/`data`/`ops`), `await_with_watchdog`,
  `_send_to`, `log`. Every node actor inherits A.
- **B — command-tree mechanics** move to `actors/command_node.py`,
  inherited only by INTERIOR nodes of the command tree (take commands from
  above AND command reports below): Scada, LocalControl, LeafAlly, hp-boss,
  pico-cycler, and the coming circuit FSMs — the hierarchical state machine
  deepens, so B's inheritor count grows; it is designed for N, not 3. Leaf
  actuators only CHECK handles (stays local to `relay.py`); sensors are
  outside the tree.
- **C+D — actuation choreography + plant judgment** move to
  `actors/hydronic/house0.py` and `actors/hydronic/nolan.py` — one file
  per family (the two strata share domain, consumers, and lifecycle; split
  later only if a file outgrows one concern). The name deliberately
  matches the artifact side: `Hydronic`, `gw.hydronic`, `HydronicLayout`.
- **E — zone/TOU odds** (`get_zone_setpoints`, `is_onpeak`,
  `is_system_cold`): family-neutral pieces reading ops words; dispositions
  decided per symbol during the move (candidates: B for onpeak? hydronic
  for system-cold) — flagged in the move diff, not silently placed.

## Directory shape (role first, then family)

```
actors/local_control/house0/   tou_base, all_tanks_tou, buffer_only_tou, standby
actors/local_control/nolan.py
actors/leaf_ally/house0/       all_tanks, buffer_only
actors/leaf_ally/nolan.py
actors/hydronic/               house0.py · nolan.py  (C+D)
actors/                        sh_node_actor.py (A) · command_node.py (B)
                               local_control_loader.py · leaf_ally_loader.py
```

`all_tanks` / `buffer_only` are House0-forever (Nolan homes are
store-under-floor next); there is no cross-family sharing inside a role
dir.

## Command-tree decisions

- **Each interior node is responsible for the tree at-and-under it and
  publishes it.** Today "publishes it" = the full-tree
  `new.command.tree` snapshot (the wire contract is
  replace-in-entirety); subtree-payload publication would be a protocol
  change — parked.
- **Publish funnel now:** the three construction sites (`scada.py`,
  `sh_node_actor.set_command_tree`, `tou_base.set_limited_command_tree`)
  all route through one B-tier `publish_command_tree()`; policy changes
  become one-line.
- **Mechanics dedupe now, ownership move later:** `Scada.set_command_tree`
  and the base's copy collapse into B's `rewrite_reports(boss)` +
  publish; scada keeps its top-level policy (vdc under pico-cycler,
  admin vs auto). The deeper fix — pico-cycler rewriting its OWN subtree
  so scada stops knowing the vdc rule — is real behavior movement and is
  the FIRST ITEM of the circuit-FSM wave (its worked example), not part
  of the pure-move phase. Single-publisher likewise parked to that wave.
- The generic base's House0 special cases (`hp_scada_ops_relay`,
  `hp_loop_*`, the sieg chain inline in `set_command_tree`) move out to
  `hydronic/house0.py` with the rest of C.

## Discipline

- **Pure moves and upgrades are separate diffs.** Move commits are
  byte-faithful relocations, verifiable by suite + symbol diff; upgrades
  land afterward as small diffs in right-sized files. The ~500-line
  guideline is a proxy (the disease is many reasons-to-change in one
  inheritance root, LLM-sharpened by context-loading costs) — no split
  purely to hit a number.
- **Ladder, not one cut:** one commit per tier extraction (A-slim → B →
  hydronic/house0 → hydronic/nolan + dir moves), suite green at each,
  deliberate breakages (House0 helpers becoming uninheritable on Nolan)
  named in the changelog entry.
- **Deletions are list-first:** every zero-caller kill list is posted for
  sign-off before deletion (decided 2026-08-31; candidates already
  audited: `orig_sieg_loop.py`, `direct_reports`, `atomic_ally`/
  `home_alone` props, one of `is_buffer_full`/`_alt`, `hp_relay_state`,
  scada.py's duplicate node props).

## Build status (2026-09-01 night run)

- ✅ Tier B: `command_node.py` (nav + `publish_command_tree` funnel — all
  three emit sites route through `build_command_tree`) + generic relay
  mechanics (`send_state_command`, `energize`, `de_energize`,
  `actuator_config`).
- ✅ Hydronic tier: `hydronic/shared.py` + `hydronic/house0.py` +
  `hydronic/nolan.py` (seed); impls + PicoCycler rebased.
- ✅ Dir moves: `local_control/house0/`, `leaf_ally/house0/` (git mv),
  loaders updated.
- Suite 231 passed / 1 skipped after every rung; nothing deleted.
- **`hydronic/shared.py` BLESSED (2026-09-01)** with the curation rule
  sharpened by the fall roadmap (two likely-at-scale layouts have NO
  buffer tank and NO iso valve): shared means "every layout we can
  imagine has this," not "both current families use it." Zone-circuit
  helpers, the vdc pair, onpeak/setpoint judgment, `latest_temps_f`
  qualify; `buffer_temps_available` did not — moved to BOTH family files
  (duplicated one-liner beats a speculative `buffered` middle tier).
  Also fixed: `derived_generator` read the moved property without
  inheriting the tier (latent AttributeError, untested path) — it reads
  `self.data.buffer_temps_available` directly now.
- **Bufferless-fall flags for the deeper layers** (not mixin-level, ride
  the names cluster / base upgrades): `ScadaData.buffer_temps_available`
  lives on the BASE data class; `scada.py`'s first-buffer-reading
  fast-forward hack assumes a buffer; `HydronicSpaceheatNodeNames`'
  docstring claims buffer names for "every hydronic plant" — buffer
  names belong a tier down when the bufferless families arrive. The iso
  valve is already Nolan-scoped (no contamination).
- Third-layout question (2026-09-01): no invented family;
  `gw1.simple.sim.layout` loadability queued as the N=3 stress test, and
  the standing rule is **a new family's sim pair ships in the same wave
  as its word**.
- **DEVIATION (superseded by the blessing above):** `hydronic/shared.py` is a third file the
  agreed two-file shape didn't have — the move surfaced genuinely
  family-neutral material (zone-circuit relay helpers, the vdc pair,
  onpeak/setpoint judgment, temperature access). Bless or redistribute.
- Deferred upgrades (not in the move): House0-flavored channel lists
  still built in `ShNodeActor.__init__`; `Scada.set_command_tree`
  mechanics dedupe done only at the construction funnel (its rewrite
  logic still its own); `zone_setpoints` attr lives in A but is used by
  shared.

## Deletion pass (signed off + executed 2026-09-01)

Deleted: `direct_reports` (both defs — CommandNode and the zero-caller
HydronicLayout copy), `is_buffer_full_alt`, `HouseStrategy`,
`House0RelayIdx`, the stale `home_alone` comment, `run_scada.py` (spruce's
service runs `gws run`; the README teaches it). Kept: `orig_sieg_loop.py`
(reference note added — Jessica's original sieg work, held for the PID
build-up), `show_settings.py` (works, operator config check),
`getkeys.py` (TLS commissioning tool). `scratch*` are personal
scratchpads (`.gitignore` covers them; `scratch.py` predates the rule —
untrack with `git rm --cached`). Lesson: importer-count is the wrong
liveness test for operator CLIs. Awaiting sign-off:
`run_async_actors_main` (orphaned by run_scada's deletion).

## Sequencing decision (2026-09-01, supersedes the hack-first debate)

No upstream "specials," no House0 rename rollback decision needed yet:
the structure is (1) simulated House0 + simulated spruce green against
tests with real coverage — the ONLY scada focus, per the GridWorks_CLAUDE
note; (2) both running in dev; (3) the four upstream data repos brought
to layout-sema ingestion in dev (the rename question resolves there,
before anything touches prod). The gridworks-data analysis
(calc_hourly_data: House0-frozen channel strings, Nolan's NULL hp_kwh_el,
relay-idx LIKE patterns) is the phase-3 seed material.

## Handoff state (2026-09-05, session snug-mistral → next)

**Landed this session:** scada `8166acc6` (conformance sweep checks the
layout closure in reverse: gwsproto vendors the tlayouts snapshot
registry at `packages/gridworks-scada-protocol/sema_closure/`, the
standing test requires every closure word to have a gwsproto twin, and
the wiki Stop hook `stop-snapshot-closure-sync.sh` blocks while the copy
and the snapshot differ — refresh the copy in every snapshot wave);
tlayouts `d6a995e` (Nolan gen emits DAC outputs, honeysuckle TODO folded
in); scada `341c99de` (move 3: DAC output actuator — see item 3).
Move 3's fixture swap is done; its **word side is
the next move: the word gate below.**

**Sema round 2, remaining moves, in order** (spec: `layout-word-axioms.md`;
decisions settled there 2026-09-02). **Next move: the bench failures under item 3** (moves 1-3 and the word gate landed;
one commit per repo).

1. ✅ **House0 word** (landed 2026-09-02: sema `dfe93be`, scada
   `050fdd54`, tlayouts `cdf531c`): axioms 10 RequiredActuators + 11
   RequiredHeatpumpEquipment, mirror + rejecting tests, fixture on the
   beech real shape (LG parts, Honeywell circuit).
1a. ✅ **Honeywell read + sim House0** (built 2026-09-02, commits
   pending at handoff: sema `SimHpIdu`; tlayouts `house0_sim_sema_gen.py`
   + gen fold-in; scada sim pair `tests/config/gw.house0.sim.*` booting
   beside beech, 269 passed). Read findings + the queued thermostat
   chunk: `unsorted.md`. Order to land: sema → rebuild the tlayouts
   snapshot (`./build_tlayouts_snapshot.sh` refuses a dirty sema tree)
   → tlayouts → scada.
2. **One commit per repo, three word moves together** (all edit the
   layout words / `gw.hydronic` with mirrors and one regen wave, no
   fixture swap):
   - ✅ **The `gw.hydronic` sieg split** (landed 2026-09-03: sema
     `8451769`, tlayouts `1741a26`, scada `d4faae53`; plus `layout.lite/013`
     `Strategy` → `HardwareLayoutTypeName`, sema `7c3e0bd` / scada
     `0d4ec979`; `UseSiegLoop` reads go through
     `ScadaData.use_sieg_loop`, the assembly check is
     `sema_to_dc.check_sieg_loop_assembly`, has-sieg is
     `HydronicLayout.flow_manifold_variant_of`) (spoke "Dropped / superseded"):
     drop `SiegLoopPlumbed` — invariant for the word, nothing reads it;
     scada derives has-sieg from the presence of a SiegLoop-classed node
     (true for the coming no-sieg word without a type check). Move
     `UseSiegLoop` to `gw.house0.operational.params` — USING is
     operational; the ten `layout.use_sieg_loop` reads (`scada.py`,
     `command_node.py`, `hp_boss.py`, `api_btu_meter.py`,
     `api_flow_module.py`) repoint to ops. Hydronic axiom 1 retires into
     a scada assembly check (ops says use it ⇒ the layout has it).
     Shared staging word: Nolan fixture + mirror, both House0 fixtures,
     the Hydronic mirror and the House0 gen ride along.
   - ◐ **`Hydronic.HpCommandNodeName` + `CommandableHeatPump` + ActuatorLeaves,
     SEMA SIDE LANDED** (sema `998b9c7`, 2026-09-03): optional `HpCommandNodeName`
     (`spaceheat.name`) on `gw.hydronic`; House0 axiom 12 / Nolan axiom
     10 `CommandableHeatPump` (biconditional; RequiredHeatpumpEquipment's
     NoActor clause defers to it); `new.command.tree/002` axiom 2
     `ActuatorLeaves` with `gw1.actor.class:013` as axiom dependency and
     dormancy in the extended description. Both sim fixtures validate
     unchanged. **gwsproto port BUILT 2026-09-03 (scada commit
     pending, 289 passed):** `House0Layout.check_axiom_12`,
     `NolanLayout.check_axiom_10`, equipment checks skip the declared
     node, `NewCommandTree.check_axiom_2`, `layout.actuators` returns the
     declared node, rejecting tests per clause, coverage allowlists back
     to empty/without them. **Also 2026-09-03 (sema branch
     `jm/layout-tree-axioms`, commit pending; scada mirrors in the same
     pending scada cluster, 298 passed):** both layout words carry the
     tree word's `PrefixClosedHandles` + `ActuatorLeaves` (House0 13/14,
     Nolan 11/12, identical wording); one gwsproto implementation in
     `type_helpers/command_tree_axioms.py` serves all three types. After
     the sema commit: rebuild the tlayouts snapshot again (layout words
     changed) before the tlayouts snapshot commit. Move 2 is then complete.
     **Also built 2026-09-03, riding the same three commits:** `Hydronic.Strategy`
     dropped from `gw.hydronic` (family = the layout word); scada
     `FlowManifoldVariant` deleted with nothing in its place (the House0
     word means has-sieg; its dc-side manifold check duplicated axiom 8
     and `House0LoadArgs` collapsed into `LoadArgs`), LocalControl loader
     dispatches with `isinstance` on `layout.sema_layout`; the three new axioms sit in the coverage
     allowlists as known unported/untested debt until the mirror port;
     tlayouts gens drop the strategy label. Commit order: sema
     `gw.hydronic: drop Strategy` (5 files, pending) → tlayouts snapshot
     rebuild + sim-pair regen (should match the hand-edited scada
     fixtures byte for byte) → tlayouts commit → scada commit.
   - **new.command.tree/002 axiom 2 `ActuatorLeaves`** (sema side built
     with the bullet above; `NewCommandTree` mirror gains `check_axiom_2`
     in the scada commit), wording agreed
     (leaf / actuator / command-node definitions at the top; NoActor
     waypoints are the LocalControl node's children; dormancy of leaf
     command nodes in `extended_description`, not a clause);
     `gw1.actor.class:013` as axiom dependency.
3. ✅ **DAC actuator (1b)** (landed 2026-09-04: tlayouts `d6a995e`, scada
   `341c99de`): `ZeroTenOutputer` keys its mechanism on the component
   (I2cDacOutputComponent → board DAC through `I2cBus`; no component →
   House0's DFR multiplexer forward, noted as the missing per-output DFR
   word); the writer actor, its three gwsproto mirrors and tests are
   gone; the Nolan fixture carries `secondary-010v` (Dac2 C, power-on
   code 3020 held exactly until the first dispatch; `AnalogDispatch.Value`
   is volts × 10). **Word gate landed 2026-09-04** (sema `d6f59e7`,
   tlayouts `335e946`, scada `5940d1b9`): Nolan axiom 5 gains
   clause c (`secondary-010v`, ZeroTenOutputer, ComponentId an
   `i2c.dac.output.component.gt`); both layout words and the tlayouts
   seed drop the writer trio, so the closure no longer reaches it and
   the scada reverse-conformance allowlist is empty; gwsproto mirror +
   two rejecting tests. House0's `*-010v` ComponentId clause and the
   per-output module word defer to the krida shift (`dac-output.md`
   "Decided 2026-09-04"); the ConfigList rule is canonized in
   `executor/components.md`. **Bench rung RAN 2026-09-05**
   (`experiments/2026-09-05-dac-output-bench/`, FAIL, reproducer in
   place): the admin dispatch reaches the scada and is forwarded, but
   never reaches `ZeroTenOutputer` (no log, chip unchanged; suspect
   `Scada._send_to`'s silent fall-through for an unrouted node or the
   boss-handle rewrite under Admin), and `verify_eeprom` reprograms
   every boot on EEPROM bytes that match the layout. **Test-first pass RAN 2026-09-05 (session
   mighty-capon, scada commit pending):** the bench's two "failures"
   were one cause, the pi booted SIMULATED (no TaDeed, sim parts in the
   honeysuckle layout), so the fake chip took the dispatch and the
   verify; routing and comparison pass on the Nolan fixture
   (`tests/actors/test_admin_on_nolan.py`, `test_zero_ten_outputer.py`).
   **The gwproactor connect-reason-code fix landed** (proactor
   `3e5087f`, tag `v4.1.13+jm2`, scada pin `0f1ff7be`) and the
   honeysuckle rung re-ran on it: the dispatch reaches the outputer on
   the box, but the boot is still SIMULATED (`dac-output.md` "Why the
   bench was simulated"). **Next move, first:** grill Jessica on the best
   way to test the chip on honeysuckle. Dropping the two sim tank
   modules is out: the layout requires the channels they capture, so
   a sim-free honeysuckle layout would fail its own axioms. Candidates
   to grill: a bench-only realness exemption, a sim device kind that
   does not trip the derivation, or reading the chip through a path
   that is not the scada's `I2cBus`. **Then:** the `scada.control.capabilities` in-place edit
   (staging) that drops the required Krida component, then the
   gridworks-admin package for Nolan, both written up in
   `admin-for-nolan.md` "What the admin tool needs from a scada"; the
   failing test is `test_control_capabilities_on_nolan`. The bench
   re-run waits on the realness decision in `dac-output.md` "Why the
   bench was simulated". Then `dac-output.md` step 5, queued as
   `experiments/future/spruce-pump-speed-sweep/`.
4. **hp-twin fixture**: tlayouts config axis → `gw.nolan.layout.hp-twin.json`
   (hp-ctrl-box as HpTwin under hp-boss, its component the MIM modbus
   bridge) + a dormant HpTwin stub so both fixtures boot. hp-boss
   driver selection keys on the control box's DeviceType value: a
   real value selects the modbus driver, `SimSamsungAE055FEYMCG` the
   sim twin; sim parts carry no device-type records.

**Trees at handoff (2026-09-05, session snug-mistral):** sema `dev` at
`d6f59e7` (cut `jm/<topic>` before any sema edit); tlayouts `jm/spruce`
at `56dbcd1`, clean; scada `jm/spruce-unlimbo` at `5940d1b9`, clean and
checked out on honeysuckle (admin link enabled in its `.env`, standing
layout restored, 153 old events in `event-archive/`). The experiments
folder holds uncommitted new files (`2026-09-05-dac-output-bench/`,
`future/spruce-pump-speed-sweep/`, logbook lines). The tlayouts snapshot and the gwsproto closure copy
are both at sema `d6f59e7`. Changelogs reconciled, no pending markers.
Two House0 fixtures boot: `gw.house0.layout.json` (hand-kept beech real
shape: LG parts, Honeywell circuit) and `gw.house0.sim.*` (from
`tlayouts/house0_sim_sema_gen.py`); the named-type and prefix-closed
tests run over both. The beech fixture still fails `sema validate` on
pre-existing shape (three channels carry InPowerMetering, four
components predate their words' config shape) — closes with a
translated beech gen, not by hand. Estimate row: OPS-392 point 6h;
scratch rows on the scoreboard for 09-02, 09-03 and 09-04 — sum at wrap.

Then the tree matrix (`command_node.py` review) and the queued chunks
(pico-cycler command 4h, krida retirement 6h).

**Honeywell layout-plumbing read (2026-09-02, no code changed):** the
four thermostat actor files are byte-identical to `main`; the plumbing
they consume (`hardware_layout.component(name)`, `get_component_as_type`,
`node_from_component`, the poller's `resolve()` building its REST
settings from the hub's MakerAPI URL, `web_listener_nodes`) survives the
DeviceComponent/sema port unchanged in behaviour, and the beech-shaped
fixture carries every input the poll path needs (hub + poller
components, `zone1-main-temp/-set/-state` captured by the stat node,
s2 forwarding SyncedReadings with Src preserved). Findings:
(1) the web-listen path is dead in the field on `main` and here:
`HubitatWebEventHandler.__call__` uses `time.time()` with no `time`
import and swallows the NameError in a bare except; and the stat node
runs under `s2` while the hub's web server runs under `s`, so neither
side ever finds the other's communicator to register handlers.
Polling is the only live path. (2) LocalControl reads setpoints by
scraping channel names (`'zone' in x and 'set' in x`) rather than the
circuit's Thermostat, and nothing consumes `Thermostat.ComponentId` or
`ThermostatKind` yet. (3) No test constructs the Hubitat or
HoneywellThermostat actors; a poller test on a canned MakerAPI refresh
response is the first coverage to add.

**Standing cautions:** repo-wide ruff has ~70 pre-existing findings
(`--fix` sanctioned after a commit); `run_async_actors_main` deletion +
`git rm --cached scratch.py` await sign-off; the tlayouts snapshot builder
refuses a dirty sema tree, so sema commits land before snapshot rebuilds;
`gen_oak_sema.py` still passes the retired `zone_device_ids` and stays
guarded behind the missing no-sieg word; the scada changelog's two 08-31
entries sit above the 09-02 ones.

## Names grilling decisions (2026-09-01; landed in `bd13a371`)

- **The walk-through carries the names work.** Each file review gives
  the H0N/H0CN references in THAT file their tier decisions and
  repoints, per the tandem rule — no standalone names pass over files
  the review will visit. Pure names leftovers: the tank1-elt commit and
  an end-of-review sweep for members no reviewed file holds.

- **Tandem H0N retirement per settled name.** Each name the grilling
  settles lands as one unit in this cluster: constant in the right
  disjoint class → H0N/H0CN member deleted → call sites repointed
  (through `self.layout.X` where a property exists). The House0 test
  fixture carries the renames NOW (it is a sim artifact); the real-fleet
  channel-history split still rides the one-coordinated-regen-per-home
  in the dev wave. Out of tandem: `H0N.tank`/`.zones` (instantiated
  machinery, home undecided) and unsettled names.
- **Liveness is judged over the alias union.** A disjoint-class constant
  with no direct readers is NOT unused while H0N/H0CN members carry the
  same name — consumer counts mean nothing until the corresponding
  aliases are deleted in tandem.
- **Every layout has a store pump** (all five, slab included), so
  `store-pump-relay` is `HydronicSpaceheatNodeNames`' name; the Nolan
  duplicate is deleted. House0's `store-pump-failsafe-relay` was this
  relay poorly named: `store_pump_failsafe` deleted from H0N/H0CN/
  House0NodeNames/House0ChannelNames, both call sites repointed
  (`relay.py`, `tou_base.py`), fixture pair renamed to
  `store-pump-relay` (sema-safe: no live axiom pins the old name).
  Suite 231 passed / 1 skipped after.

- **No `Literal` in names classes** — bare assignments throughout
  `gwsproto/names/`; the annotation narrowed nothing any signature
  demanded and doubled every rename. H0N keeps its until deleted (no
  churn on a dying class).
- **`backup`/`scada-blind` are House0 names** (moved core→House0NodeNames)
  — may return to a shared tier when the Nolan state machine and its
  local control are worked through, not before.
- **A names class is vocabulary, not a required-set** — "if a layout has
  the thing, this is its name"; requiredness lives in each layout word's
  axioms. Adopted for the elt decision below.
- **Store-tank element names go per-tank** (`tank1-top-elt`,
  `tank1-top-elt-pwr`, `tank1-top-elt-relay` + bottoms, via
  `TankNodeNames`/`TankChannelNames`; flat store-elt constants deleted;
  buffer elts stay flat hydronic-tier, Nolan copies deleted).
  `SingleStoreTank` stays in the Nolan word; the tank is already
  `tank1`. Store-loop names (`store-flow`, `store-btu`, `store-pump-relay`,
  pipes) are circuit names and keep `store-*`. Execution = its own
  commit AFTER the combined landing: gw.nolan.layout in-place edit
  (staging; word-gate ritual) + tlayouts sim-pair regen + gwsproto
  literals + code repoints.
- **hp-odu prose trimmed to one line** ("for monoblocs, hp-odu IS the
  heat pump"); the multi-odu indexing speculation stays deleted, and
  device identity is the layout's device-type records' job. Modbus
  driver selection confirmed consistent with the ShNode concept:
  node → component → DeviceType is the lookup (hp-boss keys on the
  ctrl-box component's DeviceType, same pattern as the i2c board item).
- **Commit cadence pivot (agreed 2026-09-01):** finish grilling the
  pre-existing names threads → land the ONE combined commit (green) →
  every further settled change is its own commit, starting with the
  tank1-elt move.

**Names open inventory (2026-09-01) — settled means the committed diff,
not the project.** Still open, retiring incrementally under the decided
principles (one settled name per commit):

- H0N/H0CN retirement: 277 refs remain; only three members retired so
  far (`store_pump_failsafe`, `thermistor_common_relay`,
  `House0RelayIdx`). Every remaining member needs a tier decision +
  call-site repoint — system-actor names, the rest of the relay roster,
  ~40 H0CN channel aliases, `ScadaWeb`.
- `H0N.tank`/`.zones` instantiated machinery — home undecided.
- `ZoneNodes` ≡ `HydronicSpaceheatZoneNodeNames` duplication (`relay.py`
  still builds `ZoneNodes` in `initialize_fsm`).
- Actor↔layout name duplication and Nolan-wrong direct name reads —
  `operational-params-cleanup.md` items 4-5 (the lists live there).
- tank1-elt execution (decided above; own commit).
- `gw.house0.layout` axiom 2 lacks the command-tree bones: it requires
  s/ltn/la/lc/derived-generator but not `n`, `auto`, `admin` or their
  handles, which Nolan's RequiredCommandNodes pins and the command-tree
  machinery assumes ("the normal node is required in every layout" —
  Jessica). Extend axiom 2 to the Nolan shape, same sema sitting as the
  tank1-elt move.
- Buffer-side elt load-node ordering: `elt-buffer-top` deployed vs
  `buffer_top_elt` in HSNN — the store side dissolves into tank1
  naming; the buffer side still renames in the coordinated regen.
- `HydronicSpaceheatNodeNames` buffer-names docstring claims "every
  hydronic plant" — false when the bufferless fall families arrive.
- Un-audited corners: the `simple_sim` tier, `House0ChannelNames.__init__`,
  `names/*/helpers.py`.

## Command-tree rules (confirmed with Jessica, 2026-09-01)

- **An interior node keeps its subtree; tree rewrites reparent
  delegates, never reach through them** (decided 2026-09-01). Full
  rule, rationale, and work plan: `pico-cycler-command.md`.

## ▶ Do this next

The names grilling is done and the combined commit landed (`bd13a371`);
each further settled change is its own commit. Now: the file-by-file
review WITH Jessica — functionality evaluation + first-ever tests per
file, in service of the single focus (sim House0 + sim spruce green with
real coverage; see GridWorks_CLAUDE ⏳ note). Order:
1. `actors/command_node.py` (207 L): tree navigation, `set_command_tree`,
   the `build_command_tree` funnel, relay-command mechanics
   (`send_state_command`, `energize`, `de_energize`, `actuator_config`).
   Test candidates: `the_boss_of`/`my_actuators` truth table;
   `set_command_tree` prefix-guard + sieg/non-sieg handle rewrites;
   funnel publishes an axiom-valid tree (NewCommandTree now validates).
   **The state-transition tree matrix (the big one — believed to catch
   real bugs):** today's only coverage calls `scada.set_command_tree`
   DIRECTLY (3 bosses × 2 fixtures); nothing tests the trees the actual
   STATE TRANSITIONS produce. Drive each transition on both fixtures —
   admin wakes up / times out / releases; ally suit-up and hand-back;
   every LC top-event (incl. `set_limited_command_tree`'s backup and
   scada-blind paths, House0 only); sieg vs non-sieg — capture every
   published tree, and assert each constructs (axiom 1 fires on orphan
   prefixes) AND matches the expected handle shape for that state.
   Jessica believes some of these are wrong today; the failures are the
   deliverable.
  Then, in this section with their own estimates (scopes on OPS-392):
     - `pico-cycler-command.md`
     -  `krida-retirement.md`
     -  REMOVE all gw1's and gw's in the snapshot generation for tlayouts.
  
2. `actors/hydronic/shared.py` (~250 L): zone-circuit relay helpers, vdc
   pair, onpeak/setpoint judgment, `latest_temps_f`. Shared bar: "every
   layout we can imagine has this."
3. `actors/hydronic/house0.py` (~990 L): choreography + judgment; the
   judgment methods (`is_buffer_*`, `is_storage_*`) are the thinnest
   coverage in the repo and each needs a functionality conversation, not
   just a test.
Jessica reviews each file carefully before it is added; expect to
evaluate functionality and add tests as part of each review.

**Next step: finish the `is_simulated` decompression.** The 2026-09-05
pass (scada `59284cc5`) took hardware backend selection and the fake
control inputs off the bit; what is left is the part that needs
vocabulary. Provoked by this partition, so it lives here; if this spoke
keeps growing it becomes a folder.

1. **Sema:** the first-pass `TaDeed` type, the `ValidationState` enum
   (`UnValidated`, `ValidatedRealAssetAndGps`,
   `ValidatedRealAssetIncorrectGps`, `ValidatedSimulatedAsset`), and the
   scada-to-LTN contract-rejection word (offered ContractId + the scada's
   `ValidationState` as cause). Word-gate ritual per word, in a
   sema-claiming session; gwsproto mirrors with rejecting tests. Meanings
   and the transport-plane consequences are recorded under OPS-420
   ("TaDeed and the validation plane") and in the deeds exploration.
2. **Scada:** read the deed into a `ValidationState` (`UnValidated` with
   no deed); the placeholder `tadeed.json` becomes an instance of the
   word. **Refuse every LTN contract offer while `UnValidated`**, sending
   the rejection word, tested on the in-process LTN↔SCADA rig
   (`test_auto_state.py`'s shape: `Created` offered, handler stays
   empty, auto state stays LocalControl, LTN receives the rejection).
   The Krida and DFR multiplexers move to a layout fact until their sim
   twin words exist. `is_simulated` itself stays for its sim-time job
   (simulated-test-environment `sim-time.md`).
