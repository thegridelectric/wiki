# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-04 · Linear: OPS-392

> What this is: the local control that runs a Nolan house through a
> heating season: which machine runs, standby, the heating and cooling
> machines, backup, and the dispatch refusal, with the open build steps
> at the end. It sits on the completed node-actor partition
> (`executor/control-hierarchy.md` "The node-actor partition"): the
> actor tiers, the command-tree mechanics, hp-boss and the admin command
> surface.

## Where it sits

- Thread D of the spruce-unlimbo hub (OPS-219 lives there): written
  against the OPS-394 capability surface from day one; the zone slice of
  that surface is settled in `../spruce-settled/thermostat-and-zone-control.md`.
- Partition tier C+D: Nolan plant judgment lives in
  `actors/hydronic/nolan.py`, the machines in `actors/local_control/nolan/`
  (`buffer_only_tou.py`, `buffer_only_cooling_tou.py`, mirroring `house0/`), loaded by `local_control_loader.py` from the ops word
  (`control-strategy-selection.md`: ops chooses the machine, the
  machine owns its state).
- Names: `backup` and `scada-blind` are core names
  (`gwsproto/names/core/node_names.py`), available to every layout; both
  layout words fix their handles under `auto.lc` (axiom
  `CommandNodeHandles`). A Nolan layout carries both. Its `backup` node
  drives the buffer's electric elements, which stay in the layout for
  three uses: a winter local control that adds them, admin when someone
  is cold, and a Nolan FLO telling the scada to use its resistive
  elements.

## Selection: which machine runs

No authored field names the machine. The loader derives it from three
authored facts, and its `else: raise` is the consistency check:

| `Standby` | Family | `SeasonalStorageMode` | `ServiceMode` | Local control machine |
| --- | --- | --- | --- | --- |
| true | any | any | any | standby, shared (`local_control/standby.py`) |
| false | House0 | AllTanks | Heating | `AllTanksTou` |
| false | House0 | BufferOnly | Heating | `BufferOnlyTou` |
| false | Nolan | BufferOnly | Heating | `NolanBufferOnlyTou` |
| false | Nolan | BufferOnly | Cooling | `NolanBufferOnlyCoolingTou` |

`gw1.actuation.authority` retires and no strategy enum replaces it: an
authored machine name restates the three facts above and can disagree
with each of them. `MonitorOnly`'s job, a scada that touches nothing,
is `Standby` with posture `MonitorOnly`. The loader reads the fields once
at construction; a change is a restart (`control-strategy-selection.md`
"Live ops updates").

The other readers of the retired authority:

- **Leaf ally.** The loader keeps picking the family's ally by storage
  mode; there is no standby ally. The refusal is one gate in the
  `LeafAlly` wrapper reading `AcceptsDispatch`, whatever the reason
  (today duplicated in `leaf_ally/house0/all_tanks.py:199` and
  `buffer_only.py:173`).
- **LTN.** Bids and FLOs run only when `AcceptsDispatch` and
  `ServiceMode` is `Heating`, read from `gw.house.operating.status`
  (today off `layout.lite`, `ltn/ltn.py:876`, `:968`, which no longer
  carries them; `SeasonalStorageMode` moves with them). Its pre-status
  default (`ltn.py:526`, `Active` today) flips to refusing.
- **Derived generator.** The usable-energy gate
  (`derived_generator.py:843`) reads the same two.
- **Sieg strategy.** `Standby` forces `HoldFullSend`
  (`sieg_loop/strategy.py:31`), unchanged.
- **House0 `tou_base`.** The `Monitor` top state and its two events
  lose their sender (`tou_base.py:83`, `:506`).

`gw1.seasonal.storage.mode` (`AllTanks` / `BufferOnly`, published)
keeps its name. It is already the shared choice both families author
and every actor reads: the two loaders, the derived generator, and the
LTN off `layout.lite`, which is where the FLO choice belongs (today
made by hand). The sieg strategy is the same kind of fact for the loop.

