# Pico liveness as the fleet ran it (2024-11 to the renovation deploy)

Status: Draft · Pass 0 · Updated 2026-09-08

> What this is: the pico-missing rule the deployed scada code ran on
> the fleet, so a reader of pico data from that window can tell the
> code's behaviour from the picos'. The current rule is in the code
> (`actors/pico_liveness.py`) and the changelog carries the change;
> this page holds what the fleet ran before it, which nothing else
> records once `main` moves.

## The rule the fleet ran

Three HTTP-fed actors (tank module, BTU meter, flow module) each kept
their own copy of "is my pico posting": a `last_heard` stamp, a
threshold, and a 10 s loop sending `PicoMissing` to the pico-cycler and
a `ChannelFlatlined` per channel, meant to repeat at most once a minute.
The copies differed:

- **Tank module** (`api_tank_module.py`, from `908f9fa3`, 2024-11-08):
  threshold one capture period of silence, so a single slow post read
  as missing; and the once-a-minute limit compared the last-report
  timestamp itself to 60, which is always true, so once missing it
  reported every 10 s loop tick.
- **BTU meter** (`api_btu_meter.py`, from `1680afd8`, 2025-09-24):
  threshold 2.5 capture periods, rate limit correct.
- **Flow module** (`api_flow_module.py`): threshold 2.5 times the
  pico's publish-after setting, rate limit correct, `PicoMissing`
  only, no `ChannelFlatlined`.

The pico-cycler (`pico_cycler.py`) answered any `PicoMissing` from
`PicosLive` by opening the shared VDC relay for 5 s, closing it, and
waiting 60 s for the picos to return. Its guard against reacting to a
pico it had just cut, "ignore `PicoMissing` within 60 s of a cycle"
(from `4bd10512`, 2025-01-09), stamped its clock at the relay close, so
the 5 s open window was unguarded: a `PicoMissing` arriving then marked
the pico Flatlined although the cycler had cut it. With any zombie on
the roster the cycler also power-cycled the bus every 30 min
(`SHAKE_ZOMBIE_HR = 0.5`, from `4f84e366`, 2024-11-11).

## Its signature in the data

- A tank pico's single late post could trigger a whole-bus VDC cycle,
  rebooting every pico on the house; the picos then rejoined wifi as a
  herd. The 2026-08-03 pico gap analysis (`experiments/
  2026-08-03-pico-gap-analysis/`) measured the herd effect on spruce
  and the 30 min shake rhythm; the tank-side false trigger is a second
  source of bus cycles in the same data, not separated there.
- A tank pico reported missing kept reporting every 10 s until it
  posted, so `PicoMissing` counts in the journal over-count tank picos
  relative to BTU and flow picos by up to 6x per minute of silence.
- A Flatlined roster row inside the 5 s after a relay open is the guard
  gap, not a pico fault.

## What replaced it

Scada `e0029d3d` on `jm/spruce-unlimbo` (2026-09-08): one
`PicoLiveness` rule for all three actors (missing after 2.5 expected
post periods, first report at the crossing, one a minute while silent,
a post resets it) and the cycler guard clock started at the relay-open
confirmation. The zombie shake cadence is unchanged. This page's window
closes on the date that commit reaches the fleet boxes; record it here
then.
