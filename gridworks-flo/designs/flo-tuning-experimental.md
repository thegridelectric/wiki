# flo-tuning-experimental — a knob under tuning changes bruce and nothing else

Status: Draft · Pass 0 · Updated 2026-11-19 · Linear: OPS-696
**EDD: no** the sema suite, the bruce suite and the key test: a knob read
from `Experimental` reaches bruce's optimizer with no change to any word.

> What this is: `flo.tuning.bruce` and `flo.path.penalties.bruce` each gain
> one open-container field, `Experimental`, for the knobs and penalty series
> the bruce optimizer is still tuning. A knob is added in bruce, sent inside
> the dict, echoed back in the recommendation, and promoted to a declared
> field once it settles. One coordinated version bump adopts the shape;
> after it, a new knob changes no word.

## The eight repos

The repos that changed for the unmet-load penalty on 2026-11-18, and that
move once more at this bump:

| repo | what it does with the tuning |
|---|---|
| sema | defines the words |
| tlayouts | authors each house's tuning in its operational params |
| gridworks-scada | the LTN copies the tuning into each request, untouched |
| gridworks-flo | dispatches on the Tuning TypeName, moves bytes |
| optimal-flexibility | bruce: the one reader of the knobs |
| gridworks-journalkeeper | stores the request and the recommendation |
| gridworks-web-backend | serves journaled words, relays a re-run |
| gridworks-web-frontend | the penalty tuning panel and plot |

Only bruce and the frontend's panel know what a knob means.

## The problem

The unmet-load penalty of 2026-11-18 added two knobs to `flo.tuning.bruce`
and one series to `flo.path.penalties.bruce`. Because every nested reference
pins a version and every word closes with `additionalProperties: false`,
that was five word bumps in one sema PR (tuning 002, params 003,
rerun.request 001, penalties 001, recommendation 002) and **A CHANGE IN 8 REPOS**.

Only two of the eight have code that knows what the knobs mean: bruce, and
the frontend's penalty tuning panel. The other six pass the tuning through
untouched (the scada copies `ops.FloTuning` into the request, the flo
service dispatches on the Tuning TypeName, the journal stores the payload)
and still had to regenerate, redeploy, and in the field the journal went
blind to the new versions for a day (OPS-693). bruce itself decodes with
`extra="ignore"` twins and would have accepted the new keys without any
sema change; the change was forced on it by the LTN's generated class
refusing to construct a request with unknown keys.

## The decision

Each of the two bruce-owned words gains one required field:

```yaml
  Experimental:
    type: object
    description: >
      Knobs the bruce optimizer reads while they are being tuned, keyed by
      name. The bruce commit a recommendation names defines the keys. A
      knob that settles becomes a declared field in the next version.
```

An open container (`type: object`, no `properties`) is the shape the sema
spec provides for content whose structure is not declared at this layer
(`sema/spec/authoring/types.md` "Open Containers"; precedent
`derived.channel.gt` `Parameters`). The generator renders it as a declared
`dict[str, Any]` attribute, so every consumer at every version has the
field, knows it is a dict, and knows the schema declined to type its
contents. The field is required and empty when there is nothing under
tuning, so no consumer grows an `is None` branch.

**Rejected: `additionalProperties: true` on the word.** The generator
renders it as `extra="allow"`; the extras survive a round trip but a
consumer whose snapshot predates them sees them only in pydantic's extras
bag, with no attribute and no name on the schema. The word stops being
truthful about its own shape.

**The first concrete example.** The two unmet-load knobs and their penalty
series move into `Experimental` at the bump, so the first instance of the
new shape is non-empty and shows how a knob under tuning is sent and
echoed: `flo.tuning.bruce` 003 declares exactly the fields of 001 plus
`Experimental`, and `flo.path.penalties.bruce` 002 declares the fields of
000 plus `Experimental`. Two words, two examples: the knobs go in on the
tuning word and the penalty series they produce come back on the penalties
word. Declared fields other than `Experimental` are elided.

```json
{"TypeName": "flo.tuning.bruce", "Version": "003", ...,
 "Experimental": {"UnmetLoadPenaltyEnabled": true, "UnmetLoadPenaltyWeight": 10.0}}
```

```json
{"TypeName": "flo.path.penalties.bruce", "Version": "002", ...,
 "Experimental": {"UnmetLoadPenaltyUsdList": [0.0, 0.0, 1.2]}}
```

**The promotion rule.** A knob leaves `Experimental` for a declared field
with a description when its meaning and range have settled. The spec's own
stabilization clause says the same of open words ("as schemas stabilize,
types SHOULD transition toward `additionalProperties: false`"). Without the
habit the dict becomes the permanent home of everything, which is the cost
this design accepts for knobs still in flux and refuses for settled ones.

**What the dict cannot state.** An axiom may not constrain an open
container's contents unconditionally (types.md "Open Containers"), so the
penalties word cannot state that each series in `Experimental` has the
step count of `RswtPenaltyUsdList`. bruce's own tests state it.

## The words

| word | new version | delta from the current version |
|---|---|---|
| `flo.tuning.bruce` | 003 | `UnmetLoadPenaltyEnabled`, `UnmetLoadPenaltyWeight` removed; `Experimental` added, the two values moved into it |
| `flo.path.penalties.bruce` | 002 | `UnmetLoadPenaltyUsdList` removed; `Experimental` added, the series moved into it; axiom PenaltyListLengths names the three declared lists |
| `flo.params` | 004 | Tuning: bruce 002 → 003 |
| `flo.rerun.request` | 002 | Params: flo.params 003 → 004 |
| `flo.recommendation` | 003 | PathPenaltiesList: penalties 001 → 002 |
| `gw.operational.params` | 000, in place (staging) | FloTuning: bruce 002 → 003 |

Every current version is `published`, so each is a new version; the
upgrades are dump, move the keys, validate.

## Consumers and the roll

The same eight repos, once, in the order OPS-693 states: every reader
vendors the new version beside the old, the answer's readers deploy (LTNs,
journalkeeper, web), the answer's sender restarts (flo), the request's
senders roll (tlayouts regenerated, LTN houses).

After the roll a knob Thomas adds inside `Experimental` changes bruce,
and the frontend only if he wants a control for it; a generic key and value
panel over `Experimental` removes even that. No other repo moves and no
deploy is coordinated.

## Plan

1. ✅ Sketch branches `jm/flo-tuning-experimental` in sema (committed,
   `c8cc461`, `ci.sh` green; the five versions are staging) and in
   optimal-flexibility (bruce reads the knobs from `Experimental`, writes
   the series into it, lifts 002 and 003 requests to 004; snapshot
   rebuilt with `--allow-staged`; suite green).
2. **Next move:** push both branches and open the two PRs as sketches for
   Thomas; review together; design to Pass 1. Settle there whether the
   frontend's re-run panel renders `Experimental` as a generic key and
   value table.
3. Promote the five versions (`sema promote`), then the roll per OPS-693's
   order with the remaining six repos.
4. Distill into `executor/bruce-flo.md` "Costs and penalties" and
   `executor/primary.md`; delete this file.
