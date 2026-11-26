# The dev-sim twins come from tlayouts

Status: Draft · Pass 0 · Updated 2026-11-26

**EDD: no** build-out work, verified by one play of the pod on the copied
houses, with each TerminalAsset's `g_nodes` row in the journal equal to
the seed's id, and by a check that the committed houses equal the pinned
tlayouts output.

> What this is: the plan for leg 4 of OPS-720 as its own unit of work.
> The simulated stack in `experiments/dev-sim/` stops generating its two
> houses. It copies beech1 and beech2 from tlayouts output at a pinned
> commit, takes the FLO's GNode and the two deeds from the registry's
> export, and deletes its own generator.

## Why

The stack makes its houses with its own generator, `beech_sim_gen.py`
(244 lines) run by `gen_layout.sh`. Read on 2026-11-26:

- It starts from orange's `HOUSE0_SIM` (`beech_sim_gen.py:42`) and
  changes the zones and tanks. It does not read the real Beech's spec.
- It mints GNodeIds with `uuid4`, builds the `ta.deed`, and writes the
  FLO's `g.node.gt`.
- It edits the generated records afterwards: `MarketMakerAlias`,
  `SeasonalStorageMode`, and every web server set not to serve.
- The houses are `…keene.beech.at` and `…keene.beech.buf`, with the
  storage mode in the alias.

tlayouts now has what the generator stood in for. At `d907d9e`,
`simulate()` builds a sim house from a real spec and `sim_gen.py` writes
`output/beech1-sim/` and `output/beech2-sim/`, with identity from the
registry's export. Read on 2026-11-26: the two layouts differ only in
`GNodes` and in each channel's `TerminalAssetAlias`, the two operational
params differ only in `ScadaAlias`, both say `AllTanks`, and
`MarketMakerAlias` is already `d1.isone.me.versant.keene`.

Until this is done the stack's tlayouts pin stays at `240fc01`. Past
`5313ab2` the stack's generator does not run, so no tlayouts change
since then can reach the pod.

## What the generator does that a copy does not

Each row needs a home before the generator can go.

| Thing | Today | Proposed home |
|---|---|---|
| The variant: `BufferOnly` on the second house | a dict edit after generation | `dev-sim/`: one step sets beech2's `SeasonalStorageMode` on the copied params, decoded and written through the snapshot class (decided 2026-11-26) |
| The display names `beech-at` and `beech-buf` | written into the layout's GNodes by the generator, then inserted into the journal's `g_nodes` by `journal_boot.py` | Open: see "The journal is a projection" |
| The web server does not serve | `unserved()` in the generator | tlayouts' `simulate()`: a sim house has no pico posting to it |
| The `ta.deed` of each house | a `TaDeed` built in the generator, validator `d1.validator.gridworks`, a typed-in `IssuedS` | the registry: `gnr export-dev` writes one `ta.deed` per simulated TerminalAsset beside the `g.node.gt` files, under the same committed-equals-fresh test |
| The FLO's `g.node.gt` | constants in the generator | the export's `d1.flo-g.node.gt-006.json` |
| `plant-overrides.json` (`TOutdoor`, `PZoneValve`) | a committed file, copied to the second house | stays in `dev-sim/` as one file mounted in both plants; it is an experiment setting |

## The change

Three repos, in this order. Each is its own branch and PR.

1. **tlayouts.** `simulate()` sets the web server not to serve. The
   outputs are regenerated and the regen test covers them.
2. **Registry.** `gnr export-dev` writes the deeds of the simulated
   TerminalAssets into `dev-universe/`.
3. **experiments**, branch `jm/dev-sim-twins` on `jm/plant-seam`.
   - `sources.txt`: the tlayouts pin moves to the commit from step 1,
     and `grid-node-registry` is added at the commit from step 2.
   - `copy-houses.sh` replaces `gen_layout.sh`. It copies each pair
     from `.sources/tlayouts/output/` to `beech1/` and `beech2/` under
     the names the scada reads (`hardware-layout.json`,
     `operational-params.json`), and copies each deed and the FLO's
     GNode from `.sources/grid-node-registry/dev-universe/`.
   - `variants.json` states, per house alias, the storage mode: beech1 is `AllTanks`, beech2 is `BufferOnly`. One step applies the mode to the
     copied params through the snapshot class, in the scada's
     environment at its pin.
   - The houses are committed. `run.sh` stops before the build when a
     committed layout differs from the pinned output, or a committed
     params file differs from the pinned output with its variant
     applied.
   - `pod.yaml`, `journal_boot.py`'s mounts, the web seed loop,
     `flo_matrix.py`'s mount, `package.sh`, `run-packaged.sh`,
     `stop.sh` and the README take the new folder names and aliases.
   - `beech_sim_gen.py`, `gen_layout.sh`, `house/` and `house-buffer/`
     are deleted.
   - The experiment's instance records which alias ran which variant.

