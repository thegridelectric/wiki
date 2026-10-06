# acceptance-and-reconciliation

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-531

> What this is: a spoke of [`primary.md`](primary.md). The one path by
> which a parameter set comes into force at the LTN, how the automatic
> and operator sets coexist, and how the LTN and its SCADA come to hold
> the same set.

## Why one path

Last season each house's parameters lived in two places, the SCADA's
operational params and what the LTN sent the FLO, and the two were edited
separately. On one day the LTN at one house sent a design-day RSWT 20 °F
below the value the SCADA's layout held. Parameters were also changed by
hand several times a season with no record of why beyond the values
themselves. One acceptance path with one in-force set and an id closes
both.

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

## Bounds

The acceptance check needs declared bounds, and none exist yet:

- an acceptable range for each parameter;
- an acceptable change from the set in force;
- an acceptable range for the load the set predicts.

Last season's hand-set values give a first sense of scale: the load
coefficients moved by up to half between revisions in one house.

## Sets and switching

The LTN holds at least an automatic set and an operator set and knows
which is in force.

Open, decided here before code: which set is in force when both exist;
how an operator switches between them; what an incoming fit does while
the operator set is in force; whether an operator set expires; which
values an operator may set and against what bounds; how the state is
visible. Whether an override is first a comparison tool (run the FLO on
both sets, show the difference) before it is a control tool.

Until every parameter group has an estimator
([`parameter-word.md`](parameter-word.md) "What a set covers today"), the
groups the fit does not produce are set through the operator path.

## LTN ↔ SCADA reconciliation

The LTN sends the in-force set to the SCADA whenever it changes. When
the SCADA was down: on boot the SCADA reports the set it holds (the same
word, with its id); the LTN replies with the in-force set if the ids
differ. The word carries the whole set and its id, never a delta.

The SCADA's own copy of house parameters in its operational params stops
being a place to edit them. How the SCADA persists the received set
across a restart, and what it runs on when it has never received one, is
open.

## Reporting

A weekly report of the sets that came into force and a glitch on a
refused fit. Report format and where it is read are open.

## Build step

The acceptance path with both entry points; the LTN → SCADA send and the
on-boot reconciliation.

## Verified by

A real LTN on a real broker accepts a fit from its subprocess and an
operator set from its API through the same path, publishes the in-force
set, and its next plan reflects it. After a SCADA restart the SCADA holds
the same set id as the LTN.
