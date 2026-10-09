# estimating — what the scoreboard has taught us

Status: Draft · Pass 0 · Updated 2026-10-09

> What this is: the lessons drawn from the owner's estimates log (per
> person, kept outside the wiki; the raw estimate-vs-actual rows). The
> scoreboard records what happened; this records what to do differently
> next time. "Before you estimate" is the whole brief; the sections
> after it are the reasoning, and "Notes" the dated analyses behind it.

## Before you estimate

Read this section, then quote. Each line is argued below.

- **Estimate the spoke**, one row with a point and a 90% interval; never a
  chunk, rung or rope member.
- **Read the design's own Plan lines, not its framing.** Designs open big
  and scope small.
- **Quote two halves.** New artifacts you will author: fast, bounded by
  what you write. Existing code you must touch or reconcile: discovery,
  unbounded from outside; scale it by how old, large and foreign the code
  is.
- **The scoreboard runs lopsided under.** Of 39 finished rows, 19 sit in
  their interval (49% against the 90% target); 15 misses are under the
  low bound, 5 over the high. The low bound follows an inflated point.
  Build-out work: halve the low bound, leave the high. A spoke that opens
  a sema word or a board: leave the point, raise the high bound several
  times over it.
- **Add the rebuild-grade spec beat** as its own line, about a tenth of
  the point, whenever the design is about to be distilled.
- **Row discipline.** Design/spoke is the slug only (`OPS-392
  basic-sieg`); the scope goes in the estimate comment on the issue; Est.
  date now, Done date at wrap.

## The unit is the spoke

Estimate at the spoke, not below it. An earlier practice split a brown-field
spoke into per-chunk estimates — a `rope:` row with `· r:<name>` members, or
numbered rungs — to test whether the pieces became estimable once the layer was
open. The per-piece machinery cost more than the calibration it bought, and the
boundaries kept shifting as the work revealed itself. So a spoke gets one
estimate, quoted with the two-halves method below, and the scoreboard records
the Actual against the whole spoke.

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

## The third half: bringing the spec to rebuild grade

When the code works and the design is about to be distilled, the
`executor/` still has to reach the bar a fresh session could rebuild the
domain from: the wire contract pinned, every setting named, the tables
listed, a glossary and a reading order, and a plain narrative of what the
service is for. That is authoring, not discovery, so it sizes well and
holds no surprises. It also comes due at a predictable moment, the
milestone consistency pass, and is easy to leave out of an estimate
because it is not on the design's Plan lines. Name it as its own line
item when scoping, on the order of a tenth of the point. For a service
the size of FIS it was about an hour for a hub and three spokes. When it
shows up in the Actual, it is this beat, not the discovery tail.

## Notes

Dated analyses, most recent first. The table in each is the state of the
scoreboard that day; "Before you estimate" carries the current reading.

### 2026-10-09 — hit rate on the finished rows

| | count |
| --- | --- |
| finished rows with an interval | 39 |
| in interval | 19 (49%) |
| under the low bound | 15 |
| over the high bound | 5 |

Excluded: dac-output and the sim-green rope row, which carry no interval.

The unders are routinely half the point or less: mtls-fis-auth 11.5h
against a 20h floor, alert-manager 1.5h against 4h, sasl-mechanism-plugin
1.25h against 3h, regenesis 2.25h against 4.5h. The overs are the
brown-field spokes that opened a layer: sema-round-2 20.4h against a 12h
ceiling, krida-retirement 15h against 12h, pico-cycler-command 9.6h
against 8h, the semafy pilot 9.5h against 9h. Reading: the point is
inflated for build-out work and the low bound follows it; the high bound
is about right except where a sema word or a board is touched.
