# Concern: TerminalAsset deeds & TradingRights

Status: Draft · Pass 0 · Updated 2026-06-23

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

## Mechanism requirements (merged 2026-06-10 from gridworks-infra `ltn/ltn-trading-rights.md`, now deleted)

TradingRights authorize the LTN to enter Dispatch contracts with the
SCADA and market contracts on its behalf. The working notes' four
requirements on the proof mechanism:

1. **Single authoritative answer** to "who can control this SCADA" —
   ideally a shared registry.
2. **Unforgeable identity**: the SCADA verifies the caller holds a
   specific private key (or equivalent), not just a string alias.
3. **Easy to audit and rotate**: moving the asset to a different LTN is
   a single-record update; a compromised LTN key is revocable.
4. **Uniqueness**: one concrete entity may hold the Dispatch Contract at
   a time, demonstrated by TaTradingRights ownership.

The notes proposed **building on the gwproactor active link** for the
uniqueness leg (the one-active-parent property doubling as
one-counterparty enforcement). Caveat added at merge: that same 1:1
property is the link mechanism's *structural limitation* for the
aggregation future (see `executor/scada-ltn-link-state.md`) — if the
transport goes fan-out, uniqueness needs its own enforcement rather than
riding the link topology.

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
