# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-pico` code repo**. The matching git commit (in
`gridworks-pico`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-09-22 — Retry the params post until the scada answers

**What.** In the two tank-module and two BTU-meter mains (and the
regenerated `provisioner.py`): `update_app_config()` returns whether the
scada answered and takes a `late` flag; `start()` keeps the result;
`main_loop()` posts again every `PARAMS_RETRY_S` while the link is up
until the scada has answered. A late answer that changes settings saves
the config and resets the pico. The tank module now sets
`needs_reconnect` on a failed params post, as the BTU meter already did.

**Why.** `start()` gives the link 10 s, then posts params once. On any
boot where the link takes longer, the post fails silently and nothing
posts again, so the scada never checks that pico's identity or sends the
layout's capture settings. At spruce this was about half of all boots
(`experiments/2026-09-19-spruce-pico-params/`). Branch `td/pico-easy-fixes`.
