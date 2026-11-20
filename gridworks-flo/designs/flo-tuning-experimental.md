# flo-tuning-experimental — a knob under tuning changes bruce and nothing else

Status: Draft · Pass 0 · Updated 2026-11-20 · Linear: OPS-696
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
| tlayouts | authors each house's tuning in its operational params, `Experimental` included |
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
When bruce settles as a whole, `Experimental` leaves both words and every
remaining knob is declared (OPS-697).

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

## What the journal records

**Where a knob's value lives.** Every knob, declared or under tuning, is
authored in tlayouts: a house's `gw.operational.params` names its
`FloTuning`, `Experimental` included, and the LTN copies it into each
request untouched. One authoring place for operational params, versioned
with the rest, and journaled inside each request as sent. A knob under
tuning differs from a declared one only in where the word stops
describing it.

**The record of a slot is the two words already journaled.** The LTN's
`flo.params` and the FLO's `flo.recommendation` go through the class taps
to the ear, and the journalkeeper keys each on its `CreatedMs`
(`gjk/sema_message_persistor.py` `MSG_CREATED_AT_FIELDS_MS`). The knobs
are in the request's `Tuning.Experimental`, the series in each path's
`PathPenaltiesList` `Experimental`. Nothing else is needed as long as the
request bruce solves is the request the LTN sent, which two rules keep
true:

- **No defaults inside bruce.** A knob bruce reads MUST be present in
  `Experimental`; a request lacking it is refused (`flo.refusal`). The
  sketch does this (`bruce/service.py` `experimental_knob` raises on a
  missing key). A default inside bruce would make the journaled request
  lie about what ran.
- **The lift is information-preserving.** bruce lifts a 002 or 003
  request to 004 by moving the declared knobs into `Experimental`; the
  journaled older version states the same values under their declared
  names.

**What a knob change costs.** Adding or retuning a knob at a live house
is a tlayouts edit, regen, commit, push and `roll.sh` at that house,
since the LTN reads operational params once at construction. A field
roll per experiment, with no sema bump and no deploy of the other
repos. Offline the knob is free: bruce's local runs and the visualizer's
re-run set `Experimental` in the request directly.

**Rejected: knob values in a per-house table inside bruce, with the
recommendation echoing the tuning it solved with.** It lets Thomas change
a live knob with a bruce deploy alone, but splits operational params
across two repos and needs a `Tuning` field on `flo.recommendation` so
the journal states what ran. One authoring place won.

**Rejected: bruce returns the effective `flo.params` and the FLO
broadcasts it (`rjb`).** The journal's id is `(from_alias, TypeName,
CreatedMs)`, so a `flo.params` from the FLO's alias is a second request
row for the same slot, and the FLO gains a publish path to own.

**Out of scope: re-runs.** The browser's re-run solves in a thread
inside the web backend (`api/v2/routers/flo_rerun.py`) and nothing of it
is journaled, edited knobs included. That is true before this design and
after it, and is its own issue if a re-run's knobs are worth keeping.

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
2. ✅ Shared with Thomas 2026-11-19. The remaining six repos updated
   locally on `jm/flo-tuning-experimental` branches, each gate green:
   journalkeeper, web-backend, web-frontend, gridworks-flo, scada (twins
   and fixtures), tlayouts (every house at tuning 003). bruce's re-run
   path lifts older params as the bytes path does.
   End to end on the laptop dev stack the same evening: the LTN's 004
   request with the knobs in the dict, bruce's 003 answer with the series
   in the dict, the bid, both journaled
   (`experiments/2026-11-19-flo-tuning-experimental-e2e/`, PASS).
3. ✅ Thomas reviewed and agreed, 2026-11-19 (design to Pass 1 when
   the stamp is bumped). Settle there whether the
   frontend's re-run panel renders `Experimental` as a generic key and
   value table.
4. The five versions stay **staging** on the sema branch (`c8cc461`) while
   Thomas finishes the PR; a 2026-11-19 promotion was reverted 2026-11-20
   so he can edit the words in place without a sema version. **Next
   move:** the seven commits are pushed on `jm/flo-tuning-experimental`
   and Thomas takes the PR; promotion (bottom-up, `sema promote`) and the
   roll per OPS-693's order follow his review.
5. Distill into `executor/bruce-flo.md` "Costs and penalties" and
   `executor/primary.md`; delete this file.
