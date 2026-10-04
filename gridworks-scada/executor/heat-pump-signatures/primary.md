Status: Draft · Pass 0 · Updated 2026-10-01

# Heat pump signatures

What this is: what each heat pump model looks like in the scada's
channels when it starts, runs, idles and defrosts, so that code reading
power, flow and lift can tell those states apart per model. One doc per
kind of behaviour, one section per model inside it: code asks one
question across every model ("is the compressor running?", "is this a
defrost?"), and a threshold is set against every model's evidence at
once. Every power threshold here is on `hp-odu-pwr`, the channel of the
unit that holds the compressor; `hp-idu-pwr` and `hp-ctrl-box-pwr` show
circulators and are read on their own where a model's behaviour shows
there. These docs are the evidence; the numbers are acted on in scada
code per model, keyed on the heat pump `DeviceType` the layout binds to
`hp-odu`, and no ops or layout word carries them.

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
- The Samsung stop lag and minimum compressor run. The journal shows the
  draw falling under 80 W within a minute of the call opening on an old
  run and four minutes after it on a run ninety seconds old; the Nolan
  machine opens the call 120 s before an on-peak window on that reading
  until a call-cycling experiment at spruce measures it.
- The tables the code acts on live in `actors/hp_boss/sensing.py`
  (`HP_TRAITS`, `DEFROST_SIGNATURES`), with the sieg loop's `StratProtect`
  constants still outside it; the running / stopped power pair does not
  handle defrost. Where it converges, and what the layout names:
  `control-hierarchy.md` "The heat-pump surface".
- Elm's Arctic high-temp monobloc (MAHRW030ZA (BEH2)-R32) has no
  `DeviceType` value and no signature yet.
