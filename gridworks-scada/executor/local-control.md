# Local control

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: how a scada chooses its local control, what standby is,
> the Nolan heating machine and the heat-pump watch it follows, the
> subscriptions that feed them, the top state every local control
> reports, and the dispatch refusal with the operating status that
> carries it. The actor tiers and the command tree it stands on are in
> [`control-hierarchy.md`](control-hierarchy.md) "The node-actor
> partition"; the cold judgment is in [`cold-house.md`](cold-house.md).

## Selection

No authored field names the machine. `LocalControl`
(`actors/local_control_loader.py`) derives it from the ops word's
`Standby` and `ServiceMode`, the layout family, and the family params'
`SeasonalStorageMode`. A row the table does not have raises, which is
the consistency check.

| `Standby` | Family | `SeasonalStorageMode` | `ServiceMode` | Local control |
| --- | --- | --- | --- | --- |
| true | any | any | any | `StandbyLocalControl` (`local_control/standby.py`) |
| false | House0 | AllTanks | Heating | `AllTanksTouLocalControl` |
| false | House0 | BufferOnly | Heating | `BufferOnlyTouLocalControl` |
| false | Nolan | BufferOnly | Heating | `NolanBufferOnlyTou` |
| false | Nolan | any | Cooling | none; the loader raises `NotImplementedError` |

An authored machine name would restate these facts and could disagree
with each of them, so there is no strategy enum. A scada that touches
nothing is `Standby` with posture `MonitorOnly`. The fields are read
once at construction; a change is new operational params and a restart.

The other readers of the same facts:

- **Leaf ally.** `LeafAlly` (`actors/leaf_ally_loader.py`) picks
  House0's ally by storage mode and gives every Nolan layout
  `NolanLeafAlly`. There is no standby ally.
- **LTN.** Bids and FLOs run only when `AcceptsDispatch` is true and
  `ServiceMode` is `Heating`, both read with `SeasonalStorageMode` from
  `gw.house.operating.status` (`ltn/ltn.py`). Until a status arrives the
  LTN refuses.
- **Derived generator.** The usable-energy gate reads `AcceptsDispatch`
  and `ServiceMode` from the scada's own params.
- **Sieg strategy.** `Standby` runs `HoldFullSend` whatever the family
  params say (`selected_strategy`, `sieg_loop/strategy.py`).

`gw1.system.mode` is the predecessor of these ops fields. It stays
published because older words depend on it and the web backend reads
it; the scada does not read it.

## Standby

A house is in standby or it is not, and moving between the two is new
operational params and a restart. `StandbyLocalControl` serves every
family.

**The top machine** has two states of `gw2.lc.top.state`. `Standby`
holds the tree under the `standby` node. `Dormant` means another node
holds it, which at a standby scada is admin, since standby refuses
dispatch. `TopGoDormant` and `TopWakeUp` move between them, and each
transition is reported with its cause. `GoDormant` raises if actuators
are still under the actor. A `WakeUp` in any state but `Dormant` is
ignored. The scada's `enforce_auto_state_consistency` treats a standby
local control as any other. A scada out of standby never reports
`Standby`.

**The command tree says standby.** The actor claims the tree under
`standby` at construction and on each `WakeUp` from `Dormant`, and the
scada's boot tree hangs under `standby` when the ops word says
`Standby`. The live tree reads `auto.lc.standby.<node>` and nothing
hangs under `n`, so the commander of every command is `standby`.

**The posture** is set at `ActuatorsReady` and on each `WakeUp` from
`Dormant` (`set_standby_posture`).

1. De-energize every `Relay` directly under `standby` that the ops
   word's `EnergizedStandbyRelays` does not list.
2. Energize the listed ones.
3. Send hp-boss `TurnOff` (`HydronicNode.turn_off_hp`).

The 0-10V outputs stay at their power-on levels and are never written.
The command tree keeps its shape: five-v-boss runs, the sieg loop holds
`HoldFullSend`, hp-boss sits at `HpOff`. Step 3 exists because hp-boss
has no dormant or wake handling and an admin session can leave it
`HpOn`.

