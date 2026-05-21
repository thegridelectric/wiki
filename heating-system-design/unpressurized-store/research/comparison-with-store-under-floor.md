# Design A (Store-Under-Floor) vs Design B (Garth Tank + Radiant Floor)

**Status: stub.** This memo is the eventual home for the head-to-head
life-cycle comparison the user flagged at the start of the design
exercise. It depends on the engine and dashboard
([`../executor/README.md`](../executor/README.md)) being far enough
along to run priced scenarios; the numbers below are placeholders
until then.

A mirror of this file should land in
`../../store-under-floor/research/` so either design's reader finds it.

## The two designs in one sentence each

- **Design A — Store-Under-Floor.** A 1000 ft² × 6" pour of flowable
  fill on rigid insulation, with PEX embedded in the slab. The slab is
  **both** the thermal store and the radiant emitter. Capacity
  ~7.4 kWh/K useful; ~111 kWh at 15 K useful ΔT.
  ([`../../store-under-floor/research/design.md`](../../store-under-floor/research/design.md))
- **Design B — Garth Tank + Radiant Floor.** A 150 gal H/D=3
  unpressurized stratified water tank, separate from a slab-on-grade
  radiant floor that is sized purely as an emitter (4" concrete on
  insulation). Tank capacity ~0.66 kWh/K useful; ~13.8 kWh at 21 K
  useful ΔT. ([`design.md`](design.md))

## The comparison axes

The two designs differ on more than capacity. Each axis below needs to
land in the priced dashboard outputs.

| Axis | Design A | Design B | Notes |
|---|---|---|---|
| Capex — store | 14 m³ flowable fill + insulation + tubing | 150 gal Garth tank (~$2300) + HX + valves + diffusers | TBD by costed-BOM |
| Capex — emitter | (shared with store) | Separate slab-on-grade radiant floor | A is cheaper here |
| Total useful storage | ~111 kWh | ~13.8 kWh | A wins by ~8× |
| Useful ΔT for HP | ~15 K | ~21 K (and mid-injection can shift further) | B wins on per-K COP |
| TOU bridging (typical day) | Many hours (slab is huge mass) | ~5 h (per [`tou-bridging.md`](tou-bridging.md)) | A wins on long shifts |
| TOU bridging (design day) | Bridges most peaks | Marginal; HP through peak | A wins |
| Negative-price soaking | Limited by slab → 35 °C peak | Tank can take immersion charge to 60 °C | B wins on $/kWh-stored when prices are negative |
| Resilience (multi-day outage) | Big slab dominates | Tank too small alone; depends on solar+battery | A wins absent on-site generation |
| Solar self-consumption (mid-day surplus) | Slab fills slowly; capped at low temp | Tank charges to 60 °C in ~1 h at 15 kW | B wins on cycle time, A wins on total kWh |
| Architectural flexibility | Slab-on-grade only (or massive engineering for upper floors) | Tank goes in a closet; floor type is free | B wins |
| Retrofit possibility | None — it's a new pour | Direct swap for buffer banks | B wins |
| Construction cost certainty | Slab work has known unit costs but bigger schedule risk | Off-the-shelf tank + standard plumbing | B wins on schedule risk |
| Service / replacement | 50-year asset; not replaceable | Tank is replaceable; HX serviceable | B wins on long-term ops |
| Stratification benefit | None — slab is one isothermal mass | Mid-injection enables COP gains | B wins |

## The user's hypothesis (to test)

> "I suspect [Design B] may be more cost-effective faced with standard
> time-of-use distribution tariff + wholesale prices, but the equation
> may shift if self-consuming local solar at scale or with resilience
> for longer grid outages."

The dashboard should produce a 4-panel chart, one panel per scenario,
each plotting **annualized total cost of ownership** (capex amortized +
energy + maintenance reserve) vs. **dead-band tolerance** (the comfort
knob) for both designs:

1. **Versant TOU only.** Hypothesis: B wins or ties, because B's tank
   exactly covers the binding 5 h peak and A's surplus capacity is
   unused.
2. **Versant TOU + ISO-NE wholesale (real-time prices).** Hypothesis:
   B wins more decisively — negative-price hours appear in real-time
   data ~50 hr/yr and B can soak them with the immersion heater.
3. **TOU + wholesale + 8 kW local solar (no battery).** Hypothesis:
   A starts catching up because solar surplus is mid-day energy
   delivered at low temperature, which matches the slab. B's tank
   saturates fast.
4. **TOU + wholesale + solar + multi-day outage resilience.**
   Hypothesis: A wins on storage hours, but B wins if paired with a
   modest battery for pump power. Compound-system question.

## Open questions

1. Whose envelope load shape are we anchoring to — Polstein's
   Millinocket Manual J, or a TMY3-based archetype?
2. What's the discount rate / amortization horizon for capex (10 yr?
   30 yr? slab life vs tank life differ a lot)?
3. Maintenance reserve assumptions — A has no moving parts in the
   store; B has pumps, valves, an HX, and possibly immersion elements.
4. Does the comparison include the **2× and 3× tank** variants of B,
   which trade some of A's capacity advantage for more capex? The
   dashboard should sweep `n_tanks` rather than assume 1.
5. Solar + battery sizing — is this an exogenous given, or part of
   the optimization?

## Direct capex comparison — same baseline as the store-under-floor worked examples

