Status: Draft · Pass 0 · Updated 2026-05-30

> What this is: detailed Versant Bangor Hydro District (BHD)
> tariff schedules relevant to transactive / storage-controlled
> load pricing. Companion to [`primary.md`](primary.md). Sourced
> from the Versant BHD consolidated tariff PDF, eff. July 1, 2025:
> https://www.versantpower.com/docs/default-source/rates/july-1st--2025/versantpower-bhd-tariffs-2025-07-01.pdf

## Rate A-1 — "Home Eco Rate with Bonus Meter" (Time-of-Use)

**Page reference:** 6.1.1, 14th Revision, eff. July 1, 2025.

**Likely the most important tariff in this folder** — this is the
existing residential TOU rate that already prices storage-controlled
load close to its cost drivers.

### Eligibility

> Residential customers with **thermal energy storage devices,
> electric battery storage devices, and/or vehicle chargers** who
> agree to install a **second metered point of delivery** (the
> "bonus meter").

- Versant inspects the equipment to confirm it is "sized appropriately
  for residential use." Failed inspection → denial.
- Single-phase, 60 Hz, standard secondary voltage.
- No explicit minimum kW / kWh threshold in the tariff text.
- Tariff language is **technology-neutral on the storage side**;
  "thermal energy storage" is generic and likely includes HP + hot
  water / glycol thermal store, not just legacy ETS resistive
  bricks. **Subject to Versant inspection** — load-bearing
  practical question.

### TOU windows

Weekdays:

- **Peak:** 7 a.m. – 12 p.m. and 4 p.m. – 8 p.m.
- **Shoulder:** 12 p.m. – 4 p.m.
- **Off-Peak:** 8 p.m. – 7 a.m.

Weekends / holidays:

- **Shoulder:** 7 a.m. – 8 p.m.
- **Off-Peak:** 8 p.m. – 7 a.m.
- **No on-peak period.**

Holidays: New Year's, Washington's, Patriot's, Memorial, Independence,
Labor, Columbus, Veteran's, Thanksgiving, Christmas. DST-shift
schedule applies the two weeks bracketing DST transitions.

### Rate structure (eff. July 1, 2025)

- **No customer charge on the bonus meter** (the primary A-3 / A-4
  meter carries it).
- **No demand charge.**

**Distribution energy:**

| Period | Winter | Non-winter |
| --- | --- | --- |
| On-Peak | $0.54784 / kWh | $0.53302 / kWh |
| Shoulder | $0.00608 / kWh | $0.00608 / kWh |
| Off-Peak | **$0.00000 / kWh** | **$0.00000 / kWh** |

**Total Delivery** (distribution + transmission + stranded-cost +
conservation):

| Period | Winter | Non-winter |
| --- | --- | --- |
| On-Peak | $0.61210 / kWh | $0.59728 / kWh |
| Shoulder | $0.07034 / kWh | $0.07034 / kWh |
| **Off-Peak** | **$0.06426 / kWh** | **$0.06426 / kWh** |

### Why this matters

For storage-controlled load that runs **entirely off-peak**, total
delivery is **6.4 ¢ / kWh** — vs Rate D-4's effective ~14.8 ¢/kWh
(optimistic floor reading) or ~64 ¢/kWh (strict floor reading) for
the same load on a commercial single-customer arrangement.

The structural difference: A-1 has **no demand charges and no NCP
transmission**, so storage-controlled load that avoids the peak
period pays close to *cost-causal* delivery rates.

---

## Rate D-4 — Primary Power Large – Time-Of-Use

**Page reference:** 20.1.1, Twelfth Revision.

### Eligibility

Customer agrees to pay for service on the basis of **≥ 500 kW** of
demand, at **primary voltage with customer-owned transformer**.

### What "primary, customer-owned transformer" means

"Primary voltage" is utility-industry shorthand for **medium-voltage
distribution** — in Versant Bangor Hydro District this is typically
**12.47 kV** three-phase (some feeders run 4 kV, 23 kV, or 34.5 kV).
The three voltage layers:

| Layer | BHD typical | Used by |
| --- | --- | --- |
| **Transmission** | 115 kV, plus 34.5 kV subtransmission | Bulk grid + Rate T-1 customers |
| **Primary distribution** | **12.47 kV** | Medium-voltage feeders + Rate D-4 / M-1 customers |
| **Secondary distribution** | 120 / 240 V residential, 208 V or 480 V three-phase commercial | Houses, small commercial |

"**Customer-owned transformer**" means:

- Versant brings primary 12.47 kV lines up to a connection point on
  the customer's property (the "Retail Delivery Point").
- **The customer** owns and operates the transformer that steps
  12.47 kV down to whatever secondary voltage they use internally.
- Versant does not maintain any equipment downstream of the
  connection point.
- The customer is responsible for primary-side switchgear,
  protective relays, metering, grounding, etc.

**What this costs.** A 1–3 MVA pad-mount transformer plus
interconnection switchgear, primary cable, and metering typically
runs **$50k–$300k** for a customer-owned substation at this scale.
For a 100-home HOA, that's $500–$3,000 per home amortized —
meaningful but not prohibitive in the context of campus
infrastructure.

