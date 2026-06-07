Status: Draft · Pass 0 · Updated 2026-05-30

> What this is: hub document for the **Versant Bangor Hydro District
> (BHD)** tariff analysis. Versant BHD is the closest in-territory
> case study for the transactive-load-pricing question framed in
> [`../primary.md`](../primary.md). Many findings apply to Versant's
> parallel district (Maine Public) and to other Northeast utilities
> with similar demand-charge / NCP transmission structures.
> Companion docs:
> [`tariffs.md`](tariffs.md) (the detailed rate schedules),
> [`../transmission-direct.md`](../transmission-direct.md) (the
> bypass option).

## Versant BHD as case study

Versant Power's Bangor Hydro District is the relevant distribution
utility for transactive-load projects across Penobscot, Hancock,
and Piscataquis counties.
Its rate book is representative of Northeast investor-owned utility
practice:

- **TOU rates with peak-period demand charges + minimum demand
  floors** (Rate D-4) — the structure that bills transactive load
  *as if* it were firm load and is the main distortion to be
  worked around.
- **Non-coincident-peak transmission demand by default** (NCP) —
  unavoidable by TOU shifting because NCP = customer's *own* max
  in any period regardless of when.
- **A residential TOU heat-storage rate exists** (Rate A-1 "Home
  Eco Rate with Bonus Meter") with **off-peak total delivery of
  ~6.4 ¢/kWh** — the closest existing instrument that prices
  transactive load near its actual cost drivers.

## The five rate classes worth knowing

| Class | Threshold | Voltage | Decision-relevance for transactive load |
| --- | --- | --- | --- |
| Rate A-1 / A-3 / A-4 | residential | secondary | A-1 (TOU heat-storage bonus meter) is the **cheapest available structure** for storage-controlled load — see [`tariffs.md`](tariffs.md). |
| Rate M-2 | ≥ 25 kW, < 500 kW | secondary | Flat NCP demand. Available without the D-4 floor. |
| Rate M-1 | ≥ 25 kW, < 500 kW | primary | Same as M-2 at primary voltage. |
| Rate D-4 | **≥ 500 kW** | primary, customer-owned transformer | TOU demand + 500 kW floor in every period + NCP transmission. **The distortion-heavy commercial tariff.** |
| Rate T-1 | ≥ 500 kW | transmission ≥ 34.5 kV | Lower distribution component, but interconnect capex is multi-million — see [`../transmission-direct.md`](../transmission-direct.md). |

## The headline findings

1. **Rate A-1 is the existing tariff that already gets it
   approximately right.** Off-peak total delivery 6.4 ¢/kWh, no
   demand charges, technology-neutral language ("thermal energy
   storage devices, electric battery storage devices, and/or vehicle
   chargers"). Per-home (residential) structure, requires a second
   meter on the storage device, requires Versant sizing inspection.
   Probably the right answer for most transactive-load applications
   in Maine if the use-case fits residential service.
2. **Rate D-4 is the wrong tariff for transactive load** at
   moderate scale (100s of homes / 500 kW–2 MW). The 500 kW
   peak-period demand floor + NCP transmission bills the load as
   firm even when it's not. See
   [`../../knifes-edge-development/scenarios/boe-delivery.md`](../../knifes-edge-development/scenarios/boe-delivery.md)
   for what this costs in concrete numbers.
3. **The CP transmission election is gated to "Battery Storage"
   only** — explicitly not thermal storage. **The policy ask** to
   expand this is documented in
   [`../../knifes-edge-development/regulatory-change-for-cp.md`](../../knifes-edge-development/regulatory-change-for-cp.md).
4. **No public retail interruptible tariff** in BHD's rate book for
   loads in the 0.5–2.5 MW range. Versant's retail path for "I can
   drop on signal" is participation in the **Maine statewide
   Demand Response Initiative (DRI)** — a program, not a tariff.

## Open questions

- **Rate A-1 sizing inspection criteria** — does Versant accept HP
  + thermal store, or only legacy ETS-brick resistive heat? Confirm
  with Versant or a customer already on A-1.
- **Multi-meter Rate A-1 strategy** — can a single homeowner have
  multiple bonus meters (one for HP, one for battery, one for EV)?
- **Aggregating Rate A-1 across an HOA** — if each home is its own
  Rate A-1 customer with bonus meter, does the HOA play *only* a
  control / aggregation role? Legal structure question.
- **Rate D-4 floor interpretation** — billing-demand minimum per
  period vs customer qualification gate. The agent-read of the
  tariff says per-period; the user has been reading it as
  qualification-only. The difference is ~$2,700/year/home in the
  HaaS+D-4 case. Tariff specialist confirmation needed.
- **Versant general rate-case timeline** — when is the next
  opportunity to amend tariffs?
