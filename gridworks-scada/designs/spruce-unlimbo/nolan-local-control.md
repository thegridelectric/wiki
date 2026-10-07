# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-07 · Linear: OPS-392

> What this is: what to check as Nolan local control runs in the beta
> windows, and the brief for the adversarial review. What is built is
> specified in `executor/local-control.md` and `executor/cold-house.md`;
> this spoke does not repeat it.

## Weather forecast at the scada

The resume-window finding ("For the review" below) is a weather bug:
the scada pulls its forecast from api.weather.gov at start, the leaf
ally refuses a contract until a forecast exists, and a restart under a
live contract ends the contract whenever that pull is slow or down.
The scada should not be sourcing weather at all; the LTN relays it
(`../spruce-settled/ltns-ready.md`, gwwf `executor/delivery.md` "LTN
relay is primary"). Until the LTNs run, the scada keeps a pull path,
but to our own service and through sema. Four steps, each with its
test first:

1. ✅ **Shape check.** Does `gw.weather.forecast` carry what the
   scada reads off `weather.json` today (hourly unix times, °F, mph,
   a 96 h horizon)? Answered below under "Shape"; anything missing is
   a gwwf question before it is a scada one.
2. ✅ **Sim weather in the harness.** `weather_source.py`:
   `SimWeatherSource` (forecast and delay the test sets) is every
   live test's source; the NWS pull sits behind the same interface.
   `test_a_slow_weather_fetch_does_not_end_a_resumed_contract`
   (`tests/actors/test_startup_contract_load.py`) is the field bug
   written first, red until step 3.
3. ✅ **Persisted forecast, as sema, loaded first.** `GwwfWeatherSource`
   keeps the last `gw.weather.forecast` and the bundle record beside it
   as sema JSON in the config dir and decodes both in its constructor,
   so a restarted scada holds them before the resume wait; each call
   tries the facade first and falls back to the stored pair within the
   pull timeout (20 s, inside the ally's five-minute bail). The
   hand-built `weather.json` dict is gone.
4. ✅ **Pull from gwwf.** `GwwfWeatherSource` pulls
   `latest-forecast/{WeatherBundleName}` from the facade the
   `weather_api_url` setting names (`https://forecast.electricity.works`,
   Caddy on the forecast box, `gridworks-infra/forecast/instance-README.md`),
   derives slice times from the bundle record and unscales per Unit, and
   hands the derived generator and the LTN the legacy `weather.forecast`
   shape. There is no NWS kind and no lat/lon anywhere in the scada: the
   kinds are Gwwf (the default) and Sim, and the station's position lives
   on gwwf's location record. The gwsproto twins for the four weather
   words and the fidelity enum carry their axioms and counterexample
   tests; the live Millinocket payloads are the fixtures, and
   `tests/test_misc/test_weather_source.py` runs the source against a
   local facade. The coldest-of-month list stays as the last resort until
   gwwf's SeasonalTemplate record exists. Witnessed 2026-10-07 with a dev
   scada on the laptop against the dev broker and the real facade
   (scada `5e23e386`): `Pulled a 96-slice Live forecast starting
   2026-10-07T17:00:00Z`, both files written to the config dir, and the
   derived generator's `Got forecast` from them; a second run with the
   facade URL on a dead port logged `Forecast pull … failed`, no
   coldest-of-month, and the stored pair served. One gap seen: under a
   plain `gws run` the `weather_source` INFO lines do not reach the
   scada's log output (the failure line does, through the scada logger);
   the pull line only showed with an extra handler. Route that logger
   with step 6.
5. ✅ **Ally waits for a forecast.** A contract wakes the ally into
   Initializing with no forecast; the five-minute bail there names what
   is missing. Both tests in `tests/actors/test_startup_contract_load.py`
   green. gwwf publishes `us.me.millinocket.forecast.nws.hourly96`
   hourly (minted 2026-10-07; first emission 15:01Z). Order from here:
   the ops word names the bundle, then step 4 and step 3 together.

6. ☐ **The legacy forecast type goes.** **▶ Do this next:** the
   derived generator and the LTN read `gw.weather.forecast` and the
   bundle record directly, the sim source returns the sema message, the
   `weather.forecast` twin comes out, and the `weather_source` logger
   joins the scada's log output. Boxes get steps 3 and 4 at the next
   deploy; `experiments/put_layout.sh` places the regenerated ops pair.

### Shape

Everything the scada reads off `weather.json` is in `gw.weather.forecast`
or derivable from the bundle record it names. The scada holds two
persisted sema instances, not one: the last forecast message and the
bundle record (`gw.weather.forecast.bundle.gt`, fetched rarely from
`GET /{party}/bundles`), because slice times and units live on the
record, not the message.

| Scada reads | `weather.json` | `gw.weather.forecast` |
| --- | --- | --- |
| hourly times | `time`, unix s | `FirstSliceStart` + the record's `SliceDurationSList` |
| outdoor temp | `oat`, whole °F | `TempValues`, scaled per the record's Unit (`FahrenheitX100`) |
| wind | `ws`, whole mph | `WindSpeedValues`, scaled per Unit (`MilesPerHourX1000`) |
| horizon | 96 h kept, 48 h used | the bundle's `TotalSlices` |
| staleness | `time[-1] >= now + 48 h` | `SourceUpdatedTime`, `MessageCreatedMs`, `Fidelity` |
| fill | coldest-of-month list in code | `Fidelity: SeasonalTemplate` from gwwf |
| location | scada lat/long sent to NWS | `BundleName`; the location is the station's |

**The 96 hours stay.** The persisted copy covers the box losing the
internet, an outage gwwf's Stored rung cannot reach; 96 h keeps 48
real hours through a two-day cut-off, and a day-old forecast beats a
seasonal constant for the required-energy and swt sums. A 96-hour
hourly bundle is its own slug in gwwf; the FLO takes its first 48 h
and never asks for more.

**Fill is a fidelity, not a slug.** gwwf publishes on one bundle and
marks each message Live, Stored or SeasonalTemplate; a consumer never
switches subscription when the source dies. The template is one
record per weather location (a new gwwf word; the scada's twelve
monthly values are the Millinocket row). The scada persists its
station's template beside the forecast and uses it only when cut off
from gwwf past its 96-hour copy.

**Location is the station's, never the house's.** The scada and the
LTN both send house lat/long to api.weather.gov today; that stops.
The NWS gridpoint is the forecast channel's `SourceLocator`. The ops
word names the bundle and nothing else; method and station are read
off the record, never parsed from a name.

**No interpolation at the scada.** gwwf's NWS adapter verifies the
product is contiguous and rejects a short one, so a forecast that
arrives is complete and aligned; interpolated replay exists only for
observations. The scada's `if 'temperature' in period` filter, which
drops a missing hour and shifts every later index, goes with the
fetch.

gwwf dependencies, named in the gwwf issue, not here: the 96-hour
bundle slug; the per-location seasonal template word and the rung
built on it; `BundleName` on `gw.operational.params`.

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
| Every stop reaches `HpDetectedOff` | Within two minutes of the last read above 500 W. The off line is 10 W above the standby measured through early October; a stop that holds `HpDetectedOn` is winter standby above it |
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
tries to break it. Three lists: what we know is still open; what we
think a recent commit fixed, each with the test that pins the fix, for
the reviewer to re-break; and what we know about and have placed, not
to be raised again.

**Open, try to break:**

- **resume-window.** The four seconds before `resume_loaded_contract`.
  The flake in
  `test_a_live_stored_contract_is_taken_up_again_after_a_restart`
  (`tests/actors/test_startup_contract_load.py`) is reproduced: it is
  the weather fetch. The derived generator pulls the forecast from
  api.weather.gov at start; the leaf ally refuses a contract while
  `heating_forecast` is `None` ("Missing forecasts required for
  operation", `leaf_ally/house0/all_tanks.py`, `buffer_only.py`). When
  the fetch takes longer than the four seconds, the resume hands the
  ally the contract, the ally gives up at once, and the scada
  terminates the contract it just resumed: `latest_scada_hb` goes
  `None`, auto_state falls back to LocalControl, the LTN gets a
  TerminatedByScada heartbeat. Slowing `DerivedGenerator.get_weather`
  to 8 s makes it fail every time; isolated runs pass because the fetch
  takes ~0.4 s. Two defects, one test each, test first: the suite talks
  to a live weather API (a sim weather source belongs in the harness),
  and a restart under a live contract ends the contract whenever the
  weather API is slow or down. Still to walk: an offer in the window, a
  contract that expires in it, a store written by another status.

**Patched, confirm:**

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
  the one termination path whoever decides, and no longer prefixes the
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

**We know about this, don't raise it:**

- **watch-defaults.** Closed 2026-10-07 (`6618a82b`) on spruce's power history: the
  defaults stand and the lines are right for this unit
  (`executor/local-control.md` "The heat-pump watch", "Authoring a
  row"). The one residual, winter standby above the off line holding
  `HpDetectedOn`, is now reported by the watch itself: one Warning
  `hp-watch-held-on` per spell after ten minutes between the lines.
  Pinned by
  `test_held_on_between_the_lines_for_the_hold_warns_once_per_spell`
  and `test_a_stop_inside_the_hold_warns_nothing`
  (`tests/actors/test_hp_watch.py`). To re-break: a stop whose wind-down
  sits between the lines longer than ten minutes, which would warn on a
  healthy unit.
- **stale-params-push.** A whole-file params push carrying the source's
  `AcceptsDispatch: true` clears a `ServiceContractBroken` latch. Not
  open in today's code: the only push is `experiments/put_layout.sh`,
  which shows the difference and asks, and `ScadaParams` from the LTN
  carries `Ha1Params` only. It is a constraint on the brokered push,
  recorded in OPS-408; the second-writer fact is
  `executor/cold-house.md` "The refusal".

The warm exit on-peak waiting for a loop pass is the tick problem of
`../spruce-settled/async-local-control.md`, not a review item here.

Code: `actors/local_control_loader.py`, `local_control/standby.py`,
`local_control/nolan/buffer_only_tou.py`, `actors/hp_watch.py`,
`actors/leaf_ally_loader.py`, and in `actors/scada.py`
`resume_loaded_contract`, `enforce_auto_state_consistency`,
`process_ally_gives_up` and `report_operating_status`.