`gw1.system.mode` is the predecessor of the two ops fields: the
registry marks it "conflated actuation authority with the thermal
service" and `replaced_by` `gw1.actuation.authority` + `gw1.service.mode`.
It is still published because older words depend on it and the web
backend reads it; the scada does not. `ServiceMode` is the one of the two
the scada keeps.

## Standby

One machine serves every family, `local_control/standby.py` on
`HydronicNode`. Its enum
`gw1.local.control.standby.top.state` stays (`EverythingOff` ⇄
`Dormant`), reported as a `SingleMachineState` at start and on each
transition.

**At `ActuatorsReady` and again on every `WakeUp`,** having claimed `n`:

1. De-energize every `Relay` directly under `n` that
   `EnergizedStandbyRelays` does not list.
2. Energize the listed ones.
3. Send hp-boss `TurnOff` (`HydronicNode.turn_off_hp`, the command
   every family's local control uses).

The 0-10V outputs stay at `ZeroTenPowerOnList` and are never written.
The command tree is not flattened; each command node keeps its
power-less posture: five-v-boss runs, the sieg loop holds
`HoldFullSend`, hp-boss sits at `HpOff`. Step 3 exists because hp-boss
has no dormant or wake handling and an admin session can leave it
`HpOn`; `NoHeatingOrCooling` is not true until the call is open. The
overlap check is one line beside the assembly's coverage and poll-floor
checks: a listed name is a `Relay` ShNode whose boot handle sits
directly under `n`.

**The House0 default list** (authored by `tlayouts`) is
`hp-failsafe-relay` and `aquastat-ctrl-relay` (Krida 5 and 8, both
`SwitchToScada` when energized). The call relay (Krida 6,
`hp-scada-ops-relay`) is hp-boss's and is `NormallyClosed` on House0,
so step 3 energizes it: three relays energized, the heat pump and the
boiler both held off. Relay 5 stays under `n` rather than moving to
hp-boss: George plans to remove it, and its state also decides whether
the boiler runs. **Nolan's list is empty**: its call relay is
`NormallyOpen`, so off is de-energized. Same posture, different lists,
which is what `gw.standby.posture` names.

**The energized list never reaches under a command node.** A listed
name must be a `Relay` whose boot handle is `auto.<Name>`. Each layout
word's `CommandNodeHandles` axiom fixes every relay's boot handle, so
the check needs only the layout. A relay owned by a command node fails
the params load and the scada does not start: `hp-scada-ops-relay`
under hp-boss, `hp-loop-on-off-relay` and `hp-loop-keep-send-relay`
under the sieg loop, `vdc-relay` under the pico cycler
(`check_energized_standby_relays`, `sema_to_dc.py:115`). Standby
reaches a command node's relay only through that node's command, as
step 3 reaches the call relay through hp-boss.

The "hold everything off" behavior at spruce is a running machine (the
winter hack, `NolanBufferOnlyTou` with the call held open), not
standby. Standby refuses dispatch by axiom.

## The heating machine: `NolanBufferOnlyTou`

The winter hack (`starter-scripts/spruce_winter_hack.py`) as scada
behavior, with the same three rules and as little code as they allow.
Every transition reports a `SingleMachineState`, so the machine's state
rides the snapshot and the journal; commands leave only at transitions.

**States** (a new Nolan enum, word gate): `Initializing`, `HpCallOn`,
`HpCallOff`, `Dormant`. The state names the one plant decision the
machine makes, the heat-pump call. Later pump-speed work (primary and
secondary speeds shaping the water temperature into the buffer and
store) adds setpoints the loop drives and 0-10V commands; it adds no
states.

**Transitions.**

- `Initializing → HpCallOff` once the actuators are ready and the boot
  posture is commanded (below). Boot never opens with a call.
- `HpCallOff → HpCallOn` when off-peak (ops `Tariff`) AND the band says
  wants charge; `HpCallOn → HpCallOff` when on-peak OR the band says
  full. Checked every 60 s; the band latch is state of the machine,
  not of the enum.
- `* → Dormant` on `TopGoDormant`; `Dormant → Initializing` on wake,
  so a released tree is re-booted rather than resumed.

### The buffer band and ScadaBlind

- **The HP call is gated by the buffer band, as on the box today.**
  Off-peak AND buffer not full: the call closes; on-peak, or buffer
  full, it opens. The band is a latch on two channels: buffer-depth3
  (bottom) at or above the full threshold sets it, buffer-depth1 (top)
  below the charge threshold clears it, and it holds in between. Both
  channels are required; either one stale blinds the band.
- **ScadaBlind means the band is blind.** `MissingData` fires when
  either buffer channel is stale for more than 5 minutes; the
  `scada-blind` node then drives the HP call on the schedule alone
  (closed off-peak, open on-peak) and the heat pump's own limits stop
  it when the buffer is hot. The pump and iso valve keep following
  heat-pump power. `DataAvailable` returns to Normal when both channels
  are fresh again. This replaces the winter hack's "hold the latch
  while stale" with a state the machine reports.
- **Tunables live on words.** The two band thresholds
  (`BufferFullF`, `BufferChargeF`) go on `gw.nolan.family.params`; the
  on-peak windows come from the ops `Tariff`, never a second copy in
  the actor.

**Top machine.** `Normal` runs this machine; `ScadaBlind` (either buffer
channel stale > 5 min) drives the call on the schedule alone from the
`scada-blind` node and keeps the postures; `Monitor` commands nothing;
`Dormant` means admin holds the tree. No `UsingBackup` transition while
spruce's ops availability is false.

### Postures

The loop enforces these every check; they are not states.

- Zones: every failsafe relay de-energized (thermostat has the zone),
  every scada zone relay open. Commanded at boot, re-asserted each
  check.
- Secondary pump and iso valve follow hp-boss's threshold machine
  (below): on in `HpOn` and in `Unknown` (no fresh power means pump
  on), off in `HpOff`, the valve moving in the same step as the pump. This
  follows the unit whatever closed the call, so it is not a function
  of `HpCallOn`.
- Charge valve closed, store pump off.

**Boot posture** (`Initializing`): the machine commands every actuator
it is the direct boss of, once they are ready: the postures above plus
the HP call open. Nothing is "left at its adopted state".


### The heat-pump threshold machine

A small, throwaway machine in hp-boss, on Nolan layouts only:
`spruce.hack.hp.state`, with values `Unknown`, `HpOn` and `HpOff`.
It reads `hp-odu-pwr` through the power meter actor's reading path (not
the snapshot, not a direct Modbus poll). It goes to `HpOn` on the first
read above the on line and to `HpOff` on the first read below the off
line, and holds in between; that latch is memory, which is why this is
a machine and not a pair of derived channels (`report-all-machine-states.md`
"Channels or machine states"). It boots in `Unknown` and goes back to
`Unknown` whenever power goes stale; the pump runs there, and the first
fresh read moves the machine to `HpOn` or `HpOff`. This matches the
starter script, which treats the first seconds after boot as unknown
power. Every transition reports a
`SingleMachineState`.