## Names in the folder

A name in the folder says which house and nothing about the variant.

| Today | After |
|---|---|
| `house/`, `house-buffer/` | `beech1/`, `beech2/` |
| `events/`, `events-buffer/` | `events-beech1/`, `events-beech2/` |
| `beech-sim-scada`, `beech-sim-scada-buffer` (and plant, ltn, mosquitto) | `beech-sim-scada1`, `beech-sim-scada2` |

## What moves with it

- Every alias and GNodeId in the pod changes once. The journal is
  rebuilt on every play. `./eventstore` and the two event folders from
  earlier plays have the old aliases and are cleared by hand once.
- The scada and plant pins have to decode tlayouts' output at the new
  pin. Where the layout word moved between `240fc01` and the new pin,
  the three pins move together in `sources.txt`.
- The sim Beech built from the real spec is a different house from the
  one built from orange. The optimizer's matrices are named by a hash
  of the storage configuration (`c148abb7` for AllTanks and `b32a6b0a`
  for BufferOnly today). If the hash changes, `fill-bruce.sh` builds
  both again, about 3 hours a mode on the laptop.
- A pod already running on a box keeps its old houses until it is
  played again from the new branch.
- The three service images still bake `scripts/dev-g.node.gt.json`.
  That is leg 3 of OPS-720 and is not touched here.

## Verification

1. `./run.sh` on the laptop: all containers up, both LTNs report
   `ValidatedSimulatedAsset`, both scadas' reports are in the journal,
   and each TerminalAsset's `g_nodes` row has the seed's id.
2. Each house gets a FLO answer at an hourly ask.
3. `grep -rn uuid4 dev-sim/` finds nothing, and the generator and its
   wrapper are gone.
4. With one byte changed in a committed house, `run.sh` stops and names
   the file.

## The journal is a projection

The journal database is a projection of messages and is the authority
for nothing. A GNode's identity and display name are the registry's
facts (`wiki/vision/data-meaning-sovereignty.md` "Sovereignty: shared
meaning, owned facts"), and the journalkeeper writes `g_nodes` from the
registry's `g.node.forest` (`g_node_forest_persistor.py:110`).

The stack breaks this today: `journal_boot.py:135` inserts `g_nodes`
rows with SQL, from each layout's GNodes, because the pod runs no
registry. A display name set at that insert would make the journal the
only place the name exists, so this change does not do that.

Decided 2026-11-26: a display name is a label for people, and the rule
that a twin's name says nothing about its variant is about the alias
alone. So the registry's seed can name the twins' TerminalAssets
`beech-at` and `beech-buf`, and the name reaches the front end as a
projection of the registry's fact.

Undecided: how `g_nodes` reaches the stack's journal as a projection.
Three ways, in order of preference so far:

1. The registry runs in the pod, seeded with the dev universe, and the
   journalkeeper projects its `g.node.forest`. This is the leaning as of
   2026-11-26 and is not yet decided. It widens this change by a
   container, an image and the registry's own database.
2. The SQL insert in `journal_boot.py` stays as known debt, with its
   values read from the registry's export in place of the layouts.
3. Something in the pod publishes the export as a `g.node.forest` for
   the keeper to project. That is a process speaking as `d1.gnr`, and it
   is not done without an explicit decision.

## Open

- **Pages that do not show the display name.** Read on 2026-11-26 at
  the pinned commits: the front end's houses table, house picker and
  morning report show the TerminalAsset's `g_nodes.display_name`
  (`installation_summaries.py:59`, `HousesTableCard.tsx:376`), and in a
  pod with no registry nothing writes that column after
  `journal_boot.py`. The real-time page header shows a segment of the
  scada's alias (`RealTimeStatusHeader.tsx:26`), and the information
  and alerts pages show the alias first. With beech1 and beech2 those
  pages say nothing about the variant. Whether they should take the
  display name is a front-end question outside this change.
- **The deed's home and its values.** The table proposes the registry's
  export. `IssuedS` and the validator alias need a stated source; OPS-720
  has the same question open.
- **Container names**: `scada1` and `scada2`, or the house name spelled
  out.
- **The supervisor alias** (`d1.super` for weather, `d1.super1` for the
  rest) follows the seed, and OPS-720 has it open. It changes here only
  if the seed has it by then.
- **Whether the experiments PR stacks on `jm/plant-seam`** or waits for
  the two draft PRs under it to merge.

## Do this next

Decide whether the registry runs in the pod, the deed's home and the
container names; write the variant
step in the shape of the scada's `ops_word_with`, then a review pass on this file.
After that, step 1 in tlayouts.
