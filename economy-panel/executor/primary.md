Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: the hub for the **Economy Panel** architecture — a
> residential smart electrical panel that combines an NEC-grounded
> analog overload-protection failsafe with trust-anchored
> revenue-grade economy metering and a latent panel-level market maker, all
> inside a sub-panel-shaped enclosure. **Open-source by default.**
> Intentionally distinct from the venture-backed smart-panel
> industry.
>
> **Natural install:** any **heat-pump-thermal-storage home** —
> existing Versant Rate A-1 customers and the broader population
> of heat-pump-TS homes elsewhere. The pitch is "install this now
> and add EVs, heat-pump water heaters, and batteries gracefully
> later as your flexible-load count grows." See
> [`../../economy-energy-markets/executor/primary.md`](../../economy-energy-markets/executor/primary.md)
> for the EEM market-participation context.

## The architecture — three stacked layers

Each layer is independently grounded and independently inspectable:

1. **Analog failsafe (Service-Entrance Overload Protection).**
   Electromechanical overload protector at the service entrance.
   NEC 220.70 / 750.1 compliant. ~$331 BOM in UL-listed off-the-
   shelf parts. Software-independent: even if every controller
   above this layer fails or is misconfigured, the failsafe cuts
   the transactive load when total approaches the service-entrance
   limit. Sourced from the **Piantedosi Special** designed by
   Matt Piantedosi (MassPort / Logan Airport). See
   [`../research/piantedosi-special.md`](../research/piantedosi-special.md).

2. **TaReader integration with a master economy meter.**
   The TaReader reads a single revenue-grade master economy
   meter (committed externally as the EKM Omnimeter in the
   2026-06-05 ISO-NE letter) and submits its AMR data upward
   to ISO-NE per III.6.4(f). **The architecture does NOT
   commit to per-TerminalAsset sub-metering at the v1 stage**
   — when homes add additional TerminalAssets (EV, HPWH,
   battery), the right metering approach will be decided
   then. For heat-pump-thermal-storage v1 deployments, the
   panel typically also includes an extra CT for **COP
   accounting** (so the resistive elements can be
   distinguished from the heat-pump compressor for system-
   efficiency monitoring), but this CT is *internal
   monitoring*, not market-facing data; only the master
   economy meter feeds the market.

3. **Latent panel-level MarketMaker — capability-ubiquitous,
   activation-conditional.** Every Economy Panel ships with
   panel-MarketMaker software present and dormant on the
   already-present MCU. Marginal hardware cost: zero. Activation
   per install depends on conditions (cohort scale, tariff
   structure, frequency of local panel-constraint binding, or
   reconstitution arrival); activation is a software switch, not
   a hardware retrofit. **The Trojan-horse property:** every
   Economy Panel deployed under the safety + cost + convenience
   story is *already* a latent MarketMaker GNode anchored at a
   panel-ampacity constraint point, ready to activate when the
   conditions warrant. This is how the EEM-context vision of
   MarketMakers sprouting at constraint points actually scales.

The layers compose without dependence: the failsafe works without
the TaReader. The TaReader works without a panel MarketMaker. The
panel MarketMaker is meaningful only behind a service entrance
with multiple TerminalAssets.

## Architectural commitments (Pass 0 — to be refined)

1. **Open-source by default.** Hardware BOM, firmware, protocols
   all open. The capital structure of the project is the load-
   bearing strategic commitment, not an afterthought.
2. **Software-independent physical safety.** Service-entrance
   overload protection is electromechanical, not firmware-driven.
   No physical-safety claim depends on a software path. The
   smart side (TaReader, panel-MarketMaker, LAN gateway) cannot
   cause an overload / fire / arc-flash event regardless of
   firmware bugs, network attacks, or misconfiguration — the
   analog failsafe overrides. Direct cost-structure consequence:
   **firmware is NOT in the safety path → UL 916 (EMS) and
   UL 3141 (PCS) firmware functional-safety certification are
   NOT required.** This is a load-bearing cost-engineering
   commitment, not just a design preference: those certs are
   what every proprietary smart-panel competitor is paying
   $50k+ to amortize across their installed base.
3. **NEC-compliant by construction.** Setpoint logic conforms
   to NEC 220.70 / 750.1 EMS provisions. Inspector-grade and
   electrician-installable.
