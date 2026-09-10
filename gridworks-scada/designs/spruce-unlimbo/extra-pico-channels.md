# Extra pico channels: required or tracked (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392

> What this is: the decision, per channel, of which readings from
> spruce's three free-standing pico tank modules (fancoil, floor1,
> pipes1) the Nolan layout word REQUIRES and which are optional things
> the house tracks. Before the `jm/spruce-unlimbo` launch: the layout
> that ships must state the requirement, and the cycler now reports
> those picos by name so a missing one is visible in the journal.

## The three picos

Re-energized on site 2026-09 after being disconnected 2026-08-10; the
scada on spruce (`actual-spruce` `69d5d6ec`) reports each in its pico
roster. Each is a `GridworksTankModule3` reading three thermistor
depths under its own actor name (`tlayouts/spruce_sema_gen.py`,
`extra_tank_modules`; generator `nolan_sema_gen.py`
`emit_extra_tank_modules`):

| Actor | Pico | Depth channels (each `-device` WaterTempCTimes1000 and `-micro-v` MicroVolts) |
| --- | --- | --- |
| `fancoil` | pico_239531 | `fancoil-depth1..3` |
| `floor1` | pico_71156b | `floor1-depth1..3` |
| `pipes1` | pico_672531 | `pipes1-depth1..3` |

The seven identity derived channels built on them
(`extra_identity_deriveds`):

| Derived | Source | Meaning |
| --- | --- | --- |
| `fancoil-swt` | `fancoil-depth1-device` | fancoil circuit supply |
| `fancoil-rwt` | `fancoil-depth2-device` | fancoil circuit return |
| `floor-swt` | `pipes1-depth1-device` | floor circuit supply |
| `floor-rwt` | `pipes1-depth2-device` | floor circuit return |
| `zone1-bedrooms-floor-temp` | `floor1-depth1-device` | slab temperature, zone 1 |
| `zone2-living-rm-floor-temp` | `floor1-depth2-device` | slab temperature, zone 2 |
| `zone4-garage-floor-temp` | `floor1-depth3-device` | slab temperature, zone 4 |

`fancoil-depth3` and `pipes1-depth3` feed no derived channel.

## The question

`gw.nolan.layout` lists what a Nolan house must have in
`RequiredSensing` and `HydronicChannelExistence` (heat-pump and pump
power, the BTU and tank channels). None of the channels above is in
either list today: the word treats all three picos and their deriveds
as optional. Decide, per row:

- **Required by the layout word**: local control or the settlement
  path reads it, so a Nolan house without it is not a Nolan house. A
  required channel is named in the word (a new version if the latest
  is published; in place if staging) and the scada's coverage check
  fails without it.
- **Tracked**: spruce carries it because the sensor is on the wall;
  another Nolan house may not. It stays a per-home entry in the
  generator config and nothing depends on it.

The likely split: the circuit supply and return pairs (`fancoil-swt`
and `-rwt`, `floor-swt` and `-rwt`) are what a per-circuit control
loop and the zone/circuit model would read, so they are candidates
for required, keyed to the circuit rather than to the pico name. The
slab temperatures are tracked. That is a proposal to grill, not a
decision.

## Done when

- Each of the sixteen rows above has a decision recorded here.
- The required ones are named in the Nolan layout word, and
  `spruce_sema_gen.py` emits them under the required names.
- The scada's coverage check refuses a Nolan layout missing a
  required one, with a test.
- Snapshot on spruce shows every pico posting after the deployed
  layout regenerates (`starter-scripts/snap_watch.py`).

## Witnessed 2026-09-10

The production journal has all three posting from 2026-09-09 20:00 UTC
(the re-energizing) to 2026-09-10 11:29 UTC, about 60 readings an
hour per channel; `fancoil-depth3` and `pipes1-depth3` read the 3.3 V
rail (no thermistor on depth 3). At 07:32:40 EDT the box lost its
ethernet carrier and the GridWorks SSID at once (the router was replaced), the
scada died on its watchdog and restarted, and since then none of the
five tank modules (buffer, tank1, fancoil, floor1, pipes1) has posted
while the four BTU picos do; the cycler has held all five as Zombie
and shaken them every 30 min without effect. Cause, found with the starter-scripts receiver run on port 8000
in the scada's place for 150 s (only the four BTU boards posted, all to
eth0 .116) and the router's lease log: the tank modules post to the
BaseUrl `http://192.168.2.200:8000` in their comms config, and the pi
held .200 on wlan0 by DHCP from the old router; the new router leased .7. The
BTU boards post to the eth0 address and never noticed. Restored at
13:44 EDT with a runtime alias, then made persistent with
`nmcli con mod "Wired connection 1" +ipv4.addresses 192.168.2.200/24`
(recorded in the box README); all nine picos read Alive in the journal
at 17:39 UTC and the address survived the 14:31 EDT reboot. Still to
do on the new router (a TP-Link, web UI at 192.168.2.1): keep .200 out
of its DHCP pool or reserve it for the pi's eth0. The lesson for the
layout: a pico's BaseUrl is an address the house must guarantee, and
nothing in the layout or the scada says which address that is.

The same note lives in three more places; clear all four together when
the new router keeps .200 for the pi:

- the spruce box's `~/README.md`, "Non-repo state placed on this box",
  the 2026-09-10 runtime-alias entry;
- Claude's session memory, `project-spruce-new-router-scada-ip.md`
  (`~/.claude/projects/-Users-jessica-GridWorks/memory/`);
- the comment of 2026-09-10 on [GRI-11](https://linear.app/gridworks/issue/GRI-11/spruce).
