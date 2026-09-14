# ltn-automated-house-params

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-531

**EDD: yes** verified on a real broker: a running LTN accepts a
parameter set from its own fit subprocess and another from an operator
through its API, both through the same acceptance path; publishes the
in-force set; its SCADA holds the same set id after a SCADA restart; the
LTN's SQLite file is deleted and the LTN keeps running without a gap in
its plan.

> What this is: how an LTN keeps the house's thermal parameters and
> refreshes them automatically. Parameters are a sema JSON file beside
> the hardware layout; each LTN owns a small, bounded SQLite working
> store; the fit runs on the LTN box; an operator's set reaches the LTN
> through the LTN's own API; the in-force set is what the SCADA runs on.
> Rides the LTN on gwbase ([OPS-435](https://linear.app/gridworks/issue/OPS-435)).

## Decisions

- **One SQLite file per LTN, never a shared database.** One LTN per
  house, one store per LTN. A fleet-wide database grows in ways nobody
  planned and its schema becomes meaning that cannot move. Every table
  is a projection of a sema word, the schema is derived from the word
  and never authored by hand, and the LTN may change its own store's
  structure freely: nothing else depends on it.
- **Bounded retention, as a rule.** The store holds a working window,
  three weeks of hourly rows reduced from the messages the LTN receives,
  plus forecasts, prices, and the live bid and contract state. Nothing
  older, and nothing in it is a source of truth. A question further back
  is answered by the journal or the eventstore, not by the LTN.
- **A lost store starts empty.** Nothing the LTN needs to keep running
  is in the store. Deleted, it refills from live messages over three
  weeks; until the window is deep enough the LTN runs on the set it has.
  No recovery reads the ear capture or the journal: the LTN is control
  plane and stays up with the observability plane down
  ([`glossary.md`](../../glossary.md) "Control plane vs. observability
  plane").
- **House parameters are a sema JSON file, not rows.** Word instances on
  disk beside the hardware layout under the LTN's XDG config directory,
  read at load and validated through the snapshot class, exactly as the
  layout is. The filename follows the on-disk grammar for sema instances.
  The LTN holds at least an automatic set and an operator set and knows
  which is in force; how sets are kept on disk and switched is decided
  here, not presumed (see Sets and switching).
- **The fit runs on the LTN box, as its own daily process.** The LTN
  reduces the messages it receives to hourly rows; the fit is a
  least-squares fit over the window, small, and runs as a subprocess so
  a crash or a hang in it cannot stall the LTN. Work leaves the box only
  when it crosses the threshold: more than ~30 s against the control
  period, a toolchain the box should not carry, or memory beyond the
  box's share among its LTNs. Today that is supergraph regeneration and
  the FLO, whose cost is memory rather than CPU — the flo-as-a-service
  seam ([OPS-514](https://linear.app/gridworks/issue/OPS-514)), not this
  design.
- **The LTN is the only writer to the SCADA.** Operator parameter changes
  reach the LTN through its own application API over HTTPS with a
  fleet-operator identity ([OPS-408](https://linear.app/gridworks/issue/OPS-408)):
  never a web page to the SCADA, never a broker command from a web app.

## Acceptance path

One path in the LTN validates a parameter set against declared bounds
and makes it the set in force; two entry points feed it:

- **The fit subprocess.** Its result is checked; if it passes it becomes
  the automatic set. A failed check keeps the set in force and publishes
  a glitch. No command, no ack: there is no counterparty.
- **The operator, via the LTN's API.** Authority checked at the LTN; the
  reply states whether the set is in force and whether a supergraph
  regeneration was triggered (the supergraph is cached by a hash of the
  physical parameters, so a changed set invalidates it); refused on
  schema, a value outside bounds, or a caller without authority.

Whenever the in-force set changes the LTN publishes it as an event (the
record; ear captures it) and sends it to the SCADA.

## Sets and switching

Open, decided here before code: which set is in force when both exist;
how an operator switches between them; what an incoming fit does while
the operator set is in force; whether an operator set expires; which
values an operator may set and against what bounds; how the state is
visible. Whether an override is first a comparison tool (run the FLO on
both sets, show the difference) before it is a control tool.

## LTN ↔ SCADA reconciliation

The LTN sends the in-force set to the SCADA whenever it changes. When
the SCADA was down: on boot the SCADA reports the set it holds (the same
word, with its id); the LTN replies with the in-force set if the ids
differ. The word carries the whole set and its id, never a delta.

## Sema words

Registry search first; each new word goes through the sema authoring
gate. `flo.params.house0` is the existing LTN → SCADA word
(`AlphaTimes10`, `BetaTimes100`, `GammaEx6` with the operating points
beside them).

- The parameter set into the LTN, from the fit subprocess or the
  operator: fitted values, fit window, method, the fit-quality figure
  [OPS-519](https://linear.app/gridworks/issue/OPS-519) defines, created
  stamp. Which values is Open until the method is written down; whether
  house thermal mass leaves the FLO's parameters for the energy
  prediction is decided before the word is authored.
- The in-force set between LTN and SCADA, both directions: the
  successor of `flo.params.house0`, or a new version of it.

## Inputs

The OPS-519 hand-off: the method written down (hourly channels, weather
fields naming any the fleet does not collect, regression form, backlook
window, retraining frequency, how fit quality is conveyed), the code
committed beside the FLO with the script that derives hourly rows from
the messages the LTN receives, and the cold-start prior. The parameter
word stays Open until those exist.

## Build order

1. The sema words, staging, under the sema gate; the on-disk files
   beside the layout; the LTN loads the in-force set at boot.
2. The SQLite working store as derived projections of the words the LTN
   already consumes, the hourly reduction, and the three-week trim.
3. The acceptance path with both entry points; the LTN → SCADA send and
   the on-boot reconciliation.
4. The fit subprocess on the box, daily.
5. The EDD run above, logged under `experiments/`.

## Done-when

- A real LTN on a real broker accepts a fit from its subprocess and an
  operator set from its API through the same path, publishes the
  in-force set, and its next plan reflects it.
- After a SCADA restart the SCADA holds the same set id as the LTN.
- Deleting the SQLite file loses nothing the LTN needs to keep running.
- The store never exceeds its window: a three-week-plus-one-day run
  shows the trim holding.