**The lists.** House0's is `hp-failsafe-relay` and `aquastat-ctrl-relay`
(both `SwitchToScada` when energized). Its call relay is hp-boss's and
is `NormallyClosed`, so step 3 energizes it: the heat pump and the
boiler are both held off. Nolan's list is empty, since its call relay
is `NormallyOpen` and off is de-energized. The posture is the same and
the lists differ, which is what `gw.standby.posture` names.

**The list never reaches under a command node.** A listed name must be
a `Relay` whose boot handle sits directly under the tree root. A relay
owned by a command node (`hp-scada-ops-relay`, the sieg loop's two
relays, `vdc-relay`) fails the params load and the scada does not start
(`check_energized_standby_relays`, `sema_to_dc.py`). Standby reaches
such a relay only through its node's command.

## The Nolan heating machine

`NolanBufferOnlyTou` (`local_control/nolan/buffer_only_tou.py`) charges
the buffer on the time-of-use schedule and leaves the store alone. Its
plant judgment is `NolanHydronic` (`actors/hydronic/nolan.py`). It is
the loop spruce ran through the winter of 2025-26
(`starter-scripts/spruce_winter_hack.py`) as scada behavior.

**States** (`gw1.nolan.lc.buffer.only.state`): `Initializing`,
`HpCallOn`, `HpCallOff`, `Dormant`. The state names the one plant
decision the machine makes, the heat-pump call. Every transition
reports a `SingleMachineState`. In Normal the call is commanded only at
a transition.

**Transitions.**

- `Initializing → HpCallOff` once the actuators are ready and the boot
  posture is commanded. Boot never opens with a call.
- `HpCallOff → HpCallOn` when off-peak AND the band wants charge;
  `HpCallOn → HpCallOff` when on-peak OR the band is full. Off-peak ends
  the heat pump's call-open lead before an on-peak start, so the unit is
  off when the window opens. Checked every 60 s (`TOU_CHECK_S`).
- `* → Dormant` when the top machine leaves Normal; back through
  `Initializing` on return, so a released tree is booted again rather
  than resumed.

**The buffer band** is a latch on two channels: buffer-depth3 (bottom)
at or above `BufferFullF` sets full, buffer-depth1 (top) below
`BufferChargeF` clears it, and it holds in between. Both thresholds are
on `gw.nolan.family.params`; the on-peak windows come from the ops
`Tariff`. The actor holds no second copy of either.

**ScadaBlind means the band is blind.** `MissingData` fires when either
band channel has not been read for 5 minutes (`BLIND_S`). The tree
moves under the `scada-blind` node, which drives the call on the
schedule alone (closed off-peak, open on-peak); the heat pump's own
limits stop it when the buffer is hot. The call machine reports
`Dormant` meanwhile. `DataAvailable` returns to Normal through a boot
when both channels are fresh.

**The cold house.** On the cold watch's `HouseCold`
([`cold-house.md`](cold-house.md) "The latch") the tree moves under the
cold state's node and the call machine reports `Dormant`. With the ops
word's `UsesBackupWhenCold` false the state is `ColdOverride`: the call
is commanded closed and held whatever the tariff. With it true the state
is `InBackup`: the call is opened if it was closed, and the relays the
layout's `gw.element.backup` names are closed from `backup`; the
machine refuses to construct with `UsesBackupWhenCold` true and no
element backup in the layout, since it has no other backup to go to.
The boot pass opens the element relays, so a cold stay ends with them
open whichever way it ends, and a layout whose elements are not in
service still has the scada holding them off. In either state the pump
follows the hp-watch as in Normal and a blind band changes nothing. The
watch's `HouseWarm` returns the machine to Normal through a boot when it
is off-peak, else the first off-peak check does, so a stay entered
on-peak holds through the rest of the peak.

**Postures are not states.**

- Zones on their thermostats (every failsafe relay de-energized, every
  scada zone relay open), charge valve closed, store pump off. These are
  commanded once, in the boot pass.
