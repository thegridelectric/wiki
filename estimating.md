# estimating — what the scoreboard has taught us

Status: Draft · Pass 0 · Updated 2026-08-14

> What this is: the lessons drawn from
> [`jess-estimates.md`](jess-estimates.md), which
> holds the raw estimate-vs-actual rows. The scoreboard records what
> happened; this records what to do differently next time.

## The dominant signal: new code vs. old code

Every large miss so far sorts the same way.

**Work that authors new artifacts finishes far under estimate.** The SASL
mechanism plugin was quoted at 6h and took 1.25h; its connect wiring was
quoted at 2.5h and took 0.2h. The registry populate-and-deploy step was
quoted at 13h and took 7.5h. The reason is that new code is bounded by what
you write, and the writing is the fast part. The estimate anchors instead on
how *consequential* the subsystem sounds — "the one custom Erlang artifact",
"the client half of the auth gate" — when the artifact is a hundred-line
module and a settings block.

**Work inside existing, already-shipped code runs over.** The semafy pilot
was quoted at 4h and took 9.5h; the summer hack through scada blew a 24h
estimate. Here the work is not authoring but *discovery*: what does this code
assume, what breaks when it moves, what has silently drifted, whose
assumptions am I about to violate. Discovery cannot be sized from outside,
because the whole point is that you cannot see it until you touch the code.

A day inside gridworks-base showed both halves at small scale. The new
plugin, credentials class, and connect wiring landed in well under half the
quoted time. The surprises all came from touching what already existed: a
snapshot regen collided with a hand-written file living inside a generated
tree, a stale index lied about which schema versions were vendored, a demo
script turned out to have been unrunnable since May, and a lint cache masked
a real break. None of that was visible at estimate time.

## What to do about it

**Quote the two halves separately.** Count the artifacts you will author, and
size that half from the design's actual Plan lines rather than its framing
(designs open big and scope small). Then size the existing code you must
touch or reconcile, and scale that half by how old, how large, and how
foreign it is. The second half is where the misses live — near zero in a
young repo, dominant in scada.

**Widen downward for green-field.** The misses are asymmetric: actuals land
*below* the 90% low bound, repeatedly. An interval that cannot contain a
five-fold overestimate is not a 90% interval. When the work is mostly new
code, the low bound should be roughly a third of the point, not two thirds.

**Widen upward for old code, rather than raising the point.** The risk in
brown-field work is a long discovery tail, not a uniformly slower pace. The
honest shape is a modest point estimate with a high bound several times it.

**Treat a surprise as data about the code, not about the estimate.** Each
brown-field overrun named something real — a hand-edit inside generated
output, an untested script, a cache that could disagree with CI. Those are
findings worth fixing at the source, and fixing them is what shrinks the
next estimate in that area.
