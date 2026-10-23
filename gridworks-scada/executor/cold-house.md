# Cold house

Status: Draft · Pass 0 · Updated 2026-10-20

> What this is: how a scada judges that a house is cold, what it says when
> it is, and how it stops taking dispatch until a person clears it. One
> judgment and one cold-watch actor serve every family; the code is
> `gw_spaceheat/actors/hydronic/cold.py` and the scada's
> `process_break_service_contract` (`gw_spaceheat/actors/scada.py`).

## The judgment

`ColdJudgmentNode` is a tier under both family tiers, so every local
control, every leaf ally and the cold watch share the same
`is_system_cold`. The house is cold when at least one critical zone is
cold.

A zone is judged through its primary circuit, the zone-call circuit its
`PrimaryCircuitPosition` names (`gw1.hvac.zone`). The temperature is the
reading on that circuit's `TempChannelName`, the air temperature at the
circuit's own thermostat; the setpoint is read on its
`SetpointChannelName`; the heat call is the heat-call derived channel
whose one input is the circuit's whitewire channel; and the rule is
chosen by the circuit's `SetpointSource`. No channel name is built from
a zone's place in a list. A zone's other circuits take no part: at
spruce a call on the living room's fancoil circuit does not make the
living room cold.

- **`FromThermostat`:** cold at `COLD_DELTA_F` (2 °F) or more under the
  lower of the circuit's setpoint as on-peak began and its current
  setpoint. A thermostat raised during on-peak does not make the house
  cold, and neither does one lowered. The on-peak-start memory is
  refreshed off-peak and held through on-peak; the hold is the
  protection. The temperature is the thermostat's own report, so a
  Honeywell house is judged on the reading its thermostat acts on.
- **`Learned`:** cold only while the circuit is calling for heat and
  `COLD_DELTA_F` or more under its recorded setpoint. The call is the
  thermostat saying the zone is under its setpoint; the record says by how
  much. A circuit that is not calling is never cold by this rule, so a
  thermostat turned down does not read as a cold house, and a thermostat
  turned up leaves the zone warmer than the record.

**The warm-up allowance (`FromThermostat` only).** A zone that has just
been asked to warm is not cold, whatever it reads, until it has had time
to get there. A warm-up starts at three moments: a boot, a raise of the
circuit's thermostat setpoint, and the pass after the local control
leaves `InBackup` or `ColdOverride`. At the first pass after the start
with both a setpoint and a temperature for the zone, the zone's deficit,
the judged setpoint less the temperature capped at
`WARM_UP_DEFICIT_CAP_F` (10 °F), divided by `WARM_UP_F_PER_H` (4 °F an
hour, what a called zone warms at) is its allowance, and until that long
has passed the zone is not cold. An 8 °F deficit gets two hours, a 2 °F
raise thirty minutes, 10 °F or more two and a half hours. A thermostat
lowered starts nothing and counts at once; a raise during on-peak is
judged against the on-peak-start setpoint, so its deficit is what that
setpoint says. After the allowance the judgment and the latch run as in
steady state, so a heat source failing in steady state still pages after
`COLD_LATCH_S`. Standby exit is new ops params and a restart, so the boot
allowance covers it; a restart during a genuine cold spell delays the
page by the allowance, which is accepted. A `Learned` zone has no
allowance: its rule already counts a zone cold only while its thermostat
calls under the record. The two constants are code beside the other
four, until a house shows it needs its own.

A critical zone with no temperature reading, or with no setpoint to
judge against, is logged and skipped. The layout words guarantee the
channels themselves: every zone's primary circuit carries a setpoint
channel and a temperature channel (`gw.hydronic` "PrimaryCircuit",
`gw1.zone.call.circuit` "SetpointNeedsTemp").

`COLD_DELTA_F` is the one place the 2 °F lives: a named constant at the
top of `cold.py`, used in the single comparison. It is code, not a
parameter. The other three constants beside it are `COLD_LATCH_S`,
`STILL_COLD_IN_BACKUP_S` and `FREEZE_F`
([`magic-thresholds.md`](magic-thresholds.md) "Strategy timers (leaf ally
and local control)").

## The recorded setpoint

A learned setpoint is not always there to read: the generator withdraws
it when it suspects the thermostat was moved, and its channel is empty
after a restart. So the judgment never reads the channel's latest value.
The cold watch keeps, per critical zone whose primary circuit is
`Learned`, the last value the circuit's setpoint channel carried, and
every judge reads that record from the scada's shared data.

