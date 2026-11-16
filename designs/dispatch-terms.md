# Dispatch terms

Status: Draft · Pass 0 · Updated 2026-11-16 · Linear: OPS-686

**EDD: no.** Build-out, verified by the sema suite with a test that
refuses a constant whose instances can differ, and by the scada and
LTN suites round-tripping `slow.dispatch.contract` 001 with its
`DispatchTerms`.

> What this is: the standing agreement that every hourly slow dispatch
> contract is an instance of, how a market maker and product point to
> one such agreement over time, and the sema mechanism, a constant,
> that makes an agreement's name unique and sema the authority for it.

## Why

Every hour an LTN and a scada make a `slow.dispatch.contract`: the scada
holds the house's average power, the LTN settles the hour at the
market's price. Behind each hour stands an agreement between the legal
entity responsible for the scada and the legal entity responsible for
the LTN, the financial and action obligations of both parties, and the
rules of the market they trade in: a Provisional price at the slot
open acted on only toward less consumption, a Final by 240 s or the
Provisional is the Final, one amendment of the hour's contract at the
Final, the contract binding at the Final, settlement at the maker's
Final. Nothing names that agreement today. A market maker and product
resolve to one agreement at any time, the agreement can change over
time, and the ledger has to say which agreement each hour was under.

## Decisions

- **A sema constant is a type whose every valid instance is the same
  JSON.** Every property is `const` and required, with
  `additionalProperties: false`, marked `x-gridworks.constant: true`
  after `owner`, with exactly one version `000`. Two readers who
  validate an instance against the type hold identical bytes, so the
  type's name is the value's name, and sema's registry tests refuse a
  constant whose instances could differ or that gains a second
  version. Versioned with a single `000` rather than versionless, so a
  constant is identified on the wire like every other type and the
  thin versionless path stays unused.
- **Terms are a family of constants starting with `dispatch.terms`.**
  Each agreement is one constant type named under that prefix, for
  example `dispatch.terms.first.isone.hack`. The family is a
  parameterized curve of agreements, each immutable, each a name.
- **The first constant is `dispatch.terms.first.isone.hack` 000,
  staging, with the handful of terms a program acts on.** The market
  maker alias and product, the final deadline in seconds, the
  amendments allowed, the stage settlement binds at, and what a bidder
  may do on a Provisional (`ProvisionalAction`); the two parties by
  GNode alias and the hash and locator of the signed text join when the
  text is signed. The agreement in full is the signed text; the
  constant's prose summarizes it. A token reference is one optional
  bit for a constant that wraps an NFT; the chain is not required. Its
  prose carries the market rules above as the terms' legal
  requirements. Staging until the signed text exists.
- **`slow.dispatch.contract` 001 adds `DispatchTerms`**: the name of the
  constant the contract is an instance of, a `left.right.dot`. Every
  hourly contract then states its agreement. The version bump shares
  the wave with the amendment status below.
- **A maker's pointer is a dated word, `market.terms`.** The maker
  states that from `EffectiveS` its market in `MarketProductName` runs
  under `DispatchTerms`, with `CreatedMs`. One axiom: `EffectiveS` is a
  slot boundary of the product, so no hour is split between two
  agreements. The maker publishes it when it changes, and the history
  of a market's terms is the ordered set of these words.
- **The store is the one emissions already have.** `market.terms` is
  journaled from birth and the S3 eventstore keeps it under the key
  grammar with the maker alias as subject and the product as
  condition. The terms in force for a slot are the latest `market.terms`
  with `EffectiveS` at or before the slot start. Nothing new is built
  for storage.
- **The contract can be amended once, at the Final.** The status enum
  `gw1.slow.dispatch.contract.status` 001 appends `Amended`; an
  amendment heartbeat carries the same `ContractId` with the new
  `AvgPowerWatts`, `Status` Amended, `PreviousStatus` the status
  before, and the reason in `Cause`. The scada replaces the body it
  holds and keeps the energy accounting running. One amendment per
  contract is a term of the agreement, stated in the executor, since a
  type axiom cannot see the previous message.
  `slow.contract.heartbeat` 003 follows the enum version.
- **The LTN offers at the Provisional and amends at the Final.** An
  offer whose power is above the previous hour's is held at the
  previous hour's power until the Final. With no Final by 240 s the
  offer stands. The 240 s is the maker's deadline, held in the LTN as
  a fact about the market beside the slot length.
- **A price names its terms later.** `latest.price` gains the terms
  name in a later version, so a price and the agreement it binds
  travel together. Not this wave.

## Plan

**Do this next:** the LTN sculpt's open gaps, listed in the price-stages
design (OPS-684), which owns the LTN rule. The sema turn is done (sema
`jm/dispatch-terms`); the scada's amendment branch and the LTN rule are
built on scada `jm/price-stages` and uncommitted; the constant stays
staging with `ProvisionalAction` added, until its signed text exists.
After that, the MarketMaker publishes `market.terms` for Keene and the
LTN reads it in place of the one constant it knows.

1. **Sema**: the words above; vendor into the scada and the maker.
2. **Scada**: built, uncommitted; the contract-lifecycle sub-spec in the scada
   executor is still to be opened. `DispatchTerms` on the contract is the
   one constant the LTN knows, `actors/dispatch_terms.py`, until the LTN
   reads `market.terms`.
3. **LTN**: built, uncommitted; the offer table, the single amendment and
   the deadline pinned by unit tests, the gaps above still open.
4. **MarketMaker**: publish `market.terms` for Keene; the journal keeps
   it.
5. **The signed text** for the first terms, and the constant's promotion.

## Open

- Which legal entities the parties' aliases name, and what the signed
  text is for `dispatch.terms.first.isone.hack`.
- Whether the constant marker is a registry kind of its own or a flag
  on a type, and whether a constant may have versions.
- Whether `market.terms` is journaled by type or by topic.
