Status: Draft · Pass 0 · Updated 2026-09-24

# Heat pump signatures

What this is: what each heat pump model looks like in the scada's
channels when it starts, runs, idles and defrosts, so that code reading
power, flow and lift can tell those states apart per model. One doc per
kind of behaviour, one section per model inside it: code asks one
question across every model ("is the compressor running?", "is this a
defrost?"), and a threshold is set against every model's evidence at
once.

| Doc | What it holds |
| --- | --- |
| [`startup-signatures.md`](startup-signatures.md) | a start: delay, power ramp, lift, loop open and closed; running/stopped thresholds; the LG at its limit; how the channels report |
| [`running-signatures.md`](running-signatures.md) | steady running: power, flow, lift |
| [`idle-signatures.md`](idle-signatures.md) | compressor off: standby draw and what the unit does on its own while idle |
| [`defrost-signatures.md`](defrost-signatures.md) | a defrost, and how to tell it from a stop |

## Coverage

| Model | House | Start-up | Running | Idle | Defrost |
| --- | --- | --- | --- | --- | --- |
| Mitsubishi Ecodan | maple | measured | in start-up | standby only | measured |
| LG | beech | measured | in start-up | standby only | Open |
| Samsung AE055FEYMCG | spruce | measured | measured | measured | Open |

"In start-up" and "standby only" mean the numbers sit in
`startup-signatures.md` and have not been broken out.

## Open

- Defrost at spruce and beech.
- Idle behaviour beyond standby draw at maple and beech.
