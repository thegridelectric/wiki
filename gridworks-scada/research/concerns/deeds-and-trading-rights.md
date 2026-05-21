# Concern: TerminalAsset deeds & TradingRights

Design intent from Jessica. **Not implicit in the SCADA code yet** — Jessica
wants this written up here as the target. Historical context in `old_words/`.

## The target mechanism (Jessica)

Two distinct credentials the SCADA's identity rests on:

1. **TerminalAsset deed** — a signed key incorporating *third-party validation*
   of:
   - GPS location of the asset,
   - asset type (car, hot-water heater, thermal-storage heat pump, …),
   - power metering.
   This is the proof that the physical thing the SCADA represents is real, where
   it claims to be, and metered as claimed.

2. **TradingRights certificate** — held by the **homeowner**, provided to the
   aggregator **with clawback** as part of the SLA. Both the **MarketMaker** and
   the **SCADA REQUIRE this from the LTN** — i.e. an LTN cannot transact for this
   asset without presenting valid trading rights, and the SCADA will not accept
   dispatch from an LTN that lacks them.

The clawback is the homeowner's lever: revoking TradingRights moves
representation to a different aggregator (the only thing that fully completes the
Representation Contract — `old_words/representation-contract.md`).

## Historical model (`old_words/`, superseded direction)

The Algorand-era design (context, not the plan):

- **TaDeed**: the TaOwner holds a TaDeed establishing ownership of the
  TerminalAsset; the TaOwner creates an Algorand account for the SCADA and signs
  its public address (`ScadaAlgoAddr`) to the GNodeFactory; the SCADA signs
  DispatchContract messages with that key (`old_words/g-node-instance.rst`).
- **TradingRights**: blockchain NFT the homeowner grants the aggregator under the
  Representation Contract (`old_words/representation-contract.md`).
- **GNodeStatus** gates everything: `Active` (evidence the asset exists) is
  *required* before any contract needing trading rights or a deed can be entered;
  `Suspended` when certification lapses (`old_words/g-node-status.rst`).

## The likely modern direction

Moving off Algorand toward **mTLS + signed certificates** — same trust
properties (durable identity, third-party validation, clawback via revocation)
without the blockchain. This dovetails with the FIS / mTLS work in
[[../../../gridworks-fleet-index-service/research/design]] (cert CN = GNodeId;
single authorized instance per node). Open: is the TerminalAsset deed a separate
cert from the connection cert, or layered on it?

## Open questions

- Who is the third-party validator of GPS / asset-type / metering, and what does
  the signed deed actually contain?
- Where do the MarketMaker's and SCADA's "REQUIRE trading rights from the LTN"
  checks live (they don't exist in SCADA code yet — confirm)?
- Relationship between the deed, the mTLS client cert, and the FIS instance
  authorization.

## Links

[[liveness-and-sla]] · [[non-gnode-interfaces]] · [[../principles]] ·
`old_words/representation-contract.md` · `old_words/g-node-instance.rst`
