# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-scada` code repo**. The matching git commit (in
`gridworks-scada`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-09 — ltn sends correct scada wrapped (`981f0939`)

**What:** Replace the five `Message(..., Dst="broadcast", ...)` publishes in
`gw_spaceheat/actors/ltn/ltn.py` with real proactor-peer addressing: `Bid` → the
MarketMaker (`Dst="mm"`); `FloNextHourPlans`, `Glitch`, and both
`FloParamsHouse0` sends → the scada (`Dst=self.scada.name`, i.e. `"s"`). Each
site carries a HACK comment to revert to a real `rjb` broadcast once the LTN is a
gwbase actor (it leaves the scada lexicon).

**Why:** `Dst="broadcast"` is a magic string the proactor turns into a wire
routing key with no valid GridWorks envelope, so a gwbase consumer
(JournalKeeper) drops it at parse — silent data loss (prod saw `broadcast.glitch`
/ `broadcast.flo-next-hour-plans`). Addressing a real peer makes a valid
`gw.<src>.to.<peer>.<type>` key that gwbase parses (tolerant short-form parse,
gridworks-base design `must-accept-current-ltn-messages`). `"mm"` is deliberately
the gwbase `RoutingClass.MarketMaker` token, so the key already matches the
new/future rabbit structure. Design `ltn-sends-gw-wrapped`, OPS-387; depends on
the gridworks-base parser change publishing.

## 2026-05-14 — Add back a much-pruned docs folder (`c05a7625`, merged `6734aa0f` / PR #562)

**What:** Restores a `docs/` folder to the scada repo with three focused,
hand-pruned documents — `docs/editor-setup.md` (109 lines),
`docs/provisioning.md` (257 lines), and `docs/tls.md` (123 lines). No code
changes; docs only. Authored 2026-05-07, merged to `dev` on 2026-05-14.

**Why:** The repo's earlier `docs/` had been removed; this brings back a
deliberately slimmed-down subset covering the three things a human setting
up scada actually needs — editor setup, device provisioning, and TLS — as
repo-standalone docs (a repo's own docs stand alone for a human and don't
reference the wiki). Curated-minimum rather than the full former tree.
