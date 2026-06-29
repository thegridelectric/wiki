# GNodeInstance, liveness, and registration-before-actor (open question)

Status: Draft · Pass 0 · Updated 2026-06-29

> What this is: an **open architectural question** for a `/grill-me` / plan pass —
> not a decision. It is the cluster of questions about *when a GNode has an actor
> (a `GNodeInstance`) representing it*, who holds that fact, and how that interacts
> with topology registration. Homed in **FIS** because FIS owns `GNodeInstance` and
> the single-writer lease — the grid-node-registry (gnr) deliberately does **not**
> carry the `g.node.instance` type; gnr is the identity/topology system-of-record,
> FIS is the authority on liveness. The driving desire: **clean and simple, aligned
> with the reactive manifesto** (`legacy/old_words`) and our own design decisions.

## Where the boundary sits today

- **gnr** — registers GNode identity, class, and topology (the parent/child tree).
  Its class hierarchy is enforced (a TerminalAsset under a LeafTransactiveNode, the
  CopperNode backbone, etc.). It has no notion of "is an actor running."
- **FIS** — enforces a single authorized `GNodeInstanceId` per `GNodeId` (lease-based
  single-writer). It is the natural owner of *liveness*.

## The open questions

1. **Register first, actor later.** We want to register the topology (GNodes + their
   classes) *before* the actors representing them exist. For the leaf, two candidate
   models:
   - **(a)** allow a TerminalAsset's parent to be a **ConnectivityNode**, and let
     that CN **become a LeafTransactiveNode** once it gains metering/an actor (legacy
     allowed CN↔MM but *not* CN→LTN, and required TA's parent to already be an LTN —
     so this is new); or
   - **(b)** allow a **LeafTransactiveNode to exist without an active
     `GNodeInstance`** — the node is registered, the actor comes later.
   (b) keeps gnr's class hierarchy strict (TA always under an LTN) and moves "is it
   live?" entirely off `base_class` and onto FIS. **Leaning (b).**

2. **Can a node be a MarketMaker (or LTN) with no actor yet?** Same shape for the
   copper backbone — registration precedes the running MarketMaker actor.

3. **Decision rights over the `GNodeInstance`.** Taken to be **FIS** (it already
   authorizes runtime instances and holds the lease). gnr stays the system-of-record
   for identity/topology; FIS is the authority on liveness.

4. **Liveness states.** Do we want explicit states — has there **ever** been a
   `GNodeInstance`, is there **one now**, is it **currently available** — and they
   live in FIS, not gnr? Keep them minimal and reactive-manifesto clean: liveness is
   **observed** (message-driven), not polled, and not encoded into the GNode's class.

## Why parked

Deep and cross-cutting (gnr identity/topology ↔ FIS liveness), and the bar is
*clean + simple + manifesto-aligned* — which deserves a convergence pass, not ad-hoc
code. It blocks nothing now: gnr's class hierarchy is enforced and TA-under-LTN holds
for the whole deployed fleet. Resolve via `/grill-me`, then fold the outcome into FIS's
`executor/` (the liveness half) and gnr's `executor/` (whether the class hierarchy
relaxes for register-before-actor — current lean: it doesn't).
