# TaDeed and TaTradingRights without Algorand

Status: Draft · Pass 0 · Updated 2026-08-14

> What this is: the successor to the legacy Algorand ownership plane —
> TaDeed (proof a validated terminal asset is owned), TaTradingRights
> (transferable, clawback-able authority to trade/dispatch it) — rebuilt on
> validator-signed records instead of NFTs. An exploration: the shape is
> converged enough to write down, the word schemas and registrar home are
> not. Extends the original intent capture at
> `wiki/gridworks-scada/explorations/deeds-and-trading-rights.md`
> (2026-06-23), which should fold into this doc once both can be edited in
> one session. Transport-plane counterpart: the mTLS + FIS auth work
> ([OPS-420](https://linear.app/gridworks/issue/OPS-420)).

## Legacy grounding (vision, not how)

In `legacy/g-node-factory`, the deed was an Algorand NFT whose name was the
asset's alias — `gnf_db.py`:

> `asset_name=g_node.alias, unit_name="TADEED"`

— minted by the factory, with the TaValidator holding its own cert NFT
(`unit_name == "VLDTR"`, `tavalidatorcert_algo_create.py`). An alias change
provoked a deed swap, and the exchange ceremony exists as types in
`legacy/gridworks-atn` (`old_tadeed_algo_return`, `new_tadeed_send`).
Dispatch authority was a smart contract both parties joined
(`dispatch_contract.py`, `join_dispatch_contract.py`). **TradingRights were
held by the homeowner** and granted to the aggregator under the
Representation Contract, with clawback as the homeowner's lever — revoking
them moves representation to a different aggregator
(`legacy/old_words/representation-contract.md`). `GNodeStatus: Active`
(evidence the asset exists) was required before any deed- or
rights-bearing contract could be entered.

What carries forward is the principle set: cryptographic veracity, third
parties attesting physical facts, homeowner sovereignty over
representation, transferable rights with clawback under an SLA, and
location embedded in the ownership document. The Algorand plumbing does
not.

## The two planes — opposite rename semantics, on purpose

The legacy design fused transport identity and ownership attestation into
one credential story. They separate:

- **Connection cert** (transport plane, mtls-fis-auth): binds the immutable
  `GNodeId` to a keypair. Says nothing about location, metering, or
  ownership. A rename **never** reissues it — a rename must never brick a
  house's comms; convergence is a FIS connection kill and re-check.
- **TaDeed** (authority plane, this doc): a validator's signed attestation
  of *a physical, metered asset at a grid location, owned by someone*. For
  a TerminalAsset the alias encodes the copper path — the market context
  the asset settles in — so **the alias belongs in the deed**, and a
  re-parent that changes the copper path invalidates the location claim:
  the deed is swapped (a retire record + a fresh issue), the legacy
  ceremony reborn as two signed records. An alias change provokes a new
  *deed*, never a new *connection cert*.

This answers the origin capture's open question ("is the deed a separate
cert from the connection cert, or layered on it?"): separate plane,
different document kind, deliberately opposite rename behavior.

## Mechanism: validator-signed sema records

`ta.deed` and `ta.trading.rights` become vocabulary words; each instance
carries a detached signature over its canonical form, made by the
**TaValidator's key, whose cert chains to the GridWorks CA** — how a third
party plugs into the trust root without holding any GridWorks authority.
X.509 deed-certificates were considered and rejected: certs are not
transferable, clawback becomes revocation, and revocation distribution is
exactly the machinery the fleet does not have.

- The deed binds **TaId (the TA's GNodeId — the immutable anchor) + the
  alias at issue (the attested location) + the owner (the homeowner's
  principal) + the attested facts (GPS location, asset type, power
  metering) + the validator's identity**.
- **Issue, transfer, clawback, retire are each a new signed record** — a
  transfer *is* a record, the semantics NFT ownership provided, without a
  chain. The append-only record sequence is the ledger; the eventstore is
  its durable history; a registrar (see Open) projects current-holder
  state; a public read façade makes any deed verifiable by anyone holding
  `ca.crt`.
- **TaTradingRights are the homeowner's.** The rights record grants an
  LTN's principal the authority to trade and dispatch a specific TA,
  referencing the SLA terms (by hash). Clawback is a homeowner-signed (or,
  for cause, validator-signed) revocation record — the lever that completes
  the Representation Contract by moving the asset to a different
  aggregator as a single record update.

The origin capture's four mechanism requirements, satisfied: a **single
authoritative answer** (the registrar's current-holder projection);
**unforgeable identity** (authority attaches to principals whose keys are
proven at the transport plane — never a string alias); **easy audit and
rotation** (re-aggregation and key revocation are each one signed record);
**uniqueness** (one rights holder per TA at a time, by construction of the
record chain). Uniqueness deliberately does NOT ride the proactor link's
one-active-parent property — the origin capture's own caveat: if transport
goes fan-out, link topology stops being an enforcement mechanism. Rights
are enforced by record + gate, not by wiring.

## Enforcement — where the documents bite

The deed is never shown in-band. It is a registry fact consulted at the
decision points where identity (the transport plane's *who is asking*)
meets authority (this plane's *what may they do*):

- **Dispatch: FIS `/auth/topic`.** An LTN's dispatch publish toward a scada
  is authorized only if the LTN's principal currently holds the
  TaTradingRights for that scada's TA — and rights exist only over a valid
  deed. An unentitled dispatch is not delivered-and-rejected; the broker
  refuses to route it. Since topic verdicts cache per connection,
  **clawback triggers a FIS connection kill** for that LTN — the same
  cache-flush move OPS-420 specifies for renames. This is the
  DispatchContract's successor, with the broker as referee.
- **Markets: the MarketMaker.** A bid naming a TA is accepted only from the
  principal currently holding its rights — checked against the registrar's
  projection at bid time, in the ack-is-a-binding-contract model.
- **The scada itself.** The origin intent: the scada REQUIRES rights from
  the LTN. Under the one-authz-layer principle the fabric makes this
  structurally true — an unentitled dispatch cannot reach the scada. Whether
  the scada *additionally* verifies a locally provisioned signed rights
  record (offline-checkable with `ca.crt`) is an open posture question —
  lean: not in hybrid; in `w`, where real money and real heat ride the
  answer, defense in depth is cheap and the record is one small file.

## Lifecycle ordering — cert first, deed second

1. Registry rows created (TA + scada + LTN, `Pending`) — identity exists.
2. Provisioning mints the connection cert (`CN=<GNodeId>`) — the scada can
   join the broker and telemeter. Commissioning needs comms before a
   validator ever visits.
3. TaValidator attests on site → **TaDeed** issued. (The legacy
   `GNodeStatus` gate carries forward: deed- and rights-bearing contracts
   require the TA `Active`.)
4. The deed enables the **TaTradingRights** grant to an LTN.
5. Only now does any party hold dispatch or market authority over the TA.

A freshly certed, undeeded scada connecting and emitting telemetry with
nobody entitled to dispatch it is the correct commissioning state, not a
gap.

## Deeds attest reality — in every universe

Proposed invariant: **a TaDeed SHALL only be issued for a physically
validated asset, in any universe.** The deed's meaning is that a third
party staked a signature on physical facts; a deed for a simulated asset is
a false attestation wearing the trust machinery. Hybrid universes don't
*require* deeds (trust by configuration/mTLS — gnr executor "Universes"),
but hybrid's real houses MAY receive real ones — so the full validator
ceremony can be dry-run on real Millinocket houses before the `w` universe
exists. If the hybrid game ever needs rights-transfer mechanics for
simulated assets, that is a distinct, clearly-marked word, never a TaDeed.

Non-copper services (weather, ear, gjk) get no deed — nothing physical to
attest. Their complete trust story is the transport plane: identity cert,
FIS principal, publish-time alias pinning, `validated-user-id` — which
already gives consumers broker-authenticated provenance on every message.

## Open

- **Registrar home.** Who projects current-holder state: gnr (it already
  serves the identity forest), a `w`-universe registrar sibling, or FIS
  (which consults but maybe shouldn't own). The terminalasset-registry
  domain exists to answer this.
- **Word schemas** — `ta.deed`, `ta.trading.rights`, the retire/transfer/
  clawback record kinds; signature scheme and canonical form (sema words
  are the payload; the signing convention is new ground).
- **Validator onboarding** — how a TaValidator's key is issued, scoped, and
  retired; whether validator certs carry constraints or FIS holds a
  `validator` principal kind (the principal-model exploration has the
  slot).
- **Re-parent granularity** — does every re-parent invalidate the deed, or
  only one that changes the market context (a cosmetic rename leaves
  metering and location physically unchanged)? Lean: the deed pins the
  copper path; any copper-path change re-attests. Needs a grill.
- **SLA encoding** — what of the SLA is machine-readable in the rights
  record (hash only vs. structured clawback conditions).
- **Scada-side verification posture** — see Enforcement; decide with the
  `w`-universe design.
- **Fold the origin capture** —
  `wiki/gridworks-scada/explorations/deeds-and-trading-rights.md` becomes a
  pointer here (or is deleted) once a session holds both claims.
