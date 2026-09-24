# The Siegenthaler loop actor, as it runs

Status: Draft · Pass 0 · Updated 2026-09-21

> What this is: what `SiegLoop` does in the field today and where it falls
> short, read from the code and from maple's journal. The code is
> `gw_spaceheat/actors/sieg_loop.py` on scada `origin/main` @ `54f74302`
> (620 lines), which maple and beech run. `jm/spruce-unlimbo` @ `8f76cf68`
> carries the same logic; its diff in this file is mechanical (base class,
> typed temperatures, `ActuationAuthority` for `SystemMode`). Line numbers
> below are `main`'s unless marked.

## What the loop is for

A three-way valve on the heat pump's primary loop. At full keep the heat
pump's water recirculates in the small loop; at full send it goes on to the
buffer or the store. Two jobs follow from that. At a start, keep the water
in the small loop until it is hot enough to be worth sending, so a start
does not push cold water into a hot tank. At a stop, close the loop where
the primary pump keeps running: maple's pump sits inside the Mitsubishi,
the scada cannot switch it, and with the valve at send and the heat pump
off it mixes the buffer (`buffer-depth1` 103.2 F to 95.3 F in twelve
minutes, against 0.3 F with the loop closed;
`experiments/2026-09-20-maple-starts-heating/README.md` findings 12 and
14).

## How it runs

- **Two machines in one actor.** Valve: `FullySend`, `FullyKeep`,
  `KeepingMore`, `KeepingLess`, `SteadyBlend`. Control: `Initializing`,
  `Blind`, `HpOff`, `HpStartingUp`, `HpHasLift`. `engage_brain` (`:216`)
  runs every `control_interval_seconds = 30`.
- **Travel is timed, never sensed.** `FULL_RANGE_S = 100`, position kept as
  `keep_seconds`, `t1 = 26`, `t2 = 82` (`:165-166`). The moves sleep for
  the travel time and adjust the count.
- **Two relays, not alike.** Relay 15 selects direction and speaks
  `change.keep.send`; de-energized is keep less, toward send. Relay 14 runs
  the motor and is wired normally closed: `CloseRelay` de-energizes it and
  the motor runs, `OpenRelay` energizes it and the motor is dormant. The
  actuator has end switches, so driving into a stop does no harm. With the
  scada dead or power lost both relays de-energize and the valve travels to
  full send, which keeps the house warm.
- **Start.** HpBoss reports `PreparingToTurnOn` or `HpOn` → `HpStartingUp`,
  whose entry parks the valve at `t2`, just inside keep
  (`moving_to_just_keep`, `:337`). The one designed way on is
  `hp_loop_is_getting_hot` (`:203`): `max(lwt, ewt) > MaxEwtF - 20` →
  `HpHasLift` → full send. There is no target LWT, no LWT slope and no
  travel-time reckoning; the 2025–26 loop (`c55fe9eb`) had all three.
- **Stop.** HpBoss reports `HpOff` → `HpOff` → full keep, or full send
  when the actuation authority is `Standby`.
- **Blind** (`is_blind`, `:265`): lift or power missing, or power over
  500 W more than 120 s after `hp_turned_off_time`. Blind drives to full
  send, and `hp_loop_is_getting_hot` also answers true when blind.
- **Tree.** `sieg-loop` sits directly under whichever boss holds the tree,
  admin included, with relays 14 and 15 beneath it (`scada.py:1259` on the
  branch). It is not a command node: it takes no `fsm.event`.

## What maple shows

From the journal DB, 2026-09-20 22:00 to 2026-09-21 07:00 ET, the four
runs under local control:

| On command | Power over 500 W | Valve to send | Via | Max LWT |
| --- | --- | --- | --- | --- |
| 22:15:10 | 22:19:00 | 22:19:04 | `Blind` | 138.9 F |
| 04:43:16 | 04:47:05 | 04:47:07 | `Blind` | 138.1 F |
| 06:20:37 | 06:24:26 | 06:24:37 | `Blind` | 127.0 F |
| 06:37:37 | 06:45:10 | 06:45:37 | `Blind` | 128.9 F |

The control state never reached `HpHasLift`. At 04:47:07 LWT was about
70 F and EWT about 71 F, both reporting, with the buffer top near 118 F.
Maple's running `MaxEwtF` is 145 (its own `layout.lite`), so the designed
threshold is 125 F. Thirty-day maximum LWT 138.9 F, EWT 120.3 F.

## Where it falls short

Most consequential first.

