# Gridworks Provisioning — primary

Status: Draft · Pass 0 · Updated 2026-05-28

> **What this is.** The acceptable-minimum hub for the GridWorks
> provisioning + installer domain. Captures the actor + assertion
> model (carried forward from the legacy GNodeFactory / Algorand
> design, decoupled from blockchain), the role mTLS + FIS + the
> Sema-coupled "gem" GNode registry play, and the MVP installer-app
> flow. Most details are marked Open — fan out into sub-specs as the
> design converges.

## One-line summary

Provisioning turns hardware + paper agreements into a fully-credentialed,
broker-connected, Sema-correct GNode in the gem registry — through a
multi-party-attested process whose trust anchor is *independent validator
concurrence*, not any single party (including GridWorks).

## Actors

| Role | Persona name (legacy) | Responsibility |
|---|---|---|
| **TaOwner** | Holly Homeowner | Owns the physical terminal asset (heat pump, EV, hot water heater, …). Initiates provisioning. |
| **TaValidator** | Molly Metermaid | Independent third party. Certifies the asset exists, is metered, is located as claimed. **Trust anchor — Molly is the check on Holly AND on GridWorks.** |
| **GridWorks (GNF — GNodeFactory)** | — | The central registry admin. Holds the gem. Co-signs assertions. Cannot create TaDeeds alone. |
| **AtomicTransactiveNode (ATN)** | — | The trader-on-behalf-of-asset. Holds TaTradingRights. Separable from TaOwner so trading authority can be reassigned without disturbing ownership. |
| **SCADA (hardware)** | — | The Pi that senses + controls. Has its own cert binding hardware identity to TaAlias. |
| **Installer (app + human)** | (Aris, GridWorks staff, eventually homeowner) | Drives the provisioning flow on-site; communicates with the provisioning service. |

## Key assertions (the "NFTs" — decoupled from blockchain)

Each assertion is a signed, multi-party-attested record. In the legacy
design these were Algorand NFTs; in the gem-based implementation they
are gem rows with signed-record IDs.

1. **TaValidatorCert** — *"This validator is authorized to issue
   TaDeeds."* Required multi-sig: `[GridWorks Admin, Validator]`.
   Establishes the validator role.
2. **TaDeed** — *"This terminal asset exists, has this alias, is
   located at this coordinate, is owned by this entity."* Required
   multi-sig: `[GridWorks Admin, Validator]`. **Neither party alone
   can mint one** — this is the cornerstone trust anchor.
3. **TaTradingRights** — *"This AtomicTNode is authorized to trade
   on behalf of the asset."* Assigned by TaOwner; revocable. Encodes
   the Service Level Agreement.
4. **ScadaCert** — *"This hardware (with this public key) is the
   SCADA for this TaAlias."* mTLS cert binding device identity to
   asset identity. Issued during step 3 of installation (see
   "Installer flow" below).

Plus a **DiscoveryCert** used during the bootstrap step to establish
network presence before the SCADA's identity is finalized.

## The distributed-approval mechanism

What blockchain provided in the legacy design — and what the
underlying trust mechanic actually is:

| Mechanism | Blockchain impl (legacy) | Decoupled impl (gem + FIS) |
|---|---|---|
| Multi-party concurrence | 2-sig Algorand multisig transactions | Multi-signed gem rows; provisioning service rejects writes lacking required signatures |
| Independent verifiability | Public Algorand chain + asset indices | Cryptographic signatures + public-key registry coupled to FIS |
| Tamper-evident records | Append-only chain | Append-only audit log; root hashes optionally externally attested |
| Programmable conditions | Smart contracts | Explicit SLA documents + revocation hooks + dispute-resolution process |
| Asset-handoff atomicity | NFT transfer transaction | Signed transfer-of-authority record + revocation of prior holder's claim |

**The trust anchor is multi-party-attestation, not any specific
substrate.** The blockchain-decoupled implementation keeps the
trust model; the substrate becomes postgres + signatures + FIS.

## The gem — Sema-coupled GNode registry