4. **Constraint point = panel ampacity.** The setpoint that
   the analog failsafe enforces is the same constraint the
   (optional) panel-level MarketMaker clears against. No two
   numbers to keep in sync.
5. **Master economy meter is the only required market-facing
   meter; per-TerminalAsset sub-metering is deliberately not
   specified at v1.** The TaReader's only market-facing read is
   the master economy meter (revenue-grade ANSI C12 — committed
   externally as the EKM Omnimeter for v1). For homes with one
   TerminalAsset (the heat-pump-thermal-storage v1 case), this
   is sufficient: the master meter IS the per-TA meter. For
   homes that later add additional TerminalAssets (EV, HPWH,
   battery), how to sub-meter them is an **open architectural
   question** to be resolved when it actually arises — not
   pre-committed in v1. The architecture's commitment is to
   stay agnostic: keep options open for appliance-embedded
   sub-meters, panel-side per-circuit sub-meters, or hybrid
   approaches as the v2+ deployment realities clarify.
6. **No vendor lock to GridWorks-specific market participation.**
   TaReader integration is one option. The architecture must
   admit other transactive-market frameworks as long as they
   meet equivalent Participation Requirements.
7. **Cost class — an order of magnitude cheaper than the
   proprietary smart-panel category at OEM volume; 3–5× cheaper
   at moderate volume.** Working ranges (Pass 0; to be tightened
   as the spec matures):
   - Single-unit retail BOM: ~$700–1100 (full bundle including
     revenue-grade master economy meter).
   - Moderate-volume BOM (~1000 units): ~$400–600.
   - OEM volume (~10k+ units): ~$250–400.
   - Total installed (panel + electrician + inspector): ~$1.2–1.8k
     at moderate volume, vs. ~$4–7k for incumbent smart panels
     (SPAN, Lumin, Square D Energy Center).

   The cost reduction comes from three specific decisions:
   (i) removing firmware-as-safety (no UL 916 / UL 3141
   certification cost loaded onto the safety path; the analog
   failsafe is built from already-UL-listed off-the-shelf parts);
   (ii) removing VC-return loading (no Series-A-fueled headcount
   and brand-margin embedded in unit pricing); (iii) using
   off-the-shelf UL-listed parts throughout instead of custom
   silicon or custom enclosures. Each is necessary; together they
   are sufficient.

## Why this is open-source

The residential smart-panel industry (SPAN, Lumin, Stepwise,
Leviton Load Center, Schneider Square D Energy Center, et al.)
is venture-funded and priced/positioned to monetize a customer
base. Their capital structure requires (a) UL 916 / UL 3141
firmware-certification cost amortization, (b) VC-return margin
loading, and (c) proprietary moats to defend both. The
combination forecloses the business model that would let
panels actually enable price-sensitive transactive participation
at the service-entrance scale — SPAN's $176M Series C + Eaton's
$75M (early 2026) is explicitly pivoting the most-funded
incumbent *toward* utility-side DERMS and *away* from
resident-side bidding.

Open-source from day one is what lets the cost reductions
enabled by the architecture (no firmware-as-safety cert, no
VC-margin, off-the-shelf UL-listed parts) actually reach
homeowners instead of being re-captured by the next venture
entrant.

See [`../research/industry-survey.md`](../research/industry-survey.md)
for the comparative analysis. See
[`../research/governance-leads.md`](../research/governance-leads.md)
for the working governance posture (GridWorks-incubated
through critical-mass adoption, with eventual layer-(c)
protocol handoff to LF Energy).

## Regulatory positioning

The Economy Panel sits in a specific regulatory posture worth
making explicit:

- **Physical safety** is upheld by the analog failsafe (NEC
  220.70 / 750.1), the off-the-shelf UL-listed parts, and a
  forthcoming UL assembly listing of the Piantedosi-pattern
  subassembly. Inspectors see a UL-listed device.
- **Consumer-protection safety** is upheld by the **Service
  Level Agreement** between the TaOwner and the TaAggregator
  (and indirectly with the CEP). The TaOwner is a voluntary
  participant, holds the TaDeed and TaTradingRights, and can
  claw back at any time per SLA terms. Economy Energy is a
  parallel sub-economy, not regulated retail service.
