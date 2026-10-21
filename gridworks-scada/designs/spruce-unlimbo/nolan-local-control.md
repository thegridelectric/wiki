# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-20 · Linear: OPS-392

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
(`ltns-ready.md`, gwwf `executor/delivery.md` "LTN
relay is primary"). Until the LTNs run, the scada keeps a pull path,
but to our own service and through sema. Six steps, each with its
test first:

1. ✅ **Shape check.** Does `gw.weather.forecast` carry what the
   scada reads off `weather.json` today (hourly unix times, °F, mph,
   a 96 h horizon)? Yes; canonized in `executor/weather-forecast.md`.
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

6. ✅ **The legacy forecast type goes.** `WeatherSource.forecast`
   returns the `gw.weather.forecast` message and its bundle record as a
   pair; the derived generator and the LTN hold the pair and derive
   their hourly °F / mph series off it; the `weather.forecast` twin and
   the message to the LTN are gone. The coldest-of-month fill is a
   `gw.weather.forecast` of Fidelity SeasonalTemplate on the stored
   bundle record, so a box with no bundle record stored or reachable
   has no forecast at all (a WARNING names it) where the old code
   filled blind; the record is pulled once and kept, so this is a
   first-boot-without-internet case. The source logs under
   `<base>.weather_source`: pull failures and fills at WARNING, the pull
   line at INFO. Plant time in the weather path comes from
   `services.clock`: the source judges coverage and fills on it, the
   sim source's slices start at the plant's next hour, the consumers
   slice on it; only the pull timeouts are wall time.
   `tests/test_misc/test_weather_source.py` pins each rung, the clock
   and the logger. Boxes get steps 3, 4 and 6 at the next deploy;
   `experiments/put_layout.sh` places the regenerated ops pair.

7. ✅ **gwwf's seasonal template.** The scada's hand-kept list is a
   gwwf record and gwwf builds the rung it declares, so a Fidelity
   SeasonalTemplate message is gwwf's own and the scada's fill reads the
   record. Months are the grid; the create command took a new version.
   Built, each with its test first:
   1. ✅ **The word** (sema `6cb1aee`). `gw.weather.seasonal.template.gt` 000, staging:
      LocationAlias, TempByMonth (twelve, January first, °F x100),
      Start, Id; axiom TwelveMonths. No wind and no unit fields: gw1.unit
      holds one temperature and one wind unit, so a unit field could take
      one value, and a design-cold template carries no wind. The x1000 on
      wind stays where it is: NWS serves whole knots as km/h floats, so a
      scaled integer loses nothing; gwwf reading the rounded text layer
      instead of the raw gridpoint is a separate fetch gap, not this
      spoke's.
   2. ✅ **`gw.weather.create.cmd` 001** (staging): Record gains the
      template; 000 stays published. Sema suite green (812). Same commit.
   3. ✅ **gwwf builds the rung and serves the record** (`f4484ed` on
      `jm/seasonal-template`): `seasonal_templates` table and migration,
      insert-only create, broadcast on the location alias,
      `/seasonal-templates` on the facade, the scheduler's third rung
      (each slice at its UTC month's value, no wind, the downgrade
      glitch; no template still glitches and skips), the actor taking
      the location's latest Start at boot. The regen script passes
      `--allow-staged`; the snapshot is latest-only, so the vendored
      create command is 001 and 000 leaves the snapshot. `ci.sh` green
      (43 passed, docker up).
   4. ✅ **The scada reads the template** (`109d4404` on
      `jm/spruce-unlimbo`): the
      `WeatherSeasonalTemplateGt` twin (`sema validate` OK), the list
      and its note gone. The bundle record and the template are
      provisioning: boot reads them from the config dir, pulls whichever
      is missing, and raises `WeatherProvisioningError` without both, so
      an install without the service fails at its first boot; with the
      service reachable, the first boot pulls and keeps them. The test
      conftest seeds both records into every per-test config dir beside
      the ops params and the deed. Weather and named-type tests green;
      full suite green (1559).

   gwwf is deployed on the forecast box with the migration applied and
   the Millinocket template minted (2026-10-09; the facade serves it
   under `/hw1-isone-weather/seasonal-templates`). The mint needed its
   own principal under the FIS gate: `gwwf create` connects as the
   `hw1.weatherminter` Service on a second cert in the weather certs
   dir (gwwf `0066e01`). Witnessed on spruce 2026-10-09 (scada
   `97ea5806`, `experiments/2026-10-09-nolan-local-control-windows/`): first
   boot pulled the bundle record, the template and a Live forecast
   from the facade and kept them as sema files in the config dir.

   **▶ Do this next.** Read the spruce window's record
   (`experiments/2026-10-09-nolan-local-control-windows/` "Found") against the
   table in "What to check in the field" and mark each row witnessed
   or still open; the call, the band and the blind-band rows need a
   longer window or an off-peak one. Then the maple window (both pis).
   The cert window (`--cert`, the upstream link on spruce's own cert to
   the prod broker; harness and box are ready) waits until
   `layout.lite` 013 is published and `finalize-layout-lite-13.md` is
   done: a window on the prod broker announces its layout to the fleet.

### Shape

Answered and canonized: how the scada reads the forecast pair, why the
96 hours stay, fill as a fidelity, and the station as the location are
`executor/weather-forecast.md`. What remains here is the gwwf side that
spoke step 7 builds.

## Proof is in the pudding


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
| A cert window is admitted by FIS | The upstream link connects to hw1-1 on the box's cert with no password; FIS `auth_events` shows one allow for principal `9024e45e…` on the window's instance id, a lease created on it, and the deployed scada's lease superseded; the scada log shows the upstream link active and `gw.scada.commit` sent |
| First boot provisions weather from the facade | `Pulled a 96-slice Live forecast` in the log, the bundle record and the seasonal template written to `scada-experiment/`, no `WeatherProvisioningError` |
| A Nolan scada boots with the call open | `gw1.nolan.lc.buffer.only.state` goes `Initializing` then `HpCallOff`; zones on their thermostats, charge valve closed, store pump off |
| The call follows the schedule and the band | `HpCallOn` only off-peak with the band wanting charge; `HpCallOff` at buffer-depth3 ≥ `BufferFullF`, and 120 s before each on-peak window |
| The pump follows the heat pump, not the call | `spruce.hack.hp.state` goes `HpDetectedOn` above 500 W and `HpDetectedOff` below 80 W; secondary pump and iso valve move with it, and run in `Unknown` |
| Every stop reaches `HpDetectedOff` | Within two minutes of the last read above 500 W. The off line is 10 W above the standby measured through early October; a stop that holds `HpDetectedOn` is winter standby above it |
| A blind band is a state | Either buffer channel stale 5 minutes: `gw2.lc.top.state` `ScadaBlind`, commands from `scada-blind`, call on the schedule alone; back to `Normal` through a boot; a `HouseCold` while blind goes to the cold state |
| Standby reads from the tree | A standby scada's command tree hangs under `auto.lc.standby` and its commands come from `standby`; an admin session reports `Dormant`, its release reports `Standby`, and the posture is restored |
| The operating status is quiet | One `gw.house.operating.status` after startup, then one per changed field; an admin session moves `TopState` alone |
| A refusing scada ends a stored contract | Restarted refusing dispatch with a live contract in the store: one `TerminatedByScada` heartbeat to the LTN carrying the reason, the leaf ally never in charge |
| A cold Nolan house needs a person and runs the heat pump | `critical-zone-cold` glitch, then `gw2.lc.top.state` `ColdOverride` in the same minute, call closed on-peak, commands from `cold-override`; back to `Normal` through a boot once warm and off-peak |
| An offer is answered only after the announcement | A scada booted with its first fetch held slow sends `gw.scada.commit` and its first `gw.house.operating.status` only once the first forecast is in; an offer sent before that is not taken, and the first taken offer follows the ally's first judgment with a forecast |
| A refusal reaches the LTN with its reason | For each refusal reason the scada can derive (no deed, operator hold, service contract broken, blind, in admin): one `slow.contract.rejection` at the LTN naming it, nothing else moves, the leaf ally stays dormant |
| A contract ends by each termination case | A contract taken and ended by its duration, by the LTN, by the scada refusing mid-contract, and by an admin session (`InAdmin`): one terminating heartbeat to the LTN with the cause, the ally dormant after it, the next offer taken afterwards |
| The Hubitat reports both thermostats | Beech's two Honeywell zones (`down`, `up`) have fresh setpoint and temperature readings in the window's capture; a zone with neither is the Hubitat gap round four saw |
| Nothing unexpected in the data or the log | After each beech window, the capture and the scada log are read through for what no row above names: a reading that never arrives, a state that flaps, a glitch nobody expected, a reading dropped at a boundary |
| A boot into a cold house pages nothing while it warms | A scada started with a `FromThermostat` critical zone under its setpoint logs `<zone> warming up: N minutes of allowance left` each minute and raises no `critical-zone-cold` until the allowance is out; the deficit over 4 F an hour matches N |
| The elements never close | No `CloseRelay` to `buffer-top-elt-relay` / `buffer-bottom-elt-relay` in any window; `OpenRelay` to both at every boot. Spruce runs `UsesBackupWhenCold` false this winter: the radiant floor keeps the house from getting too cold, and with it false no path closes an element relay |

Every box carries an `operational-params.json` older than the ops word
(`OilBoilerBackup` for `UsesBackupWhenCold`); a window on this branch
puts the regenerated pair first (`experiments/put_layout.sh`).

Spruce's window runs `jm/spruce-unlimbo` against the `jm/spruce` layout
and displaces the winter hack, so an experiment window there is short
(`experiments/field-window-recipe.md`).

On the laptop sim (2026-10-14), `experiments/offer_contract.py` offers a
contract as the LTN at any minute, so a refusal is read within a minute
instead of at the top of the hour. Seen there: a restart under a held
contract with the hold set ends it with `TerminatedByScada` /
`OperatorHold`; an offer is refused with `OperatorHold`,
`ServiceContractBroken` (latch set), `NoTaDeed` (deed `UnValidated`) and
`ScadaBlind` (`buffer-depth1` disabled in the layout), each reaching
the LTN as a `slow.contract.rejection` naming the reason. Not yet seen:
`InAdmin` (an admin session is interactive), a termination mid-contract.

Beech ran its first window out of Standby on 2026-10-14 (19:58 to
20:20, dev broker, laptop LTN): `BufferOnly` local control at `HpOff`
on a full buffer, never `Standby`; an `offer_contract.py beech` offer
refused with `OperatorHold` and the rejection at the LTN; both Honeywell
thermostats reporting on their 300 s period; every enabled channel in
the window's reports. Found: `dist-depth3` reads the 3.3 V pico rail
(open thermistor, hardware); one `local_mqtt` response timeout at boot;
`usable-energy` has no value under `OperatorHold` because
`derived_generator.py` guards the estimate on `DispatchHold`, which is
not the rule we want.

Beech's second window (2026-10-16, hold off, `--ltn`) did not open:
the scada pins `gw.weather.forecast.bundle.gt` 001 and the deployed
forecaster still serves 000, so `provision_bundle` fails the boot on
both pis. The window waits on the forecaster deploy; the scada is the
side that has moved. Also found: the tlayouts snapshot lagged the
scada's channel-word pins (003/002 against 004/003), fixed by a regen.

Oak's first two windows (2026-10-20, `b3b71004`, both pis, observe-only;
`experiments/beta-field-windows/runs/2026-10-20-1831-oak-second-window/`)
passed: sane on-peak posture, no errors, all four Hubitat zones
reporting, the deed and tank board-variant glitches cleared by the oak
gen fix. **Found and fixed in tlayouts:** the branch did not hear
oak's three flow picos (`pico_436531`, `pico_836d31`, `pico_974532`:
missing from the first poll, zombied after five 5 V cycles) while
`main` journals all six flow channels, because the oak gen left `kind`
off its FlowSpecs and the default is hall; the picos are reed, so the
actor registered only the hall routes and the reed posts got a silent
404. The gen now says `kind="reed"`. **Open from them:** a wrong-kind
pico posting to the scada was invisible; the app now registers a
catch-all POST route after every actor's routes, so a post nothing
serves (a pico of the wrong kind, a pico posting as a node the layout
lacks) is an `unserved-post` Warning glitch naming the path and the
posted identity, since what posts is known only after the 5 V bus
cycles and the params arrive (to confirm at oak's next window);
hp-odu-pwr near 204 W with the heat pump commanded off against the LG's
26 W standby, the hp watch silent ("The heat-pump watch"); the fake
sieg loop leaves relay 15 reading 1; `store-cold-pipe` in the disabled
roster; `house_window.sh`'s end check knows no oak channel names.

**Fir's heat pump is a Samsung, not an LG (2026-10-21).** `fir_gen.py`
declares the LG pair that oak and beech have; fir runs a Samsung
Hydrokit: outdoor unit AM048TXMDCH (208-230 V, 54,000 Btu/h heat,
R-410A, nameplate photographed) and indoor unit AM048CNBFCB (Drive
folder "Samsung HydroKit Assembly"). `gw1.device.type` has no value for
either, so the fix is a sema enum addition, a fir gen correction and a
regen, before fir's first window. The LG signatures draw on beech and
oak only.

The energy estimate no longer depends on the dispatch hold: the two
`DispatchHold` clauses are out of the guard, the test is
`test_usable_energy_does_not_depend_on_the_dispatch_hold`, and
`executor/dispatch-gate.md` "The answer" states the rule.

**Do this next**, on beech with the hold off for the window: the remaining
refusals (`ServiceContractBroken`, `NoTaDeed`, `ScadaBlind`), the
`InAdmin` termination and refusal through `gwa watch`, and a
termination mid-contract.

## The secondary loop belongs under hp-boss (field finding 2026-10-18)

**What happened.** In the spruce window of 2026-10-18
(`experiments/2026-10-18-spruce-upstairs-fancoil-window/`, round 2) the
heat pump lost its call twice at the handover (the hack's exit opens it,
Nolan's boot posture opens it again) and local control re-closed it a
minute later. hp-watch then read the interrupted unit's ramp-down as
HpDetectedOff, and local control did what the posture says for an off
heat pump: secondary pump off, iso valve closed. Fifty seconds later the
operator took admin, local control went dormant, and when the unit
restarted on the re-closed call nothing put the pump and valve back. It
ran six minutes into a loop with no sink, went thermo-off at 145 F
leaving water, and sat for nineteen minutes until the operator restored
the loop by hand. Under local control alone the posture would have
healed itself at the restart; the admin takeover froze it.

**The rule this breaks.** The secondary loop must be consistent with the
heat pump in every top state, admin included. Today it is consistent
only while local control is awake, because the pump and valves float
with the tree and local control is the only thing that drives them.

**The change.** House0 already has the pattern: sieg-loop is a fixed
sub-boss under hp-boss owning its relays, keeping them consistent with
the heat pump whoever is on top, with the operational params choosing
its strategy. Nolan gets the counterpart, a secondary-loop boss under
hp-boss owning the secondary pump relay, the iso valve relay and the
charge valve relay, with one mode, `Buffer` or `Store`, that local
control sets and that defaults to `Buffer`:

- The pump follows the heat pump: on when the call is closed or the unit
  is sensed on, off when the call is open and the unit is sensed off,
  after a settle. The state "call closed, pump off" becomes unreachable,
  and hp-watch's weak spots (the shutdown ramp, defrost) matter less
  because the call is part of the decision.
- The valves follow the mode, with the invariant that at least one
  destination is open whenever the pump runs: `Buffer` is iso open and
  charge closed; `Store` is charge open and iso closed. When the pump
  stops the iso closes against the convection loop off the buffer top.
- Local control decides the call and the mode; it no longer commands the
  pump or the valves. Admin commands the heat pump through hp-boss and
  the destination through the loop boss, and reaches none of the three
  relays directly (an interior node keeps its subtree). The one use this
  removes, the pump alone with the heat pump off as in the pump-speed
  sweep, returns as a loop-boss override command if a window needs it.
- Only the first form, pump and iso as direct children of hp-boss, was
  considered and rejected: the iso valve follows the destination, not
  the pump, so a store charge would run the pump against a closed iso
  with no one holding the charge valve open.

**What it costs.** A sema change in one wave: the Nolan layout word's
handle axiom gains `auto.hp-boss.<loop-boss>` and its three relay
handles, a mode enum for the loop boss, the tlayouts Nolan gen, the
gwsproto twin, both `set_command_tree` rewrites, and the loop boss as a
machine the scada reports. Build `Buffer` first; `Store` is a declared
value until the store is in use (`SeasonalStorageMode` is `BufferOnly`
at spruce and the hack holds the charge valve closed). The test is a
window on spruce: take admin while the heat pump is running, read the
pump and iso unchanged; open the call from the panel, read the pump stop
and the iso close after the settle.

## A zone is cold only after its warm-up allowance (field finding 2026-10-18)

**What happened.** Oak started heating on 2026-10-17 with the upstairs
zone 9 F under its 64 F setpoint (journal pull, `zone4-upstairs-temp`):
56 F at 10:02, 59 F at 11:02, 64 F at 12:02, then held. A called zone
warms at about 4 F an hour and takes two hours to close a 9 F gap. The
cold watch latches after five minutes of cold passes, so a house that
starts heating from a standby or a setpoint raise pages while it is
doing exactly what it should.

**The rule.** A warm-up starts at a setpoint raise, at a boot, and at
the end of a backup or cold-override spell. From that moment each
critical zone has an allowance of its deficit at the first pass divided
by `WARM_UP_F_PER_H` (4.0, a named constant beside the other four at the
top of `cold.py`; code, not a parameter, until a house shows it needs
its own). Until the allowance runs out the zone is not cold, whatever
it reads. After it, the judgment and the five-minute latch run as
today, so a heat source failing in steady state still pages after five
minutes. An 8 F raise gets two hours, a 2 F raise gets thirty minutes,
a thermostat lowered counts at once.

**Standby exit is a boot.** Leaving standby is new ops params and a
restart, so the watch cannot see it as an event; every boot starts an
allowance for every critical zone from its deficit at first reading.
That covers standby exit and the ordinary restart into a cold house,
which are the same situation to the watch. A restart during a genuine
cold spell delays the page by the allowance, thirty minutes to an hour
at 2 to 4 F under, and that is accepted.

**What it retires.** The `executor/cold-house.md` "Open" item agreed
2026-10-14 (judge a raise against the setpoint two hours earlier) goes:
the allowance subsumes it and is sharper for small raises. The "cold
with no call" item stays open; a disabled thermostat (oak's living room
that day) is not reached by this rule.

**Agreed 2026-10-19.** The deficit is capped at 10 F, so the longest
allowance is two and a half hours. The allowance applies to
`FromThermostat` zones only. A `Learned` zone keeps today's rule: cold
when it calls continuously for `COLD_LATCH_S` at `COLD_DELTA_F` or more
under its recorded setpoint, which `cold.py` and
`tests/actors/test_cold_handling.py` already cover. Spruce is the only
house with `Learned` zones; oak's are `FromThermostat`, so oak's 10-17
warm-up is the case this rule covers. Standby exit is left for later.

**Built 2026-10-20.** `cold-house.md` "The judgment" states the
allowance, the cap, the `FromThermostat` scope and the three starts;
`cold.py` judges it (`warming_up`, `start_warm_up`), and the watch starts
a warm-up when the top state leaves `InBackup` or `ColdOverride`. Pinned
by the warm-up tests in `tests/actors/test_cold_handling.py` (a boot into
a cold house, the first reading after a boot, the cap, a raise, a
thermostat lowered, each cold-state exit). Not yet witnessed on a box.

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

- **spruce-window-2026-10-09.** Five items from the first window
  (`experiments/2026-10-09-nolan-local-control-windows/` "Found"): a Critical
  `i2c-expander-reset` glitch on 0x21 at boot+1 min (OPS-452
  signature); the secondary pump commanded on for 150 ms at boot while
  the hp watch is Unknown; `required-energy` and the zone setpoint
  channels never valued; heat-call and energy channels flapping stale
  two minutes after a 300 s publish; the cold watch's setpoint and
  temperature misses for three zones. From run 2: expander 0x21 reset
  three times across the two windows, each near a relay transition on
  0x21, a Critical glitch each time; and the beech board-variant
  warnings, closed in tlayouts.

**Patched, confirm:**

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
