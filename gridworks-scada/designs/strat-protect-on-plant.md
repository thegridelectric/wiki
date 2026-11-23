# strat-protect-on-plant

Status: Draft · Pass 0 · Updated 2026-11-22 · Linear: OPS-705

**EDD: yes** Verified when a simulated Beech from merged code runs a day
against its plant with the scada reading every channel and actuating
every relay, the record replays green against the scada executor's
`plant.md`, and on that plant each `StratProtect` scenario below runs as
a test: a start that parks, waits and opens as LWT reaches the target; an
off honoured late that rests at keep until LWT reaches the target; a
defrost that shuts the send path; a restart that finds the valve; and
every missing-input case that opens the valve and does not guess.

> What this is: `StratProtect` developed and tested against the
> simulated plant instead of against maple and beech. The plant is
> gridworks-terminalasset `ta-plant` stepping the Beech FMU built from
> `modelica/Hydronic.mo` and `Beech.mo`. The strategy's state as it runs
> today is `../executor/sieg-loop.md`; the critique of its state machine
> and names is that file's "Where it falls short". The valve positions
> and the field measurements behind them are in "Decisions" here.

## Why

The loop's logic has been chipped in the field one night window at a
time, with the house as the test bed: the Nov 16 off that left the
Ecodan running nine minutes into a 55 to 64 °C buffer top is one of a
dozen such findings. Each costs a night and risks a cold house or a heat
pump lockout. The plant can run that hour in seconds, at any outdoor
temperature, with any valve, and the same test then pins the rule.

Two things make the plant good enough for this. First, Olly's Beech
model is placed as on the schematic and already takes the valve motor's
two relays as inputs and emits the sieg flow and the loop temperatures.
Second, the one part it models by the motor rather than by the valve,
the split between the keep onset and the keep complete, is exactly where
the strategy's decisions fall, so that part is the first plant change.

## Decisions

- **The Keene-house valves are ball valves and their split is per
  house.** Between keep onset and keep complete the flow split is a
  steep non-linear function of motor seconds at maple and close to
  linear at beech. The positions, in motor seconds from the send stop:

  | Position | Maple (2026-09-28) | Beech (2026-11-13) |
  | --- | --- | --- |
  | Keep onset | 26 | 13 |
  | Half point | 36 | |
  | Keep complete | 56 | 54 |
  | Keep stop | 94 | 75 |

  Beech's flow meter answers 3.5 s late; maple's six crossings agree
  only with a 4 s lag. The source of the lag (pulse period, pico post,
  scada stamp) is unexplained and is dug into with the pico firmware
  work. The three positions are parameters of the hardware layout and
  the loop reads them from there (decided 2026-11-12); the word's shape
  is open, a valve component or fields on the layout word. The plant
  takes the same parameters, so one layout drives both.
- **The off path opens on temperature, not on power.** With hp-boss off
  and the outdoor unit over the idle line, the valve goes to send only
  when LWT is at or above the destination temperature (the
  `House0Hydronic` accessor of the target), and otherwise rests at keep
  while the loop warms. The compressor-running read stays as the gate.
- **A defrost shuts the send path.** During a defrost the heat pump pulls
  heat from the loop; at full keep the loop's own water supplies it and
  the buffer top is untouched. The loop reads the defrost from the heat
  pump's signature (`../executor/heat-pump-signatures/defrost-signatures.md`)
  and from the Modbus four-way-valve bit where a house has it, and goes
  to keep for its duration; HpBoss still reports Off through a defrost,
  so this is the loop's own read.
- **Valve position is two channels.** The homed position, reported only
  while the valve has made at most one continuous move since it last
  ended on a stop, and the reckoned position, always reported. Both
  derived (`derived.channel.gt`) from the two relay energization
  channels with the loop as creator; the unit is `gw1.unit` 001's time
  quantity. No vocabulary change beyond the two channel words.
- **The target's margin and the pacing of the move to send** are decided
  on the plant: one travel, or a first part to the reckoned moment and a
  gradual finish over about 30 s.
- **A rest at send for a plant whose primary pump stops with the
  compressor** is a fact about the plant; where it is declared (layout,
  ops word, observed) is open. Neither House0 plant qualifies today.

## Plan

**Do this next:** step 1, the merge of the plant stack, in the order
below; nothing else here runs until the branches are on their trunks.

