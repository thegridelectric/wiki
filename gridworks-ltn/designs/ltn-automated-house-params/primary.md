# ltn-automated-house-params (hub)

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-531

**EDD: yes** verified on a real broker: a running LTN accepts a
parameter set from its own fit subprocess and another from an operator
through its API, both through the same acceptance path; publishes the
in-force set; its SCADA holds the same set id after a SCADA restart; the
LTN's SQLite file is deleted and the LTN keeps running without a gap in
its plan.

**▶ Active spoke: [`parameter-word.md`](parameter-word.md)**

> What this is: the hub for how an LTN keeps the house's thermal
> parameters and refreshes them automatically. Parameters are a sema JSON
> file beside the hardware layout; each LTN owns a small, bounded SQLite
> working store; the fit runs on the LTN box; an operator's set reaches
> the LTN through the LTN's own API; the in-force set is what the SCADA
> runs on. Rides the LTN on gwbase
> ([OPS-435](https://linear.app/gridworks/issue/OPS-435)).

## Where this starts from

The estimation method and its code exist: an hourly least-squares
regression for heating load in the `gridworks-house-parameters` repo,
described in
[`../../research/house-parameter-estimation.md`](../../research/house-parameter-estimation.md).
It replaces the load coefficients (alpha, beta, gamma) and nothing else.

Three facts from the 2025–26 season shape the spokes
(`heating-system-design/mix-or-not.md` "Charge: how hot is hot
enough" holds the values and where they are stored):

- The parameters were set by hand and revised several times a season in
  every house.
- The LTN and the SCADA each held a copy, and the copies were edited
  separately.
- Required source water temperature is not a parameter and not a
  measurement. It is computed from forecast load through a curve drawn
  from two hand-set points, and local control and the FLO use the result
  differently.

## Decisions that hold across the spokes

- **The LTN is the only writer to the SCADA.** Operator parameter changes
  reach the LTN through its own application API over HTTPS with a
  fleet-operator identity ([OPS-408](https://linear.app/gridworks/issue/OPS-408)):
  never a web page to the SCADA, never a broker command from a web app.
- **One set is in force, and it has one home.** The LTN holds it; the
  SCADA holds a copy with the same id or asks for it. No second place to
  edit a parameter exists.
- **House parameters are a sema JSON file, not rows.** Word instances on
  disk beside the hardware layout under the LTN's XDG config directory,
  read at load and validated through the snapshot class, exactly as the
  layout is. The filename follows the on-disk grammar for sema instances.
- **The LTN is control plane.** Nothing in this design reads the journal
  DB or the ear capture; the LTN stays up with the observability plane
  down ([`glossary.md`](../../../glossary.md) "Control plane vs.
  observability plane").
- **Work stays on the LTN box unless it crosses the threshold:** more
  than ~30 s against the control period, a toolchain the box should not
  carry, or memory beyond the box's share among its LTNs. Today that is
  supergraph regeneration and the FLO, whose cost is memory rather than
  CPU: the flo-as-a-service seam
  ([OPS-514](https://linear.app/gridworks/issue/OPS-514)), not this
  design.

## Spokes

In build order.

1. **[`parameter-word.md`](parameter-word.md)** — the sema words: what a
   parameter set carries, which parameter groups it covers, and what
   required source water temperature means in it.
2. [`working-store.md`](working-store.md) — the per-LTN SQLite store, the
   hourly reduction from received messages, and the three-week trim.
3. [`acceptance-and-reconciliation.md`](acceptance-and-reconciliation.md)
   — the one path by which a set comes into force, sets and switching,
   and the LTN ↔ SCADA exchange.
4. [`fit-on-the-box.md`](fit-on-the-box.md) — adopting the regression as
   a daily subprocess: inputs, window, bounds, cold-start priors, and the
   checks on the method.

## Done-when

- A real LTN on a real broker accepts a fit from its subprocess and an
  operator set from its API through the same path, publishes the
  in-force set, and its next plan reflects it.
- After a SCADA restart the SCADA holds the same set id as the LTN.
- Deleting the SQLite file loses nothing the LTN needs to keep running.
- The store never exceeds its window: a three-week-plus-one-day run
  shows the trim holding.

The EDD run is logged under `experiments/`.

## Notes

- This design is also the first step toward the terminal-asset registry:
  the acceptance path and in-force exchange are the path hardware layouts
  and operational params want too
  ([OPS-471](https://linear.app/gridworks/issue/OPS-471),
  [OPS-392](https://linear.app/gridworks/issue/OPS-392),
  [OPS-408](https://linear.app/gridworks/issue/OPS-408)). The in-force
  exchange carries a whole artifact with its id for any of the three, so
  there is one LTN-to-SCADA mechanism and not three.
