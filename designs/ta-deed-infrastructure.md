# ta-deed-infrastructure

Status: Draft · Pass 0 · Updated 2026-10-07 · Linear: OPS-574

**EDD: yes** verified by a validator issuing a real deed on a real
Millinocket house through the deed tool, the registrar serving it, the
house's GNode going `Active`, and the scada's trading gate opening on the
deed's state; and by the same ceremony on a simulated house producing a
`ValidatedSimulatedAsset` deed that a `w` broker refuses.

> What this is: the TaDeed and the infrastructure that produces, stores and
> serves it. A deed is a validator-signed sema record attesting what a
> terminal asset physically is and where it sits on the grid. The
> infrastructure is a validator's deed tool, validator onboarding into the
> GridWorks trust root, a registrar with a public read façade, the GNode
> status flip, the simulated-asset path, and the re-attestation flows. The
> transport plane (certs, FIS, the broker gate) is OPS-420; TaTradingRights
> stay in `terminalasset-registry/explorations/deeds-and-trading-rights.md`.

## Why now

The hundred-homes plan (`hundred-homes/tools.md` "Validator's deed tool",
`notes/customer-acquisition-notes.md` "Rough calendar") has the deed tool
ready for the spring 2027 seed installations, the first homes where
Ridgeline issues the deed. The service-level agreement draft names the
independent validator. A replaced meter sends a home back to the deed tool
and the home is flagged until the new deed exists; the validator makes a
yearly physical check of the meters. None of this exists yet, and today
nothing compares a layout with the physical house.

## The deed

A TaDeed attests the **validation state** of a device, in any universe. A
TaValidator stakes a signature on what the asset is, and the deed carries
that finding as a `ValidationState` that every reader consults; the deed's
existence alone says nothing. The values, one per thing a validator can
vouch for:

- `UnValidated`: no deed. The scada's own default before a validator
  visits.
- `ValidatedRealAssetAndGps`: physical load drawing electricity where its
  alias and GPS say it is (the Millinocket houses).
- `ValidatedRealAssetIncorrectGps`: physical load drawing real electricity,
  but not at the declared location. Run against Millinocket prices on `hw1`
  from somewhere else (a bench box is the small case).
- `ValidatedSimulatedAsset`: no electricity drawn anywhere.

