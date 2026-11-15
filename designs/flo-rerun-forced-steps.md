# FLO re-run: forced heat pump steps

Status: Draft · Pass 0 · Updated 2026-11-15 · Linear: OPS-683

**EDD: no** build-out on a shipped tool, verified by each repo's suite
and one laptop check: a re-run with two steps forced off draws a path
with those steps at zero and a different cost, and the web box still
answers 404 on the route.

> What this is: the second half of the visualizer's FLO re-run. The
> first half shipped 2026-11-15 (web-backend `9bac6f7`, `c260b4a`;
> web-frontend `c7ad3f8`) and is recorded in the web-backend visualizer
> executor "FLO": a laptop backend solves an hour again with bruce's
> penalty tuning edited, and the page draws the answer. This design adds
> what that half left out: forcing heat pump steps on or off, which
> bruce's optimizer params already accept and no sema word states.

## Why a word first

The seam between browser and backend is sema both ways. Today the
re-run's body is the hour's `flo.params` with its Tuning edited, and
`flo.params` has no place for "the heat pump is forced on at steps 3 and
4". Adding the lists as an ad hoc field of the request would put meaning
in a JSON shape nobody vendors; the forced steps become a word the
registry defines and every repo on the path vendors.

## The ask, in order

1. **Sema.** Make a word for this: a `flo.rerun.request` that wraps a
   `flo.params` with the forced-on and forced-off step lists (step
   ordinals into the request's `StepDurationMinutes`), or, if the author
   prefers, the two lists as optional fields of `flo.params` itself. The
   spec goes into the registry first; the snapshot is vendored into
   optimal-flexibility, gridworks-web-backend and gridworks-web-frontend
   before the first consumer line.
2. **optimal-flexibility.** `bruce.service.recommend` takes the new word
   (or the new fields) and passes the forced steps to the optimizer.
3. **gridworks-web-backend.** The route's body becomes the new word
   (`api/v2/routers/flo_rerun.py`, tests in `tests/test_flo_rerun.py`);
   the lock moves to the bruce commit that reads it
   (`uv lock --upgrade-package bruce-energy`).
4. **gridworks-web-frontend.** The panel (`src/visualizer/FloRerunPanel.tsx`,
   `src/visualizer/flo-rerun-tuning.ts`) gains the two step lists and
   sends the new word.

Running the tool locally is in the web-backend README, "The FLO re-run
on a laptop": the `rerun` dependency group, `BACKEND_FLO_RERUN=in-process`
with `BACKEND_RUNNING_LOCALLY=true` (a deployed API refuses the setting).
bruce reads `flo.params` at the version its snapshot vendors, and an
older journaled hour answers 422 saying so.

## Checks

- Each repo's suite.
- On a journaled hour against `tsdb_tap`: a re-run with the heat pump
  forced off for two steps draws a path with those steps at zero and a
  different cost; forced on, the same two steps at the heat pump's
  maximum.
- The web box answers 404 on the route.

## Open

- The same re-run over the broker, a FLO-service request and answer
  pair, so a browser against the web box could ask for one. Nobody needs
  it yet; it is a design of its own when someone does.