1. **Every run opens through `Blind`, onto a cold loop.**
   `hp_turned_off_time` is set at a stop (`:414`) and cleared only at
   construction (`:163`), so from the first stop onward any run drawing
   over 500 W counts as a heat pump ignoring its off command
   (`:270-272`). The loop goes blind within seconds of the compressor
   starting and drives to full send with the loop some 50 F colder than
   the tank it feeds. The house is heated; the start-up job is not done at
   all. That the timer is the cause is read from the code and matches all
   four runs; the log line that would prove it is on the box.
2. **The designed trigger leans on the wrong number.** `MaxEwtF` is the
   heating curve's limit for the distribution system, not a heat pump
   fact. At maple's 145 the threshold is reachable; at the 170 in the
   branch's ops params for maple and beech it is 150 F, above anything
   maple's heat pump has produced. With defect 1 fixed and nothing else
   changed, that valve stays at keep and the house gets no heat.
3. **`HpStartingUp` has no bounded way out.** A heat pump that runs and
   never satisfies the trigger leaves the valve parked. At keep the small
   loop heats as nearly one mass, the heat pump reaches its upper limit
   and stops itself, and it does so again on each restart. At beech the
   LG reaches its limit about six minutes into a loop-closed start, and
   twice in spring 2025 seven such trips in a row ended in a lockout
   cleared by hand ([`startup-signatures.md`](heat-pump-signatures/startup-signatures.md) "The
   LG at its upper limit"). Repeated limit trips are a worse outcome than
   a destratified tank.
4. **`Blind` mixes two meanings and fails open for both:** missing data,
   and a heat pump thought to be ignoring its command. It is a peer state
   with six transitions out. A restart into it at maple stalled four
   minutes (finding 15).
5. **Others address the valve's relays.** Local control
   (`local_control/house0/tou_base.py:366`), both leaf allies
   (`leaf_ally/house0/all_tanks.py:509`, `buffer_only.py:397`) and standby
   (`local_control/house0/standby.py:122`), branch line numbers, send
   `sieg_valve_hold` or energize relay 14 while initializing. The relays'
   boss is the loop, so these are refused (`auto.lc.n … must be immediate
   boss`, the same README `:331-333`).
6. **The valve cannot be commanded or seen.** No command vocabulary, so
   the admin panel cannot move it without taking relays 14 and 15 from
   under it. The valve machine's report is commented out
   (`trigger_valve_event`), it starts from an assumed `FullyKeep`, and
   every move ends in `SteadyBlend`, a stop included: the triggers into
   `FullySend` and `FullyKeep` are defined and never fired.
7. **`MonitorOnly` does not stop it.** The authority's meaning is no
   physical control action at all; the loop checks only `Standby`.
8. **A control state does not fix a posture.** `HpOff` is keep or send
   depending on the authority, and the control state is re-sent every
   tick whether or not it changed.
9. **Relay outcomes are ignored.** `process_message` takes
   `ActuatorsReady` and `SingleMachineState` only; acks, nacks and the
   relays' full reports fall to "unexpected message". A refused or failed
   relay command leaves the loop believing the move happened. The relay
   actor does hold a failed I2C write as an enforcement target and
   retries it with a critical glitch, so a transient failure heals below
   the loop.
10. **A move in flight has no owner.** Moves are tasks that sleep; a new
    move does not await the old one's end, and a scada stop part way
    leaves relay 14 de-energized with the motor running to the send stop.
11. **A change of boss is noticed on the 30 s tick,** not when the tree is
    rewritten; nothing tells an actor its handle changed.
12. **About 250 lines serve blend control that does not run:** `t1`,
    fractional moves, the keep-seconds arithmetic,
    `process_reset_hp_keep_value`,
    `process_sieg_loop_endpoint_valve_adjustment`. `HpHasLift` names a hot
    loop, not lift.
13. **The simulated House0 cannot exercise it.** The orange and willow
    layouts have no `hp-lwt` or `hp-ewt`, so no test reaches the start-up
    path.

## Related

- A start, as the heat pump shows it, loop open and closed:
  [`startup-signatures.md`](heat-pump-signatures/startup-signatures.md).
- Defrost, as the heat pump shows it: [`defrost-signatures.md`](heat-pump-signatures/defrost-signatures.md).
- Command nodes and replies: [`control-hierarchy.md`](control-hierarchy.md)
  "Command interfaces and replies".
- What comes after the launch fixes:
  [`../explorations/sieg-loop-next.md`](../explorations/sieg-loop-next.md).
