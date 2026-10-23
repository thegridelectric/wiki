# Field checks (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-21 · Linear: OPS-392

> What this is: the claims about the unlimbo scada that a beta window
> confirms against reality, each a row to read from the window's log,
> capture and `report.event` state lists, and the record of which
> windows have confirmed which. What is built is in `executor/`; this
> spoke does not repeat it.

## The rows

A row gets ✅ with the house and date when a window shows the
behaviour. A row shows ❌ when a window showed the opposite; the
finding goes to the spoke that owns the behaviour and the row stays
open.

| Claim | What to see |
| --- | --- |
| A cert window is admitted by FIS | The upstream link connects to hw1-1 on the box's cert with no password; FIS `auth_events` shows one allow for principal `9024e45e…` on the window's instance id, a lease created on it, and the deployed scada's lease superseded; the scada log shows the upstream link active and `gw.scada.commit` sent |
| ✅ First boot provisions weather from the facade (spruce 2026-10-09) | `Pulled a 96-slice Live forecast` in the log, the bundle record and the seasonal template written to `scada-experiment/`, no `WeatherProvisioningError` |
| ✅ A Nolan scada boots with the call open (spruce 2026-10-21) | `gw1.nolan.lc.buffer.only.state` goes `Initializing` then `HpCallOff`; zones on their thermostats, charge valve closed, store pump off |
| The call follows the schedule and the band | `HpCallOn` only off-peak with the band wanting charge; `HpCallOff` at buffer-depth3 ≥ `BufferFullF`, and 120 s before each on-peak window |
| ✅ The pump follows the heat pump, not the call (spruce 2026-10-21) | `spruce.hack.hp.state` goes `HpDetectedOn` above 500 W and `HpDetectedOff` below 80 W; the secondary pump moves with it, 4 to 5 ms after each transition, and runs in `Unknown`; the call relay moves it not at all. The iso valve is open from the boot posture on (`executor/local-control.md` "Standby") |
| ✅ Every stop reaches `HpDetectedOff` (spruce 2026-10-21, 1 s after the last read above 500 W) | Within two minutes of the last read above 500 W. The off line is 10 W above the standby measured through early October; a stop that holds `HpDetectedOn` is winter standby above it |
| A blind band is a state | Either buffer channel stale 5 minutes: `gw2.lc.top.state` `ScadaBlind`, commands from `scada-blind`, call on the schedule alone; back to `Normal` through a boot; a `HouseCold` while blind goes to the cold state |
| Standby reads from the tree | A standby scada's command tree hangs under `auto.lc.standby` and its commands come from `standby`; an admin session reports `Dormant`, its release reports `Standby`, and the posture is restored |
| ✅ The operating status is quiet (spruce 2026-10-21: four messages) | One `gw.house.operating.status` after startup, then one per changed field; an admin session moves `TopState` alone |
| ✅ A refusing scada ends a stored contract (laptop sim 2026-10-14) | Restarted refusing dispatch with a live contract in the store: one `TerminatedByScada` heartbeat to the LTN carrying the reason, the leaf ally never in charge |
| A cold Nolan house needs a person and runs the heat pump | `critical-zone-cold` glitch, then `gw2.lc.top.state` `ColdOverride` in the same minute, call closed on-peak, commands from `cold-override`; back to `Normal` through a boot once warm and off-peak |
| An offer is answered only after the announcement | A scada booted with its first fetch held slow sends `gw.scada.commit` and its first `gw.house.operating.status` only once the first forecast is in; an offer sent before that is not taken, and the first taken offer follows the ally's first judgment with a forecast |
| A refusal reaches the LTN with its reason | For each refusal reason the scada can derive (no deed, operator hold, service contract broken, blind, in admin): one `slow.contract.rejection` at the LTN naming it, nothing else moves, the leaf ally stays dormant. Seen on the laptop sim 2026-10-14 for `OperatorHold`, `ServiceContractBroken`, `NoTaDeed` and `ScadaBlind`, and at beech 2026-10-14 for `OperatorHold`; `InAdmin` not yet |
| A contract ends by each termination case | A contract taken and ended by its duration, by the LTN, by the scada refusing mid-contract, and by an admin session (`InAdmin`): one terminating heartbeat to the LTN with the cause, the ally dormant after it, the next offer taken afterwards |
| ✅ The Hubitat reports both thermostats (beech 2026-10-14) | Beech's two Honeywell zones (`down`, `up`) have fresh setpoint and temperature readings in the window's capture; a zone with neither is the Hubitat gap round four saw |
| ❌ Nothing unexpected in the data or the log (spruce 2026-10-21) | After each window, the capture and the scada log are read through for what no row above names: a reading that never arrives, a state that flaps, a glitch nobody expected, a reading dropped at a boundary. A finding goes to the spoke that owns the behaviour |
| A boot into a cold house pages nothing while it warms | A scada started with a `FromThermostat` critical zone under its setpoint logs `<zone> warming up: N minutes of allowance left` each minute and raises no `critical-zone-cold` until the allowance is out; the deficit over 4 F an hour matches N |
| ✅ The elements never close (spruce 2026-10-21) | No `CloseRelay` to `buffer-top-elt-relay` / `buffer-bottom-elt-relay` in any window; `OpenRelay` to both at every boot. Spruce runs `UsesBackupWhenCold` false this winter: the radiant floor keeps the house from getting too cold, and with it false no path closes an element relay |
| Oak hears all six flow channels from the first poll | After the `kind="reed"` gen fix (2026-10-20): the three reed picos registered and posting, no `unserved-post` for them |

