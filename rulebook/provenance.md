# Where this comes from

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: the traditions the executor recipe takes from, and
> what each contributed. Rationale for a reader of the recipe; a
> session building or checking an executor does not need it.

The traditions where two independent builds have to agree: IETF RFC
practice (normative keywords with stable IDs, conformance sections,
interoperability between independent implementations as the real
test); protocol and codec specs that ship test vectors; state machines
with invariants as AWS reports using them (Newcombe et al., CACM 2015);
Parnas's module guide (what each part hides and exposes). Knight and
Leveson (1986) showed independent builds from one spec fail together
where the spec is ambiguous. Commit0 (2024) found agents given spec
documents alone reproduce none of 54 libraries fully, and that vectors
and test feedback are what move them: the reason traces rank first and
rationale ranks last here. Spec-first tooling of 2025 (Spec Kit, Kiro)
is per-feature and goes stale on merge; the parts taken are stable
requirement IDs and one-condition-one-sentence phrasing. The table
shape is the CMCC rulebook's (Sturms), with the sema twist: the
authored files are the source and the rulebook a projection.
