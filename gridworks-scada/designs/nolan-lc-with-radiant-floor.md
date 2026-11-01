# Nolan local control with the radiant floor as storage

Status: Draft · Pass 0 · Updated 2026-11-01 · Linear: OPS-648

**EDD: yes** the verification is a cold night at spruce in the journal:
the living-room air stays within 2 F of its setpoint through the night
with no `critical-zone-cold` glitch, and the heat pump's calls line up
with the slab's state as the model predicts them.

> What this is: the Nolan buffer-only local control treats the buffer
> tank as the whole store. At spruce the radiant slab is a second store
> with its own charge state and a lag of hours. This design brings the
> slab's state into the storage the local control reasons about. The
> modeling still has to be worked out; this file keeps the record that
> motivates it and the questions to answer first.

## The night that showed it (2026-10-31 ET)

The first freezing night of the season at spruce. Outdoor temperature at
Millinocket fell from 59 F mid-afternoon on 2026-10-30 to 32 F at 07:10.
The night before, no spruce zone had called for heat.

The control did what it is designed to do. Spruce ran `main` at
`6106170b`, the Nolan buffer-only TOU controller with the 90 F charge
and 130 F full band and the Versant weekday on-peak windows. Every
heat-pump edge matches the band:

| time ET | event | buffer reading |
|---|---|---|
| 00:19:54 | call on | top fell under 90 F |
| 01:39:54 | call off | bottom reached 130 F |
| 05:42:55 | call on | top at 89.9 F |
| 07:19:56 | call off | bottom reached 130 F (a Saturday, so no 07:00 on-peak) |

The living room cooled anyway. The cold-watch raised `critical-zone-cold`
at 03:27:55 ET ("living-rm at 66.8 F, setpoint 69.0 F") while the buffer
top read 132 F and the distribution supply 126 F. Heat was available in
the buffer and was not reaching the room:

- The living room's emitter is the radiant slab. Its floor sensor read
  68.3 F at 23:00, under the room air, after days without a call. It
  passed the room air near 02:00 and had a usable lead only hours
  later: 71 F at 06:00, 73.4 F at 10:00. All night the slab charged
  while the room fell from 68.9 F to 65.4 F.
- Flow to the slab was about 0.55 gpm with a 36 F drop while the supply
  was hot, roughly 10 kBTU/h, and rose to about 1.6 gpm once the supply
  fell toward 95 F. That looks like a mixing valve throttling the hot
  side; to be checked on site.
- The living room's fan-coil circuit never called. That lever is the
  spruce-unlimbo thermostat-and-zone-control spoke's, Linear OPS-532.
- Upstairs called from 22:24 to 01:45 and overshot from 68 F to 75.7 F.
  When that call ended, all three critical zones started cooling about
  three times faster. From then on the slab was the only heat path into
  the house.

The cold-watch could not escalate: `HouseCold` goes to the local control
only with the stores empty, and the buffer was full. A `ColdOverride`
would have closed the call into a buffer already at 130 F.

The record is the journal under `hw1.isone.me.versant.keene.spruce.scada`
from 2026-10-30 16:00 to 2026-10-31 11:00 ET; `experiments/spot_check.py`
reads it.

## What the design has to work out

The slab is storage with a state the control cannot see in the buffer
band. A full buffer and a cold slab is a house about to go cold; a warm
slab and an empty buffer is a house with hours in hand. The local
control needs the slab's charge in the same ledger as the buffer's.

- **The slab model.** Start from our own analysis of the radiant system
  in `wiki/heating-system-design/`: the two-lump floor-and-room model
  with G (floor to room, kW per F) and C (floor heat capacity, kWh per
  F) per zone, fitted to spruce's journal, Linear OPS-601. This night is
  a clean dataset for that fit: a slab starting under the room air, a
  long charge, a cold outdoors.
- **What the control does with it.** Candidates: charge the slab ahead
  of a forecast cold night while off-peak (the heating forecast had the
  cold coming); hold the buffer band aside when the slab is under the
  room air; let the slab's state count toward "stores empty" in the
  cold-watch so a cold slab can escalate.
- **The flow to the slab.** Why 0.55 gpm when the supply is hot. A
  mixing valve setpoint, a zone valve, or the loop itself. A site fact
  before a control fact.
- **Which layouts.** Spruce has three slab zones with floor sensors. The
  Knife's Edge homes put the store under the floor, where the slab is
  the store. The model should serve both without a per-house special.

## Do this next

Pull the 2026-10-30 to 10-31 window into `experiments/spruce-radiant-slab/`
and fit G and C for the living room from it, so the first control
question (how long a cold slab takes to pass the room air at a given
supply) has a measured answer.