- The secondary pump and iso valve follow the hp-watch state: on in
  `HpDetectedOn` and `Unknown`, off in `HpDetectedOff`, the valve moving
  in the same step as the pump. This follows the unit whatever closed
  the call, so it is not a function of `HpCallOn`. The pump is commanded
  the moment a state arrives, and each check derives it again and
  commands only a change. A state that arrives while Dormant is kept and
  commands nothing; the boot on wake commands the pump by it.

**Boot** commands every actuator the machine is the direct boss of, in
one pass: the postures above plus the call open.

## The heat-pump watch

`HpWatch` (`actors/hp_watch.py`) runs on Nolan layouts only, at the
`hp-watch` node. It reports `spruce.hack.hp.state`: `Unknown`,
`HpDetectedOn`, `HpDetectedOff`.

Running is sensed, not assumed: the unit can run its own schedule and
ignore the call. The watch reads `hp-odu-pwr` through a channel
subscription. It goes to `HpDetectedOn` on the first read above the on
line and to `HpDetectedOff` on the first read below the off line, and
holds in between. That latch is memory, which is why this is a machine
and not a derived channel. It starts in `Unknown` and returns to
`Unknown` when the scada forwards a `ChannelFlatlined` for the channel.
A first read between the lines, with no earlier state to hold, is
`HpDetectedOff`: running the pump when the system is not hot
destratifies the buffer.

**The node.** ActorClass `HpWatch`, ActorHierarchyName `s.hp-watch`, no
Handle, outside the command tree. The watch reports under its own node,
so sensing stays out of hp-boss, the command node. `gw.nolan.layout`
axiom 32 (HpWatchNode) requires it in every Nolan layout; House0
layouts do not carry it. It runs whichever local control is selected.

**The lines are hard-coded by heat-pump device type**: `HP_TRAITS` in
`actors/hp_boss/sensing.py`, one `HpTraits` row per supported heat pump
(on line, off line, call-open lead). Spruce's Samsung AE055FCYDCG is
500 W on, 80 W off, 120 s lead. A Nolan layout whose heat pump has no
row stops the scada at load (`check_hp_traits`, `sema_to_dc.py`). It is
a scada check and not a layout axiom: adding a heat pump is a code
change, not a word change.

**Authoring a row.** The lines bracket a band the unit only passes
through: the off line sits above every idle plateau and idle pulse
(controls, crankcase heater, oil-return and fan cycles), the on line
below the lowest sustained running draw, and nothing the unit does sits
between them for longer than a ramp. Both come from the unit's own
power history, not its data sheet. With the lines so placed, `Unknown`
and the first between-read are tie-breaks, not safety choices: the
watch is wrong only when the band holds something. Spruce's Samsung,
measured 2026-08-03 to 2026-10-07: standby 62 to 68 W with pulses to
390 W, running draw 505 W and up, starts across the band in under 24 s
and stops in under 62 s.

**A held On is reported.** `HpDetectedOn` with every read between the
lines for `HELD_ON_S` (600 s) means the unit has stopped and its standby
draw sits above the off line, so the secondary pump is running between
cycles. The watch raises one Warning glitch `hp-watch-held-on` per such
spell, measured from the first between-read, and leaves the state
alone; a read above the on line starts a new spell. The periodic report
every capture period guarantees reads during a plateau, so the warning
comes within two capture periods of the hold.

## Subscriptions

An actor asks the scada for a channel's readings or a machine's states,
and the scada forwards them as they arrive. No actor polls, and none
reads another's state by reaching into it.

**Two in-process subscription messages**
(`actors/in_process_messages.py`). Neither
crosses a process boundary, so neither is a sema word, but both are
typed as one would be:

- `ChannelSubscribe(ChannelName)`
- `MachineStateSubscribe(NodeName)`

The subscriber is the envelope's sender, not a field. A machine is
named by its node and not its handle, because a command node's handle
moves with the command tree and a subscriber wants its states under
every tree.

**The scada keeps two maps**, `channel_subscribers` and
`machine_state_subscribers`, each from a name to its subscribers. On
receipt it looks the name up in the layout (a data channel, not a
derived one; a node) and raises on one the layout does not have: a
subscription to nothing is a defect in the subscriber, found at boot.

**Forwarding carries existing sema words only.**

