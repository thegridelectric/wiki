# Data, meaning, and sovereignty

Status: Draft · Pass 0 · Updated 2026-07-13

> What this is: the vision-grade *why* under how GridWorks holds data and
> meaning — formal enough to compose, open enough to keep growing, and built so
> the past stays legible. The concrete architecture position is
> [`../sema/research/where-meaning-lives-in-gridworks.md`](../sema/research/where-meaning-lives-in-gridworks.md);
> this doc keeps only the dream. A north star, held lightly.

## Formal, yet open to new expression

A system that means something must be able to say what it means — once,
explicitly, so that strangers can compose against it without shared tribal
knowledge. That is Sema: meaning declared in a language, versioned and
checkable, rather than smuggled in naming conventions or buried in a schema.

But formality must not become a cage. The grid is a place of permanent partial
knowledge — sensors fail, models lag, hardware varies, intent changes. So the
language is **additive by discipline**: new perceptions arrive as new versions
and new types, never as silent redefinition. Meaning can grow without breaking
what already stood. This is the whole trick — *emergence and evolution without
chaos* — formal enough to trust, graceful enough to keep learning.

## The past stays legible

A living system must be able to look back honestly: what did we know, when did
we know it, and what did we do about it. So the record is **immutable**. The
**EAR reads everything** — the universal audit tap captures every message that
crosses the fabric, unopinionated and complete, as proof-of-history that can be
replayed, re-derived, and re-examined long after the moment passed. Identities
are immutable too (`GNodeId`); names and roles may evolve, but the thread back
through time is never cut.

This is the engineering bones the Reactive Manifesto names — message-driven,
resilient, elastic — read as a moral stance as much as an architecture: a
distributed system that can always account for itself.

## One complete record; many opinionated stores

The journal does not judge. **The EAR keeps everything; downstream databases
are free to be opinionated** — to care about only their slice, to optimize for
their own questions, to forget what doesn't serve them. A complete, neutral
record underneath; selective, purposeful projections on top. No projection has
to carry the whole world, because the whole world is already kept once.

## Sovereignty: shared meaning, owned facts

Here is the sovereignty: **meaning is shared, facts are owned.** There is one
language so that everyone can understand each other — but no central owner of
the truth. Each party governs its own authoritative facts in its own small,
slow, Sema-correct store: the **GNode registry** for topology and identity, a
market maker's **product catalog** for the market it runs. Others consume
projections of those facts; they do not get to redefine them.

So a node can join the commons without surrendering control of itself. The
shared language buys interoperability; sovereignty over one's own facts is never
the price of admission. This is the same commons the rest of the vision describes
from other angles — a map many build together
([`transactive-grid.md`](transactive-grid.md)), an ecosystem of independent
companies ([`ecosystem.md`](ecosystem.md)) — here read as: *agree on what words
mean; keep authorship of your own truth.*

## Sovereignty of the person: the TaOwner holds the keys

The section above is sovereignty between organizations. It reaches all the way
down to the person: **the owner of a TerminalAsset holds its keys.** In a
distributed system, sovereignty is decided by key custody. Whoever signs at
genesis defines what every later signature means — if the platform holds
everyone's keys, moving the record to a more distributed authority changes
nothing real, and the change cannot be retrofitted: bindings attested by a
registrar stay registrar-attested; provenance does not upgrade in place. So
the owner is a first-class signing principal from the start — in the ceremony
that certifies their asset, in the deed that names it theirs, in the trading
rights they grant onward.

Holding keys must not mean running infrastructure. The legacy TaDaemon showed
the pattern: an agent that acts on the owner's behalf — holds the deed, passes
trading rights to the bidding agent — without ever owning them. Delegation
with revocation; custody stays a choice. This is also what makes TaDeed and
TaTradingRights real instruments rather than platform bookkeeping: the
demand-side flexibility belongs to the homeowner, who grants its use. It is
not an aggregator's database row about them.

Today the machinery is deliberately stubs — the registry's `Proof` seam,
nodes entering Pending until validated — and this principle binds the designs
that will fill them in. Current mechanism thinking:
[`../grid-node-registry/explorations/create-words-and-validation-stubs.md`](../grid-node-registry/explorations/create-words-and-validation-stubs.md).
