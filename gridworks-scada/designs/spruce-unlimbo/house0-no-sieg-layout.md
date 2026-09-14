# House0 no-sieg layout (spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-392

> What this is: authoring the `gw.house0.no.sieg` layout word and its three
> generators (oak, fir, elm) so the sieg-less House0 family can be deployed
> this fall. A launch item: three of the six boxes are this family, and the
> branch cannot go onto them without the word.

## The family

There are three in-field layout families, not two. `gw.house0.layout` now
MEANS has-a-siegenthaler-loop (maple, beech); `gw.nolan.layout` is spruce;
and **oak, fir, and elm** are the sieg-less House0 topology — the same core
plant as House0 with no siegenthaler loop: no sieg-loop actor, no
`sieg-cold` / `sieg-flow` / `sieg-flow-hz` sensing, no hp-loop valve relays.
They need their own word, `gw.house0.no.sieg`, before they can be
sema-authored.

A sieg loop is a topology change (family), not a variant. Whether the loop
is *used* is an operational param (`UseSiegLoop`, migrating layout → ops);
having the loop at all is the family split. Today's `gw.house0` test fixture
carries `UseSiegLoop: false`, so it has been quietly modeling this family and
likely becomes its fixture when the word is authored.

## The sema word

`gw.house0.no.sieg` is authored as a flat word (sema words do not inherit —
every field is spelled out): take the `gw.house0.layout` schema and remove
the sieg surface. Concretely, relative to House0:

- Drop the sieg-loop actor node and its command-tree membership.
- Drop `sieg-cold`, `sieg-flow`, `sieg-flow-hz` from `RequiredSensing`
  (and any `DerivedSiegSum`).
- Drop the hp-loop valve relays from `RequiredActuators`.
- Keep everything else House0 has — including `store-pump-relay`, which is
  an every-hydronic-plant name, not per-family.

The word-gate sitting decides the exact axiom set (mirror House0's tiers
minus the sieg clauses). This should be light: the shape is House0 with a
known slice deleted, not a new design. Follow the sema authoring gate before
touching the registry — read the registry/authoring spokes for the kind
being touched and post the read-receipt summary first; the spec itself is
change-controlled and this adds a word, so the addition is discussed before
the edit.

The `gw.house0` word's sieg-unconditional tightening waits on this word: once
`gw.house0.no.sieg` exists to carry the sieg-less homes, House0 can require
the sieg surface unconditionally.

## The generators

Convention is `<house>_gen.py` in `tlayouts/`, with the pre-partition
sources preserved as `old_gen_<house>.py`. Three generators emit this
family:

- `oak_gen.py` — **already exists** and must be repointed to
  `gw.house0.no.sieg` (it cannot emit `gw.house0.layout`, which now means
  has-a-sieg-loop).
- `fir_gen.py`, `elm_gen.py` — to be written, from `old_gen_fir.py` /
  `old_gen_elm.py` as the sources to translate.

The stub `tlayouts/house0_no_sieg_sema_gen.py` (raises `NotImplementedError`)
marks the seam: it becomes the real family generator following the
`oak_gen.py` / `spruce_gen.py` worked pattern, and the three per-home gens
build on it. Each gen's output validates via `sema validate` and loads a
scada suite green against the emitted instance; a sim pair ships in the same
wave as the word (the standing rule).

The two simplified-manifold installs in this family remove the iso valve and
buffer tank; the third is a cement store-under-floor with no water tanks.
Nothing above the family tier may assume a buffer tank, an iso valve, or
`total_store_tanks ≥ 1` — the physical-detail gathering for each install
(heat pump model, manifold, slab charge/sense) continues in the
spruce-settled fall-layouts work (OPS-532); this spoke owns the word and the
generators.

## Done when

- `gw.house0.no.sieg` is authored (staging), axioms mirrored, `sema validate`
  green on a fixture.
- `oak_gen.py`, `fir_gen.py`, `elm_gen.py` emit their layouts; each output
  validates and loads a scada suite green.
- The no-sieg sim pair exists and both contract tests pass on it.
- The `gw.house0` sieg-unconditional tightening lands on top.

## Open

- The simulated fourth layout of the fall set — whether it is this family or
  `gw1.simple.sim.layout` — stays with OPS-532.
- Real oak/fir/elm instance filenames (distinct from the fixture).