To keep this apples-to-apples with
[`../../store-under-floor/research/design.md`](../../store-under-floor/research/design.md)
Worked Examples A and B, the baseline for **all** rows below is the same:
**a standard 4″ structural radiant slab-on-grade** (~1000 ft², ~$4 200,
on rigid foam with edge insulation, with PEX at 9″ spacing, a manifold,
and a single circulator). Both designs add their store hardware on top
of this baseline; both designs use the slab as the emitter. Costs are
the **delta over baseline**, per house.

### Design B — incremental BOM for the 1× 150 gal Garth tank module

| Line item | Notes | Cost |
|---|---|---|
| Garth 150 gal custom H/D=3 tank | Custom fab uplift over $2 300 stock 350 gal — quote TBD | **+$3 000** |
| Brazed-plate HX, 15 kW, 5 K approach | SWEP B25/Alfa Laval CB30 class | **+$600** |
| HP-side circulator | Taco 0015 / Grundfos 26-99, installed | **+$400** |
| Tank↔load circulator (above baseline floor circ.) | Second circulator for tank→slab mix | **+$400** |
| 3-way motorized injection-elevation valve | Belimo B3 + LR24A actuator | **+$500** |
| Discharge return switching valve (bottom ↔ LM) | Smaller Belimo + actuator | **+$300** |
| Sieg-loop mixing valve (delta over baseline ORV) | PID-controlled 3-way vs. simple ORV | **+$300** |
| 6 kW immersion heater + contactor + HL interlock | Tank-internal element | **+$400** |
| Plumbing + labor between tank, HX, HP, slab | Allowance | **+$1 500** |
| Tank insulation jacket (if not bundled) | 3″ closed-cell or polyiso wrap | **+$200** |
| Sensor string (6× RTD on tank, 2× flow meters) | Wired to agent | **+$500** |
| Air separator + expansion tank for HX loop | Closed-loop hardware | **+$200** |
| Electrical for immersion + actuators | 30 A circuit + low-voltage | **+$300** |
| **Net cost difference per house (1× tank)** | | **≈ +$8 400** |
| **$ / kWh of active useful storage** | $8 400 ÷ 11.7 kWh | **≈ $718 / kWh** |

Multi-tank variants share all the non-tank lines once; each additional
tank adds the tank + plumbing tie-in + sensor string but not the HX,
circulators, valves, immersion, electrical:

| Variant | Storage (useful kWh) | Δ capex vs baseline | $ / kWh |
|---|---|---|---|
| Design B, 1× 150 gal | 11.7 | $8 400 | $718 |
| Design B, 2× 150 gal | 23.4 | $10 900 | $466 |
| Design B, 3× 150 gal | 35.1 | $13 400 | $382 |

### Side-by-side with store-under-floor worked examples

| Design | Configuration | Δ capex | Active useful kWh | $ / kWh | Bridging @ 2.5 kW |
|---|---|---|---|---|---|
| **A — store-under-floor Ex. A** | 4″ flowable-fill store + 2″ gypcrete overlay (lean) | **+$7 490** | 61 | $123 | ~24 h |
| **A — store-under-floor Ex. B** | 12″ flowable-fill store + 2″ gypcrete overlay (outage) | **+$11 440** | 183 | $63 | ~73 h |
| **B — Garth tank, 1×** | 150 gal tank + slab-on-grade radiant | **+$8 400** | 11.7 | $718 | ~5 h |
| **B — Garth tank, 2×** | 2× 150 gal + slab-on-grade radiant | **+$10 900** | 23.4 | $466 | ~9 h |
| **B — Garth tank, 3×** | 3× 150 gal + slab-on-grade radiant | **+$13 400** | 35.1 | $382 | ~14 h |

### Reading this table

1. **Design A wins decisively on capex per kWh of stored energy.**
   Flowable fill is so cheap per cubic meter that even the smallest
   practical pour (4″, Example A) buys ~5× the useful storage of a
   single 150 gal Garth tank — at lower absolute capex.

2. **Design A Example A and Design B 1× are within $1 000 of each
   other on absolute capex** ($7 490 vs $8 400) despite Design A
   delivering ~5× the storage. Most of Design A's apparent
   "free" advantage is the −$590 emitter swap credit (replacing the 4″
   structural slab with a 2″ gypcrete overlay) plus the very low
   $160/yd³ unit cost of flowable fill. Strip the emitter-swap credit
   and the two are at $8 080 vs $8 400 — **essentially tied**.

3. **$/kWh is not the right success metric for Design B.** Matt's
   space-constrained scenario asks for ~5 h of TOU bridging plus
   negative-price absorption, not for raw kWh capacity. Design A
   Example A overshoots that target by ~5× because it can't pour
   thinner than 4″. Design B 1× hits the target exactly. The relevant
   metric is **$ per hour of design-intent capability**, which the
   dashboard should report alongside $/kWh.

4. **Design B's capex story relies on its non-energy advantages:**
   architectural flexibility (works upstairs and in retrofits), HP COP
   gain from mid-injection and higher useful ΔT, immersion-heater
   compatibility for negative-price hours, smaller footprint, and
   serviceability. None of these show up in the kWh-denominated
   capex table.

5. **Cost estimates here are rough** (±20 %). The Garth custom-fab
   quote is the biggest unknown — getting an actual quote for a
   24″ × 71″ tall-narrow variant is the next concrete step. Plumbing
   labor allowance is the second-biggest uncertainty.

## Next step

The full life-cycle (energy + maintenance + amortization) numbers
above are qualitative. Plugging them into
real dollars requires the costed-BOM engine, the priced-scenario
runner, and the simulator. Queued behind the CFD work in
[`../executor/cfd.md`](../executor/cfd.md) and the engine work in
[`../executor/README.md`](../executor/README.md).
