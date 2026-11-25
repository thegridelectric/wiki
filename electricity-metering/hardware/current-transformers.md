# Current transformers in hand

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: the clamp-on CTs GridWorks has, what they are, and how
> they relate to what a meter vendor would ship. Measurement error of
> split-core CTs in general is `../research/snap-on-ct-errors.md`.

## The two we have

| photo | part | rating | class | core | where |
|---|---|---|---|---|---|
| [`yhdc.sct013.000.png`](yhdc.sct013.000.png) | YHDC SCT013, 100 A : 50 mA | 100 A | 1 | split | spruce, one turn on the store pump (CT1) and the secondary pump (CT2), into the Gw108's 470 Ω burden |
| [`yhdc.sct006.png`](yhdc.sct006.png) | YHDC SCT006, 20 A : 25 mA | 20 A | 1 | split | spare; the better fit for a 2 A circulator, which sits at 10% of its rating rather than 2% |

Both are YHDC (Beijing Yaohuadechang) class 1 split-core clamps with a
current output (no internal burden; the burden is on the board). Class 1
means ±1% of reading at rated current under IEC 61869-2 conditions, with
no guarantee below 5% of rating and phase error of 3 to 4° at a low
burden, more at 470 Ω (`../research/snap-on-ct-errors.md` "Burden and
phase shift"). At spruce the SCT013 is an indicator and tells on from
off by a factor of 80 in RMS; it is not a meter.

## Are these the CTs EKM ships

No, though they are the same manufacturer's family. EKM's CTs (SCT-013-200,
ESCT-015-200UL, SCT-025-200UL and the BCT solid-core line) are YHDC-made
parts specified to EKM's 26.6 mA secondary at rated current, because the
Omnimeter's input is scaled for 26.6 mA. Ours are the stock 50 mA and
25 mA variants of the same SCT013 and SCT006 bodies. An Omnimeter reading
our clamps would be off by the ratio of the secondaries (50 over 26.6 for
the SCT013) unless its CT ratio setting is adjusted, and the California
type approval that EKM holds lists only EKM's 26.6 mA models
(`hardware/ekm-meter.md`).

## What a metered CT would be instead

For a metered 2 A circulator the research answer is a 5 A-rated
revenue-grade split-core (Dent CT-SRS-005, 0.05 to 10 A; or Continental
Control Systems ACTL-0750-005), ±0.3 to 0.5% from 1% of rating, with the
meter programmed with that CT's phase constant and the CT 25 mm from the
heat-pump feeder. The gw108 board's 470 Ω burden would have to change to
suit a voltage-output or 5 A-class CT.