The deed binds the TaId (the TA's GNodeId, the immutable anchor), the alias
at issue (the attested location; the alias encodes the copper path, the
market context the asset settles in), the owner (the homeowner's
principal), the attested facts (GPS, asset type, power metering: the meter
as installed, its serial, the circuit it measures, a reference comparison)
and the validator's identity. Each instance carries a detached signature
over its canonical form, made by the validator's key, whose cert chains to
the GridWorks CA. That is how a third party plugs into the trust root
without holding any GridWorks authority. Issue, retire and re-issue are
each a new signed record; the append-only sequence is the ledger and the
eventstore its durable history. X.509 deed-certificates were considered
and rejected: certs are not transferable, and revocation distribution is
exactly the machinery the fleet does not have.

**Words.** `ta.deed` v000 and `ta.validation.state` exist in staging
(TaId, TaAlias, ValidationState, ValidatorAlias, IssuedS). Still open: the
signature and canonical form (sema words are the payload; the signing
convention is new ground), the owner principal field, the attested-facts
fields, and the retire record kind.

**Non-copper services** (weather, ear, gjk) get no deed. Nothing physical
to attest; their whole trust story is the transport plane.

## Two planes, opposite rename semantics

- **Connection cert** (transport plane, OPS-420): binds the immutable
  GNodeId to a keypair. Says nothing about location, metering or
  ownership. A rename never reissues it; convergence is a FIS connection
  kill and re-check.
- **TaDeed** (this design): a re-parent that changes the copper path
  invalidates the location claim, so the deed is swapped: a retire record
  and a fresh issue. An alias change provokes a new deed, never a new
  connection cert.

## Lifecycle: cert first, deed second

- **make-g-node**: the scada's GNode is created `Pending` (`g.node.status`)
  with its alias, and its transport cert is minted against that alias in
  the same act. The cert admits the scada to the broker; alias pinning
  means it can only ever speak as that alias. This is the state of the
  whole fleet today.
- **validate**: a TaValidator visits, the deed tool walks the checks, the
  signed deed is issued, and the GNode goes `Active`. Activation is the
  deed landing.
- **Pending is the fence.** A `Pending` GNode with a cert connects and
  telemeters. Nothing consequential is open to it: no LTN holds rights over
  it and no contract binds. There is no separate holding broker for the
  undeeded; the status on the ordinary broker is the holding pen. Today the
  fence is enforced on the scada side (an `UnValidated` scada rejects every
  contract offer with `slow.contract.rejection`, scada executor
  `scada-ltn-link-state.md` "The trading gate"); a broker-side rights
  check at FIS `/auth/topic` is the exploration's planned second layer,
  not built.
- **re-attest**: a replaced meter, or a re-parent that changes the copper
  path, retires the deed and the home goes back to `Pending` until the new
  deed exists. The yearly meter check is a re-attestation that confirms the
  current deed.

**What the scada reads** is already canonical: which silicon to drive comes
from the layout's board record, whether to listen to a time coordinator from
the layout being simulated, whether it may join an LTN contract from its
`ValidationState` (scada executor `components.md` "Hardware backend
selection is the layout's job"; `scada-ltn-link-state.md` "The trading
gate").

## Simulated assets

A simulated asset gets a real deed with `ValidatedSimulatedAsset`, signed
by a validator. What the validator vouches for is small (the identity
declares itself simulated, the layout carries sim devices, the universe is
dev or hybrid) and the deed admits to dev and hybrid universes, never `w`.
The universe guardrail refuses a simulated layout on a `w` broker from the
scada side; the deed refuses it from the validation side. Hybrid universes
do not require deeds, but hybrid's real houses may receive real ones, so
the full validator ceremony is dry-run on real Millinocket houses before
the `w` universe exists. For the simulated fleet the make-imaginary wand
issues Pending GNode, cert and simulated-asset deed in one motion, so sims
are never `UnValidated` for long.

## The infrastructure

- **validator-deed-tool**: walks the validator through the on-site checks
  and produces the signed deed. The user interface the validator (Ridgeline)
  uses in the house. Needs the home's component list readable by a person
  (`hundred-homes/tools.md` "Component list per home").
- **validator-onboarding**: how a validator's key is issued, scoped and
  retired; whether validator certs carry constraints or FIS holds a
  `validator` principal kind.
- **registrar**: holds the signed records, projects current state, serves
  it behind a public read façade so any deed is verifiable by anyone
  holding `ca.crt` (reads follow `api-pattern.md`). Who owns it is open
  (below).
- **status-flip**: the deed landing moves the GNode `Pending` to `Active`
  in the GNode registry (gnr), and a retire record moves it back.
- **make-imaginary**: the simulated-fleet path above.
- **re-attestation flows**: new deed on meter change; the yearly check;
  the home flagged while undeeded.

## Open

- **Registrar home.** gnr (it already serves the identity forest), a
  `w`-universe registrar sibling, or FIS (which consults but maybe should
  not own). The terminalasset-registry domain (OPS-471) tracks layouts and
  operational params over time; whether the deed registrar lives beside it
  or elsewhere is part of this question.
- **Which GNode's status gates.** The scada's GNode, the TA's, or both.
- **Re-parent granularity.** Does every re-parent retire the deed, or only
  one that changes the market context? Lean: the deed pins the copper
  path; any copper-path change re-attests. Needs a grill.
- **Scada-side verification posture.** Whether the scada additionally
  verifies a locally provisioned signed deed offline with `ca.crt`. Lean:
  not in hybrid; in `w`, defense in depth is cheap.
- **Signature scheme and canonical form** for a signed sema record.

## Done-when

- A validator issues a deed on a real Millinocket house through the tool;
  the registrar serves it; the GNode is `Active`; the scada accepts a
  contract offer it refused the day before.
- A simulated house gets a `ValidatedSimulatedAsset` deed from the
  make-imaginary wand and a `w` broker refuses it.
- A retired deed sends a house back to `Pending` and the scada's trading
  gate closes.
- Any party with `ca.crt` verifies a served deed's signature.
