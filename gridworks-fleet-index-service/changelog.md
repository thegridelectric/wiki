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

## 2026-05-20 — Seed wiki project from gridworks-infra design content

**Why:** The FIS design material was living in `gridworks-infra/authority/
fleet-index-service/` (README + lifecycle), but `gridworks-infra` is an
operations playbook for production troubleshooting and provisioning — a
different function from the design/rebuild record. Splitting design intent
out into `wiki/gridworks-fleet-index-service/` (matching the code repo name)
keeps the playbook free of timeless design prose and gives FIS the standard
wiki triad: `changelog.md` (WHY) + `research/` (the planning/validation
cycles) + `executor/` (the faithful-rebuild spec, written once research
converges). The two source files moved verbatim into `research/` as
`design.md` and `lifecycle.md`; the infra copies were deleted with no
pointer left behind.