- A reading on a subscribed channel goes to each subscriber as a
  `SingleReading`.
- A `ChannelFlatlined` for a subscribed channel goes as received. This
  is how a stale channel reaches a subscriber.
- A `SingleMachineState` whose `MachineHandle` ends in a subscribed node
  name goes as received. On a `MachineStateSubscribe` the scada also
  sends the node's latest state when it holds one, so a subscriber that
  starts after the publisher's first report still gets it.

Subscribers today: `HpWatch` to `hp-odu-pwr`; `NolanBufferOnlyTou` to
`hp-watch`; the sieg loop to `hp-boss`; the cold watch to `lc`.

## The top state

Every local control reports one enum, `gw2.lc.top.state`: `Dormant`,
`Normal`, `ScadaBlind`, `Standby`, `InBackup`, `ColdOverride`. Each
machine lists its own states:

| Local control | States |
| --- | --- |
| `StandbyLocalControl` | `Dormant`, `Standby` |
| House0 (`LocalControlTouBase`) | `Dormant`, `Normal`, `ScadaBlind`, `InBackup`, `ColdOverride` |
| `NolanBufferOnlyTou` | `Dormant`, `Normal`, `ScadaBlind`, `InBackup`, `ColdOverride` |

`Dormant` means another node holds the tree: admin, or the leaf ally
under a dispatch contract. Command nodes exist only for the states that
command, one each: `n` for `Normal`, `backup` for `InBackup`,
`cold-override` for `ColdOverride`, `scada-blind` for `ScadaBlind`,
`standby` for `Standby`. All five are core names, both layout words fix
their handles under `auto.lc`, and their `ActuatorLeaves` axiom states
the correspondence; `backup` exists exactly when the layout declares a
`Hydronic.Backup`, the other four always. The state nodes have no actor of their own: a message
addressed to one, such as a relay's ack to its commander, is delivered
to the local control actor (`_send_to`, `sh_node_actor.py` and
`scada.py`).