## Look out for at spruce: the iso relay and the 0x21 reset

The 2026-08-23 gw108 relay stress run at spruce
(`experiments/2026-08-23-gw108-relay-stress/`) found that energizing
the iso-valve relay with fewer than two other 0x21 coils already
energized resets expander 0x21 (35 in 100 with none on, 2 in 30 with
one, 0 in 90 with two or more); the secondary-pump relay never resets
it, and the same board on the bench with nothing on the contacts never
resets. Command spacing makes no difference. The 10-21 boot posture
commanded `OpenValve` to the iso with every other 0x21 coil just
commanded off, and the `i2c-expander-reset` followed. At every spruce
window: note which 0x21 coils are on at each iso transition, and read
an `i2c-expander-reset` against the iso command that preceded it
before blaming anything else.

## Patched, confirm

Each a recent fix with the test that pins it, for a reviewer or a
window to re-break.

- **warm-up-allowance.** A `FromThermostat` zone is not cold inside its
  warm-up allowance (2026-10-20): its deficit at the first pass after a
  boot, a setpoint raise or a cold-state exit, capped at 10 F, over 4 F
  an hour. Pinned by
  `test_a_boot_into_a_cold_house_is_not_cold_for_its_deficit_over_four_degrees_an_hour`
  and its neighbours (`tests/actors/test_cold_handling.py`). To
  re-break: a raise read as two steps by the thermostat (each step its
  own allowance from a smaller deficit); a zone whose temperature arrives
  only after the setpoint moves; a restart during a real cold spell,
  where the page waits out the allowance by design.
- **cold-every-pass.** The watch says cold on every pass (`3fdfb362`,
  2026-10-07) the latch holds with the stores empty;
  `BreakServiceContract` once per spell, `HouseWarm` once after. A
  machine `Dormant` when one arrives moves at the pass after it wakes.
  Pinned by
  `test_five_minutes_cold_with_the_stores_empty_tells_the_local_control_on_every_pass`
  (`tests/actors/test_cold_handling.py`) and the cold-state wait at the
  end of
  `test_a_house0_house_cold_with_its_stores_empty_under_a_dispatch_contract_ends_it`
  (`tests/actors/test_cold_handling_live.py`). A cold spell with the
  stores full still sends the machine nothing, by design: cold with heat
  in the stores is a distribution fault, not a case for the cold states.
- **blind-band-cold.** A cold house with a blind band takes its cold
  state (`3fdfb362`, 2026-10-07). The cold states need no band, so
  `HouseCold` moves `ScadaBlind` as it moves `Normal`; the warm exit
  re-boots `Normal`, which goes blind again at its next check. Pinned by
  `test_heating_cold_with_a_blind_band_goes_to_cold_override`
  (`tests/actors/test_local_control_nolan.py`) and
  `test_the_watchs_cold_message_moves_a_blind_house0_tree_under_backup`
  (`tests/actors/test_local_control_tree_by_top_state.py`). To re-break:
  is anything in `ScadaBlind` (House0's aquastat switching, Nolan's
  schedule call) left half-done by that exit?
- **termination-cause.** A terminating heartbeat carries the decider's
  reason as given (`7199cd76`, 2026-10-07): `process_ally_gives_up` is
  the one termination path whoever decides, and does not prefix the
  cause with "Ally Gives up". Pinned by the cause assertions in
  `test_a_live_stored_contract_is_ended_by_a_scada_that_refuses_dispatch`
  (`tests/actors/test_startup_contract_load.py`) and the cold-under-
  contract live test. To re-break: a reason that reaches the LTN
  without saying who decided or what it saw.