It replicates the control loop that grew up in spruce's starter scripts
(`starter-scripts/spruce_winter_hack.py`), and it stands in for the
heat-pump state machine (`../spruce-settled/hp-unit-sensor.md`), which
retires it. Running is sensed, not assumed: the unit can run its own
schedule and ignore the call, and a sensed start says more than an
assumed one. It is also a first, rough step in driving the secondary
pump to keep the buffer stratified. The word's `extended_description`
carries the reasons and the Samsung evidence for where the on line
sits.

**The lines are hard-coded by heat-pump device type**, not authored on
any word: `HP_TRAITS` in `actors/hp_boss/sensing.py`, keyed by the
gwsproto `DeviceType` / `SimDeviceType` enums, one `HpTraits` row per
supported heat pump (on line, off line, call-open lead). Spruce's
Samsung AE055FCYDCG is 500 W on, 80 W off, 120 s lead. A new heat pump
is measured and added as a row. A Nolan layout whose heat pump has no
row fails loudly at boot (step 6a).

## The cooling machine: `NolanBufferOnlyCoolingTou`

**`NolanBufferOnlyCoolingTou`** is today's branch loop given a name, and
BufferOnly is the one storage mode it serves (a Nolan layout authoring
AllTanks has no machine in either service mode): the
non-cooling circuits held (failsafe energized, scada relay open, so
heat calls are ignored and only the fan coils can call), iso valve
open, secondary pump on, the cool call closed off-peak and open
on-peak. Two facts the module states at its top: the scada cannot put
the heat pump into cooling, a person changes the unit's mode (today
that may mean moving a RIB), and the call contact is inert while FSV
2091 is 0. Which circuits cool is already a layout fact:
`gw1.zone.call.circuit` carries `EmitterType` (`gw.zone.emitter.type`:
Other / RadiantSlab / FanCoil) and `CanCool`, with axiom 1
"OnlyFanCoilsCool". The machine holds every circuit whose `CanCool` is
false; `HELD_CIRCUIT_POSITIONS` goes. No code reads `CanCool` today.

