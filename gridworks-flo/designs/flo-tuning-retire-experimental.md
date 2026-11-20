# flo-tuning-retire-experimental — the tuning scaffolding comes out once bruce settles

Status: Draft · Pass 0 · Updated 2026-11-19 · Linear: OPS-697
**EDD: no** the sema suite, the bruce suite and the key test: every knob
bruce reads is a declared field of `flo.tuning.bruce`, and every series it
writes is a declared field of `flo.path.penalties.bruce`.

> What this is: the reverse of OPS-696. When bruce stops being in rapid
> flux, every knob and series still inside `Experimental` becomes a
> declared field with a description, `Experimental` is removed from
> `flo.tuning.bruce` and `flo.path.penalties.bruce`, and the frontend's
> generic panel over the dict goes. One coordinated bump across the same
> eight repos, in the roll order of OPS-693.

## When

Thomas says bruce has settled: no knob has changed value or meaning for
long enough that the next change is expected to be a rare, deliberate
one, worth a sema bump and a roll. The decision is his and is recorded on
the Linear issue when it is made. Until then this design is queued and
OPS-696's shape stays in force.

## The decision

The open container was the right shape while a knob might change every
week; a settled optimizer deserves a word that states its whole shape.
With `Experimental` gone:

- every knob is a declared field with a description and a range, so a
  reader of the word, the journal or the visualizer's re-run panel knows
  what each value means without opening optimal-flexibility;
- axioms may constrain every penalty series, so the step-count axiom
  covers all of them.

## The words

| word | new version | delta |
|---|---|---|
| `flo.tuning.bruce` | 004 | every knob then in `Experimental` becomes a declared field; `Experimental` removed |
| `flo.path.penalties.bruce` | 003 | every series then in `Experimental` becomes a declared field; `Experimental` removed; the step-count axiom names every list |
| `flo.recommendation` | 004 | PathPenaltiesList: penalties 002 → 003 |
| `flo.params` | 005 | Tuning: bruce 003 → 004 |
| `flo.rerun.request` | 003 | Params: flo.params 004 → 005 |
| `gw.operational.params` | in place (staging) or bump | FloTuning: bruce 003 → 004 |

The exact field list is written at the time, from what is in
`Experimental` then; the upgrades move each key out of the dict into its
declared field.

## Consumers and the roll

The same eight repos as OPS-696 (sema, tlayouts, gridworks-scada,
gridworks-flo, optimal-flexibility, gridworks-journalkeeper,
gridworks-web-backend, gridworks-web-frontend), once, in the order
OPS-693 states: every reader vendors the new version beside the old, the
answer's readers deploy, the answer's sender restarts, the request's
senders roll. The frontend's generic key and value panel over
`Experimental` is deleted in the same change.

## Plan

1. Thomas declares bruce settled; the knob list is fixed on the issue.
2. Sema PR: the six versions above, upgrades, examples, samples,
   regenerated runtime.
3. optimal-flexibility PR: knobs read from declared fields, series
   written to declared fields.
4. tlayouts: every house's tuning authored in full; regenerate.
5. The roll per OPS-693's order with the remaining five repos.
6. Distill into `executor/bruce-flo.md` "Costs and penalties" and
   `executor/primary.md`; delete this file.
