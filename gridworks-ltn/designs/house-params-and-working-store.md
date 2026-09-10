# house-params-and-working-store

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-531

**EDD: yes** verified on a real broker: a fitted house-parameter record
reaches a running LTN over its surface, is acked, written to disk and
picked up by the FLO with a supergraph regeneration; then the LTN's
SQLite file is deleted and the LTN rebuilds its working window from the
ear capture and resumes without a gap in its plan.

> What this is: how an LTN stores what it needs to run: the house's
> thermal parameters as a sema JSON file beside the layout, and a small,
> bounded, rebuildable SQLite working store per LTN. It also defines the
> surface through which a fitted parameter set reaches the LTN, and
> leaves the operator override of that fit to be grilled. Rides the LTN
> on gwbase ([OPS-435](https://linear.app/gridworks/issue/OPS-435)).

## Decisions

- **One SQLite file per LTN, never a shared database.** One LTN per
  house, one store per LTN. A fleet-wide database grows in ways nobody
  planned and its schema becomes meaning that cannot move. The guard here
  is structural: every table is a projection of a sema word, the schema
  is derived from the word and never authored by hand, and the whole
  file can be deleted and rebuilt. A store that can be dropped without
  loss cannot get stuck.
- **Bounded retention, as a rule.** The store holds a working window,
  three weeks of readings, forecasts and prices, plus the live bid and
  contract state. Nothing older, and nothing in it is a source of truth.
  The journal DB and the eventstore are the archive; a question further
  back is answered there, not by the LTN. The LTN's read façade serves
  the window only.
- **House parameters are a sema JSON file, not rows.** One word instance
  on disk beside the hardware layout under the LTN's XDG config
  directory, read at load and validated through the snapshot class,
  exactly as the layout is. The filename follows the on-disk grammar for
  sema instances (subject, condition, type name, version). At most two
  sets are kept: `current` and `previous`, the previous one being the
  rollback for a bad fit. No parameter history on the LTN; the ear
  capture has every record ever accepted.
- **The bus is the record; disk and SQLite are views.** A parameter
  record is published before it is written, the LTN acks it, ear captures
  it. A lost file or a deleted SQLite store is a re-fetch from the
  capture. This is the registry's durability pattern applied to one
  house.
- **The estimator runs beside the LTN, never inside it.** Fitting house
  parameters from weeks of hourly scada and weather data is analysis,
  and analysis never slows the production system. The fit reads the
  journal DB as a batch job and hands the LTN a record. The LTN keeps no
  fitting code and no training data.

## The parameter surface

Delivering a fit to the LTN is a command on an LTN command surface
(`../../command-surface.md`), one tier above the homeowner's setpoint on
the impact ladder because it changes what the FLO believes about the
house.

- **Command.** The house-parameter word, carrying the fitted values, the
  fit window, the method, a fit-quality figure and a created stamp.
  Which values: today the FLO's house thermal-response coefficients live
  in `flo.params.house0` as `AlphaTimes10`, `BetaTimes100`, `GammaEx6`
  with the operating points beside them; the fitted set is expected to
  be that family, or a successor the fit method defines. Open until the
  method is written down (see Waiting on).
- **Reply.** Ack states the set is now `current`, whether a supergraph
  regeneration was triggered (the supergraph is cached by a hash of the
  physical params, so a changed set invalidates it), and when the new
  plan takes effect. Nack with a reason: schema, an implausible value
  against declared bounds, or a sender without authority.
- **Authority.** The fleet operator's identity, checked at the LTN;
  the step-up assertion, as for any high-impact command.
- **Cadence.** Deliberate, weekly or on a meaningful change, never per
  run of the fit. The regeneration cost is the reason.

## To grill: operator-supplied parameters from a UI

An operator will want to supply an alternative parameter set from a UI,
overriding the fitted one. Not designed here; grill before writing:

- Is an override a third set beside `current` and `previous`, or does it
  become `current` and push the fit to `previous`?
- Does an override expire, or hold until released, and what does the
  next fit do when it arrives while an override holds?
- Which values may an operator set, and against what bounds?
- How the UI reaches the LTN: the same surface with a different sender,
  or the read façade plus this surface as one operator tool.
- Whether an override is a comparison tool (run the FLO on both sets,
  show the difference) before it is a control tool.

## Waiting on

- The fit method's inputs, stated by its author: which hourly channels,
  which weather fields, and the regression form. The current fits appear
  to use hourly data and an irradiance series the fleet does not yet
  collect; the weather-forecast service and the journal need those
  before the LTN can be fed a fit that depends on them. Until that
  write-up exists the parameter word stays Open.

## Build order

1. The house-parameter word, staging, under the sema gate; the on-disk
   file beside the layout; the LTN loads it at boot, `current` then
   `previous` on validation failure.
2. The SQLite working store as derived projections of the words the LTN
   already consumes, with the three-week trim and the rebuild-from-capture
   path.
3. The parameter surface: command, ack with regeneration flag, nack
   reasons, authority check.
4. The EDD run above, logged under `experiments/`.

## Done-when

- A real LTN on a real broker accepts a fit, acks with the regeneration
  flag, writes `current`, moves the old set to `previous`, and its next
  plan reflects the new parameters.
- Deleting the SQLite file and restarting the LTN rebuilds the window
  from the ear capture with no gap in bids or dispatch.
- The store never exceeds its window: a three-week-plus-one-day run
  shows the trim holding.
- The read façade serves the window and refuses nothing older; the
  journal answers it instead.
