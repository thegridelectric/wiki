# Glossary — Store-Under-Floor Research

Quick definitions for the terms, symbols, and acronyms used across the
research docs in this folder. Alphabetical. Where a definition needs the
physics behind it, that lives inline; pointers to the source doc are in
brackets.

## Symbols

| Symbol | Reads as | Definition | Units | Where used |
|---|---|---|---|---|
| **k** | "kay" | **Thermal conductivity** — how readily a material conducts heat. A high-k material moves heat fast; a low-k material is an insulator. Drives both how fast tubes in the slab can extract/deposit heat, and how fast the slab loses heat to its surroundings. | W/(m·K) | everywhere |
| **c_p** | "see-pee" | **Specific heat** — heat needed to raise 1 kg of the material by 1 K. | kJ/(kg·K) | materials |
| **ρ** | "rho" | Density. | kg/m³ | materials |
| **ρc_p** | "rho see-pee" | **Volumetric heat capacity** — heat stored per m³ per K of temperature rise. The headline number for any thermal store; flowable fill is ~1.9 MJ/(m³·K), water is ~4.18 MJ/(m³·K). | MJ/(m³·K) or kWh/(m³·K) | materials, design |
| **α** | "alpha" | Thermal diffusivity, α = k / (ρc_p). Governs how fast heat *moves through* a mass, separate from how much heat the mass holds. | m²/s | edge-loss |
| **UA** | "you-ay" | **Overall heat-transfer conductance** — the product U·A of a heat-transfer coefficient and area, in W/K. The thermal analogue of electrical conductance. Heat transferred = UA × ΔT. | W/K | pipe-geometry |
| **C** | "see" | Per-meter conductance of a tube in the slab — the per-unit-length version of UA used in shape-factor formulas. C × L_tube = UA_total. | W/(m·K) | pipe-geometry |
| **LMTD** | "L-M-T-D" | **Log Mean Temperature Difference** — the right average temperature difference to use when a fluid changes temperature along a heat-exchanger length. LMTD = (ΔT₁ − ΔT₂) / ln(ΔT₁/ΔT₂). | K | pipe-geometry, design |
| **NTU** | "N-T-U" | **Number of Transfer Units** = UA / (ṁ·c_p). A dimensionless measure of how thoroughly a fluid stream exchanges heat over a tube field. Higher NTU = closer the outlet approaches the wall temperature. | — | design |
| **ε** | "epsilon" | **Effectiveness** of a heat exchanger = 1 − exp(−NTU). The fraction of the maximum possible temperature change the fluid actually achieves. | — | design |
| **ΔT** | "delta-tee" | A temperature difference between two points. | K | everywhere |
| **Δ_depr** | "delta-depr" | **Local-temperature depression** — the bulk-store temperature minus the (lower) fill temperature immediately around the discharge tube. Caused by the tube pulling heat faster than conduction can replenish it. | K | design, pipe-geometry |
| **Δ_NTU** | "delta-N-T-U" | The fluid outlet's approach to the local fill temperature; (1−ε) × (T_fill,local − T_in). | K | design |
| **Δ_mix** | "delta-mix" | Mixing-valve authority margin — headroom for the mixing valve to throttle without driving full open. ~1–2 K. | K | design |
| **Useful ΔT** | | The temperature swing the store can actually deliver: T_store,max − T_store,min. Bigger useful ΔT means more kWh stored per m³. | K | design |

## Acronyms and terms

