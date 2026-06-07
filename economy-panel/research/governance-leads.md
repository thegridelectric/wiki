Status: Draft · Pass 0 · Updated 2026-06-07

> Research note (not normative). Tracks candidate stewards and
> integration partners for the Economy Panel architecture. The
> open question — "GridWorks-incubated through critical-mass
> adoption, or steward-led from day one?" — is unresolved.
> See [`../executor/primary.md`](../executor/primary.md) "Why
> this is open-source and not a startup" and the (Open)
> [`../executor/stewardship.md`](../executor/stewardship.md)
> spoke.

## EKM Metering — externally committed for v1 master economy meter

**Status:** The **EKM Omnimeter** is named in the 2026-06-05
letter to ISO-NE (Matt White) as the revenue-grade meter
GridWorks will install behind the Versant bonus meter — i.e.
the master economy meter for the parallel-metering
configuration. This is a public commitment, not an internal
working choice.

**Per the letter (excerpted):** "We would also specifically
welcome ISO-NE's input on the revenue-grade meter we install
behind the Versant bonus meter. We have in mind the EKM
Omnimeter."

**What this fixes in the v1 spec:**
- The master economy meter is revenue-grade (ANSI C12) by
  EKM Omnimeter, ~$200 contribution to the BOM at single-unit
  retail.
- The Economy Panel encloses an EKM Omnimeter behind its
  smart-side wiring; the TaReader reads it (probably pulse
  output) for the ISO-NE AMR submission.

**Open follow-ups (broader EKM relationship):**
- **Sub-metering layer (layer-b) integration.** EKM's per-
  circuit meter products are candidates for the panel-side
  sub-meters (v1 panel-side, not appliance-embedded per the
  red-team revision). Specs, pricing at OEM volume, protocol
  openness all open questions.
- **OEM-embedded path** (long-term, ≤$15 target). If EKM is
  interested, a partnership where they spec an embedded
  variant for heat-pump / HPWH / EV-charger / battery OEMs
  could be the layer-(b) endgame.
- **Strategic fit / cultural fit.** Non-VC ≠
  mission-aligned. A direct conversation with EKM about
  open-source posture, protocol disclosure, and willingness
  to commit to an open BOM is the next step.
- **GridWorks-EKM existing relationship?** Unknown; needs
  internal check.

## Candidates ruled out by the industry survey

The 2026-06-07 industry survey
([`industry-survey.md`](industry-survey.md)) confirms none of
the smart-panel incumbents are credible stewards. All are
firmware-as-safety, proprietary, and capital-structured against
resident-side transactive participation.

- **Stepwise** — $1.4M pre-seed, contract-manufactured via SoPark.
  Jane Chen (Wharton/Sloan, no EE/firmware background); no public
  open-source stance. Not a panel replacement — a power monitor
  between panel and large new load.
- **SPAN** — $176M Series C closing Jan 2026 + $75M Eaton
  investment Mar 2026. **Explicitly pivoting away from
  resident-side bidding** toward utility-as-customer DERMS via
  SPAN Edge + Landis+Gyr. Most-funded incumbent and the
  least-aligned trajectory.
- **Lumin**, **Leviton Load Center**, **Schneider Square D
  Energy Center** — proprietary firmware in the safety path;
  UL 3141 / UL 916 certification cost as moat against open
  entrants. Not steward candidates.
- **Savant Power Modules**, **Koben Systems (Schneider Pulse)**
  — newer entrants; same proprietary thesis at smaller scale.

## Other lead categories to watch

- **Cooperative/muni-owned utilities** considering smart-panel
  programs — would have the right mission profile but may lack
  manufacturing/engineering scale.
- **University-led open hardware initiatives** (MIT, NREL,
  Berkeley Lab) — could be a host for the open-source
  reference design but not a hardware shipper.
- **Existing open-source energy projects** (OpenEnergyMonitor,
  OpenEMS) — potential collaboration on firmware / data
  protocols, not on the panel hardware.
- **Mission-aligned hardware co-ops** (Wikitribune-shaped
  organizations for hardware, if any exist) — TBD.

## Governance recommendation (from industry survey)

The 2026-06-07 survey found **no credible mission-aligned
steward exists today**. OpenEMS e.V. is the closest cultural
fit but works neither on service-entrance hardware nor on US
NEC compliance; handing them the architecture would mean
abandoning the analog-failsafe and panel-MarketMaker layers.
OpenEnergyMonitor is a hobby/monitoring project.

**Recommended posture:**

1. **GridWorks owns commercialization through critical-mass
   adoption.** Specifically:
   - Layer (a) — analog failsafe physical IP + reference BOM
     under a permissive hardware license (e.g., CERN-OHL,
     Solderpad).
   - Layer (c) — protocol spec stewarded by GridWorks until
     battle-tested.
2. **EKM evaluation in parallel.** Independent of the
   layer-(a)/(c) call, evaluate EKM as the **layer-(b)
   sub-metering integration partner** (target: ≤$15
   appliance-embedded). Their meter expertise + lack of VC
   pressure make them the strongest near-term hardware ally
   even if not the long-term steward.
3. **Eventual handoff to a neutral foundation for layer (c).**
   **LF Energy** is the natural home (it already hosts
   OpenEMS-adjacent projects). Hand off only after:
   (i) at least one third-party manufacturer ships a UL-listed
   Service-Entrance Overload Protector to the open BOM, AND
   (ii) at least one utility integrates the transactive protocol.
4. **Layer (b) sub-metering open from day one.** UL barriers are
   lower than for layer (a); the network effect requires open
   sub-metering interop to scale across appliance OEMs.

## Open follow-ups

- Talk to EKM (or whoever at GridWorks already has a
  relationship) about: (i) embedded-meter cost-engineering at
  the ≤$15 target, (ii) protocol openness, (iii) willingness
  to be the layer-(b) partner under an open-source covenant.
- Investigate **LF Energy** governance model for the eventual
  protocol handoff path.
- Confirm UL 916 / UL 3141 certification cost and process for
  the analog-failsafe reference design — survey flagged this
  as a barrier any open project will hit.
