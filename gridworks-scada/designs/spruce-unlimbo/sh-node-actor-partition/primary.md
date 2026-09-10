# sh_node_actor partition (rope hub)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392
**EDD: yes** the simulated House0 and spruce runs and the real-house
witness runs are the verification; a chunk reaches Verified only when
one of them exercises it (`experiments/`).

> What this is: the rework of `sh_node_actor.py` (1852 lines, five
> concerns, inherited by every node actor: the relay actor carried
> `turn_on_HP`, the thermistor reader carried `is_buffer_full`). Grilled
> 2026-08-31; the decision was to decouple the function families into
> tiers (below). Because this is a fundamental part of the scada and the
> code has little test coverage, the work runs as a **rope**: move
> carefully and considered, one chunk at a time, and when a chunk exposes
> significant technical debt, open another rope chunk rather than push
> through. Each chunk gets its own estimate (`r:sim-green` rows in
> `admin/jess-estimates.md`); the rope as a whole is not estimable. The
> record here (Done, with estimate against actual per chunk) is the
> evidence for a question we want answered: can full time-to-completion
> in the scada code be estimated once a layer is open, where estimates
> made from outside blew up?

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
actors/hydronic/               shared.py · house0.py · nolan.py  (C+D)
actors/                        sh_node_actor.py (A) · command_node.py (B)
                               local_control_loader.py · leaf_ally_loader.py