**Review `nolan/buffer_only_cooling_tou.py` before the 2027 cooling season.** The loop was
written without a state machine (only the top machine is one) and
carries its schedule and plant knowledge as constants rather than
operational params: `ONPEAK_WINDOWS` (07:00–12:00 and 16:00–20:00,
weekends off-peak, no `Tariff` read), `HELD_CIRCUIT_POSITIONS`
(1, 2, 4), `STARTUP_DELAY_S` 30, `SEQUENCE_STEP_S` 15, `TOU_CHECK_S` 60
(`buffer_only_cooling_tou.py:71-89`). A note at the top of the module says so; the review
itself, schedule from the ops `Tariff`, circuits from `CanCool`, the
loop as a machine with reported states, is summer work.

## The top machine and backup

The shared enum `gw1.lc.top.state` stays the vocabulary; what each state
means at a house comes from the layout, not from the enum. Nodes exist
only for the states that command: `n`, `backup`, `scada-blind`
(`gwsproto/names/core/node_names.py:19-22`); Monitor commands nothing
and Dormant means the tree is someone else's.

**Backup is a layout structure plus an ops availability, not a state
name.** `UsingNonElectricBackup` bakes one house's answer (an oil boiler
behind the aquastat switch) into the shared enum, and `OilBoilerBackup`
on the ops word is a plant fact in the wrong word: every House0 gen sets
it true, including a house whose boiler is missing a part and whose
installed buffer and store elements are not wired. The shape to
converge on:

- The layout word carries a `Backup` chunk: a kind and the actuator
  nodes it drives (oil boiler via the aquastat switch; electric elements
  with their relay nodes; none). Installed-but-unwired elements are not
  in the layout, since the scada has no node to command.
- The ops word says whether the wired backup may be used now (a
  `BackupAvailable` flag or per-backup enable). An out-of-service boiler
  is an ops fact; the layout does not change to record it.
- `SystemCold` transitions to `UsingBackup` (the renamed state) only when
  the layout has a backup and ops says it is available. Otherwise a cold
  house is a Critical glitch: the house needs a person, not a state. The
  cold judgment at a house with derived setpoints is
  `cold-house-derived-setpoint.md` (2 °F or more under setpoint, and
  the constant-call rule against the last recorded setpoint).
- `backup` is a required node only where the layout has a backup kind.
- Spruce: kind = electric elements, and this winter its ops
  availability is false: the radiant floor keeps the house from getting
  too cold, so the machine never enters `UsingBackup` at spruce. A
  cold house raises the "critical zone cold" glitch
  (`cold-house-derived-setpoint.md` "What a cold house says") at any
  time of day, on-peak included, and the machine stays in Normal. The ops flag is the whole mechanism; no
  Nolan-specific code path says "do not switch".
