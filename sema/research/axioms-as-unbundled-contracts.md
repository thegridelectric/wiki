# Axioms as the grammatical layer of the unbundled contract (research)

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: a framing of sema axioms relative to blockchain smart
> contracts, distilled from a vision-session exchange (2026-06-09). Context
> for the future ERB-axiom integration design; not normative.

## The family resemblance

Sema axioms and smart contracts are of one family: **rules attached to the
shared world rather than to any party's application**, with teeth that come
from *everyone running the same check*. On a chain that is every validator
executing the contract; in sema it is every generated runtime enforcing the
same axiom — which is why multi-language conformance (golden canonical
instances every runtime must round-trip) matters: it is the cheap cousin of
consensus, proving identical enforcement at every endpoint without a global
machine. Both are also published commitments accepted by participating —
the field-of-dreams adoption move ("building the GNode tree *is* the act of
agreeing") is "code is law" minus the ideology.

## The genus difference: performative vs grammatical

A smart contract *executes* — holds custody, moves assets, refuses to
release collateral. An axiom can only render an utterance invalid; it
cannot act. The chain bundles grammar, attribution, and consequence into
one expensive machine; the GridWorks stack unbundles them:

- **axioms = grammar** — is it well-said?
- **signatures over canonical bytes = attribution** — who said it?
- **physics reconciliation + TaValidator reputation = consequence** — what
  happens to liars?

Where the genuinely performative piece is needed (the binding
`market.maker.ack`, custody of TaTradingRights, clawback), that is not the
axiom layer's job — economy-energy-markets invariant 14 keeps the evidence
mechanism framework-agnostic.

## Non-Turing-completeness is the lessons-learned branch

A restricted constraint language is *decidable*: axioms can be statically
verified, cross-language enforcement can be proven equivalent, and there is
no halting problem, gas metering, or reentrancy. The history of
smart-contract exploits is substantially the history of Turing completeness
(The DAO; the reentrancy bug class); the field's own correction has been
retreat toward restricted languages (Bitcoin Script stayed deliberately
non-complete; Clarity is decidable by design).

**The discipline for ERB-axiom integration:** keep the axiom language small
enough to stay decidable and the multi-substrate conformance proof stays
possible; let it grow general and we inherit the chain's bug class without
the chain's consensus.
