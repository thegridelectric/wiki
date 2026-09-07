# hp-boss-cleanup (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope, 3h (2–9);
> hub [`primary.md`](primary.md). hp-boss becomes a first-class permanent
> system delegate, present in every layout, tested for the first time.
> Decisions 2026-09-01. **Done when** admin turns the heat pump on and off
> through hp-boss on spruce (below).

## Decisions

- **hp-boss always exists** — every layout family, ActorClass HpBoss,
  enforced by each word's core axiom
  (`CoreShNodesExistenceAndActorClass`); the actor runs in every layout
  too (below). Chosen over conditional-on-commandability because the confirmed reporting rule
  requires it: **hp-scada-ops-relay reports to hp-boss in ALL states in
  ALL layouts** (the pico-cycler/vdc pattern; admin commands through
  it: `admin.hp-boss.hp-scada-ops-relay`).
- **HAS vs USING.** Having a sieg loop is topology (the layout word —
  `gw.house0.layout` MEANS has-sieg; sieg-less homes are
  `gw.house0.no.sieg`, see the layouts spoke). USING the loop is
  operational: `UseSiegLoop` migrates from `Hydronic` to
  `gw.house0.operational.params`.
- **hp-boss ALWAYS runs; the sieg-loop actor runs only when used.**
  (2026-09-07.) hp-boss is constructed in every layout, sits in every
  command tree with `hp-scada-ops-relay` under it, and owns the heat
  pump's on/off. `UseSiegLoop` selects hp-boss's **strategy**, not its
  existence: with the loop, TurnOn goes through `PreparingToTurnOn` and
  waits on `SiegLoopReady`; without it, hp-boss closes the relay
  directly. The sieg-loop actor is the one that exists only when the
  loop is used. "Dormant" is not used for any of this; in scada code
  that word means one thing, an actor whose node is a leaf of the
  current command tree (`command-tree-matrix.md`), and hp-boss is never
  a leaf.
- **Commandable heat pumps hang under hp-boss.**
  `Hydronic.HpCommandNodeName` (optional, both words) names WHICH node
  takes commands — `hp-odu` (native modbus, e.g. elm's Arctic arriving
  this week) or `hp-ctrl-box` (Samsung via MIM). Conditional axiom
  `CommandableHeatPump`: present ⇒ the named node exists with a
  ComponentId and its effective handle parent is hp-boss.

## The work

1. Sema core-axiom edits + Nolan regen (hp-boss node returns to the
   Nolan fixture NOW, not when the MIM arrives).
2. Code: hp-boss family-selected like LC/LA; the interior-subtree rule
   covers its tree placement (with the pico-cycler work); dormancy
   gates on ops.
3. **First-ever hp-boss tests**: tree placement on both fixtures,
   dormant-vs-engaged behavior, sieg vs non-sieg command shapes,
   commandable-node dispatch when HpCommandNodeName lands.

## hp-twin extends this later

hp-boss will also boss the heat pump directly, through an HpTwin actor
(sema command events in, modbus out), once we can talk digitally to heat
pumps. That work is outside this rope; the decisions taken so far and
the fixture sketch are in `../unsorted/hp-twin.md`, which extends this
chunk's first pass rather than reopening it.

## ▶ Do this next: admin turns the heat pump on and off through hp-boss

The experimental test of success for this chunk: admin turns the heat pump
on and off through hp-boss, the heat pump's command node, not by
dispatching `hp-scada-ops-relay` directly; witnessed on spruce. Needed
before anything else that touches the heat pump.

## Sieg loop needs its tires kicked

The sieg-loop control has never run unsupervised in the field for a
long stretch. Treat it as unverified: the hp-boss/sieg test work here
is also the sieg loop's first real exercise, and field confidence
comes only through this design's EDD bar (bench/box runs), not the
suite.

## Open

- Two code items ride this chunk from the matrix findings:
  `process_fsm_event` must return after the `bad_boss` glitch, and the
  `to_name == "hp-boss"` rewrite in `scada.py` goes, since it addresses a
  handle that does not exist under admin in a sieg layout.
- How hp-boss learns `UseSiegLoop` at boot (operational params, not the
  layout word) once the field migrates.
