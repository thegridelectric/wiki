# One source for d1 GNode identity

Status: Accepted · Pass 1 · Updated 2026-11-25 · Linear: OPS-720

**EDD: no** build-out work, verified by each repo's suite, a regen test in
tlayouts over every committed sim output, and one run of the simulated
stack on the exported ids.

> What this is: the plan for making the registry's dev seed the one
> source of d1 GNode identity, with an export every other repo reads at a
> pinned commit. It lists where d1 identity is stated today, what was
> decided on 2026-11-25, the four legs of the change and what is still
> open.

## Why

A GNode's identity in the d1 universe is its alias, its GNodeId and, for
a physical node, its PositionPointId. Five places state it today and they
disagree.

| Where | What it states | How |
|---|---|---|
| `grid-node-registry/src/gnr/dev_universe.py` | the copper backbone to `d1.isone.me.versant.keene`, seven houses under it each with `.ta` and `.scada`, `d1.time`, `d1.flo`, `d1.isone.me.weather`, `d1.isone.me.price` | ids computed from the alias (`deterministic_uuid4`) |
| tlayouts sim drivers (`spruce_sim_gen.py`, `orange_sim_gen.py`, `willow_sim_gen.py`, `hazel_sim_gen.py`, `larch_sim_gen.py`, `beech_sim_gen.py`) | three `g.node.gt` records per house | constants typed into each driver |
| `scripts/dev-g.node.gt.json` in gridworks-price-forecast, gridworks-marketmaker and gridworks-weather-forecast | the service's own GNode | a hand-kept file baked into the image |
| the simulated stack's layout generator (`experiments/2026-11-11-beech-sim-compose/beech_sim_gen.py`) | the two houses, their `ta.deed`, the FLO's `g.node.gt` | fixed ids for one house, fresh `uuid4` on every run for the other |
| scada and terminalasset test fixtures | copies of tlayouts output | copied by hand |

Three disagreements, read on 2026-11-25:

- `d1.isone.me.versant.keene.beech` is `9d8fe596…` in the seed and
  `13734431…` in the sim Beech layout.
- The MarketMaker `d1.isone.me.versant.keene` is `12dfcbf4…` in the seed
  and `7f1c4d2e…` in the market maker's image.
- The services run as `d1.weather` and `d1.price`, which is where a cloud
  GNode service that is not grid topology belongs. The seed has them
  under `d1.isone.me`.

The simulated stack runs no registry and no FIS, and its broker has no
topic gate, so nothing checks a GNodeId today. The one consumer of ids
across services is the stack's journal boot, which inserts a `g_nodes`
row per TerminalAsset from each house's layout. This design removes the
disagreement before a gate exists to trip on it.

## Decided (2026-11-25)

- **The registry's dev seed is the one source.** The registry is the
  authority for GNodes, and the seed's ids are a function of the alias,
  so nothing is typed by hand.
- **Other repos read an export.** The registry writes `g.node.gt`
  instances; a consumer vendors them at a pinned registry commit. A
  consumer does not import the registry package and does not copy
  `deterministic_uuid4` with its domain tag, since each would be one more
  hand-kept copy.
- **A twin is a second place.** Two variants of one house run head to
  head as two leaves built from the same spec, in one run and one market:
  `…keene.beech1` and `…keene.beech2`. The name says nothing about the
  variant, which is only in the operational params. A home that exists
  only as a simulation takes a number; a home that stands in for one real
  house keeps its name. The mapping from
  alias to variant is recorded in the experiment's instance. A twin goes
  into the seed when an experiment uses it.
- **The seed grows a `ct.newhaven` branch** for orange, hazel and willow,
  which the sims have as `d1.isone.ct.newhaven.<name>1`.
- **The `ta.deed` is registrar business.** Until a d registrar runs, one
  script beside the export writes the deed of a simulated asset. A layout
  generator does not.
- **The export is one file per GNode in a registry folder.** The folder
  is `grid-node-registry/dev-universe/`; each file is the GNode's wire
  form named by the sema filename grammar
  (`d1.isone.me.versant.keene.beech1-g.node.gt-006.json`). A service
  vendors its one file; tlayouts vendors the folder. `gnr export-dev
  <dir>` writes the folder from the seed, and a registry test asserts the
  committed folder equals a fresh export, so a seed change cannot merge
  without its export.
- **A consumer pins by commit.** The consumer copies what it needs and
  records the registry commit beside the copy, in
  `<copy-dir>/REGISTRY_COMMIT`. A refresh is a copy from a registry
  checkout at the new commit plus the new hash; the consumer's own tests
  then say what the new ids broke. No package.

## The legs

In order. Each leg is its own branch and PR in its repo.

