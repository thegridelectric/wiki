# beech-sim-day

Status: Draft · Pass 0 · Updated 2026-11-18

**EDD: yes** Verified when a simulated Beech started from merged code
runs a day against its plant with its scada reading every channel from
the plant and actuating its relays, and the record replays green against
the scada executor's `plant.md`, which then moves to `Verified`.

> What this is: the step from a plant seam that runs in the field
> (gridworks-scada 2b2028f0) to a simulated house that runs for a day on
> merged code alone. The scada's side of the contract is
> `wiki/gridworks-scada/executor/plant.md`; the decisions are in
> [`../primary.md`](../primary.md).

## Do this next

Merge the plant's side. Nothing here runs until the branches below are
on their trunks, and they are a reviewer's work, in this order.

1. gridworks-terminalasset PR 2 (`katahdin-layout` to `dev`), the base
   of the stack.
2. gridworks-terminalasset PRs 3 to 6, in stack order, each containing
   the one before. `ta-katahdin-layout`, which builds a Katahdin layout
   from a House0 one, does not go in (decision 7).
3. experiments PR 1 (`ow/plant-seam`): `2026-11-10-plant-crossing`,
   `2026-11-10-plant-loop`, `2026-11-11-beech-sim-compose`, the compose
   stack and the scada image recipe.
4. wiki PR 2 (`ow/katahdin-fmu`), the changelog entries for the above,
   rebased onto main with the three orderings resolved by hand. Its
   StratProtect entry goes: main took its own `strat_protect.py` and
   the blind-reason line did not merge.
5. Correct the three wiki files that contradict the merged plant: the
   OPS-40 hub (keep the plant simple, no Modelica), `build-plant.md`
   against `simulated-actors.md` on which actor sends actuation, and
   `three-family-plants.md` (one body per family and one compiled model
   per house, as built).

Then the run: the beech-sim-compose stack from merged `main` and `dev`,
a day, the scada's persisted reports as the record, checked against
`plant.md` clause by clause.

## The branches

| Repo | Branch | PR | Note |
| --- | --- | --- | --- |
| gridworks-terminalasset | `katahdin-layout` | 2 | base of the four below; merges to `dev` first |
| gridworks-terminalasset | `ow/plant-seam`, `ow/katahdin-fmu`, `ow/beech-components`, `ow/beech-plant` | 3 to 6 | a stack, each containing the one before |
| experiments | `ow/plant-seam` | 1 | the plant experiments and the compose reproducer |
| wiki | `ow/katahdin-fmu` | 2 | changelog entries; merges when the code does |

## Open

- Whether the plant link's broker becomes its own setting before the
  day's run or after (decision 5). Today the scada's link is a second
  MQTT client on its upstream broker settings, TLS ignored, and the
  plant sends on its own GNode connection.
- Whether the simulated tank module and BTU meter path, which takes each
  flux as a pico post, depends on the steady 5 s flux rate that OPS-672
  changes.