- When spruce's availability is turned on: `UsingBackup` energizes the
  buffer elements from the `backup` node during off-peak only; the HP
  call, the secondary pump and the iso valve keep their Normal rules.
  The elements' own safety cutout turns them off for now; a soft cutout
  underneath it (the scada stops the elements before the safety limit)
  is a to-do of this spoke, not a launch item.
- Elm has an oil boiler with electric elements installed in its buffer
  and one store tank but not wired; the boiler was out of service (a
  missing part) through 2026-09 and is working again, so elm's kind is
  oil boiler and its ops availability true. The unwired elements stay
  out of its layout until wired.

Open: the state rename is a new version of the published enum plus its
gwsproto mirror (word gate); the `Backup` chunk lands on both layout
words; House0's on-peak ScadaBlind branch reads the layout kind in
place of `OilBoilerBackup`.

## The dispatch refusal and the operating status

The scada says whether it will take a dispatch contract, and why. It
is the seed of the actuation-authority concept that TaTradingRights
and the homeowner–aggregator contract flesh out later; nothing more is
claimed for it now.

- `AcceptsDispatch: boolean` on `gw.operational.params`: the one test
  every gate reads.
- `DispatchRefusalReason`, `gw.dispatch.refusal.reason`: `Standby`,
  `NoAggregator` (collecting data, no aggregator chosen),
  `ServiceContractBroken` (the house went cold; held until a person
  clears it). Present iff `AcceptsDispatch` is false.

The scada writes its own params file: OPS-408 makes the LTN the way
new params reach a scada, and a scada that latches
`ServiceContractBroken` writes the same file. The cold detection and
the latch are a later build step; the reason value exists now so the
word's shape is final. A note for OPS-408: a whole-file push carrying a
stale `AcceptsDispatch: true` for an unrelated change clears the
latch; the pushed file has to start from the scada's last reported
status.

**Axioms on `gw.operational.params`** (numbers continue from 2):

3. If `Standby` is true, `AcceptsDispatch` is false and
   `DispatchRefusalReason` is `Standby`.
4. `DispatchRefusalReason` is present iff `AcceptsDispatch` is false.
5. The posture fixes the list per family: `MonitorOnly` means an empty
   list; with `FamilyParams` `gw.house0.family.params` and posture
   `NoHeatingOrCooling`, the list is exactly `hp-failsafe-relay` and
   `aquastat-ctrl-relay`; with `gw.nolan.family.params` and that
   posture, the list is empty. New postures and families extend the
   table.

**The operating-status record** (agreed with George 2026-09-29; moved
here from the launch odds and ends). The team cannot read how a house
is operating from one place: machine states ride the snapshot, the
posture rides `layout.lite`, the contract status lives in the LTN. The
scada emits `gw.house.operating.status` once after its startup
announcements and then only when a field changes; a healthy hour
produces none. It carries the slow facts of the LTN–scada agreement so
"not dispatching" reads as a reason: no standing (`ValidationState`,
from the deed), an admin session (`TopState`), a refusing posture
(`AcceptsDispatch` with its reason, `Standby`, `ServiceMode`), or no
offer this hour. `LtnDispatching` is true from the first heartbeat that
goes Active and false only after no contract has been active for a
settling window past a completion, so back-to-back hourly contracts
read as one long true. Not carried: the raw contract status (cycles
four times an hour) and the live machine's state (reported per
transition, `report-all-machine-states.md`). It is
its own reported record, not a snapshot field and not part of the
link state. Publishing it promotes its closure with it.
Six of its fields are authored in `gw.operational.params` and copied
from the scada's decoded params, never a second source; the other five
are runtime facts. It is a projection, not a subset or a `$ref` of the
params word. It is the LTN's one source for the posture facts:
`layout.lite` 013 no longer carries `AcceptsDispatch`, `ServiceMode` or
`SeasonalStorageMode`, so a live params update cannot leave the boot
projection and the status record disagreeing.

