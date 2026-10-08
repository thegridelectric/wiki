# Hundred-home cert mint

Status: Draft · Pass 0 · Updated 2026-10-07 · Linear: OPS-575

**EDD: yes** verified when a house provisioned by the one tool run connects
through the live gate on cert and claims with no hand step on the FIS box,
and a house the registry does not know is denied; witnessed by the FIS
gate battery's MQTT leg, not by code review.

> What this is: make a house's broker identity one provisioning act that
> scales to 100 homes. Today a house's two identities (scada, LTN) each
> need a client cert cut on certbot and a principal row on the FIS that
> gates the broker. The design decides whether a GNode needs a row at all
> and folds whatever remains into the mint. FIS v1 is OPS-422; the gate
> window and the proactor MQTT client-id change are OPS-420.

## Where it stands

The prod FIS holds sixteen principal rows: weather and eleven houses as
GNodes, four Services. The eleven house rows were minted by hand on
2026-10-07 from the cert ledger (`fis principal create --kind GNode
--g-node-id`), one ssh loop, because their certs were cut before the mint
tool existed. Elm's scada has no row because its cert is not in the ledger
(pi unreachable); it gets one when `record elm` runs. The mint tool already
creates a GNode's row on the gating FIS as its first step, so a house
minted through the tool costs no second hand step today. What does not
scale is the row itself: per-house state on the authority box that must
agree with the registry and the ledger, three places that can drift.

## The question

A GNode is already fully described by the registry: its GNodeId is the
cert CN, its alias and class are what the gate checks, its status is the
registry's. The principal table adds nothing a GNode did not already have
except the suspension lever. Two shapes:

- **A. Rows for everyone, minted by the tool.** The model as built. The
  tool is the single act; the row is a side effect the operator never
  types. Cost: a third copy of "this house exists", and a house moved to a
  new FIS (a broker move, a second universe) needs its rows carried as
  records.
- **B. Rows for Services only; GNodes derived from the registry mirror.**
  The gate admits a GNode iff the mirror (or a read-through) knows its
  GNodeId with status Active and the claims match. The suspension lever
  for a GNode becomes a registry status change, or a small FIS-local
  block set if the gnr round trip is too slow for an emergency eviction.
  Cost: the executor's principal model splits in two, and `/auth/topic`
  must read through on a mirror miss as `/auth/user` does.

B is the shape the vision wants: a house exists in one authority, the
registry, and every other service learns of it from there. A decides
nothing new and is what runs today.

## Out of scope

Renewal automation (a follow-on named in OPS-420's cert lifecycle); the
provisioning service that later absorbs the tool; the proactor MQTT
client-id change (OPS-420).

## Do this next

Decide A or B with the human (grill the B lever: what suspends a house in
an emergency, and how fast). Then one spoke: the gate change if B, the
tool's house path and the carry-rows recipe if A, and the battery leg that
is the done-when.
