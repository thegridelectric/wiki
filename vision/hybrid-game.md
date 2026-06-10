# The hybrid game (vision)

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: the hybrid real + simulated world as a positive-sum, massively
> multiplayer front door to GridWorks — and the trust membrane that keeps it
> honest. A spoke of the [vision hub](primary.md).

## The invariant: same code, except time

Simulated agents run the **same code** as real-world agents except in how they
process time: ticks from a TimeCoordinator instead of the wall clock. There is
no "sim version" of the codebase to drift out of sync. An agent that performs
well against simulated terminal assets is already production code, one
configuration change away from reality.

## A collection of time coordinators

TimeCoordinators are not one global clock but a **collection, organized along
the GNode tree** — so one tree carries three overlays: **time, physics, and
money**, with granularity following grid topology.

- **Multi-rate.** In a full sim run, some subtrees step every second while
  others step every hour. (Feasibility is not the open question — federated
  co-simulation with per-federate timesteps is established practice, e.g.
  HELICS for grid co-simulation, DEVS-style event triggering. The novelty is
  the organization along the grid's own topology.)
- **Event-triggered.** When a reading arrives, the local coordinator fans a
  couple of extra timesteps to the **essential-physics actors** in its subtree
  — terminal assets now, network modelers eventually.

## Network modelers → MarketMakers: an AMM with a physical invariant

Network modelers begin mapping our comprehension of the real-time OPF. They
may **merge with — become — the MarketMakers**, because both need to
communicate with each other in a distributed way that creates shared meaning.

Said precisely: a blockchain AMM prices against an arbitrary mathematical
invariant (constant-product, x·y=k) with no referent in the world. This prices
against a **physical invariant** — the line's actual capacity and measured
flow. It is an AMM whose bonding curve is reality, updated by measurement
(see [`permissionless-eyes.md`](permissionless-eyes.md)). The distributed
conversation has a near-pun namesake in the literature: **ADMM** decomposition
of OPF, where what neighboring nodes exchange while converging *are prices*.
Sema is the shared-meaning substrate that literature never had: LLM and human
participants negotiate semantic evolution in natural language at design time;
Sema freezes each agreement into a canonical, signable, machine-speed contract
for runtime.

Open (honest caveats): distribution-level state estimation from sparse sensors
is underdetermined; convergence of distributed price coordination under real
latency is a research problem. The structure degrades gracefully — one
constrained line, one MarketMaker, and real measurement is valuable
standalone. Patchy comprehension for a patchy grid.

## Coherence: singing together

When sim federates run together with real systems, the focus is on simulated
terminal assets (and eventually simulated copper) being **interesting and
believable** while progressing close enough in time with the real assets that
the whole system coheres — tracking the wall clock within a **bounded skew**.
Like singing together over the phone, but with little enough delay that it
feels like music. Detached from reality, the same world can run at any speed.

## A positive-sum game

The hybrid world is a front door for people who like playing online games —
and it is **more fun than a meme coin, because it isn't zero-sum**: the score
is grounded in physical value created — surplus absorbed, lines balanced,
homes warmed. The scaling image is a **dandelion puff**: it could explode out
into hundreds of thousands of active builders/participants, and every seed is
genetically complete (same code), able to root in reality.

## Who it's for

Tradespeople, and anyone who is a geek who loves learning how to make things
work — people who appreciate **analog failsafes and appropriate simplicity**,
not tech for tech's sake. Crossing from the game into the physical world (a
CT install, a heat-pump commissioning) should feel like graduation, not a
discontinuity.

## The trust membrane

Validation is the membrane between sim and real: a terminal asset becomes real
in the GNode tree only when a **reputation-staked, locally-known human (a
TaValidator)** attests to it. Local people can check with each other that they
use the same TaValidator; if something is fishy, the TaValidator's reputation
is on the line.

- **Reputation-at-risk, not capital-at-risk.** Proof-of-stake security is
  purchasable, transferable, ultimately plutocratic — and pays for itself with
  token inflation, importing a mindset of unending exponential consumption.
  Reputation is non-transferable and non-purchasable; it must be earned in a
  community that can check. The lineage is Grameen-style joint liability —
  local mutual knowledge as collateral — *minus the currency*.
- **Cryptographic backing from the human link of trust.** Every validation is
  signed. A fraudulent asset is a document, not a rumor; the trail cannot be
  disowned later.
- **Physics is the continuous auditor.** A simulated asset certified as real
  creates *ghost power* — claimed flows that the independent eyes on the
  actual lines never see. One fake hides in measurement noise; at any kind of
  scale, the energy-balance discrepancy localizes to a subtree and the
  signatures in that subtree identify the validator. Fraud at scale gets
  *easier* to catch, not harder — the inverse of financial fraud.
- **Make it very evident.** Deterrence is a design requirement, not a policy:
  validators see at onboarding that the trail is permanent and the physics
  reconciles continuously, so anyone validating simulated systems as real at
  scale will almost certainly be brought to account. Honest deterrence beats
  punishment ever being needed.
