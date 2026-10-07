# TaDeed and TaTradingRights without Algorand

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: the successor to the legacy Algorand ownership plane,
> rebuilt on validator-signed records instead of NFTs. This doc holds the
> TaTradingRights half (transferable, clawback-able authority to trade and
> dispatch a validated asset) and the enforcement points; the TaDeed and
> its infrastructure are the ta-deed-infrastructure design (Linear
> OPS-574). An exploration: the shape is
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

The connection cert (transport plane, OPS-420) and the TaDeed (OPS-574)
are separate documents with deliberately opposite rename behavior: a
rename never reissues the cert and always provokes a new deed. The
deed side is specified in the ta-deed-infrastructure design (Linear
OPS-574) "Two planes, opposite rename semantics". TaTradingRights ride
the deed side: rights exist only over a valid deed.

## Mechanism: validator-signed sema records

`ta.deed` and `ta.trading.rights` become vocabulary words; each instance
carries a detached signature over its canonical form, made by the
**TaValidator's key, whose cert chains to the GridWorks CA** — how a third
party plugs into the trust root without holding any GridWorks authority.
X.509 deed-certificates were considered and rejected: certs are not
transferable, clawback becomes revocation, and revocation distribution is
exactly the machinery the fleet does not have.

- What the deed binds and how it is signed: ta-deed-infrastructure
  (OPS-574) "The deed".
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

Specified in the ta-deed-infrastructure design (OPS-574) "Lifecycle:
cert first, deed second". What this doc adds: the deed enables the
**TaTradingRights** grant to an LTN, and only then does any party hold
dispatch or market authority over the TA.

## Deeds attest reality — in every universe

The `ValidationState` values, simulated-asset deeds and the universe
rule are in the ta-deed-infrastructure design (OPS-574) "The deed" and
"Simulated assets"; the scada-side consequences are canonical in the
scada executor `scada-ltn-link-state.md` "The trading gate". Non-copper
services (weather, ear, gjk) get no deed and no trading rights; their
whole trust story is the transport plane.

## Open

The deed-side questions (registrar home, validator onboarding, re-parent
granularity, scada verification posture) moved to OPS-574.

- **Word schemas** — `ta.trading.rights` and the transfer/clawback record
  kinds. The deed words and the signing convention are OPS-574's.
- **SLA encoding** — what of the SLA is machine-readable in the rights
  record (hash only vs. structured clawback conditions).
- **Fold the origin capture** —
  `wiki/gridworks-scada/explorations/deeds-and-trading-rights.md` becomes a
  pointer here (or is deleted) once a session holds both claims.