The record outlives a restart. The scada keeps it in
`recorded-setpoints.json` in its data directory, beside the dispatch
contract file, where the scada keeps what it writes itself. A file beside
the layout would be written into whatever folder the layout path points
at, which in tests is the repo's fixture folder. The file holds a
`gw.recorded.setpoints`: the scada's alias and a list of `single.reading`
words, unique by channel. A file written by another scada is ignored at
load.

## The latch

`ColdWatch` is the actor at the `cold-watch` node, a core node of every
layout word. It calls `cold_watch` once a minute on its own loop,
whichever local control runs and whatever its top state, so a house that
goes cold under a dispatch contract or under admin pages like any
other. No local control calls the watch. The watch pats the scada's watchdog, so a watch that
stops is a scada restart and not a silent gap.

The watch learns whether the house is in backup by subscribing to the
local control's machine states at start
(`MachineStateSubscribe(NodeName="lc")`): a top state of
`InBackup` is backup, any other is not.

A `FromThermostat` zone inside its warm-up allowance ("The judgment")
is not cold to the latch. When a critical zone has been cold for
`COLD_LATCH_S` (five minutes) without a warm pass between, the watch does two things, once per cold
spell:

1. It raises the Critical glitch `critical-zone-cold`, naming each cold
   zone with its temperature and the setpoint it was judged against,
   whatever the buffer and the store hold. A house in standby
   (`Standby` true in its ops params) raises no `critical-zone-cold`:
   it may be unheated on purpose. Its `zone-freezing` glitch is raised
   like any other house's.
2. When the stores are empty, it sends the local control the in-process
   message `HouseCold` and the scada `BreakServiceContract`, in that
   order. The stores are empty when the buffer is, and at a house whose
   `SeasonalStorageMode` is AllTanks the store too (`stores_empty`,
   `hydronic/cold.py`). Stores that empty later in the same cold spell
   send both then. `BreakServiceContract` goes once per cold spell;
   `HouseCold` goes on every pass the latch holds with the stores
   empty, so the watch says what it sees and the local control decides
   what the message means in its state.

A house cold with heat still in its stores can keep a contract; cold
with its stores empty, it has broken one. A warm pass ends the cold
spell and restarts the five minutes; one that ends a spell in which
`HouseCold` was sent sends the local control `HouseWarm`. It does not
undo a refusal. The messages are in `actors/in_process_messages.py`; what
each machine does with them is [`local-control.md`](local-control.md)
"The top state".

## The refusal

On `BreakServiceContract` a scada holding a dispatch contract (a live
contract heartbeat, or the leaf ally holding the command tree) that is
not already held out by its ops word:

1. sets `DispatchHold.ServiceContractBroken` true in the params it runs;
2. writes its operational-params file with that change, through a temp
   file and a rename so neither a reader nor a power cut meets half a
   file;
3. reports its operating status (`gw.house.operating.status`);
4. ends the contract through `process_ally_gives_up`, the one
   termination path whoever decides, so the LTN gets a
   `TerminatedByScada` heartbeat whose reason is
   `ServiceContractBroken` and whose cause is the watch's, as given.

From then on `dispatch_refusal` answers `ServiceContractBroken` to every
offer ([`dispatch-gate.md`](dispatch-gate.md)).

A scada holding no contract has broken none and changes nothing. A scada
whose ops word already holds it out (`OperatorHold`, or the latch
already set) keeps its params. The glitch is raised all the same.

**The clear.** Only a person editing `ServiceContractBroken` back to
false clears it. The house warming up does not. A cleared latch raises
no glitch; the scada's next operating status says it accepts dispatch.

**The scada is a second writer of its params file.** The file on a box
can therefore differ from its tlayouts source, and a push of the source
would clear the latch unseen. `scripts/roll.sh` compares the box's
params with the committed source outside the `DispatchHold` block and
installs the source only on a `y` after showing the difference; the
session-start drift check reports each house whose box params differ
from tlayouts.

## The other two glitches

- **`still-cold-in-backup`** (Critical): the local control has been in
  backup for more than `STILL_COLD_IN_BACKUP_S` (an hour) and a critical
  zone is still cold. Once per stay in backup. Only a House0 house
  reaches backup today.
- **`zone-freezing`** (Critical): any circuit's temperature channel, of
  a critical zone or not, reads under `FREEZE_F` (40 °F). At most once a
  day per circuit.

