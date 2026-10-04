# Dark channels

Status: Draft · Pass 0 · Updated 2026-10-01 · Linear: OPS-570

**EDD: yes** the verification is a replay of the 2026-09-11 and 2026-09-26
fir and beech broker traffic (journal DB pulls) through the alerter: the
new kinds must fire for both houses within their thresholds on 09-11, and
`FleetReboot` must fire once for the 10:45 cold boots; the suite covers the
rules, the replay proves them against the real record.

> What this is: two alert kinds the alerter does not have, named by the two
> ways the 2026-09-11 Millinocket power loss went unnoticed for eleven days
> at beech and twenty at fir. A house whose scada keeps publishing while
> every pico channel is dark, and a fleet that cold-boots in the same
> minute, both pass today's rules in silence.

## The record

2026-09-11 10:44 ET: every house pi lost power and cold-booted at 10:45
(fir, beech, oak, maple confirmed from boot records; elm unchecked).
Beech lost its whole pico bank in that minute (GRI-6); fir lost tank2 and
tank3 for good and its buffer pico went flaky (GRI-8). On 09-26 fir's four
remaining picos collapsed one by one over ninety minutes. In all that time:

- `NoData` never fired: both scadas kept publishing power, relay and
  zone readings, so the house was never silent.
- `CriticalGlitch` never fired: the scada's pico-cycler reported the
  zombie bank as an hourly problem event to the LTN, where it stayed.
- `ScadaRebootLoop` never fired: one boot per house is not a loop, and
  no rule looks across houses.

The journal held the whole story the entire time: last reading per pico
channel, the boot stamps, the relay-1 cycling. Nothing read it.

## The kinds

Named for the condition a human acts on, following the gwalerter spec's
table (`executor/gwalerter.md` "Alert kinds").

| Kind | Means | Evidence |
| --- | --- | --- |
| `DarkChannels` | A capturing node the layout expects to report (a pico, the ADS board, the meter) has sent no reading on any of its channels past the threshold, while the scada itself is heard. One rule at two scopes: a single node dark is a Warning; every pico dark is Critical. | node name, hw uid, channel names, last-heard time |
| `FleetReboot` | Two or more houses announced a boot (a `layout.lite` arrival after a gap) within the same minute. A grid event, not a scada fault; the alert is a prompt to look at every house that morning. | the houses and their boot stamps |

The threshold for `DarkChannels` is the node's own cadence, not one
number: a tank module posts every 60 s and a flow meter's ticklist every
10 s, so "dark" is a multiple of the expected period read from the
layout's capture settings (Open: the multiple; 20 min is the number the
09-26 record would have caught at 18:25).

## Where it reads

From the broker stream through the liveness projection (OPS-546), never
the journal DB: the alerter's 2026-09-15 paging incident came from sharing
a database with observability (OPS-545). The projection already holds
last-heard per scada; this design extends that record to last-heard per
capturing node, which the layout announcement names.

## The glitch path

A sustained all-zombie state is a scada fault a human must see. The
pico-cycler's hourly zombie problem event becomes a Critical glitch after
the first full hour (fire-and-forget, the glitch rule), so `CriticalGlitch`
carries it even before `DarkChannels` exists. Scada-side; recorded here
because the alerter is where the gap showed.

## Open

- The dark multiple per node kind, and whether a disabled node in the
  layout (`DisabledNodeNames`) is excluded or reported once as expected-dark.
- Whether `FleetReboot` wants a second signal (the eGauge power gap at
  each house) to tell a grid event from a coordinated deploy.
- Where the per-node last-heard lives: the liveness projection's record,
  or the alerter's own store.
