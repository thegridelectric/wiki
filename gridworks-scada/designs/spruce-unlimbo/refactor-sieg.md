# refactor-sieg

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). Maple and beech
> keep the sieg loop, so the branch cannot go onto them until the loop
> has run on the new code. The
> sieg-loop control has never run unsupervised in the field for a long
> stretch, so the hp-boss test work was its first exercise only on the
> sieg-less side; treat it as unverified. Field confidence comes only
> through the design's EDD bar (bench and box runs), not the suite.
> A launch item.

## Carried from hp-boss's first pass

- **Uncomment the House0 pairs in
  `gridworks-scada/tests/actors/test_hp_boss_live.py`** (`PAIRS`:
  `house0`, `house0-sim`). They are off because admin's TurnOn on a
  sieg layout parks hp-boss in `PreparingToTurnOn` until the sieg-loop
  actor sends `SiegLoopReady`, or `TURN_ON_ANYWAY_S` (120 s) passes.
  Restoring them means deciding what the live test does on that leg:
  drive the sieg-loop actor to ready on the sim plant, or shorten
  `TURN_ON_ANYWAY_S` in the test settings. The in-process
  `test_hp_boss.py` already runs all three pairs by delivering
  `SiegLoopReady` by hand.
- The tests the sieg leg still owes beyond the live pairs (no ready
  message and `TURN_ON_ANYWAY_S` closing the relay anyway, the constant
  shortened through settings) are gap 1 of
  `../spruce-settled/relay-tests.md`; that file's other gaps wait for
  the deployed line.
- hp-boss's strategy split (readiness gate × command channel) is a
  proposal in `../spruce-settled/hp-twin.md`; the sieg-loop actor is the first gate
  provider.