**The cold house.** The cold watch judges and the local control reacts
to its two in-process messages ([`cold-house.md`](cold-house.md) "The
latch"); no machine judges cold on its own loop. On `HouseCold` from
`Normal` or `ScadaBlind`, either machine goes to `InBackup` (event
`SystemCold`) when the ops word's `UsesBackupWhenCold` is true and to
`ColdOverride` (`SystemColdNoBackup`) otherwise; the cold states need
no band and no forecast, so a blind house that is cold is a cold house.
`HouseCold` in any other top state, or in a cold state, is noted and
moves nothing; the watch sends it on every pass it holds, so a machine
that is `Dormant` when one arrives (under the contract that the same
look ends) takes its cold state at the next pass after it wakes. Either
cold state leaves for `Normal`
(`CriticalZonesAtSetpointOffpeak`) on `HouseWarm` when off-peak, else at
the first off-peak check after it, and goes `Dormant` for admin like
`Normal`.

`InBackup` commands from `backup`: at House0 store pump off, store
valved to discharge, `hp-failsafe-relay` to the aquastat,
`aquastat-ctrl-relay` to the boiler; at Nolan the call open and the
element relays closed. Nolan's boot opens the element relays, so every
way out of `InBackup` (the warm off-peak return, the wake after admin)
ends with them open, commanded by the machine and asserted by a test. `ColdOverride` is the primary heat source with
the tariff set aside, from `cold-override`: at House0 store pump off,
store valved to discharge, heat pump on; at Nolan the call closed. House0's on-peak
ScadaBlind branch reads `UsesBackupWhenCold` too.

## The dispatch refusal

The scada says whether it will take a dispatch contract, and why.

- `AcceptsDispatch` on `gw.operational.params` is the one test every
  gate reads.
- `DispatchRefusalReason` (`gw.dispatch.refusal.reason`) is present iff
  `AcceptsDispatch` is false: `Standby`, `NoAggregator` (collecting
  data, no aggregator chosen), or `ServiceContractBroken` (the house
  went cold with its stores empty under a contract; held until a person
  clears it).

**Axioms 3 to 5 on `gw.operational.params`:**

3. If `Standby` is true, `AcceptsDispatch` is false and the reason is
   `Standby`.
4. The reason is present iff `AcceptsDispatch` is false.
5. The posture fixes the energized list per family: `MonitorOnly` means
   an empty list; `NoHeatingOrCooling` means `hp-failsafe-relay` and
   `aquastat-ctrl-relay` for House0 and an empty list for Nolan.

**Two gates.**

- **A new offer.** While `AcceptsDispatch` is false the `LeafAlly`
  wrapper answers every `SlowDispatchContract` with `AllyGivesUp`
  carrying the reason, and the offer never reaches the family's ally
  (`leaf_ally_loader.py`).
- **A stored contract.** The scada loads its stored contract when its
  tasks start, before any message is processed, and four seconds later
  `resume_loaded_contract` speaks of it. A live contract puts the leaf
  ally back in charge, and the LTN and the leaf ally get its heartbeat.
  A scada that does not accept dispatch ends the live contract instead:
  it terminates, stores and flushes it, the LTN gets the terminating
  heartbeat with the reason, and the leaf ally hears nothing. A stored
  contract that ran out while the scada was down is completed at the
  load, and that heartbeat goes to the LTN and the leaf ally whatever
  the scada accepts. Nothing is sent when an offer since the load has
  replaced the loaded contract.

The scada writes its own params file when it latches
`ServiceContractBroken` ([`cold-house.md`](cold-house.md) "The
refusal").

## The operating status

The scada emits `gw.house.operating.status` once after its startup
announcements and then only when a field changes; a healthy hour
produces none (`report_operating_status`, `scada.py`). It carries the
slow facts of the LTN–scada agreement, so "not dispatching" reads as a
reason: no standing (`ValidationState`, from the deed), an admin
session (`TopState`), a refusing posture (`AcceptsDispatch` with its
reason, `Standby`, `ServiceMode`), or no offer this hour.

- Six fields are copied from the scada's decoded params, never from a
  second source. The rest are the scada's alias, the time, and the
  runtime facts (`ValidationState`, `TopState`, `LtnDispatching`).
- `LtnDispatching` is true from the first heartbeat that goes Active
  and false only after no contract has been active for a settling
  window past a completion, so back-to-back hourly contracts read as
  one long true.
- It does not carry the raw contract status or any machine's state.
- It is the LTN's one source for the posture facts: `layout.lite` does
  not carry `AcceptsDispatch`, `ServiceMode` or `SeasonalStorageMode`.
- The deed is a boot-time fact; a new deed means a scada restart.

## Open

- Cooling a Nolan house from the scada is not built; the loader raises
  on a Nolan layout authoring `Cooling`. A cooling machine starts from
  the loop spruce ran through the summer of 2026
  (`starter-scripts/spruce_summer_hack.py` at `2c31bc1`): radiant
  circuits held, iso valve open, secondary pump on, the cool call
  closed off-peak and open on-peak. The scada cannot put the heat pump
  into cooling; a person changes the unit's mode, and the call contact
  is inert while FSV 2091 is 0
  (`heat-pump-comms/samsung-ae055feymcg.md`).
- Backup for a Nolan house is not built.

## Tests

| Behavior | Test |
| --- | --- |
| An ack to any state node reaches the local control actor; selection; standby posture at boot and after admin; the tree under `standby`; `Dormant` under admin and `Standby` on release; a `WakeUp` in `Standby` ignored; the auto-state check waking a `Dormant` standby | `tests/actors/test_relays_boot.py` |
| Each machine's top states and events; one state node per commanding top state | `tests/actors/test_local_control_top_machines.py` |
| The Nolan heating machine | `tests/actors/test_local_control_nolan.py` |
| The heat-pump watch, in process and against the sim meter | `tests/actors/test_hp_watch.py`, `test_hp_watch_live.py` |
| Subscriptions and forwarding | `tests/actors/test_subscriptions.py` |
| Stored contract at start, accepting and refusing | `tests/actors/test_startup_contract_load.py` |
| Operating-status emission | `tests/actors/test_operating_status.py` |
| Each machine announces its state at start | `tests/actors/test_machine_state_announce.py` |
