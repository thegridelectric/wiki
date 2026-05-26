# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Format:

```
## YYYY-MM-DD — <commit subject line>

**Why:** <the motivation — what problem, constraint, or decision drove
this change; what alternatives were considered; what this unblocks>
```

Newest at the top.

---

## 2026-05-24 — bootstrap wiki/gridworks-ltn/ at acceptable-minimum

**Why:** The journalkeeper-on-base-0.4.0 prod-broker integration test
(see `wiki/gridworks-journalkeeper/research/refactor-to-base-0.4.2.md`
Stage 5a) exposed the gap that LTN — a real production actor — had no
wiki domain at all. The LTN code lives under
`gridworks-scada/gw_spaceheat/actors/ltn/` and depends on the private
`gridworks-innovations/gridworks-flo/`, runs via tmux on the LTN host,
publishes on `amq.topic` (not the custom `*_tx` fabric), and uses
gwproactor as its framework. None of that was discoverable from a wiki
entry; future sessions touching journalkeeper / ear / scada-side
coordination needed a pointer. This bootstrap captures where the code
is today, how it runs in production, the cleanup work it likely needs
(Thomas's code, mostly), and the open decisions before a real rebuild
spec can be written (own repo vs stay in scada; `amq.topic` vs
`ear_tx`; gwbase vs gwproactor base). Acceptable-minimum on purpose —
the code stays the spec until the cleanup pass.