**Implication for a residential campus.** Versant lands primary at
the campus boundary; the campus operator owns the substation
transformer and everything downstream (including the HOA-owned
secondary distribution to each home). Each home's residential meter
is on the secondary side, downstream of the campus-owned
transformer. Versant continues to read each home's residential
meter as Assigned Meter Reader for retail billing — but the
physical distribution between the boundary substation and each home
is campus-owned. So the D-4 connection requirement isn't just a
voltage choice; it's a **whole substation that the customer must
build, own, operate, and maintain**.

### TOU windows

- **Winter:** Nov–Feb. **Non-winter:** Mar–Oct.
- **Weekday Peak:** 7 a.m. – 12 p.m. and 4 p.m. – 8 p.m.
- **Weekday Shoulder:** 12 p.m. – 4 p.m.
- **Weekday Off-Peak:** 8 p.m. – 7 a.m.
- **Weekends + holidays:** Shoulder 7 a.m. – 8 p.m., Off-peak
  8 p.m. – 7 a.m.

### Distribution demand (per kW-month)

- Peak: **$22.91**
- Shoulder: **$5.50**
- Off-peak: **$3.28**

Peak / off-peak ratio: ~7×.

### Distribution energy

$0.02213 / kWh flat across TOU periods.

### Transmission demand — NCP vs CP

- **Default: $17.41 / kW-month NCP** (non-coincident peak —
  customer's own highest 15-min in any TOU period of the month).
  Cannot be reduced by TOU shifting.
- **Optional: $29.23 / kW-month CP** ("Coincident Peak" — customer's
  load during the **60-minute interval coincident with each monthly
  BHD system peak**) in lieu of NCP.

**CP election is gated to:**

> *"separately metered Electric Vehicle Charging and/or Battery
> Storage devices known as the 'DC Fast Charging and Storage Eco
> option'."* — Rate D-4 schedule, p. 20.1.1.

- "Battery Storage" means **electrical / electrochemical** storage.
  **Thermal storage does NOT qualify** per the plain tariff text.
- Requires a **separate AMI meter** at the premises hosting the
  EV / battery devices.
- CP applies only to the separately-metered load; the bulk of the
  premises stays on NCP.

This is the load-bearing distortion. Policy ask to expand the
eligible-technology list to include thermal storage:
[`../../knifes-edge-development/regulatory-change-for-cp.md`](../../knifes-edge-development/regulatory-change-for-cp.md).

### Billing demand floor

> *"The demand used for billing (demand) will be the greatest of the
> following: 1. The average load during the fifteen (15) minute
> period of maximum use in the current month. 2. 500 kW for Peak,
> Shoulder, and Offpeak Distribution and Peak Transmission."*
> — p. 20.1.2.

> *"MINIMUM CHARGE: $7140.00 per month ... for a minimum of 500 kW
> billing demand in each time period."*
> — p. 20.1.2.

**Interpretation:** billing demand is
  floored at 500 kW *per TOU period*, regardless of actual peak in
  that period.


The difference is ~$170k / year HOA / ~$1,700/year/home for a
100-home transactive-load case. **Tariff specialist or Versant rep
confirmation is the load-bearing next step before committing.**

---

## Rate M-1 — Medium Power Primary

**Page reference:** searched M-1.

- **Threshold:** ≥ 25 kW, < 500 kW.
- **Voltage:** primary, customer-owned transformer.
- **Demand:** **$32.52 / kW-month flat NCP** (no TOU).
- **No 500 kW floor.**

Below the 500 kW threshold, M-1 is the primary-voltage commercial
alternative to D-4. Flat NCP demand without TOU savings. For
storage-controlled load, M-1 sacrifices the TOU spread but avoids
the D-4 floor.

## Rate M-2 — Medium Power Secondary

- Same threshold (≥ 25 kW, < 500 kW) at **secondary voltage**.
- Demand: **$34.82 / kW-month flat NCP**.



## Interruptible / curtailable tariffs

**No public retail interruptible tariff** in the BHD rate book for
0.5–2.5 MW loads. The only Versant-side curtailment provisions are
in **OATT Schedule 21** (FERC-jurisdictional, applies to firm
Local Point-To-Point transmission service, not retail delivery) —
penalties up to 200 % of the firm charge for failure to curtail on
directive, but no retail credit.

Versant's retail path for "drop load on signal" is participation in
the **Maine statewide Demand Response Initiative (DRI)** — a
program, not a tariff. (Detailed program info not in scope for this
rate doc.)

---

## Rate T-1 — Transmission Power

For customers with ≥ 500 kW load taking service at **subtransmission
≥ 34.5 kV or transmission > 46 kV**. Not realistic for residential
or small-commercial applications, but documented for completeness.

- Distribution Peak demand: **$1.94 / kW-month**.
- Subtransmission Peak: **$16.76 / kW-month**.
- Transmission peak: $0 default, **CP option $23.76** (60-min
  coincident with monthly BHD system peak; the rest use 15-min NCP).
- 500 kW floor (same as D-4).
- No explicit multi-month ratchet.

For the analysis of whether direct transmission-voltage
interconnection is viable for a 1–3 MW transactive-load project,
see [`../transmission-direct.md`](../transmission-direct.md).
