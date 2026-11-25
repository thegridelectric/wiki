# improved-pump-doctor

Status: Draft · Pass 0 · Updated 2026-11-24 · Linear: OPS-714

**EDD: yes** verified by the 0-10 V identification windows on the fleet's
circulators under admin, by the new doctor replayed against two journal
traces (a real Ecocirc stall, beech 2026-01-22; a dead flow meter under a
running pump, beech 2026-11-24), and by a field window where the doctor
runs on a live house.

> What this is: the pump doctors judge a pump by its loop's flow meter,
> so a dead flow meter reads as a dead pump. This design puts each
> circulator's model in the layout, identifies the models in the field by
> their 0-10 V response, and rewrites the doctor to judge the pump's power
> trace, run only for pump models that stall, and name the flow meter when
> the meter is what has died.

## Why

Beech, 2026-11-24 11:16 to 11:26 ET. Local control closed the store pump
relay for the first store charge of the season. The pump drew 20 to 24 W,
its running draw at the 65% 0-10 V setting all last winter, and the store
hot-pipe thermistor jumped 7 °C within seconds. The store flow channel
read zero throughout. The store pump doctor cycled the pump three times,
saw no flow, and sent a Critical glitch, "Store Pump Failed!!". Exhausted,
it then went quiet: the monitor re-triggered it every two minutes to
12:00 and it returned at once each time, the pump running and the store
charging underneath. The cost of a dead meter is the page and three
15 s pump interruptions per charge start.

The store flow meter has read zero since the Gw101 BTU meters went in on
2026-10-25 (tlayouts `a3630bd`). The admin check of 2026-10-28 ran the
pump 12 minutes at 22 W with the pipe temperatures moving and store-flow
at zero, and nobody read the flow channel.

Of the fourteen Critical pump-failure glitches in the last 400 days, two
others were also meter dropouts under a running pump (oak dist,
2026-10-27 and 10-28, at 72 W). Elm's dist pump doctor has fired 877
times in that span. The doctor is the one procedural recovery the scada
has, and its verdict is wrong in a way that pages people and parks a
store.

## Facts