Each condition has its own `Summary`, so on-call can tell them apart and
the later ones are not re-pages of the first.

## Backup

The latch is what moves a house out of `Normal`: `HouseCold` is the
one judgment of cold with the stores empty, and the local control acts
on it the moment it arrives rather than judging again on its own loop.
Where it goes, `InBackup` or `ColdOverride`, is the machine's decision
from the ops word's `UsesBackupWhenCold` and the layout's `Backup`
([`local-control.md`](local-control.md) "The top state"). A house with
no backup still leaves `Normal`, to run its primary heat source through
the peak.

A backup is a second source of heat, declared in the layout as the
optional `Hydronic.Backup`, one of two words. `gw.boiler.backup` is a
boiler held by its aquastat, whatever its fuel; `FailsafeRelayName` and
`AquastatCtrlRelayName` name its two relays by role, because `InBackup`
commands each differently. `gw.element.backup` is one or more resistive
elements on the relays `ElementRelayNames` lists. Each carries
`InService`, false for a backup installed but unwired or out of service;
`InService` lives in the layout only. Every relay a backup names is a
`Relay` ShNode, the names are distinct, and the `backup` command node
exists exactly when the layout declares a backup. A layout with no
backup has no `Backup`.

`ColdOverride` is not a second source: it is the primary heat source
run with the tariff set aside. A house with both a heat pump that could
run through the peak and a backup goes to its backup; it does not try
the heat pump first. All relays de-energized is the plant's failsafe
position, where the aquastat and the boiler hold a House0 house with no
scada; it coincides with boiler backup and is not a state of the local
control.

The pair is checked at load, before any actor is built
(`check_backup_when_cold`, `sema_to_dc.py`): `UsesBackupWhenCold` true
requires a `Hydronic.Backup` with `InService` true, and at a Nolan
layout an element backup, since the Nolan machine has no boiler branch.
A pair that fails does not boot. With `UsesBackupWhenCold` false the
layout may declare any backup or none; it is never used.

## Leaf allies

A leaf ally holds no rule about when a cold house ends a contract: the
watch decides it, and it runs while the ally holds the command tree. At
an offer, a House0 leaf ally asks `declines_offer_for_cold`
(`hydronic/cold.py`): a house with a critical zone cold now and its
stores empty declines the offer with `AllyGivesUp` and latches nothing,
since no contract was broken. A house cold with heat in its stores takes
the offer. A taken contract ends when the watch reports five minutes
cold with the stores empty.

## Open

- **Cold with no call.** A thermostat or wire failure can leave a
  critical `Learned` zone cold and silent, and the rule reads that as a
  thermostat turned down. A `FromThermostat` zone is still caught. A
  floor temperature per critical zone on the ops word is the candidate.
- **No record ever.** Before a `Learned` circuit's first learned setpoint
  there is nothing to judge against. The same floor is the stand-in.
- No test drives House0's `SystemCold` transition on a running scada.
- No test runs the watch on a running scada in standby.

## Tests

`tests/actors/test_cold_handling.py` covers the judgment, the warm-up
allowance at each of its three starts with its cap and its absence for a
lowered thermostat and for a `Learned` zone, the record, the
latch, the glitches, `stores_empty` by seasonal storage mode, the break
only with the stores empty, and the scada's handler with and without a
contract, in process, on both families, with the Nolan fixture's
two-circuit living room for the primary-circuit rule, the watch's
subscription and its backup flag, and a Nolan house in standby staying
quiet when cold and still reporting a freezing circuit. It also holds the House0 leaf ally
declining an offer only when cold with its stores empty.
It also holds the two messages to the local control: `HouseCold` on
every pass the latch holds with the stores empty, carrying the break's
cause, and `HouseWarm` on the warm pass only after a `HouseCold`.
`tests/actors/test_cold_handling_live.py` runs two scadas with the
watch on its own loop: a cold Nolan house holding no contract raises the
glitch, keeps accepting dispatch and goes to `ColdOverride`; a House0
house cold with its stores empty under a contract ends it and refuses
dispatch, and its local control takes its cold state once the ally
has released the tree. `tests/actors/test_system_cold_live.py` holds willow cold at
the watch and sees the local control reach `InBackup` or `ColdOverride`
by `UsesBackupWhenCold`, hold through the peak and return off-peak on
`HouseWarm`.