1. **Registry.**
   - Seed additions: `…keene.beech1` and `…keene.beech2` with `.ta` and
     `.scada`, in place of `…keene.beech`;
     `…keene.larch` with `.ta` and `.scada`; the `d1.isone.ct`,
     `d1.isone.ct.newhaven` nodes and `orange1`, `hazel1`, `willow1` under
     them, each with `.ta` and `.scada`.
   - `d1.weather` and `d1.price` replace `d1.isone.me.weather` and
     `d1.isone.me.price`.
   - The export: a command that writes the seed as `g.node.gt` instances,
     and the committed result.
2. **tlayouts.**
   - The vendored export and a lookup by alias that fails by name for an
     alias the export lacks.
   - `simulate(config, ltn_alias, ops)` in `src/tlayouts`, and one
     `sim_gen.py <house>` driver over it for the houses with a real spec
     (spruce, beech). `spruce_sim_gen.py` and `beech_sim_gen.py` go. The
     function has the rules that are about a kind of hardware: the map
     from a real heat-pump part to its sim twin, sim tanks and meter,
     blank hwuids and hosts, and what replaces hardware with no twin (a
     Honeywell stat on a Hubitat, pico BTU meters on a sieg-loop home, the
     ADS board).
   - The authored sims (orange, willow, hazel, larch) keep their drivers
     and read their identity from the export.
   - A regen test over every committed sim output. On 2026-11-25 the
     spruce-sim and larch-sim layouts and the orange and willow
     operational params differed from a regen, and only beech-sim had a
     test.
3. **Service repos.** The three `scripts/dev-g.node.gt.json` files go;
   each image takes its identity from the export.
4. **The simulated stack** (`experiments/dev-sim/`). The FLO's
   `g.node.gt` and the `ta.deed` files come from the export and the deed
   script. The houses are beech1 and beech2, copied from tlayouts output at
   a pinned commit. The stack's own layout generator and its wrapper
   script go.

## What changes with it

- Every sim layout's GNodeIds change once. The scada's fixtures
  (`gw.nolan.*`, `gw.house0.orange.*`, `gw.house0.willow.*` and the deed
  beside them) and terminalasset's fixtures are copies of tlayouts output
  and are refreshed after leg 2.
- The scada's spruce fixture is the 2026-11-01 spruce. Against a spruce
  sim regenerated on 2026-11-25, the scada suite at `73e9d523` passes
  2100 tests and fails eight that pin the old fixture's values: six in
  `tests/actors/test_zero_ten_outputer.py` on the DAC mux channel, one in
  `tests/actors/test_derived.py` on `IntermediateRswtF`, and a pico count
  in `tests/test_plant.py`. Refreshing that fixture is a scada change
  with those eight tests in it.
- The seed gives a TerminalAsset and its LTN different PositionPointIds;
  the sims give them one. The registry executor and `g.node.gt` say only
  that the id is an opaque location identity, so the sims take the seed's
  values and no spec changes.
- The stack's `pod.yaml` gives the weather service `d1.super` as its
  supervisor alias and every other service `d1.super1`. The stack follows
  the seed.

## Verification

1. Registry: its suite, with the seed tests updated for the new nodes.
2. tlayouts: `grep -rn GNodeId *_sim_gen.py` finds nothing, and the regen
   test passes for every committed sim output.
3. Two twins' layouts differ only in `GNodes` and in the
   `TerminalAssetAlias` on each channel; a tlayouts test says so.
4. The simulated stack runs on the exported ids, and each
   TerminalAsset's `g_nodes` row in its journal has the seed's id.

## Open

- **Where the deed script lives**, and what it takes for `IssuedS` and
  the validator alias (`d1.validator.gridworks` in the stack today).
- **The supervisor alias**: `d1.super` or `d1.super1`, and whether the
  seed has it at all.
- **The overrides `sim_gen.py` takes per house.** The FLO tuning and the
  operator hold differ between the spruce and beech sims today. The slot
  should stay small.
- **The web server's `Serve`**, which the stack sets to false by editing
  the layout after generation, has no config field
  (`layout_gen.py:739`).
- **Whether the seed keeps `willow` under keene** as its Pending,
  locationless home once `willow1` is under `ct.newhaven`.
- **What a `d` universe's isolation guarantee is** once localhost is not
  it (OPS-717). That text is the registry's; this design only needs the
  seed's contents.

## On completion

- The registry executor's "Universes" section gains the seed's contents
  and the export as the way other repos take d1 identity.
- The tlayouts executor replaces its list of sim pairs with the
  `sim_gen.py` driver, the lookup and the regen test.
- The twin rule (a second leaf, the variant in the operational params)
  goes into `wiki/world/primary.md`.
- This file is deleted and the Linear issue finalized.

## Do this next

Legs 1 and 2 are merged: registry `d0c8679`; tlayouts `5313ab2` (the
vendored export, `house_gnodes`, beech1-sim, the regen and identity test)
and `d907d9e` (`simulate()`, `sim_gen.py` for beech1, beech2 and spruce, the
twins test). Next, leg 3: the three service repos drop
`scripts/dev-g.node.gt.json` and take their identity from the export at a
pinned registry commit; then leg 4 in `experiments/dev-sim/`.
