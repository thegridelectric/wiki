# Aggregator

Status: Draft · Pass 0 · Updated 2026-11-25

> What this is: a sketch of the aggregator, the business entity that acts
> in a market for a set of TerminalAssets whose trading rights it has been
> granted. It stands in place of per-house LTN processes.
> Not normative, and nothing here is scheduled before the 2026-27 heating
> season.

## Why it is needed

A LeafTransactiveNode is a place: the slice of copper directly above the
metering point of one TerminalAsset. It is unique because the meter is.
A company that serves many houses is a different kind of thing. It has
service level agreements with homeowners, it has been granted their
trading rights, and it wants to run its software however it likes, one
process for a thousand houses included. The aggregator is the GNode that
company identifies as. It gives "one party acting for many houses" a
single alias, a single cert and a single bid, so the registry stays right
about who is on the broker.

## What an aggregator satisfies

1. One rights holder per TerminalAsset at a time.
2. Whoever dispatches a scada is the principal that has its trading
   rights.
3. Whoever bids proves rights over everything the bid covers.
4. A bid is for one market slot, so one bid covers only members that
   clear at the same MarketMaker.

The MarketMaker and the FIS gate can check all four whether the
bidder is an aggregator or a single LTN.

## An aggregator or an LTN process

The aggregator is a GNode, has the trading rights of its
members and runs the financial transactions with MarketMakers.

An aggregator and a per-house LTN process are alternatives for the same
place. Where every house keeps its own LTN process, each LTN has its own
rights, bids for itself and settles for itself, and a business aggregator
has no job on the broker. The company that operates those LTNs is then a
fact about who has their keys and who signed the service level
agreements, and it is no GNode.

The aggregator is a superset of an LTN: for every
member it heartbeats the scada, enters and keeps the dispatch contract,
takes its reports and plans its heat, and on top of that it bids for the
set and divides what clears. A member's LTN is then a passive GNode: it
stays in the registry as the place the meter and the price refer to, and
it has no process, cert or lease, and nothing on the broker is addressed
to it. Passive GNodes exist already. A ConnectivityNode is always one,
and a TerminalAsset is one in a real house and a running actor in a
simulated one.

A house with no aggregator is an LTN that has its own rights and bids for
itself, which is what GridWorks runs today, one LTN process per house.

A MarketMaker bidding into its parent MarketMaker is the same pattern one
level up the tree and uses the same bid word.

## What exists already

- **The bid word takes any participant class.**
  [`bid/000.yaml`](../../sema/definitions/types/bid/000.yaml)
  > "Differences between participant classes (e.g. leaf nodes,
  > aggregators, fleets, generators)"

  `BidderAlias` is any alias, `MarketSlotName` names the market, and
  `SignedMarketFeeTxn` is scoped to fee payment and says it does not
  prove portfolio composition.
- **Rights attach to a principal, and uniqueness comes from the record
  chain.**
  [`../terminalasset-registry/explorations/deeds-and-trading-rights.md`](../terminalasset-registry/explorations/deeds-and-trading-rights.md)
  "Mechanism: validator-signed sema records"
  > "one rights holder per TA at a time, by construction of the"

  Moving a house to another aggregator is one signed record. Dispatch is
  enforced at the FIS topic gate and bids at the MarketMaker ("Enforcement
  — where the documents bite").
- **The gate is per connection.** FIS enforces one live instance per
  (GNodeId, run)
  ([`../gridworks-fleet-index-service/executor/primary.md`](../gridworks-fleet-index-service/executor/primary.md)
  "Purpose"), so an aggregator is one identity with one lease however
  many houses it serves.

## Open

- **Proof of rights over the set.** The MarketMaker reads the registrar's
  current-holder projection at bid time, or the aggregator presents a
  signed membership record. The first needs no new word.
- **Where the alias sits.** An aggregator is a business entity and has no
  place in the copper, which suggests the universe root. Its members may
  span several MarketMakers, and it then bids once per market.
- **A netting party is a different kind of GNode.** A company could
  settle a portfolio as one position, so one house's shortfall offsets
  another's surplus. That party never dispatches and has no place; it is
  purely financial, and it could sit above LTN processes and aggregators
  alike. It matters only if a MarketMaker's imbalance terms are
  non-linear, since linear terms give the same sum either way. If it is
  ever wanted it gets its own GNode class and its own name.
- **Where "passive" is recorded.** An LTN moves between passive and
  active when its rights move (a homeowner leaving an aggregator to run
  their own LTN), so it may be better derived from the rights record
  than stored on the GNode.
- **Who a scada takes dispatch from.** A scada names
  its LTN as its counterparty today. With no LTN process it takes
  dispatch from the principal that has its rights, so the counterparty
  follows the rights record and changes on a clawback.
- **Dispatch at scale.** One identity keeping a
  dispatch contract and its heartbeats with every member scada, and all
  members' reports arriving at one alias.
- **Correlated failure.** An aggregator that stops
  sends every member to local control at the same moment, a step change
  in load the MarketMaker sees at once.
- **Settlement.** Meters settle per TerminalAsset; how an aggregate
  position is reconciled against them.
- **Membership changes mid-slot**, clawback included.
- **Liveness.** What a watcher of per-house LTNs (OPS-695) watches when
  the members have no process.
