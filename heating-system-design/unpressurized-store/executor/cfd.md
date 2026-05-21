# CFD Analysis — First Pass: Flute vs. Disc Diffuser

**Goal of this first pass:** decide, with quantitative evidence, whether
the unpressurized-store module should use a **single Moscone-style
self-stratifying flute** (the Vaughn-tank pattern) or **three symmetric
disc diffusers** at fixed elevations T / UM / LM driven by a 3-way
injection-elevation valve.

Out of scope for this first pass (deferred to a later run):

- Calibration of the 1-D N-node tank model's mixing / entrainment
  coefficients across the operating envelope. That's "Use 2" in
  [`../research/design.md`](../research/design.md) §Stratification and
  is a much larger sweep.
- Discharge-side return-port (bottom vs LM) optimization.
- Multi-tank series-thermocline coupling between two or more tanks.
- Transient response to defrost cycles.

The deliverable here is **one decision** + the validated geometry that
goes back to Garth as the CAD ask.

## Software stack

- **OpenFOAM 12** (or 11, whichever is current on the sim host).
  Solver: **`buoyantBoussinesqPimpleFoam`** — incompressible,
  Boussinesq buoyancy approximation, transient PIMPLE algorithm.
  Standard choice for TES tank stratification in the literature
  (Han 2009; Zurigat 1991; Lavan & Thompson 1977).
- **`pyFoam`** + plain Python for case generation and post-processing.
- **ParaView** for visualization spot-checks; the headline numbers
  come from scripted post-processing, not eyeballing.
- **uv-managed Python project** at
  `/Users/jessica/GridWorks/heating-system-design/cfd/` (sibling of
  the existing `engine/` package, sharing the parameter dataclass).

## Geometry — 2-D axisymmetric

The tank is a vertical cylinder; for the flute-vs-disc question with no
non-axisymmetric features, **2-D axisymmetric is sufficient** and is
~50× faster than 3-D. The Moscone flute is approximated as a vertical
annular slot with the integrated hole area of the real flute, which is
a documented and validated approximation (Zurigat 1991).