From the journal (second-resolution `*-pump-pwr` and `*-flow` around
each Critical glitch, and OPS-636's on/off table):

| Pump state | Power trace | Flow |
|---|---|---|
| Ecocirc stalled start | one-sample blip of 4 to 7 W (elm dist 16 to 17 W), then 1 to 5 W held | 0 |
| Healthy start, any model | the same blip, then the running level within 2 to 3 s | appears 2 to 3 s after |
| Running, Ecocirc class | store 15 to 22 W at 65%; beech dist 7 to 10 W; elm dist 18 to 34 W | steady |
| Running, Grundfos class | oak dist 60 to 72 W; fir store 59 to 67 W; spruce 180 to 199 W | steady |
| At rest, every pump | -1 to 1 W, a lone 5 W sample now and then | 0 |

Clean stall examples: beech store 2026-01-22 11:36 to 11:44 (four relay
closes, each a blip then 0 to 1 W, then at 11:55 the same pump starts at
20 W and 1.9 gpm); oak store 2026-02-02 16:09 to 16:16 (the same, four
times); elm dist 2026-01-13 and 01-15 (the stalled pump hums at 4 to 5 W
for minutes).

Model facts already measured:

- Bell & Gossett ecocirc+ 20-18: OFF below 1.20 V rising, MIN from 1.50 V,
  MAX at 10 V; below 1.19 V falling the input is disabled and the pump
  runs at its own dial setting. The fleet's original circulator.
- Grundfos UPMS 20-78 F 165 AR, measured on spruce's secondary pump
  (`experiments/archive/2026-09-06-spruce-pump-speed-sweep/`): 0 V and
  0.7 V run at minimum speed, 1.5 to 2.5 V stops it, 3 V restarts it,
  linear 3.5 to 8.5 V at 1.45 gpm/V, flat from 9 V. Signal loss means
  minimum speed. The same hydraulic family ships in a constant-curve
  variant with no 0-10 V input; the device type is minted from the full
  designation with the signal letters.
- Which pumps are which: every pump at spruce is a Grundfos. A few
  circulators elsewhere were replaced with UPMS 20-78 F units, and the
  ones that stalled repeatedly were among them; which positions is not
  recorded anywhere. Power alone misreads the model: fir store's 59 to 67 W was an
  ecocirc+ at 0 V on a full dial (see "Identification results"). The primary pumps at elm, maple and spruce belong to their heat
  pumps and are of unknown make; the scada does not drive them.

Where the doctor lives: `actors/procedural/` (`StorePumpMonitor`,
`StorePumpDoctor`, the dist pair), hosted by the local-control TOU base.
The monitor fires on relay closed, charge/discharge not charging and
`store-flow` below 0.5 gpm after a 10 s startup delay; the doctor opens
the relay, sets 0-10 V to zero, waits 15 s, closes the relay and waits 15
s for flow, three attempts, then the Critical glitch. The threshold, the
delay and the attempt bound are module constants. `gw.circulator` (000,
staging) lists each pump with its role, running, flow, power, CT and
0-10 V channels and says nothing about what the pump is. `gw1.device.type`
is a versioned, additive enum with no pump values.

## Decisions

**1. A circulator's model is a fact of the layout.** `gw.circulator` gains
a `DeviceType` field (staging, edited in place) naming a `gw1.device.type`
value minted per distinct behaviour rather than per SKU: `BellGossettEcocirc2018`
and `GrundfosUpms2078F165AR` first. A `circulator.pump.device.type.gt`
record per value states what the doctor and the 0-10 V path read:
`ControlSignal` (None, Pwm, ZeroTen, PwmAndZeroTen), `ZeroVoltsMeans`
(Off, DefaultCurve, MinSpeed), the stop band and usable band in volts,
`Stalls` (whether the model is known to stall on start), the stalled
power ceiling and the running power floor at the model's lowest
controllable speed. The sema edits follow `sema-CLAUDE.md` with its
read-receipt, in their own sitting.

**2. The field identifies each pump by its 0-10 V response.** Admin runs
the pump at its default level, steps to 0 V for 60 s, to 2 V for 60 s,
and back. A UPMS runs at minimum at 0 V and stops at 2 V; an Ecocirc
leaves 0-10 V control at 0 V and keeps running on its own curve at 2 V.
Power and flow decide. The scada's running power at the default level is
recorded for each pump as the first `RunningPowerMinW` evidence. A
person drives admin and a session records. Candidates: the pumps a doctor runs on
whose power signature leaves the model in doubt, and the two Grundfos-class
pumps, where the test tells the 0-10 V UPMS from its constant-curve
variant: oak dist, fir store, elm dist and elm secondary. The store pumps
at oak, fir, maple and elm and the dist pumps at fir and maple draw
Ecocirc-class power and are typed from the signature, with the power row
below as the evidence. Spruce is known.
Hazard: an Ecocirc on a loop with a closed valve deadheads at 0 V, so the
loop's valve posture is checked before each step.

**3. The doctor judges power, and only for models that stall.** The
monitor fires on relay closed and the pump's power below its model's
stalled ceiling after the startup delay. The doctor's attempt succeeds
when power rises above the running floor within the bound. The flow
reading plays no part in the verdict. A `gw.circulator` whose model has `Stalls` false gets no doctor. A
pump with no `DeviceType` gets no doctor and a Warning glitch at boot
naming the pump, so an unidentified pump is a visible gap. The
thresholds come from the device-type record and the layout; the module
constants go.

**4. The flow meter gets its own verdict.** A pump above its running floor
for 60 s whose loop flow stays below threshold is a Warning glitch on the
BTU meter node, "flow meter reads zero under a running pump", with the
power and flow in the details. That is the beech case and the oak case,
and it calls for a field visit to the meter. The pump is left running.

**5. Flow stays as a witness.** Each doctor glitch's details include the
power trace and the flow reading, so a reader can check the verdict
against both.

## Identification results

Beech, 2026-11-24, admin stepping the 0-10 V output with the pump running,
power from the eGauge in the journal (captured on a 4 W change), flow from
the loop's BTU meter.

| Pump | Default level | Power at default | 0 V | 2 V | Verdict |
|---|---|---|---|---|---|
| beech store | 6.5 V | 18 to 19 W | held 18 W, 60 s | 5 W within 2 s, held | Ecocirc |
| beech dist | 3.5 V | 7 to 8 W, 2.0 gpm | 6 to 7 W, 1.5 to 1.9 gpm | 1.3 gpm, power within 4 W of 6 | Ecocirc |
| oak dist | 5.0 V | 5 W, 2.0 gpm | 72 W, 6.0 gpm within 5 s | 0 W, 0 gpm within 2 s | 0-10 V pump that stops at 2 V and runs flat out at 0 V |
| fir store | 3.0 V | 9 W, 3.8 gpm | 68 W, 10.2 gpm within 3 s | 22 then 4 W, 2.8 to 3.0 gpm | Ecocirc, dial at full |
| spruce secondary | 7.6 V | 190 to 197 W, 7.8 gpm | 45 to 70 W oscillating, 0.9 to 1.3 gpm | 3 W, 0 gpm within 1 s | Grundfos UPMS, as in the September sweep |
| elm dist | 2.5 V | 21 to 26 W, 2.4 to 2.7 gpm | 21 to 22 W, 2.5 gpm | 18 to 19 W, 1.1 to 1.4 gpm | ecocirc+; restarts itself every 50 to 60 s while running (GRI-10) |
| elm secondary | 2.1 V | 6 to 8 W, 4.5 gpm | 3 then 1 W, 0 gpm within 2 s | 9 then 5 W, 4.2 gpm | stops at 0 V, runs at 2 V: an ecocirc+ whose disabled-input state is OFF, or another model; label on visit |

The ecocirc+ 20-18 manual (Xylem 671075208, "Control mode for analog
voltage input") puts the pump OFF below 1.20 V on a rising signal, at
MIN from 1.50 V and at MAX at 10 V, and disables the input below 1.19 V
on a falling signal, after which the pump runs at its own dial setting.
Beech store, beech dist and fir store all match it: they run at 2 V (the
MIN band) and run on at 0 V, each at a different power because each
pump's dial is set differently (beech store 18 W, fir store 68 W). So
for an Ecocirc the 0 V power is an installation fact, not a model fact,
and the record states only that 0 V means the dial setting, which can
be OFF: elm secondary stopped at 0 V and ran at 2 V, the manual's
"Input is disabled, OFF" rows taken literally. Elm secondary is fed
through two relays, `secondary-pump-relay` and
`secondary-pump-hack-relay`; closing the first alone leaves it unpowered. The plain
ecocirc 20-18 manual (Xylem 671075207) has no 0-10 V input at all, so
every fleet pump that answers the 0-10 V output is an ecocirc+ 20-18; the
device-type value is named for the plus model. Spruce secondary repeated the September sweep: minimum speed at 0 V,
stopped at 2 V, back to full within 3 s. Oak dist stopped at 2 V like the
UPMS but ran at full speed at 0 V. Grundfos's own UPMS documents disagree
on exactly this point: the data booklet (literature 6910086, "0-10 VDC")
says "The pump will run at its minimum speed if the signal fails (cable
break)" and its profile R table starts at 0.5 V; the installation and
operating instructions (literature 6910090, 8.2.4) say "The pump will run
at its maximum speed if the signal fails" and add the row "0 < U ≤ 0.5
Max. speed". Both put standby at 0.5 to 1 V, hysteresis at 1 to 2 V and
minimum speed at 2 to 3 V, which both pumps obeyed at 2 V. So oak dist is
a UPMS (the oak house issue GRI-7 records a Grundfos on the dist
position) of the revision the instructions describe, and spruce secondary
is one of the revision the booklet describes. They are two device-type
values, differing only in what 0 V means, until the labels say otherwise.
Neither revision stops at 0 V; a UPMS stops only in the 0.5 to 2 V band. Its historical 60 to 72 W is the full-speed
draw; at the deployed 5.0 V it draws 5 W for 2.0 gpm, inside the stall band. The store flow meter read zero throughout, so power alone
decided the store pump. The store pump at 2 V drew 5 W, the stalled
Ecocirc ceiling: this model's running floor at a low level sits inside
the stall band, so the floor is per level.

The same sitting replayed the Why section live. Local control closed the
store relay at 18:14:48 for a charge, the pump drew 19 to 24 W and the
store hot pipe rose 8 °C, and the monitor triggered the doctor at
18:16:48, 18:19:19 and 18:21:50 on the dead meter; each attempt opened
the relay, closed it 15 s later and saw no flow. Admin took the pump at
18:22:12, inside the third attempt, before the Critical fired. Each
relay close in the journal shows the healthy-start signature: a 5 to 6 W
blip, a 1 W sample, the running level within 3 to 5 s.

## Shipped ahead of the gate

2026-11-24 evening, on the human's go, a bounded chip on scada
`jm/pump-doctor-power-guard` rolled to beech: both monitors read the
circulator's power channel and treat power above a 6 W stall ceiling as
running (no doctor; one Warning on the flow meter's node after 60 s of
no flow), and both doctors count a running draw on two consecutive polls
as a successful attempt. The ceiling is a module constant; decision 1
moves it to the device-type record and decision 3's per-level floor
replaces it. Changelog entry of the same date.

## Plan

1. Identification windows (bring-up, driven by hand through admin): the 0 V / 2 V
   protocol on each candidate pump, one house per sitting, results in a
   table in this file, then in the device-type records.
2. Sema: the `gw1.device.type` values, `circulator.pump.device.type.gt`
   000, `DeviceType` on `gw.circulator`; axiom: every circulator's
   `DeviceType` names a pump record; snapshots regenerated in scada and
   tlayouts.
3. tlayouts: `CirculatorSpec` takes `device_type`; every gen states it;
   layouts regenerated and rolled with `roll_compare.py`.
4. Scada: the monitors and doctors read the circulator record and its
   device type; power replaces flow in monitor and doctor; the meter
   Warning; the boot Warning for a typeless pump. Tests: the two journal
   traces replayed (a stall that the doctor pursues, a running pump under
   a dead meter that it leaves alone and reports), the typeless-pump boot
   Warning, the attempt bookkeeping.
5. Field window: one house, one real pump start under the new doctor,
   read from the journal.

## Open

- Whether the scada should ever send 0 V to a UPMS: on one revision it
  means minimum speed, on the other full speed, and the two look alike.
  The 0-10 V path could refuse levels below the model's usable band.
- Which pumps are UPMS. Step 1 answers it. Where a pump is a constant-curve
  UPMS with no signal input, the test shows no response and the pump is
  recorded as such.
- The running floor at low 0-10 V levels: oak dist runs at 4 to 5 W on
  low speed, inside the at-rest jitter's rare 5 W sample. The floor is per
  model and per level, so the record may need the floor at the minimum
  level and the monitor may need two consecutive samples.
- eGauge capture: beech's pump power captures on a 4 W change and syncs
  every 5 minutes. A stalled pump's fall from the blip to 1 W is a 6 W
  change and is captured; a stall that settles within 4 W of the blip
  would wait for the sync. To check against the traces.
- Whether Nolan and Katahdin houses get the doctor; today only the House0
  TOU base hosts it.
- The admin panel showing the pump model (OPS-27 thread 3) stays out.

## Do this next

Read beech's first store charge under scada `246a3073` from the journal
and the box log: no doctor trigger, one Warning on `store-btu` about a
minute in, the pump left running. Then photograph the labels and dials of
elm secondary, oak dist, elm dist and fir store at the next visits, and
start Plan step 2 (the sema words) with the four behaviours in
"Identification results" as the device-type values.

## On completion

The pump device types and the doctor's rules distill into the scada
executor `procedural-interrupts.md` and `hardware-layout.md`, the sema
words hold the model facts, OPS-27 is cancelled with its threads 1 and 2
absorbed here, the pump-device-type spoke of OPS-532 goes, and this file
goes.