| Term | Meaning |
|---|---|
| **ACI** | American Concrete Institute. ACI 229R-13 is the standard for CLSM. |
| **ASHRAE** | American Society of Heating, Refrigerating and Air-Conditioning Engineers. Source of most US-side HVAC reference data, including slab-on-grade F-factor tables. |
| **CCHP** | **Cold-Climate Heat Pump** — a heat pump explicitly rated to operate (and produce useful output) at sub-zero outdoor air temperatures, typically down to −25 °C or below. Mitsubishi Ecodan, Arctic Heat Pumps, SpacePak Solstice are examples. |
| **CLSM** | **Controlled Low-Strength Material** — a flowable cementitious mix (cement + sand + water, sometimes fly ash, no coarse aggregate). Self-leveling, no float/trowel labor. Compressive strength typically 50–300 psi at 28 days, vs. ~3 000 psi for structural concrete. Also called "flowable fill" or "controlled density fill". |
| **COP** | **Coefficient of Performance** — heat-pump thermal output divided by electrical input. COP = 3 means 3 kW of heat out for 1 kW of electricity in. Falls with rising LWT and with falling OAT. |
| **DHW** | **Domestic Hot Water** — household hot water for taps and showers (≥50 °C delivery for safety). In this design, served by a separate heat-pump water heater (HPWH), not the under-floor store. |
| **EN 1264 / ISO 11855** | European standards for embedded radiant heating/cooling. Source of the canonical shape-factor formulas used to size in-slab tubing. |
| **EPS** | **Expanded Polystyrene** — bead-foam rigid insulation. Cheaper than XPS, lower compressive strength per density, R-3.6 to R-4.2 per inch depending on grade. Type IX is the high-density variant used under high-load slabs. |
| **EWT** | **Entering Water Temperature** — water temperature returning into a heat pump or heat exchanger. |
| **F-factor** | A coefficient (Btu / h·ft·°F) used in ASHRAE 90.1 and DOE compliance methods to estimate slab-on-grade perimeter heat loss as a linear function of slab perimeter. A first-cut approximation; the real heat flow is 2-D. |
| **FCU** | **Fan Coil Unit** — a hydronic coil with a blower, used for fast-response heating and for cooling/dehumidification. The Z4 zone in the diagram is most likely an FCU. |
| **HP** | **Heat pump.** In this project, an air-source monoblock (refrigerant stays outside, water connections inside). |
| **HPWH** | **Heat-Pump Water Heater** — a self-contained unitary appliance combining a heat pump with a hot-water tank. Separate from the space-heating HP in this design. |
| **LWT** | **Leaving Water Temperature** — water temperature leaving a heat pump or heat exchanger. The single most important HP-side variable for COP: lower LWT → higher COP. |
| **Monoblock** | Heat-pump architecture in which the entire refrigeration cycle (compressor, condenser, evaporator, expansion valve) lives in the outdoor unit; only insulated water lines run into the house. Contrast with split systems, which run refrigerant lines indoors. |
| **NEEP** | Northeast Energy Efficiency Partnerships — publishes the canonical cold-climate-air-source-heat-pump performance list (ashp.neep.org), with detailed COP and capacity data across operating points for hundreds of units. |
| **NTU** | See symbols. |
| **OAT** | **Outdoor Air Temperature.** The HP's cold-side reservoir. |
| **PEX** | **Cross-linked Polyethylene** — flexible plastic tubing used for in-slab hydronic loops. |
| **PEX-Al-PEX** | A multilayer pipe with an aluminum core sandwiched between two PEX layers. More expensive than plain PEX but holds its shape, has an oxygen barrier, and tolerates higher temperatures. Standard for in-slab radiant. |
| **Polyiso** | **Polyisocyanurate** rigid foam insulation. Higher R per inch than XPS/EPS when warm (~R-6/in), but loses R below freezing and absorbs water; usually a poor choice in below-grade or wet locations. |
| **Shape factor (S/L)** | A dimensionless conductance per unit length used to compute heat flow between a buried cylinder and a planar boundary. The form S/L = 2π / ln(8z/πD) applies to a cylinder midway between parallel insulating planes; the row-of-tubes form 2π / ln(s/(πr)) applies for closely spaced tubes in an infinite medium. |
| **Slab-on-grade** | A floor construction in which the building's lowest slab is poured directly on prepared earth (with insulation and a vapor barrier between), rather than on a structural deck above a basement or crawlspace. |
| **Standby loss** | Heat lost from a stored medium to its surroundings while idle. For an under-floor store, the sum of conduction through top, bottom, and edge insulation. |
| **Stratification** | A vertical temperature gradient in a thermal store, with hotter fluid/mass at the top. Easy in a water tank; difficult in a conductive solid like flowable fill, but partially achievable by placing charge tubes deep and discharge tubes shallow. |
| **TOU** | **Time of Use** electricity pricing — different rates by hour of day. The arbitrage opportunity that makes a thermal store economically interesting. |
| **Transactive controls** | The GridWorks-developed control philosophy in which loads respond to time-varying price signals (wholesale market, TOU, or simulated). The under-floor store is a tool for shifting heating energy from expensive hours to cheap hours. |
| **XPS** | **Extruded Polystyrene** rigid foam insulation. Closed-cell, high compressive strength, low water absorption. R-5 per inch. Standard choice for under-slab and edge insulation in cold-climate slab-on-grade. |

## Hydronic schematic components (from `../two-layer-floor.jpg`)

| Label | What it is |
|---|---|
| **P1** | Charging circulator — moves water HP → store charging tubes → HP. |
| **P2** | Discharging circulator — moves water store discharge tubes → mixing valve → floor zones → return. |
| **V1** | Bypass valve — routes HP output directly to the floor zones, bypassing the store charging tubes. Enables direct-HP-to-floor mode (highest COP). |
| **Mixing valve** | Tempers store-loop or HP-loop output with cooler floor-return water to hit the exact T_supply,floor target. |
| **Z1, Z2, Z3** | Floor zones (the radiant upper emitter, split into three rooms or areas). |
| **Z4** | Independent zone fed directly from the HP loop; in this design, most likely a fan-coil unit (FCU) for fast response and summer cooling if AC is in scope. |

## Project-specific names

| Term | What it is |
|---|---|
| **Polstein** | Matt Polstein, the developer of the 14-home (eventually 100-home) Millinocket development this design is for. |
| **Millinocket** | Town in northern Maine where the development is sited. ASHRAE 99.6 % design temp ≈ −30 °C. |
| **Nolan house** | A previously-built Polstein house where GridWorks transactive controls are installed on a radiant-floor heating system (without a decoupled store). Source of future field-validated HP data. |
| **Siegenthaler / John Siegenthaler** | Consulting hydronic engineer engaged on this project (review pending — these docs are GridWorks-side, not yet vetted by him). Author of *Modern Hydronic Heating* and *Heating with Renewable Energy*. |
| **GridWorks** | The company doing this design work; develops the transactive-controls layer that schedules the HP and store. |