| Parameter | Value | Source |
|---|---|---|
| Tank inside diameter | 0.60 m (24") | `tank_H_over_D=3`, 150 gal |
| Tank inside height | 1.80 m (71") | same |
| Wall thickness | 6 mm HDPE (informational; modeled adiabatic) | Garth |
| Port T elevation | 1.66 m (0.92 H) | design.md |
| Port UM elevation | 1.26 m (0.70 H) | design.md |
| Port LM elevation | 0.83 m (0.46 H) | design.md |
| Bottom outlet | 0.10 m | symmetric to top |
| Disc diffuser diameter | sweep: 200, 300, 400 mm | TBD |
| Disc-to-wall gap | sweep: 10, 20, 40 mm | TBD |
| Flute length | 1.20 m (spans T to LM) | matches Vaughn proportions |
| Flute hole pattern | per the existing Vaughn drawing in `../Anti-stratification flute.pptx` | confirm exact spec |

Mesh: hex-dominant, 50–80 k cells, refined at diffuser/flute exits and
along the expected thermocline elevation. Boundary layer 5 cells deep on
all walls. Target y+ ~30 near walls (wall-function turbulence).

## Physics

- Working fluid: water, properties at 318 K (45 °C) reference; Boussinesq
  thermal expansion β = 4.0e-4 1/K; ν = 0.60e-6 m²/s; Pr = 4.0.
- Gravity: −9.81 m/s² along axial direction.
- Turbulence: **k-ω SST** with low-Re wall treatment. Justification: the
  injection plume is moderate-Re (Re_inlet ~5e3 at 15 kW / 5 K ΔT) and
  the bulk-tank flow is essentially laminar/stratified; SST handles the
  transition cleanly.
- Walls: **adiabatic** for the first pass (ambient-loss UA enters the
  1-D model as a separate term). This isolates the stratification
  question from the heat-loss question.
- Initial condition: linear temperature profile from 30 °C bottom to 60
  °C top, no flow.

## Run matrix (first pass)

Three case families, each at three flow rates that bracket realistic
charge duties:

| Family | Inlet device | Active port | Description |
|---|---|---|---|
| A | Flute | (self-selecting) | Single flute spanning T–LM |
| B | Disc | T | Disc diffuser at top port only |
| C | Disc | UM | Disc diffuser at upper-mid port |
| D | Disc | LM | Disc diffuser at lower-mid port |

Each family × three flow rates × two charge ΔTs:

| Flow (LPM) | Equivalent Q at 5 K | Equivalent Q at 15 K |
|---|---|---|
| 8 | 2.8 kW | 8.4 kW |
| 14 | 4.9 kW | 14.6 kW |
| 22 | 7.7 kW | 23 kW |

That's 4 × 3 × 2 = **24 runs**. At ~30 minutes wall-clock per axisymmetric
case on a modern 8-core machine, **~12 hours of compute total** — runs
overnight on a single workstation, no cluster.

Inlet boundary condition: fixed mass flow + fixed temperature step above
the existing tank-bottom temperature. Outlet: bottom port, fixed flow
out.

## Metrics

Each run produces:

1. **Thermocline thickness** Δz_thermo, defined as the vertical extent
   over which the dimensionless temperature 0.1 ≤ θ ≤ 0.9, measured at
   t = 0.5 × t_full-charge. **Lower is better.**
2. **Stratification number Str** (Wu & Bannerot 1986) computed over the
   full transient. **Higher is better.**
3. **Mixing number MIX** (Davidson 1994) at end-of-charge. **Lower is
   better; 0 = perfect stratification, 1 = fully mixed.**
4. **Outlet temperature transient** T_bottom_out(t) during a subsequent
   discharge — the practical "did the cold stay cold" measure.
5. **Exergy efficiency** of the charge cycle (Rosen 2001 formulation).

Decision rule: case family **B/C/D combined** wins over family A if,
across the operating envelope, the *worst-performing disc case* still
beats the flute on MIX by ≥ 0.05 and on Str by ≥ 10%. If the disc loses
on any operating point, we either (a) keep the flute, (b) add more disc
ports, or (c) revise disc geometry and re-run.

## Repo layout (under `/Users/jessica/GridWorks/heating-system-design/cfd/`)

```
cfd/
├── pyproject.toml                 # uv-managed, shares params with engine/
├── README.md
├── src/
│   └── gw_thermal_cfd/
│       ├── __init__.py
│       ├── case_gen.py            # generate OpenFOAM case from params
│       ├── post.py                # metric extraction (Str, MIX, Δz_thermo)
│       ├── runner.py              # batch runner, foamJob orchestration
│       └── templates/             # OpenFOAM dict templates (Jinja2)
│           ├── 0/
│           ├── constant/
│           └── system/
├── cases/                         # generated, .gitignored
└── results/
    ├── runs.csv                   # one row per run, with all metrics
    └── plots/
```

## First-pass execution plan

1. **Week 1** — Stand up OpenFOAM env (containerized OK). Build mesh
   generator. Validate against a published TES tank case (e.g. Zurigat
   1991 single-inlet) to confirm the solver setup reproduces a known
   thermocline.
2. **Week 2** — Implement case generator + post-processing. Run case
   family A (flute) at all three flow rates × two ΔTs.
3. **Week 3** — Run case families B/C/D (disc at each elevation).
   Sweep disc diameter (200/300/400 mm) at the worst-case flow to pick
   the smallest disc that holds Ri_inlet > 10.
4. **End of week 3** — Decision memo: flute vs disc, with the
   recommended disc geometry attached as the CAD ask to Garth.

## Open questions for this first pass

1. **Exact Moscone flute hole pattern** — need the drawing from
   `../Anti-stratification flute.pptx` digitized into a list of (z,
   hole_diameter, n_holes_per_row).
2. **Compute host** — workstation locally, or a cloud VM? Affects
   wall-clock estimates above.
3. **Validation case** — Zurigat 1991 is canonical, but if you have a
   measurement on a Vaughn tank (T-string during a real charge), that
   would be a much better validation target.
4. **Disc material / perforation** — we're modeling the disc as a solid
   plate with annular gap. If Garth's actual fabrication uses a
   perforated disc, we may need a follow-up run with the real
   perforation pattern, but the first pass is solid-plate.