- **backup-pair-check.** The backup pair is checked at load (`7a059dbe`,
  2026-10-07): `UsesBackupWhenCold` true needs a `Hydronic.Backup` with
  `InService` true, an element backup at Nolan, before any actor is
  built, for both families. Pinned by the backup tests in
  `tests/test_misc/test_layout_word_guards_the_loader.py`. To re-break:
  a pair that passes the check and still sends a cold house somewhere it
  cannot go.
- **pump-on-power.** The secondary pump follows hp-watch alone, never
  the call (`a9acd401` plus the rule fix, 2026-10-21). Pinned by
  `test_the_secondary_pump_follows_the_sensed_heat_pump_not_the_call`
  (`tests/actors/test_hp_boss.py`) and
  `test_under_admin_the_pump_follows_the_heat_pumps_power_not_the_call`
  (`tests/actors/test_hp_watch_live.py`); read on spruce the same day.
  To re-break: a watch stuck `HpDetectedOn` on winter standby holds the
  pump on between cycles, which the held-on warning reports.

## We know about this, don't raise it

- **watch-defaults.** Closed 2026-10-07 (`6618a82b`) on spruce's power
  history: the defaults stand and the lines are right for this unit
  (`executor/local-control.md` "The heat-pump watch", "Authoring a
  row"). The one residual, winter standby above the off line holding
  `HpDetectedOn`, is reported by the watch itself: one Warning
  `hp-watch-held-on` per spell after ten minutes between the lines.
  Pinned by
  `test_held_on_between_the_lines_for_the_hold_warns_once_per_spell`
  and `test_a_stop_inside_the_hold_warns_nothing`
  (`tests/actors/test_hp_watch.py`). To re-break: a stop whose wind-down
  sits between the lines longer than ten minutes, which would warn on a
  healthy unit.
- **stale-params-push.** A whole-file params push carrying the source's
  `AcceptsDispatch: true` clears a `ServiceContractBroken` latch. Not
  open in today's code: the only push is `scripts/roll.sh`,
  which shows the difference and asks. It is a constraint on the brokered push,
  recorded in OPS-408; the second-writer fact is
  `executor/cold-house.md` "The refusal".
- The warm exit on-peak waiting for a loop pass is the tick problem of
  `../spruce-settled/async-local-control.md`.

## Windows run

- **spruce 2026-10-09** (`97ea5806`, two windows;
  `experiments/2026-10-09-nolan-local-control-windows/`): first boot
  pulled the bundle record, the template and a Live forecast from the
  facade and kept them as sema files.
- **beech 2026-10-14** (19:58 to 20:20, dev broker, laptop LTN):
  `BufferOnly` local control at `HpOff` on a full buffer; an
  `offer_contract.py beech` offer refused with `OperatorHold` and the
  rejection at the LTN; both Honeywell thermostats on their 300 s
  period; every enabled channel in the reports. Beech's second window
  (2026-10-16) did not open: the forecaster served bundle 000 against
  the scada's 001 pin.
- **oak 2026-10-20** (`b3b71004`, both pis, observe-only;
  `experiments/beta-field-windows/runs/2026-10-20-1831-oak-second-window/`):
  sane on-peak posture, no errors, all four Hubitat zones reporting,
  the deed and tank board-variant glitches cleared by the oak gen fix.
- **spruce 2026-10-21** (`a9acd401`, 11 minutes, admin TurnOn and
  TurnOff; `experiments/2026-10-21-spruce-pump-on-power-window/`): the
  pump rule, boot posture, every-stop, quiet status and elements rows.

## Next windows

Spruce rolls to `jm/spruce-unlimbo` with the `jm/spruce` layout by
`scripts/roll.sh`, which disables the winter hack while spruce is off
`actual-spruce` and installs the committed pair after showing any
difference. On the laptop sim, `experiments/offer_contract.py` offers a
contract as the LTN at any minute.

- **oak** (both pis, observe-only): the six flow channels from the
  first poll and no `unserved-post`; re-read the 204 W idle draw and
  relay 15.
- **beech** with the hold off: the remaining refusals
  (`ServiceContractBroken`, `NoTaDeed`, `ScadaBlind`), the `InAdmin`
  termination and refusal through `gwa watch`, a termination
  mid-contract.
- **fir**: first window after the fir pair regen on the Samsung
  Hydrokit pair (`SamsungAM048TXMDCH`, `SamsungAM048CNBFCB`, sema
  2026-10-21).
- **the cert window** (`--cert`, the upstream link on spruce's own cert
  to the prod broker; harness and box ready) waits on `layout.lite` 013
  published and `finalize-layout-lite-13.md`: a window on the prod
  broker announces its layout to the fleet.
