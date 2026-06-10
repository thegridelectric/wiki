# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-scada` code repo**. The matching git commit (in
`gridworks-scada`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-10 — OFI comment (`8a0e1689`)

**What:** Add an OFI comment in `gw_spaceheat/actors/sieg_loop.py`
`moving_to_hp_off_valve_position` pointing at OPS-400
`sieg-semantic-harmonization`. No behavior change.

**Why:** Flags in-code that, after `e6ba4f51`, control state `HpOff` no longer
uniquely determines valve posture (it branches on static `settings.system_mode`
with no disambiguating telemetry), and that default-when-off is per-heat-pump
(Maple Mitsubishi vs Beech LG) and not yet parameterized — so the next reader
sees the seam and the tracking issue without spelunking the changelog.

## 2026-06-10 — Open sieg valve in Standby (`e6ba4f51`, PR #570)

**What:** In `gw_spaceheat/actors/sieg_loop.py`, the transition into
`SiegControlState.HpOff` no longer hard-codes `moving_to_full_keep` (loop
CLOSED). It now routes through a new `moving_to_hp_off_valve_position(event)`
that branches on `self.settings.system_mode`: `Standby` → `moving_to_full_send`
(valve OPEN); anything else → `moving_to_full_keep` (CLOSED — heating-season
behavior unchanged). Authored + merged by Thomas.

**Why:** The simple sieg code keeps the loop closed whenever the heat pump is
off — correct for the heating season, wrong for summer/Standby (especially when
the valve is otherwise not moving). Maple sat in Standby with the loop closed
post-incident; the first action is putting the loop in full send. SiegLoop
learns posture from the **static startup config** `settings.system_mode` (env
`SCADA_SYSTEM_MODE`), so the new posture takes effect on the restart that
switches a SCADA to Standby (which also rebuilds the LocalControl tree). Design
`sieg-summer-posture`, OPS-395. Known OFI (`sieg-semantic-harmonization`,
OPS-400): control state `HpOff` no longer uniquely determines valve posture and
telemetry can't disambiguate (valve-state `SingleMachineState` still TODO); and
default-when-off is per-heat-pump (Maple Mitsubishi vs Beech LG), not yet
parameterized.

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