## Open work, in build order

Each step goes in with its tests first.

6a. **The heat-pump threshold machine** ("The heat-pump threshold
   machine" above), in this order:
   1. **The word.** `spruce.hack.hp.state` 000, a new versioned enum,
      staging, owner `gridworks-energy`: `Unknown`, `HpOn`, `HpOff`,
      default `Unknown` (the safe value: pump on). The
      `extended_description` carries the stand-in role, the reasons for
      sensing, and the Samsung evidence. gwsproto twin.
   2. **The traits table in sema types.** `HP_TRAITS` keyed by the
      gwsproto `DeviceType | SimDeviceType` enums rather than bare
      strings; its docstring names what retires it (the heat-pump state
      machine, and the device-type record carrying the values).
   3. **Fail loudly at boot.** A scada-only check in `sema_to_dc.py`,
      beside `check_energized_standby_relays`: a `gw.nolan.layout` whose
      `hp-odu` component's `DeviceType` has no `HP_TRAITS` row raises
      before any actor is built. The message names the device type,
      lists the supported heat pumps, and says the fix is a row in
      `actors/hp_boss/sensing.py`. It is not a layout axiom: adding a
      heat pump is a code change, not a word change. It covers every
      selection (standby and cooling included, since hp-boss runs the
      machine whichever local control runs) and replaces the
      construction-time raise in `NolanBufferOnlyTou`.
   4. **The machine in hp-boss**, reporting each transition; the Nolan
      pump posture reads the state and no watts.

   Tests: a Nolan boot with an unsupported heat pump fails with that
   message, in each local-control selection
   (`test_heating_unknown_heat_pump_fails_construction` becomes this
   boot test); the machine crosses at each line, holds in between,
   starts in `Unknown` and holds there until the first fresh read, goes
   `Unknown` on stale power and back; the pump posture follows all three
   values; one `SingleMachineState` per
   transition.

6b. **Standby, piece by piece, on both families** (test 7). One row per family
   in `tests/actors/test_relays_boot.py`. House0 (willow): hp-boss
   `TurnOff` leaves the normally-closed call relay energized; the sieg
   loop sits in `HoldFullSend` with both hp-loop relays as it set them;
   the vdc relay is as five-v-boss runs it; exactly the two listed
   relays are energized and every other relay under `n` is
   de-energized. Nolan: the normally-open call relay de-energized and
   hp-boss `HpOff`; the vdc relay as five-v-boss runs it; every relay
   under `n` de-energized. Plus one boot test: a params file listing a
   command node's relay stops the scada at load. Standby turns the heat
   pump off through the shared `HydronicNode.turn_off_hp`, which every
   family's local control and the House0 leaf allies also call.

7. **The shared cold handling**, written once for every family on the
   shared tier rather than a second copy of House0's: the five-minute
   cold latch (`house0/tou_base.py:247` today), the
   `ServiceContractBroken` write to the params file, and the three
   cold glitches (`cold-house-derived-setpoint.md` "What a cold house
   says"). The judgment of *when* a derived-setpoint house is cold
   stays in that spoke; this step consumes it. Test, on both sim
   pairs: a critical zone cold for five minutes → the `SystemCold`
   transition, the critical-zone-cold glitch once, `AcceptsDispatch`
   false with `ServiceContractBroken` written to the params file and
   reported on the operating status; warm again does not clear it, a
   params update does.

8. **The derived generator's required-energy pass at every hour**
   (House0, pipe-clearing). `test_main_loop_pass_survives_the_first_forecast`
   in `tests/actors/test_derived_generator_house0.py` runs on the real
   clock and sets a heating forecast but no weather forecast;
   `compute_required_energy_wh` takes an evening branch (Sunday to
   Thursday from 20:00, weekdays before 07:00) that reads the weather
   forecast's times with no None check, so the test fails whenever it
   runs in those hours and passes by day. The field does not hit it:
   the main loop fetches the forecasts first and `get_weather` always
   ends with one (the API, else the local file, else the coldest hour
   of the month). Plan, test first: pin the clock (the file's
   `pin_clock`) and run the pass at every hour of every weekday with
   the weather forecast the field would have, plus the no-forecast
   case; then the chip, a loud clear failure in the generator when the
   pass runs with no weather forecast rather than an attribute error.

9. **The first experiment.** A sim Nolan house in dev against the dev
   broker, watching the call follow the tariff across an on-peak
   boundary with the band fed from the sim buffer. The machine has not
   yet run against a real broker.

**Open defects with no step yet.**

- **Sequences ignore top-state transitions.** The cooling loop's
  `command_sequence` paces steps 15 s apart and never re-checks
  `top_state`; an admin wake-up mid-sequence still lets a command leave
  the LC, caught today only by the relay's rights check. Part of the
  cooling review.
- **Setpoints by channel-name scraping.** The LTN finds zone setpoints
  with `'zone' in x and 'set' in x` (`ltn/ltn.py:1485`) rather than the
  circuit's Thermostat; nothing consumes `Thermostat.ComponentId` or
  `ThermostatKind` yet (`../spruce-settled/thermostat-and-zone-control.md`
  "Thermostat chunk").

## Built

- **The sema pass:** `gw.standby.posture`, `gw.dispatch.refusal.reason`,
  `gw1.nolan.lc.buffer.only.state` and `gw.house.operating.status` new;
  `gw.operational.params` and `layout.lite` 013 edited in place;
  `gw1.actuation.authority` deleted.
- **The mirror wave and the shared standby** (tests 1, 2, 4, 5): loader
  selection, standby posture at boot, the dispatch refusal gate in the
  `LeafAlly` wrapper, the ops-word axioms.
- **Standby after admin** (test 3) and **operating-status emission**
  (test 6, `tests/actors/test_operating_status.py`). The deed is a
  boot-time fact: a new deed means a scada reboot. Open capture: the
  scada's startup contract load, four seconds into the run, completes as
  a reboot leftover any contract offered before it runs.
- **The band thresholds** `BufferFullF` / `BufferChargeF` on
  `gw.nolan.family.params`, with its axiom, gwsproto mirror, tlayouts
  generators and fixtures.
- **`NolanBufferOnlyTou`** with eight tests in
  `tests/actors/test_local_control_nolan.py`. The postures are derived
  every check and commanded on change; in ScadaBlind the whole tree
  moves under the scada-blind node and the Normal machine reports
  Dormant until the band is fresh again; the boot posture is commanded
  in one pass with no pacing.
- **The Nolan folder and shared heat-pump primitives** (`55be2758`).

## ▶ Do this next

Step 6a.1, the `spruce.hack.hp.state` word. Name and values are
agreed, default `Unknown` (the safe value); author it with the
descriptions below and write the gwsproto twin.

- `description`: the heat pump's running state as the scada senses it
  from outdoor-unit power, on spruce's starter-script thresholds: on
  above one watt line, off below a lower one, held in between.
- `Unknown`: no fresh power read, at boot or after power goes stale; a
  consumer runs the secondary pump. `HpOn` / `HpOff`: power
  crossed above the on line / below the off line.
- `extended_description`: stands in for the heat-pump state machine
  and repeats spruce's starter-script loop. Running is sensed, not
  assumed: the Samsung AE055FCYDCG has run on its own programmed
  schedule and not listened to the scada, so power metering showed
  when it turned on, and a sensed start says more than an assumed
  response. A first, rough step in driving the secondary pump to keep
  the buffer stratified. The on line sits above the unit's unannounced,
  undispatched draws: a first line at 300 W was crossed the very next
  night, the Samsung drawing about 350 W for a minute every five
  minutes for hours, and four times that night it ran its primary pump
  about seven minutes with no lift. The watt lines are held by heat-pump
  device type in the code that runs the machine.
