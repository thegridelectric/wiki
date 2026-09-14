# sh_node_actor partition (spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-392
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
| `hp-boss-cleanup` (09-01 decisions, 09-07 build): hp-boss the heat pump's command node in every layout, gate removal, first tests in three rungs, done-when witnessed on honeysuckle | 3h (2–9) | 1.3 + 0.6 = 1.9h, in interval | scada `30fbac27` `8e0b95c6` `3d871690`; `experiments/2026-09-07-hp-boss-admin-drive/` (`193f126` + rung 3); durable facts in `executor/control-hierarchy.md` "Fixed sub-trees vs floating actuators" and `executor/testing.md` "Recipe: admin over the wire"; open items routed to `refactor-sieg.md`, `spruce-settled/relay-tests.md`, `spruce-settled/hp-twin.md` and below |
| `pico-cycler-command` (09-01 decisions, 09-07–10 build): the cycler under a command interface with the ack pair, the per-pico state roster on the deployed line, the sim pico source, the sim-time listener leak, the panel rows; closed 2026-09-14 | 4h (2–8) | 9.6h (7.6 attributed + 2 for the close-down), outside interval | scada `ea3365b5` `6cdf8a1d` `69d5d6ec` (actual-spruce) `ca53f6d2`; sema `f2168ed`; `executor/control-hierarchy.md` "The pico-cycler command", "Command interfaces and replies"; `executor/testing.md` "Pico liveness in-process" |
| `five-v-boss` (09-08): the 5 V hold above the cycler, gwsproto + tlayouts + actor + gwadmin, dev rung and spruce window | 5h (3–10) | 2.5h, below interval | scada `4daec1ab`; `executor/control-hierarchy.md` "five-v-boss: the 5 V hold"; `experiments/2026-09-08-five-v-boss-hold/` |
| dac-output tail: step 4 harness, honeysuckle bench rung, SIMULATED root cause, proactor CONNACK fix, step 5 rehearsal + two spruce windows (09-04–06) | (same row) | 1.8 + 0.7 + 0.25 + 3.0 + 1.0 + 1.5 + 2.0 + 1.5 = 11.75h | scada `0f1ff7be` `59284cc5` `ba2c9883` `a6833464` `829038b2`; proactor `3e5087f` (`v4.1.13+jm2`); tlayouts `0a051f9`; `experiments/2026-09-05-dac-output-bench/`, `experiments/2026-09-06-spruce-pump-speed-sweep/` |
| `snapshot-drop-gw1` (2026-09-08): the chunk was already satisfied (the tlayouts seed has stripped `gw`/`gw1` local names through sema `local_names` since 07-03); closed with the seed consolidation onto sema's template pair | 0.75h (0.5–1) | 0.25h, below interval | tlayouts: root seed + build script deleted, `scripts/regen_sema_snapshot.sh` the one path (`3118aa7`) |
| `is-simulated-decompression` (2026-09-09): `ta.validation.state`, `ta.deed`, `slow.contract.rejection` in staging; gwsproto twins; the scada reads its deed into a `validation_state`, `is_simulated` answers from the layout alone, an `UnValidated` scada refuses LTN offers with the rejection word, witnessed on the in-process LTN rig on both sim pairs (`9e9a61d8`) | 1.5h (1–4) | 0.5h, below interval | sema `12a608f`; scada `4bb46035` |
| `admin-scada-peer-liveness` (2026-09-10): `process_admin_dispatch`, `process_admin_analog_dispatch` and `process_admin_keep_alive` return after logging "Ignoring" instead of executing; refusal test from hp-boss | under 1h | 0.3h | scada `b3cf3426` |

Sema round 2 closed at 20.4h against its 6h (4–12) row, past the high
bound: the three word moves sum to 8.15h and the dac-output tail that
move 3 opened adds 11.75h. The hp-twin (the heat pump's digital twin
under hp-boss) is not part of this rope; it lives in
`spruce-settled/hp-twin.md` and extends hp-boss's first pass once heat pumps
can be talked to digitally.

What the rope found on the way, kept as facts:

- The Honeywell thermostat actor files are byte-identical to `main` and
  their plumbing survives the DeviceComponent/sema port unchanged; read
  findings in `zone-relays-and-thermostat-model.md` "Thermostat chunk".
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
  values in `spruce-settled/pump-device-type.md`. Run 2 lost its flow data to a flatlined pico
  under a dormant cycler, hence the HACK `829038b2`, retired by the
  pico-cycler command (`executor/control-hierarchy.md` "The pico-cycler
  command"). The DAC output actuator is
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
(from `tlayouts/house0_sim_gen.py`); the named-type and
prefix-closed tests run over both.

## Names grilling decisions — moved

The settled names principles and the live H0N/H0CN retirement inventory
(refreshed to the branch's 423 `H0N.` + 105 `H0CN.` count) now live in
`correct-house0.md` (key context "The three strands" + rung 5), which owns
the names surface. This section is retained here only as a pointer until the
spoke retires.

## Command-tree rules (confirmed with Jessica, 2026-09-01)

- **An interior node keeps its subtree; tree rewrites reparent
  delegates, never reach through them** (decided 2026-09-01). Rule and
  rationale: `executor/control-hierarchy.md` "Fixed sub-trees vs
  floating actuators".

## Do this next

Retire this spoke (decided 2026-09-14): distill, then delete.

1. "The tiers", "Directory shape" and "Command-tree decisions" →
   `executor/control-hierarchy.md`, beside the command-node base and
   the interior-node rules (a new executor file if it runs long).
2. Names — already moved. The settled principles and the live H0N/H0CN
   inventory are in `correct-house0.md` (they ride to
   `executor/hardware-layout.md` "Names" when that spoke retires, not from
   here); the "Names grilling decisions — moved" pointer above deletes with
   the file.
3. The Done ledger → one ✅ DONE line per chunk on the spruce-unlimbo
   hub with estimate against actual, as pico-cycler-command has. (Estimation
   is spoke-level now — see `estimating.md` "The unit is the spoke" — so the
   per-chunk rope calibration this ledger fed is closed; no further chunk
   estimates.)
4. Queue leftovers: `journalkeeper-pico-states` →
   `../spruce-settled/report-all-machine-states.md`, which already names
   it; the sign-offs (`run_async_actors_main`, repo-wide ruff,
   `oak_gen.py`'s retired `zone_device_ids`) → `odds-and-ends.md`.
5. "Discipline", "State", "Sequencing decision" go with the file.
6. `git rm` this file; repoint `nolan-local-control.md` and
   `../spruce-settled/report-all-machine-states.md` at the executor
   sections; drop the hub line.