1. **Merge the plant's side and run the day.** gridworks-terminalasset
   PR 2 (`katahdin-layout` to `dev`), then PRs 3 to 6 in stack order
   (`ow/plant-seam`, `ow/katahdin-fmu`, `ow/beech-components`,
   `ow/beech-plant`), `ta-katahdin-layout` left out; experiments PR 1
   (`ow/plant-seam`: the plant crossing and loop experiments and the
   beech-sim-compose stack); wiki PR 2 (`ow/katahdin-fmu`) rebased with
   its StratProtect changelog entry corrected (main took its own
   `strat_protect.py`, the blind-reason line did not merge). Then
   correct the three wiki files that contradict the merged plant: the
   OPS-40 hub (keep the plant simple, no Modelica), `build-plant.md`
   against `simulated-actors.md` on which actor sends actuation, and
   `three-family-plants.md` (one body per family, one compiled model per
   house). Then the run: the beech-sim-compose stack from merged `main`
   and `dev`, a day, the scada's persisted reports checked against
   `plant.md` clause by clause, which moves `plant.md` to Verified.
2. **The ball valve in the plant.** `Hydronic.mo` gains a valve whose
   split is a characteristic of position, parameterised by the three
   positions above and a shape (maple's steep middle, beech's near
   line), replacing the motor-time split in `ValveMotor` for the
   Siegenthaler valve; the flow meters take a lag parameter. Beech's
   plant runs beech's numbers, and a maple plant is the same body with
   maple's. The calibration procedure
   (`experiments/procedures/sieg-valve-calibration/`) is the source of
   both; the queued `experiments/future/sieg-keep-ratio-map/` is the map
   of maple's curve.
3. **The strategy's remaining rules**, each with its failing test on the
   plant first: the temperature-gated off; the waiting-to-open test on
   the start; `SiegLoopReady` on the park's motor stop; the Blind split
   into `inputs_missing()` and the running-after-off critical glitch;
   the per-model startup signatures with the Ecodan's late off added;
   the defrost close; `MonitorOnly` energizing nothing (today
   `HoldFullSend` ends its run with `OpenRelay` under Standby, which
   energizes relay 14).
4. **The state machine and its names.** The critique in
   `../executor/sieg-loop.md` "Where it falls short" is the list; the
   items still open there as of this design: a control state that does
   not fix a posture (`HpOff` is keep or send by authority) and the
   every-tick resend; relay outcomes ignored; a move in flight with no
   owner; a change of boss noticed only on the 30 s tick; the blend
   leftovers (`t1`, fractional moves, keep-seconds arithmetic, the two
   endpoint handlers) and `HpHasLift`, which names a hot loop, not lift.
   Each becomes a state or a name with one meaning, or is deleted, and
   the plant tests pin the behaviour across the change.
5. **The edge cases.** The strategy has run only the paths the houses
   happened to take. On the plant, each of these gets a test: an off 65 s
   into a run; two starts inside one hour; a restart in every control
   state with the valve at every position; a relay command refused and
   one that fails at the I2C bus; a missing LWT, EWT, power or
   destination temperature, singly and together; a defrost during a
   start; a start with the loop already hot; the valve at an unknown
   position at boot; MonitorOnly and Standby entered mid-move.
6. **Valve position and the layout word.** The two position channels;
   the valve's positions as layout parameters and the word's shape;
   `sieg-send-flow` zeroed against a shut send path in every house's
   calibration run.

## Open

- The `sieg-flow` and `sieg-send` post-on-change behaviour against the
  layout's deltas, given the BTU picos answer the params exchange with
  version 000 against the scada's 100.
- What the Ecodan and the LG do idle beyond standby draw; the "drawing
  power after an off" line and `HpHasLift` both rest on the House0 heat
  pumps not pulsing the way the Samsung does.
- The zone heat-call periodic emission running 176 s late on the
  2026-09-27 maple strip, which reads as the derived generator's periodic
  emission firing only on an input reading. Not this loop's; a home once
  traced.
- The 2026-09-28 calibration and heat-loss window (laptop capture
  `scratch/broker-capture-20260928-134934.jsonl`): the loop's heat loss
  at 0.05 C resolution and the hp-ewt against hp-lwt same-water offset,
  which earn an experiment folder when read.
- Whether the plant link's broker becomes its own setting before the
  day's run or after; whether the simulated tank module and BTU meter
  path depends on the 5 s flux rate that OPS-672 changes.
- The loop model that would replace the power line altogether (the kept
  loop's volume from the 2026-09-28 closed-start chunks, the heat pump's
  own warming separated from room loss): three ten-minute holds at
  different temperatures with the heat pump off, which the plant can
  supply once step 2 is in.
