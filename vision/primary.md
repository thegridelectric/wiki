# GridWorks vision (primary)

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: the hub for the GridWorks vision, the why beneath the
> specs. It holds the ambition in one section and an index of the vision
> documents beside it. Not a rebuild spec, not a change plan, not an open
> investigation. When a part of the vision becomes something concrete it
> becomes a design; what stays here is direction.

## The ambition

A heating system that, in aggregate, is the best grid-balancing asset on
the grid, and at the same time the lowest-cost way for people in
Northern Maine to heat their homes. The two are one design: a thermal
store filled with electricity in the hours it is cheap and abundant
carries the house through the hours it is scarce, and the savings come
from the energy market, not from incentives.

The goal for the codebase is to carry that through the 2027
installations. The grounding is physical and under way: five homes in
Millinocket this winter, the seed installations in spring 2027, the main
installations in late summer and fall 2027, about a hundred in all. None
of this is about expected outcome or accruing money or power.

Two launches come before the next heating season: the MarketMaker and
Sema. The MarketMaker turns the bidders already in the field into a
market; they produce bids today and wait for an ack that nothing yet
sends. Sema's launch lets anyone else join in their own language. The
MarketMaker's gates and build order live in its design and Linear issue,
not here.

The hundred homes set this year's requirements, and they come before
anything new here. Heat pumps that hold up, chosen from the makes running
in Millinocket now. A simpler flow control manifold, so the standard
configurations installers build are simpler than the ones we have. An
optimizer for each configuration, so every home buys its energy well
whatever its heat pump and store. One scada codebase that runs every
layout from its Sema declaration. And the triage, installation and
site-visit tools that let a first-line person, an installer and a
validator work a home without an engineer. The plan is the
[hundred-homes repo](https://github.com/thegridelectric/hundred-homes)
(`README.md` for the goal and who holds what, `tools.md` for the
software); the engineering is the Linear initiative
[`hundred-homes`](https://linear.app/gridworks/initiative/hundred-homes-528cc367b185).

The codebase is meant to grow by invitation. The wiki's rebuild-spec
discipline is part of that: a new person, or a person working with an
LLM, should be able to orient, claim a scope and contribute.

This section is the part of the vision most likely to go stale. Revisit
it when a launch ships or when live work keeps routing around what is
written here.

## The vision, by topic

- **An ecosystem of companies stepping in.** Why we want other companies
  to join, and what kind of businesses they should be.
  [`ecosystem.md`](ecosystem.md).
- **How people join.** Publish the market and its rules and let people
  come; agreement embedded in open tools, so that building the GNode
  tree is the act of agreeing, rather than negotiated into bilateral
  deals. [`adoption.md`](adoption.md).
- **Honoring abundance.** Design so that surplus, when and where it
  shows up, is seen and received rather than curtailed. Negative prices
  behind transmission constraints are abundance being ignored; the seed
  observation is in [`ecosystem.md`](ecosystem.md).
- **The hybrid game, one world real and simulated.** Simulated agents run
  the same code as real ones except in how they process time; a
  collection of TimeCoordinators on the GNode tree; network modelers
  growing into MarketMakers. Chaos-testing the simulated fleet is part
  of how trust is built. [`hybrid-game.md`](hybrid-game.md).
- **Agents as participants.** AI agents join the way anyone joins: speak
  Sema, build a slice of the tree, play in the sim, cross into reality
  through a human validator.
  [`agents-as-participants.md`](agents-as-participants.md).
- **Independent measurement of constrained lines.** Measuring a
  constrained line ourselves is the act that bootstraps a MarketMaker,
  and it needs no utility permission. [`measuring-constrained-lines.md`](measuring-constrained-lines.md).
- **The transactive grid as a shared, living map.** TerminalAssets spoken
  for by LTNs; price and weather as a shared heartbeat; grid topology
  built collaboratively as a tree of GNodeAliases.
  [`transactive-grid.md`](transactive-grid.md); the concrete GNode
  taxonomy is in
  [`../gridworks-marketmaker/research/gnode-taxonomy.md`](../gridworks-marketmaker/research/gnode-taxonomy.md).
- **Data, meaning and sovereignty.** Formal enough to compose, open
  enough to keep growing, built so the past stays legible; shared
  meaning, owned facts, and the TaOwner holding the keys.
  [`data-meaning-sovereignty.md`](data-meaning-sovereignty.md).
  [`where-meaning-lives-in-gridworks.md`](where-meaning-lives-in-gridworks.md)
  is the companion on where meaning sits in the code.