- Because Economy Energy is voluntary, contractual, and
  parallel to the standard retail relationship Versant
  maintains with the homeowner, **the Office of Consumer
  Advocate is not a stakeholder** for Economy Energy market
  participation. Their jurisdiction over the standard
  Versant retail relationship is unchanged.
- **Versant has zero III.6.4-driven obligation to change
  anything** beyond providing a one-time class-letter
  confirming the parallel-metering configuration per
  III.6.4(e). The master economy meter installs on a
  physically separate service entrance per the
  parallel-metering option in the May 23 2024 FERC rehearing
  order (187 FERC ¶ 61,100).

## Pass 0 caveats — open assumptions to refine

These are working assumptions, not commitments. Each will need
empirical or expert validation as the spec matures.

- **Inspector reassurance is untested in residential settings.**
  The Piantedosi Special's deployment provenance is industrial
  (Logan Airport). Building inspectors in residential settings
  may vary in their reception. **Risk-reduction plan:** file a
  UL listing on the Piantedosi-pattern subassembly as a single
  device, so inspectors see a UL-listed product rather than a
  hand-assembled circuit.
- **Reconstitution timeline is uncertain.** The Maine PUC →
  Versant tariff path that would let the master economy meter
  become a sub-meter (saving ~$1500/home) could take 3–10 years.
  The architecture works fine without reconstitution under
  III.6.4(d) parallel metering; the savings are a bonus.
- **Total installed cost varies by jurisdiction** (~$1k–2.5k
  installed). Master Electrician requirement, permit fees,
  special inspections all introduce variance not captured in
  the headline range.
- **Resident appetite for transactive participation is
  inferred from the Versant A1 TOU subscriber base**, not
  directly measured. The Knifes Edge pilot is the empirical
  test.
- **Thermal / EMI in the shared enclosure** — combining
  100 A+ contactor chains with the smart-side MCU, radios,
  switching PSU, and EKM Omnimeter in one enclosure requires
  thermal/EMI design discipline; v1 enclosure cost may run
  above the $80–150 estimate.
- **EKM partnership** — EKM Omnimeter is named in the ISO-NE
  letter as the master-economy-meter v1 choice. Broader
  integration conversations (whether to use additional EKM
  CTs for COP accounting, sub-metering protocol, longer-term
  OEM-embedded path) are queued; v1 commits only to the
  master meter.
- **Per-TerminalAsset sub-metering for multi-TA homes** —
  deliberately not specified at v1. When real v2+ deployments
  with multiple TerminalAssets behind one panel arise, the
  right approach (panel-side CTs, appliance-embedded meters,
  hybrid) will be decided empirically. The architecture's
  commitment is to *not pre-commit*.

## TOC

- [`primary.md`](primary.md) — this hub
- [`hardware.md`](hardware.md) (Open) — analog failsafe BOM,
  variations, NEC mapping, UL listing path
- [`metering.md`](metering.md) (Open) — master economy meter
  spec; deferred questions for multi-TA homes; COP-accounting
  CT for heat-pump-TS
- [`tareader-integration.md`](tareader-integration.md) (Open) —
  how the panel integrates with a TaReader
- [`panel-marketmaker.md`](panel-marketmaker.md) (Open) — the
  latent panel-level MarketMaker, activation criteria
- [`sla.md`](sla.md) (Open) — the TaOwner/TaAggregator SLA
  template (consumer-protection layer)
- [`stewardship.md`](stewardship.md) (Open) — governance
  posture, layer-(c) handoff to LF Energy

## Status

- 2026-06-07 · Pass 0 stub. Three-layer architecture named
  (analog failsafe + TaReader integration + latent
  panel-MarketMaker). EKM Omnimeter as master economy meter
  externally committed via ISO-NE letter. Per-TerminalAsset
  sub-metering deliberately not specified at v1
  (architecture stays agnostic; for heat-pump-TS, master
  meter is sufficient + optional COP-accounting CT inside the
  panel). UL listing of the Piantedosi-pattern subassembly
  planned. Open-source motivation reframed around firmware-cert
  + VC-margin cost reductions. Consumer-protection-via-SLA +
  no-Office-of-Consumer-Advocate engagement posture made
  explicit. Industry survey + 12-item red-team complete.