Per [`../../sema/research/where-meaning-lives-in-gridworks.md`](../../sema/research/where-meaning-lives-in-gridworks.md):

The gem is the **canonical seed database**. It holds Sema-typed GNode
facts (`g.node.gt` records) as its primary content. The legacy
GNodeFactory django models hold roughly the same shape *plus* the
cert-related columns (`ownership_deed_id`, `ownership_deed_validator_addr`,
`owner_addr`, `daemon_addr`, `trading_rights_id`, `scada_algo_addr`,
`scada_cert_id`).

The gem-based decoupled implementation:
- GNode rows ARE `g.node.gt` Sema-typed records — sema-correct by
  construction.
- Cert columns point at internal signed-record IDs (not blockchain
  asset indices).
- Multi-sig enforcement happens at the gem-write boundary —
  attempting to insert/update a cert column without the required
  signatures returns an error.
- Lifecycle states (`Pending`, `AwaitingValidator`, `Active`,
  `Suspended`, `Revoked`) are enforced as transitions.

The gem is **the FIS reference for which GNodes exist** (per the FIS
design — *"FIS consumes [registry messages] and populates its own
g_node table, keeping a strict bijection between g.node.gt and the
g_node table"*).

## mTLS + FIS coupling

The provisioning system extends — does not replace — the mTLS + FIS
infrastructure already designed for runtime authorization
([`../../gridworks-fleet-index-service/research/design.md`](../../gridworks-fleet-index-service/research/design.md)):

- **At provisioning time**: a new GNode's cert is **minted** — by the
  provisioning service (which has authority to issue per the FIS
  trust chain).
- **At runtime**: FIS validates that cert + authorizes the
  GNodeInstanceId (per the runtime invariants).

Provisioning therefore needs:

- A **cert-issuing capability** (operates within FIS's trust chain) —
  could live in FIS itself, in a separate provisioning service that
  FIS trusts, or in a co-located component.
- A **gem-write capability** with multi-sig enforcement.
- A **broker-config push capability** so the SCADA knows where to
  connect after install.

Open: **where exactly does the provisioning service live?** In FIS,
beside FIS, or in a separate domain. See `research/concerns/`.

## Installer flow (MVP)

The installer app on-site drives this. Each step has a verification
gate; the install isn't complete until step 7 passes.

```
1. Site-pairing request
   Installer authenticates to provisioning service (installer cert
   or one-time token).
   Provides: site identifier, TaOwner identity, requested TaAlias,
   physical location.
   Service: creates gem row in Pending state; returns
   provisioning-request-id.

2. Validator concurrence
   Validator (Molly) inspects the asset on-site (or remote-attests
   per validator process).
   Submits signed attestation referencing the provisioning-request-id.
   Service: gem row advances to AwaitingValidator → if both sigs
   present, transitions to PendingActivation; emits TaDeed assertion.

3. SCADA identity minting
   Installer triggers on-Pi key generation (private key never leaves
   Pi).
   SCADA submits public key + DiscoveryCert + provisioning-request-id
   to provisioning service.
   Service: validates request is in PendingActivation; mints
   ScadaCert binding pubkey to TaAlias; returns cert + broker list.

4. On-Pi configuration
   Installer writes onto Pi:
   - g.node.gt.json (the Sema-validated GNode identity from gem)
   - ScadaCert + private key (XDG config path)
   - Broker URL list (prod, admin if applicable, plus any
     observability-side brokers the Pi needs)

5. Network connectivity test
   Installer (or SCADA's bootstrap) attempts TLS connect to every
   broker in the list.
   Records pass/fail per broker.

6. mTLS handshake + FIS authorization
   SCADA opens AMQP connect; FIS validates cert + authorizes
   GNodeInstanceId.

7. LTN ↔ SCADA pairing verification
   Cloud-side LTN (provisioned in parallel) initiates a test
   message exchange via the prod broker.
   Both sides report success to provisioning service.
   gem row transitions to Active.

(Steps 5-7 may be deferred for offline-install — site marked
OfflineConfigured; later return finalizes.)
```

### Per-site lifecycle (gem column)

```
ProvisionRequested
  → IdentityMinted        (step 1 complete; assertion in gem)
  → AwaitingValidator     (TaOwner signed; Validator outstanding)
  → PendingActivation     (both sigs present; TaDeed minted)
  → OfflineConfigured     (steps 3-4 done; broker tests pending)
  → BrokersReachable      (step 5 passed)
  → LtnScadaPaired        (step 7 passed)
  → Operational           (lifecycle terminal happy state)

  Side states:
  → Suspended             (operational issue; temporary)
  → Revoked               (terminal; cert chain revoked at FIS)
```

## What's separately needed for AtomicTNode + TaTradingRights

The MVP focuses on **SCADA-side provisioning** (steps above). The
**AtomicTNode side** — the trader's identity, the TaTradingRights
assignment from TaOwner to AtomicTNode, the SLA document — is a
parallel concern, sharing the same gem + FIS substrate but distinct
from the on-Pi bring-up. Marked Open; sub-spec when scoped.

## Trust-model invariants

Carried forward from the legacy design + extended:

1. **No single party can mint a TaDeed.** Multi-sig of
   `[GridWorks Admin, Validator]` is required. This is the trust
   anchor of the whole system.
2. **Validator independence is the check on GridWorks.** A
   compromised GridWorks admin alone cannot fabricate assets.
3. **TaOwner can revoke TaTradingRights** by reassigning, without
   disturbing TaDeed (asset ownership).
4. **Hardware identity (ScadaCert) is distinct from asset identity
   (TaDeed).** Replacing hardware doesn't change the asset; replacing
   the asset doesn't repurpose the hardware.
5. **Installation isn't complete until broker connectivity is
   demonstrated** (per `wiki/gridworks-base/designs/support-non-gnode-actors/gwbase-v-next-functional-research.md`'s
   discussion + the user's installer-must-test-brokers requirement).

## Cross-references

- [`../../sema/research/where-meaning-lives-in-gridworks.md`](../../sema/research/where-meaning-lives-in-gridworks.md) — the gem as canonical seed
- [`../../gridworks-fleet-index-service/research/design.md`](../../gridworks-fleet-index-service/research/design.md) — FIS auth model (Invariants #2, #3, #4 generalize to operator certs and installer certs)
- [`../../gridworks-scada/research/concerns/non-gnode-interfaces.md`](../../gridworks-scada/research/concerns/non-gnode-interfaces.md) — original framing of provisioning as an open concern
- [`../../gridworks-base/designs/support-non-gnode-actors/gwbase-v-next-functional-research.md`](../../gridworks-base/designs/support-non-gnode-actors/gwbase-v-next-functional-research.md) — installer-must-test-brokers requirement + observability framing
- Legacy code reference: `~/Claude/GNodeRegistry/` (gnf.gnf_db.py, gnf.django.models.py, gnf.basegnode_scada_create.py, gnf.rest_api.py)
- Legacy whitepaper docs: `~/Claude/Algorand/` (PDFs / PPTXs — read with poppler / office-tooling when needed for deeper trust-model history)

## Open — populated as design converges

- **Where does the provisioning service live?** In FIS, beside FIS,
  or as its own service. See `research/concerns/`.
- **Validator recruitment + revocation process.** How do Mollies
  become Mollies; how do they stop?
- **TaTradingRights modeling.** Gem-row or signed-contract artifact;
  SLA shape; dispute resolution.
- **Offline install finalization.** Mechanism for completing steps
  5-7 after initial provisioning.
- **Per-site lifecycle transitions.** Who can drive each transition;
  audit trail.
- **Re-provisioning + cert rotation.** What happens at hardware
  replacement, cert rotation, GNode alias change, ownership transfer.
- **Installer-app distribution + auth.** How installer certs / tokens
  are issued; how Aris-style third-party installers integrate.
- **Migration path from legacy GNodeFactory.** If there's any
  existing on-chain TaDeed data to import — or if this is greenfield.
