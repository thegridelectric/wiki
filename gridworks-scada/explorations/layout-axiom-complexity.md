# Concern: `gw.nolan.layout` — axiom complexity vs LLM comprehension

Concerns from Jessica about the `gw.nolan.layout` Sema word, framed
in terms of how easily its complexity is comprehended by LLMs (and humans).
Moved here from `sema/docs/scada-layout-concerns.md` — these are SCADA-side
concerns about a particular Sema word, not part of the Sema specification
itself.

See also [[sema-style]] for the broader Sema/SCADA relationship.

---

## 1. Axiom correctness [OPEN]

**Question:** Can correctness be verified locally per axiom, or does it require
multi-axiom composition beyond current LLM reliability?

Sema layouts rely on multiple axioms that are largely orthogonal, each
governing a distinct surface (nodes, channels, components, configs). This
orthogonality is a strength: it keeps each rule simple and composable.
However, overall correctness emerges only when these axioms are jointly
satisfied.

In current LLM systems, reasoning over **1–2 constraints is reliable, 3–5 is
hard** but manageable when the constraints are well-aligned, and beyond that
correctness degrades unless the structure is highly regular and orthogonal.
This is not a theoretical limit, but a practical constraint of present-day
models.

The primary risk is not whether an LLM (or human) can apply a single axiom
correctly, but whether it can detect inconsistencies across multiple axioms
that must hold simultaneously.

**Risk mitigation:** Correctness should be verified using multi-pass methods
rather than single-pass reasoning. This involves independently materializing
relevant sets (ShNodes, DataChannels, Component configs), evaluating each
axiom in isolation, and then explicitly checking their intersections.
Agent-based or tool-assisted approaches (e.g., code-crawling or
constraint-checking agents) can support this by iterating over the layout and
re-checking constraints across passes. Introducing controlled variation (such
as different traversal orders or decompositions) can help surface
inconsistencies that a single pass may miss. Compared to crawling SCADA code
directly, this approach is likely to be more effective: the axioms present a
normalized, declarative surface, whereas the code embeds the same constraints
implicitly across control flow, making global consistency harder to detect.

## 2. Channel existence vs production separation [OPEN]

The current system requires:

- existence axioms
- bijection axioms
- capture consistency axioms

**Risk:** correctness depends on three independent constraints aligning;
failure modes may be subtle.

**Response:** This is a question to address as we move to greater scale. We
may want to be ready for changing layouts in a one-off way without violating
the topology constraint — for example, if we want to be able to
interchangeably use a flow meter on its own or a BTU meter. Perhaps the thing
to converge on is default instruments and the [...]
*(original note trails off here; pick up when revisiting.)*

## 3. Heavy reliance on naming conventions [ANSWERED]

Encoding semantics via string patterns such as:

```
"zone{i}-{label}-..."
"tank{i}-depth{j}"
```

makes string patterns the **semantic authority**. Why are we doing this
instead of using structured fields?

**Answer:** Avoiding nesting allows for easier locking-in to the implicit
context. When backed by the Sema-based axioms this works well. It is a
model-theoretic approach.

## 4. GlobalIdUniqueness across domains [ANSWERED]

The UUID identifiers do not overlap, even across different types of objects.
This is stronger than most production systems.

**Answer:** A shared UUID raises a flag for LLMs and humans that there is some
unknown implicit axiomatic link. That doesn't happen with integer IDs —
sharing the ID `10` is a high-probability event. This is especially true with
our semantic encoding of meaning in names: in that context, a shared UUID
raises a sharp flag since it is a zero-probability event without semantic
coupling.

For example, many channels and nodes have the same *name* (e.g.,
`tank1-depth1`) and that does indeed have a semantic connection behind it —
the shared name is doing the coupling work, so the IDs are free to stay
globally unique.

## 5. Closure clauses may be brittle [ANSWERED]

We may want to add more names. For example, what if we want more depth
sensors per tank?

**Answer:** That would require a code change. What we are doing in the axioms
is codifying what the runtime code already depends on implicitly.
