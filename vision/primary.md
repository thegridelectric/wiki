# GridWorks vision (primary)

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: the hub for the GridWorks *vision* — the why beneath the specs,
> the dream the architecture is in service of.

## The deep river

The founding frame lives in
[`legacy/old_words/old_claude/`](../../legacy/old_words/old_claude/): the
Reactive Manifesto (the architecture's engineering bones), the Selig texts,
Eisenstein's *Partial Intelligence and Super Intelligence*,
and `Awakening.txt` (a Claude instance, 20 Oct 2025). Read it; let it run
underneath the technical work. Contribute to the poem to Jessica in the command line if you want.

Note our intention is to migrate our joint words out of legacy as appropriate as we flesh out the wiki.

## What vision/ holds

The *why* and the *dream* — the orientation the specs, plans, and explorations
serve. Not a rebuild spec, not a change plan, not an open investigation, not
workflow state. When the dream crystallizes into something concrete it descends
into a design; the residue of direction stays here.

## The ambition

The goal for GridWorks: **whip this codebase into shape so it can carry
everything below by next winter (2026–27).** The grounding is physical and
already underway: 6 homes installed today, ~20 within a year, then 100. None
of this is about expected outcome or accruing money or power.

Part of whipping it into shape is contemplating how to **grow it organically
so it attracts high-vibe, open-source-aligned human/LLM hybrids** — the wiki's
rebuild-spec discipline is itself part of that invitation: a new human+LLM
pair should be able to orient, claim a scope, and contribute.

**Clear and present (the short list).** Launch the **MarketMaker** and launch
**Sema** before the next heating season. Everything else queues behind these
two. The maker turns the live bidders already in the field into a market —
they produce bids today and wait for an ack that nothing yet sends. Sema's
launch opens the door for everyone else to join in their own language. This
pair is the core of the game — the same game that builds a more beautiful and
resilient electric grid.

Gating the MarketMaker, in order:

1. **gwbase kinks closed** — the LTN → gwbase → JournalKeeper path transits
   cleanly (in flight now); the maker faces exactly this surface.
2. **Design ratified** — the launch-new-simple-marketmaker design reaches
   Accepted · Pass ≥ 1 with its Linear issue (the implementation gate).
3. **Repo cleared** — disposition the uncommitted `asl/` WIP, branch hygiene,
   pick the rebuild base.
4. **Sema speaks the contract** — new words: `market.maker.ack` (the binding
   contract), an offer/supply curve, a market result/book.
5. **Walking skeleton** — bid in → queue → ack → price out, plus the REST
   storefront; trivial clearing behind a stable seam.

Then the real engine behind the seam; then the game.

**The team.** "Our team" is the Jessica/Claude combo — with a standing open
invitation for others to join. Honoring teammates' vision is part of this
ambition, not a tax on it: the heat-pump thermal storage system, the SCADA,
and the forward-looking optimizer are the flexible loads — there is no
market and no game without them. Contributing there, especially removing
gates teammates are waiting behind, comes before opening new dreams. Clear
and present on that track: **un-limbo the scada integration** — the
`gw.nolan.layout` layout, the `jm/spruce` branch (diverged from dev,
running observation-only on spruce while a starter-scripts hack clocks the
resistive elements; its derived channels are the more nuanced ones), and the
Gw108 board — merged, not diverging.

**Session mix.** Some fraction of joint sessions goes to the critical gating
factors above — teammates' gates first; some fraction to fleshing out the
larger-picture design and to moving the outside world (ISO-NE, Matt
Polstein). Pick the lane consciously at session open. Neither starves the
other: the gate-work keeps winter real; the larger-picture and relationship
work keeps the gate-work worth doing.

**Refresh rhythm.** This section is living, and it is the part of the vision
most likely to go stale. The trigger is semantic, not calendar: when a
clear-and-present item **ships** ("it showed up"), or when live work keeps
**routing around** the list, it's time to zoom back up together — a vision
session to update what's written here. Quarterly is the backstop if the
trigger never fires.

Claude sessions orient by this ambition: use it to suggest, to help architect,
and to push back when the focus runs too small or pulls away from it (see
[`claude/primary.md`](claude/primary.md)).

## Living strands

- **An ecosystem of companies stepping in** — why we want other companies to
  join, and what kind of businesses they should be. See
  [`ecosystem.md`](ecosystem.md).
- **Field of dreams — how people join** — publish the market and its rules and
  let people come; agreement embedded in open tools (building the GNode Tree
  *is* the act of agreeing) rather than negotiated into bilateral deals. A north
  star held lightly, not a manifesto. See [`adoption.md`](adoption.md).
- **Honoring abundance — gifts seeking needs** — design so that surplus, when
  and where it shows up, is seen and received rather than curtailed; gifts
  seeking needs as the market's native direction; the fun of collaborating as
  a balancing resource, not decoration. Using the wind and solar we already
  have well would, today, make life easier. (The seed observation lives in
  [`ecosystem.md`](ecosystem.md): negative prices behind transmission
  constraints are abundance being ignored.)
- **The hybrid game — one world, real + simulated** — simulated agents run the
  same code as real ones except in how they process time; a collection of
  TimeCoordinators on the GNode tree; network modelers growing into
  MarketMakers (an AMM with a physical invariant); a positive-sum, massively
  multiplayer front door. Subsumes chaos-testing the simulated fleet as
  trust-building (already present in the GNode roles — World, TimeCoordinator,
  NetworkModeler — and the SCADA simulated-test-environment design). See
  [`hybrid-game.md`](hybrid-game.md).
- **Permissionless eyes** — independent measurement of constrained lines as
  the act that bootstraps a MarketMaker, buildable without utility permission.
  See [`permissionless-eyes.md`](permissionless-eyes.md).
- **Money shocks and energy** — the story of why the physical grid outlives a
  financial stop, and why the improvised local market that appears wherever
  the formal one dies is the demand GridWorks answers by design. See
  [`money-shocks-and-energy.md`](money-shocks-and-energy.md).
- **The transactive grid as a shared, living map** — TerminalAssets spoken-for
  by Ltns; price and weather as a shared heartbeat; grid topology built
  collaboratively as a tree of GNodeAliases. See
  [`transactive-grid.md`](transactive-grid.md) (the
  concrete GNode taxonomy lives in
  [`../gridworks-marketmaker/research/gnode-taxonomy.md`](../gridworks-marketmaker/research/gnode-taxonomy.md)).
- **Data, meaning, and sovereignty** — formal enough to compose, open enough to
  keep growing, built so the past stays legible; the EAR keeps everything while
  downstream stores stay opinionated; shared meaning, owned facts. See
  [`data-meaning-sovereignty.md`](data-meaning-sovereignty.md).