```

`all_tanks` / `buffer_only` are House0-forever (Nolan homes are
store-under-floor next); there is no cross-family sharing inside a role
dir. `hydronic/shared.py` holds the family-neutral material the move
surfaced (zone-circuit relay helpers, the vdc pair, onpeak/setpoint
judgment, `latest_temps_f`); its bar is in Discipline.

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
- **The shared bar: "every layout we can imagine has this,"** not "both
  current families use it." The fall roadmap has two likely-at-scale
  layouts with no buffer tank and no iso valve, so `buffer_temps_available`
  is duplicated in both family files rather than given a speculative
  `buffered` middle tier.
- **Deletions are list-first:** every zero-caller kill list is posted for
  sign-off before deletion (decided 2026-08-31; candidates already
  audited: `orig_sieg_loop.py`, `direct_reports`, `atomic_ally`/
  `home_alone` props, one of `is_buffer_full`/`_alt`, `hp_relay_state`,
  scada.py's duplicate node props).

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
liveness test for operator CLIs.

## Sequencing decision (2026-09-01, supersedes the hack-first debate)

No upstream "specials," no House0 rename rollback decision needed yet:
the structure is (1) simulated House0 + simulated spruce green against
tests with real coverage — the ONLY scada focus, per the GridWorks_CLAUDE
note; (2) both running in dev; (3) the four upstream data repos brought
to layout-sema ingestion in dev (the rename question resolves there,
before anything touches prod). The gridworks-data analysis
(calc_hourly_data: House0-frozen channel strings, Nolan's NULL hp_kwh_el,
relay-idx LIKE patterns) is the phase-3 seed material.

## Done (the rope so far)

One row per rope chunk, named by its slug, which is also the Work cell of
its `r:sim-green` row in `admin/jess-estimates.md` (queue items and open
findings below carry the same slugs); Actual is the sum of that log's scratch rows
for the chunk (the roll-up into the log's Actual column is queued on the
hub). The what/why of each commit is in the scada changelog.

| Chunk | Est. (point, 90%) | Actual | Commits |
| --- | --- | --- | --- |
| `partition-names-grill` (2026-09-01): partition ladder + names grill | 1.5h (1–3) | 1h, in interval at bound | scada `bd13a371`; preceded by the Nolan sim pair + axioms 3–8 mirrors `617b5370` `4d5e552a` `bca080f7` (08-31, before the rope rows) |
| Deletion pass (2026-09-01) | none | in the row above | in `bd13a371` |
| `layout-word-axioms` (2026-09-01–02): axioms 3–9 + rev B + component identity | none (unestimated, no row) | 3h on 09-02 + a 09-01 portion still to patch | scada `963ccddc` `0311749b` |
| `sema-round-2`, moves 1 + 1a: House0 word, Honeywell read, sim House0 pair (09-02) | 6h (4–12) for the round, closed with the dac-output tail counted | 2.45h | sema `dfe93be`; scada `050fdd54` `98291cb6` `31a97366`; tlayouts `cdf531c` |
| Move 2: sieg split, `Strategy` → `HardwareLayoutTypeName`, `HpCommandNodeName` + `CommandableHeatPump` + tree axioms, gwsproto port (09-02–03) | (same row) | 2h + 2h | sema `8451769` `7c3e0bd` `998b9c7` + `jm/layout-tree-axioms`; scada `d4faae53` `0d4ec979` `cd6244dd` `cc44c626`; tlayouts `1741a26` |
| Move 3: DAC output actuator + word gate + reverse conformance sweep (09-04) | (same row) | 1.3h + 0.4h | scada `8166acc6` `341c99de` `5940d1b9`; tlayouts `d6a995e` `335e946`; sema `d6f59e7` |
| Sequencing read + dac-output spoke (09-02) | (same row) | 0.5h | wiki only |
| `hp-boss-cleanup` (09-01 decisions, 09-07 build): hp-boss the heat pump's command node in every layout, gate removal, first tests in three rungs, done-when witnessed on honeysuckle | 3h (2–9) | 1.3 + 0.6 = 1.9h, in interval | scada `30fbac27` `8e0b95c6` `3d871690`; `experiments/2026-09-07-hp-boss-admin-drive/` (`193f126` + rung 3); durable facts in `executor/control-hierarchy.md` "Fixed sub-trees vs floating actuators" and `executor/testing.md` "Recipe: admin over the wire"; open items routed to `../unsorted/` (`refactor-sieg`, `relay-tests`, `hp-twin`) and below |
| dac-output tail: step 4 harness, honeysuckle bench rung, SIMULATED root cause, proactor CONNACK fix, step 5 rehearsal + two spruce windows (09-04–06) | (same row) | 1.8 + 0.7 + 0.25 + 3.0 + 1.0 + 1.5 + 2.0 + 1.5 = 11.75h | scada `0f1ff7be` `59284cc5` `ba2c9883` `a6833464` `829038b2`; proactor `3e5087f` (`v4.1.13+jm2`); tlayouts `0a051f9`; `experiments/2026-09-05-dac-output-bench/`, `experiments/2026-09-06-spruce-pump-speed-sweep/` |
| `snapshot-drop-gw1` (2026-09-08): the chunk was already satisfied (the tlayouts seed has stripped `gw`/`gw1` local names through sema `local_names` since 07-03); closed with the seed consolidation onto sema's template pair | 0.75h (0.5–1) | 0.25h, below interval | tlayouts: root seed + build script deleted, `scripts/regen_sema_snapshot.sh` the one path (`3118aa7`) |
| `is-simulated-decompression` (2026-09-09): `ta.validation.state`, `ta.deed`, `slow.contract.rejection` in staging; gwsproto twins; the scada reads its deed into a `validation_state`, `is_simulated` answers from the layout alone, an `UnValidated` scada refuses LTN offers with the rejection word, witnessed on the in-process LTN rig; honeysuckle no-deed witness still to run | 1.5h (1–4) | 0.5h, below interval | sema `12a608f`; scada `4bb46035` |
| `admin-scada-peer-liveness` (2026-09-10): `process_admin_dispatch`, `process_admin_analog_dispatch` and `process_admin_keep_alive` return after logging "Ignoring" instead of executing; refusal test from hp-boss | under 1h | 0.3h | scada `b3cf3426` |

Sema round 2 closed at 20.4h against its 6h (4–12) row, past the high
bound: the three word moves sum to 8.15h and the dac-output tail that
move 3 opened adds 11.75h. The hp-twin (the heat pump's digital twin
under hp-boss) is not part of this rope; it lives in
`../unsorted/hp-twin.md` and extends hp-boss's first pass once heat pumps
can be talked to digitally.

What the rope found on the way, kept as facts:

- The Honeywell thermostat actor files are byte-identical to `main` and
  their plumbing survives the DeviceComponent/sema port unchanged; read
  findings in `../nolan-local-control/thermostat-chunk.md`.
- The bench's two "failures" had one cause: the pi booted SIMULATED.
  Routing and comparison pass on the Nolan fixture
  (`tests/actors/test_admin_on_nolan.py`, `test_zero_ten_outputer.py`);
  run 4 then passed on the real MCP4728 once the board record selected
  the silicon (`59284cc5`); the boot still carries the `SIMULATED` label,
  which is the `is_simulated` decompression in the queue.
- **The admin link talked to the scada through a refused connection.**
  With a wrong admin password the broker refused every CONNACK, and
  gwproactor queued a connect on each refusal anyway: the link moved to
  `awaiting_setup_and_peer`, emitted `mqtt.connect` and subscribed on a
  socket the broker was closing, so the admin appeared connected while
  nothing it sent could arrive. Fixed in gwproactor `3e5087f`
  (`v4.1.13+jm2`, scada pin `0f1ff7be`): a refusal rides the
  `mqtt_connect_failed` edge with its reason logged, verified against a
  real password-gated mosquitto (`experiments/2026-09-05-dac-output-bench/`
  README "Side findings", reproducer `test_connect_refused.py`). The admin panel's own client
  (`constrained_mqtt_client.py`) still has the flaw, open below.
- **Admin and scada both believed admin was in control after the
  connection was gone** (bench run 4, 2026-09-05, scada `ba2c9883`,
  log `boot-2026-09-05-run4.log`). The laptop's ssh tunnel had died
  silently; the client disconnected eight seconds after its send, and
  nothing on either side said so. The admin link never left `active`,
  the scada stayed in Admin with LocalControl Dormant, and the only
  thing that ends Admin is a fixed 120 s timer from the last admin
  message, which here fired after SIGTERM, so the auto machine woke and
  rewrote the command tree during teardown. An operator can believe they
  are controlling a scada they are not, and the scada can sit in Admin
  with no operator attached. The link has a `send_ping<admin>` task but
  no peer-liveness rule behind it. The fix (a session opened by
  take-control, `heartbeat.a` both ways, a missed beat releases Admin in
  seconds) is the admin domain's
  [OPS-529](https://linear.app/gridworks/issue/OPS-529). The
  `process_admin_dispatch` missing-`return` bug found on the same read
  is fixed (scada `b3cf3426`).
- Spruce pump-speed sweep (`experiments/2026-09-06-spruce-pump-speed-sweep/`
  "Found"): linear 3.5–8.5 V at 1.45 gpm/V, maximum from 9 V, no path
  dependence in the band; below 2.5 V the stop is path dependent. Working
  values in `../unsorted/pump-device-type.md`. Run 2 lost its flow data to a flatlined pico
  under a dormant cycler, hence the HACK `829038b2`
  (`pico-cycler-command.md` "Interim hack"). The DAC output actuator is
  canonized in `executor/hardware-layout.md` "The 0-10V output actuator".

## State (2026-09-06)

Trees: sema `dev` at `d6f59e7`, clean (cut `jm/<topic>` before any sema
edit); tlayouts `jm/spruce` at `0a051f9`, 18 commits unpushed; scada
`jm/spruce-unlimbo` at `829038b2`, clean, suite 310 passed / 3 skipped /
1 xfailed; experiments `main` at `2b2d189` plus the uncommitted run 2b/3
evidence and README in `2026-09-06-spruce-pump-speed-sweep/`. The tlayouts
snapshot and the gwsproto closure copy are both at sema `d6f59e7`.
Changelogs reconciled, no pending markers. Honeysuckle holds scada
`3d871690` (2026-09-07) with the admin link enabled in its `.env`, the
standing layout restored, and no experiments clone or admin package on
the box (bench drives run from the laptop through the ssh tunnel). Spruce is restored after the sweep: services active,
window files removed, `dev.env` carries the admin block, box README
current. Two House0 fixtures boot: `gw.house0.layout.json` (hand-kept
beech real shape: LG parts, Honeywell circuit) and `gw.house0.sim.*`
(from `tlayouts/house0_sim_sema_gen.py`); the named-type and
prefix-closed tests run over both.

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

**▶ Active spoke: [`pico-cycler-command.md`](pico-cycler-command.md)**

**Queue, in order.** Each item is its own commit with its own estimate
(scopes on OPS-392). Jessica reviews each file before it lands:
functionality evaluation plus first-ever tests per file, in service of the
single focus (sim House0 + sim spruce green with real coverage;
GridWorks_CLAUDE ⏳ note).

1. ✅ DONE `hp-boss-cleanup` (3h, 1.9h actual): in the Done table.
2. [`pico-cycler-command`](pico-cycler-command.md) (4h): items 1 and 1a, the real fix that retires the vdc hack.
3. [`krida-retirement`](../krida-retirement.md) (6h + rungs): now a spoke of the spruce-unlimbo hub, first in its list; rung 1 (the panel on Nolan) is in, rung 3 (the relay decommission) is its next move.
4. `journalkeeper-pico-states` (unestimated; own row when it starts):
   gridworks-journalkeeper vendors the new enum words (`single.pico.state`,
   `pico.cycler.event`, `pico.cycler.state`, `gw.scada.cmd.refusal.reason`)
   and reworks how it tracks enums so a state row whose enum it has not
   seen is journaled rather than dropped or coerced; then query the dev
   journal DB for the per-pico Flatlined / Alive rows the dev-broker rung
   emitted (`experiments/2026-09-07-admin-reboots-picos/`). This is the
   journal half of reading a pico flatline off the database; the spruce
   half is `pico-cycler-command.md` item 6. After krida-retirement.
5. [`command-tree-matrix`](command-tree-matrix.md) (3h; `actors/command_node.py`, 207 L): the state-transition tree matrix on `command_node.py`, with the LC dormant-sequence row.
6. ✅ DONE `admin-scada-peer-liveness` (under 1h, 0.3h actual): in the Done table. The liveness and takeover work is the admin domain's [OPS-529](https://linear.app/gridworks/issue/OPS-529).
7. [`hydronic-shared-review`](hydronic-shared-review.md) (2h; `actors/hydronic/shared.py`, ~250 L): `actors/hydronic/shared.py` review + first tests.
8. [`hydronic-house0-review`](hydronic-house0-review.md) (2h; `actors/hydronic/house0.py`, ~990 L): `actors/hydronic/house0.py` review; the buffer/storage judgment methods.
9. ✅ DONE [`is-simulated-decompression`](is-simulated-decompression.md) (1.5h, 0.5h actual): in the Done table; the spoke holds the honeysuckle witness still to run.
10. ✅ DONE `snapshot-drop-gw1` (0.75h, 0.25h actual): in the Done table.
11. LAST [`staging-words-on-prod`](staging-words-on-prod.md) (4h): the wire/layout-file word split, and with it the `layout.lite` the deployed box emits. Last on purpose: the layout's contents are settled against how local control actually runs on spruce, so everything above shapes it before it is fixed.

**Open findings and sign-offs** (unordered; each closes with a small
commit or a decision):

- [`simple-sim-n3`](simple-sim-n3.md) (3h): `gw1.simple.sim.layout` loadability as the N=3 stress test.
- Deletion sign-off: `run_async_actors_main` (orphaned by `run_scada.py`'s
  deletion); `git rm --cached scratch.py`.
- Repo-wide ruff has ~70 pre-existing findings (`--fix` sanctioned after
  a commit).
- `gen_oak_sema.py` still passes the retired `zone_device_ids`; guarded
  behind the missing no-sieg word.
- The scada changelog's two 08-31 entries sit above the 09-02 ones.
- The beech fixture `gw.house0.layout.json` fails `sema validate` on
  pre-existing shape (three channels carry InPowerMetering, four
  components predate their words' config shape); closes with a translated
  beech gen, not by hand: the hub's `correct-house0-tlayouts.md`.
- ✅ Pico liveness is one rule (`actors/pico_liveness.py`, scada
  `e0029d3d`): 2.5 expected post periods to missing, one report at the
  crossing then one a minute, shared by the tank, BTU and flow actors;
  tests in `tests/actors/test_pico_liveness.py`.
- hp-boss assumes `HpOn` at construction without reading the relay;
  the relay adopts its own state at boot (`_boot_adopt`), hp-boss does
  not. Small commit with a test (`../unsorted/relay-tests.md` item 4 is
  the relay half).
- "Task was destroyed but it is pending" at the end of every live test
  that wakes admin (`test_hp_boss_live.py`, `test_admin_on_nolan.py`
  alike, two lines each): the scada's `_timeout_admin` task
  (`scada.py`, `_renew_admin_timeout`) is still pending when the event
  loop closes. Release cancels it in the release path, so the survivor
  is the timeout renewed by a dispatch after the first, or the shutdown
  order not reaching the cancel.
- Honeysuckle's standing layout (`hardware-layout.standing.json`, the
  08-12 artifact) predates the Nolan word: it carries
  `Hydronic.SiegLoopPlumbed` and `Hydronic.Strategy`, which the word no
  longer permits, has no `hp-scada-ops-relay` and no `secondary-010v`,
  and fails `sema validate` and the coverage check at `3d871690`. The
  pair `tlayouts/honeysuckle_sema_gen.py` emits (archived in the
  dac-output experiment, on the pi as `hardware-layout.dac-output.json`)
  validates clean and is what every bench witness has run on. Making
  that pair the standing layout is the refactor: one copy on the pi and
  a line in its README. The rung-3 window restored the stale one.
- **One scada per box, enforced.** Twice now a second scada has been
  launched on honeysuckle while the first was still inside its
  `timeout` (dac-output run 3 lost two passes; the hp-boss rung-3 window
  on 2026-09-07 double-booted onto the same i2c bus and broker
  identity). A convention ("check `pgrep` first") has not held. The
  scada should refuse to start when another instance is running on the
  box: a lock the process holds for its lifetime (a pid file under the
  scada's state dir, or an advisory `flock` on it), checked in `cli.py
  run` before any actor starts, with a plain refusal line naming the
  live pid. The systemd unit on a deployed house already gives this;
  bench and dev launches are where it is missing. Small commit, own
  test.
- The admin panel's own MQTT client ignores CONNACK reason codes, the
  same flaw the proactor fix closed on the scada side; fixes with the gridworks-admin package changes.
- Honeywell web-listen path is dead in the field on `main` and here:
  `HubitatWebEventHandler.__call__` uses `time.time()` with no `time`
  import and swallows the NameError in a bare except; the stat node runs
  under `s2` while the hub's web server runs under `s`, so neither finds
  the other's communicator. Polling is the only live path.
- LocalControl reads setpoints by scraping channel names (`'zone' in x
  and 'set' in x`) rather than the circuit's Thermostat; nothing consumes
  `Thermostat.ComponentId` or `ThermostatKind` yet.
- No test constructs the Hubitat or HoneywellThermostat actors; a poller
  test on a canned MakerAPI refresh response is the first coverage to
  add.
- Deferred partition upgrades: House0-flavored channel lists still built
  in `ShNodeActor.__init__`; `Scada.set_command_tree`'s rewrite logic
  still its own (dedupe only at the construction funnel); `zone_setpoints`
  attr lives in tier A but is used by shared.
- Bufferless-fall flags (ride the names cluster / base upgrades, not the
  mixin level): `ScadaData.buffer_temps_available` lives on the BASE data
  class; `scada.py`'s first-buffer-reading fast-forward hack assumes a
  buffer; `HydronicSpaceheatNodeNames`' docstring claims buffer names for
  "every hydronic plant" (buffer names belong a tier down when the
  bufferless families arrive). The iso valve is already Nolan-scoped.
- The pump model belongs in the layout as a device-type word
  (`../unsorted/pump-device-type.md`).
- Housekeeping: commit the sweep run 2b/3 evidence + README in
  experiments; push tlayouts `jm/spruce`.
- Estimates roll-up: the `layout-word-axioms` chunk has no `r:sim-green`
  row and its 09-01 scratch portion is still to patch.
- gwproactor tests are failing in CI right now; investigate and fix.
