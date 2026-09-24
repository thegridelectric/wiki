# Three family plants: a terminal asset per layout family (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-40

> What this is: simulated-test-environment spoke giving each of the three
> layout families (`gw.house0.layout`, `gw.house0.no.sieg`,
> `gw.nolan.layout`) a simulated terminal asset, so every family gets the
> next level of testing above its sim pair: a plant that answers the
> scada's actuation with plausible sensing, on the dev broker, under the
> loop `build-plant.md` builds. The sim pairs themselves ship with the
> words (spruce-unlimbo); this spoke starts once the three pairs boot.

## Two levels of testing per family

1. **The sim pair** (layout ⊕ ops, every component a sim device type).
   Ships with each family's word, boots in-process, and carries the
   contract tests. Proves the layout loads, the actors construct, the
   command tree closes, capture tuning covers every channel. Every family
   has one: the Nolan pair is the sim-spruce gen's output, the House0
   pair is the tlayouts sim gens' output (orange-sim, willow-sim), the no-sieg pair ships with its word
   (`../spruce-unlimbo/layout-word-axioms.md` "The `gw.house0.no.sieg` word").
2. **The family plant** (this spoke). A `gridworks-terminalasset` GNode
   per family that reads the same layout file, emits `sim.plant.flux` for
   the family's sensed surface, and moves its state on the scada's relay
   and 0-10V outputs. Proves the control loops act on the plant and the
   plant answers: a heat call raises a zone's flow and drops its return
   temperature, an hp TurnOn shows up as heat-pump power and a rising
   supply temperature, a store charge warms the tank layers in order.

## What differs per family

One plant body, three plumbing rosters, read off the layout word rather
than coded per family, on the invariant that every layout carries its
capability set, its capability-to-mechanism binding and its hardware
realization (`../spruce-unlimbo/primary.md` "The invariant"):

- **House0** — the sieg loop: `sieg-flow`, `sieg-cold`, the hp-loop
  valve relays and the sieg-loop actor's `SiegLoopReady` handshake, so
  `basic-sieg.md`'s field question has a rehearsal rig; buffer, iso
  valve, store tanks.
- **House0 no-sieg** — the same plant with the sieg surface absent; the
  one that proves nothing above the family tier reaches for a sieg
  channel.
- **Nolan** — no buffer, the gw108 relay roster, the on-peak windows and
  the three extra pico modules; the reference plant, since the Nolan
  loop is the first built (`build-plant.md` "Do this now").

The physics is the first-pass room and tank model in
`simulated-actors.md`; fidelity climbs the ladder in `build-plant.md`
"Fidelity ladder" only as a test needs it.

## Done when

- Each family plant boots against its family's sim pair on the dev
  broker and the scada's channels populate from `sim.plant.flux`.
- One witnessed loop per family: a zone call, an hp TurnOn, and (House0
  families) a store charge, each showing in the journal as sensing that
  answers the actuation.
- The harness is a re-runnable reproducer under `experiments/`; findings
  distill into scoped Verified claims.

## Open

- Whether the three fall layouts (spruce-settled fall-layouts work,
  OPS-532) are three more plants or configurations of these three.
- Where the family plants run in CI, if at all: the EDD bar is the dev
  broker, and the suite keeps the in-process sim pair.
