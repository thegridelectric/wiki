# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-07 · Linear: OPS-392

> What this is: what to check as Nolan local control runs in the beta
> windows, and the brief for the adversarial review. What is built is
> specified in `executor/local-control.md` and `executor/cold-house.md`;
> this spoke does not repeat it.

## Do this next

**▶ DO THIS NEXT: step 1,** the code review from sol.

1. **Code review from sol** ("For the review" below).
2. **Run in the beta windows for maple and spruce** ("What to check in
   the field" below).

Each finding goes in with its test first.

## What to check in the field

None of this has been witnessed on a box; the tests in
`executor/local-control.md` "Tests" are in-process or against the sim.
Each row is a claim to confirm in a window, read from the journal's
`report.event` state lists and the scada log
(`experiments/spot-check-recipe.md`).

| Claim | What to see |
| --- | --- |
| A Nolan scada boots with the call open | `gw1.nolan.lc.buffer.only.state` goes `Initializing` then `HpCallOff`; zones on their thermostats, charge valve closed, store pump off |
| The call follows the schedule and the band | `HpCallOn` only off-peak with the band wanting charge; `HpCallOff` at buffer-depth3 ≥ `BufferFullF`, and 120 s before each on-peak window |
| The pump follows the heat pump, not the call | `spruce.hack.hp.state` goes `HpDetectedOn` above 500 W and `HpDetectedOff` below 80 W; secondary pump and iso valve move with it, and run in `Unknown` |
| A blind band is a state | Either buffer channel stale 5 minutes: `gw2.lc.top.state` `ScadaBlind`, commands from `scada-blind`, call on the schedule alone; back to `Normal` through a boot; a `HouseCold` while blind goes to the cold state |
| Standby reads from the tree | A standby scada's command tree hangs under `auto.lc.standby` and its commands come from `standby`; an admin session reports `Dormant`, its release reports `Standby`, and the posture is restored |
| The operating status is quiet | One `gw.house.operating.status` after startup, then one per changed field; an admin session moves `TopState` alone |
| A refusing scada ends a stored contract | Restarted refusing dispatch with a live contract in the store: one `TerminatedByScada` heartbeat to the LTN carrying the reason, the leaf ally never in charge |
| A cold Nolan house needs a person and runs the heat pump | `critical-zone-cold` glitch, then `gw2.lc.top.state` `ColdOverride` in the same minute, call closed on-peak, commands from `cold-override`; back to `Normal` through a boot once warm and off-peak |
| The elements never close | No `CloseRelay` to `buffer-top-elt-relay` / `buffer-bottom-elt-relay` in any window; `OpenRelay` to both at every boot. Spruce runs `UsesBackupWhenCold` false this winter: the radiant floor keeps the house from getting too cold, and with it false no path closes an element relay |

Every box carries an `operational-params.json` older than the ops word
(`OilBoilerBackup` for `UsesBackupWhenCold`); a window on this branch
puts the regenerated pair first (`experiments/put_layout.sh`).

Spruce's window runs `jm/spruce-unlimbo` against the `jm/spruce` layout
and displaces the winter hack, so an experiment window there is short
(`experiments/field-window-recipe.md`).

## For the review

The reviewer reads `executor/local-control.md` against the code and
tries to break it. The places most likely to give:

1. **The refusing restart ends its contract through
   `process_ally_gives_up`**, though the ally did nothing: the cause
   reads "Ally Gives up", and the auto-state trigger is ignored when
   the scada is already in `LocalControl`.
2. **The four seconds before `resume_loaded_contract`.** An offer in
   that window, a contract that expires in it, and a store written by
   another status are the cases to walk. The suite shows it:
   `test_a_live_stored_contract_is_taken_up_again_after_a_restart`
   (`tests/actors/test_startup_contract_load.py`) times out at 30 s on
   some runs and passes on the next, with `latest_scada_hb` still
   `None`, so the resume is racing something.
3. **The watch's defaults.** `Unknown` runs the pump; a first read
   between the lines is `HpDetectedOff`. Either could be wrong for a
   heat pump other than spruce's Samsung, and the lines are hard-coded
   per device type.
4. **A whole-file params push** carrying a stale `AcceptsDispatch:
   true` clears a `ServiceContractBroken` latch (OPS-408).
5. **A cold house with a blind band takes its cold state.** The cold
   states need no band, so `HouseCold` moves `ScadaBlind` as it moves
   `Normal`; the warm exit re-boots `Normal`, which goes blind again
   at its next check. The reviewer confirms nothing in `ScadaBlind`
   (House0's aquastat switching, Nolan's schedule call) is left
   half-done by that exit.
6. **The watch says cold on every pass** the latch holds with the
   stores empty; `BreakServiceContract` once per spell, `HouseWarm`
   once after. A machine `Dormant` when one arrives moves at the pass
   after it wakes. A cold spell with the stores full still sends the
   machine nothing, by design: cold with heat in the stores is a
   distribution fault, not a case for the cold states.

The warm exit on-peak waiting for a loop pass is the tick problem of
`../spruce-settled/async-local-control.md`, not a review item here.

Code: `actors/local_control_loader.py`, `local_control/standby.py`,
`local_control/nolan/buffer_only_tou.py`, `actors/hp_watch.py`,
`actors/leaf_ally_loader.py`, and in `actors/scada.py`
`resume_loaded_contract`, `enforce_auto_state_consistency`,
`process_ally_gives_up` and `report_operating_status`.
