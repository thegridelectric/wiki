# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Newest at the top.

---

## 2026-05-21 — Establish ear as a top-level domain; spec the passive broker tap

**Why:** The ear (universal audit tap) was previously an implicit part of
the rabbit broker definitions with no home of its own. As we made the
gridworks-base topology code-generated and drift-proof, we had to decide
where the ear's audit `#`-fan-in lives and how it relates to production
isolation. Two decisions drove this note:

1. **Ear is a cross-cutting fundamental mechanism, not a sub-part of
   gridworks-base.** gridworks-base's generator merely *emits* the `ear_tx`
   exchange + `#` bindings; the ear's persistence/replay semantics span the
   whole system. So it earns a top-level `wiki/ear/` domain, peer to
   gridworks-base and the fleet-index-service.
2. **Production isolation:** the control broker should host only real-time
   grid-ops participants. Resolved by keeping `ear_tx` as a *passive*
   shovel source (near-zero cost with no consumer) and forwarding it via a
   shovel to a separate analytics broker where journalkeeper self-
   provisions — so no analytics entity ever connects to the control broker.
   The shovel + analytics broker are out of gwbase's generator scope.
