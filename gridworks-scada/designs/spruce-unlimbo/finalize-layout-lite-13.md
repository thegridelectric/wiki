# Finalize `layout.lite/013` (spoke)

Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: OPS-392

> What this is: the spoke that takes `layout.lite/013` from staging to
> published with the JournalKeeper digesting it, so a scada on
> `jm/spruce-unlimbo` can connect to the production broker, and gives
> the LTNs what they need once the word stops sending them operational
> parameters. The segment after the LTNs run on the new code is
> `ltns-ready.md`; the merge to `main` is `deployment.md`.

## Do this next

**Next move:** the fleet cutover is under way (2026-10-23 night): spruce and
maple run `jm/spruce-unlimbo` on both halves; oak rolled forward at 01:42 ET
and back to `td/generalized-flo` at ~03:07; fir is next, beech waits (sick),
elm is offline. Before the next boot on the branch, fix OPS-619: the sieg
loop's own atomic report for a strategy-chosen move has no event and the
journal refuses the whole report.event (oak 01:45, maple 03:15). Then step 3,
the LTN harness mode.

1. ✅ Every LTN on the `ltn` box has `LTN_HA1_PARAMS` in its `.env`
   (2026-10-22): each house's value is the `Ha1Params` of the last
   `layout.lite` its scada sent to the journal (011 for the five
   House0 houses, 012 for spruce; elm's dates from 2026-08-16, its
   last boot), and each parses as `Ha1Params` in the checkout's venv.
   Still owed: the `.env` line is non-repo box state and belongs in
   `gridworks-infra/ltn/README.md` (the repo was mid-edit on `main`
   when this went in); and `roll.sh` could refuse to roll an LTN whose
   `.env` lacks the line, since no FLO runs without it.
   A `layout.lite/013` instance built offline from the committed
   `jm/spruce` pair by the scada's own builder (`layout_lite` in
   `actors/scada.py`), `sema validate` clean, is at
   `scratch/hw1.isone.me.versant.keene.spruce.scada-layout.lite-013.json`
   for the journal work (OPS-473). Building it showed that tlayouts
   reused a channel's id across a telemetry change (23 water
   temperature channels, `WaterTempCTimes1000` to `CelsiusTimes100`);
   tlayouts now keys a data channel's id on name and telemetry, and the
   spruce layout is regenerated with fresh ids for those 23.
2. ✅ The reality check (2026-10-23, 00:52–01:01 ET). `roll.sh spruce to
   jm/spruce-unlimbo` moved the pi and the LTN to `044b0eef` and
   installed the committed `jm/spruce` layout on the pi (byte-identical
   to tlayouts `origin/jm/spruce`). The scada ran 00:57:39–00:58:24,
   linked to the LTN in six seconds, and the journal took the 013
   `layout.lite` (twice: the boot broadcast and the reply to the LTN's
   request), the `gw.scada.commit`, a `gw.house.operating.status` and
   four `unserved-post` warning glitches; no report.event. The layouts
   projection moved from 012 to 013 and `reading_channels` keyed all 89
   data channels by the layout's channel Id (89 active, 44 of the old
   rows deactivated; 2 derived rows added) and added 38 `gjk.pseudo`
   rows, one per declared machine, named `<node>-state`. Started for
   good at 00:59:32; the 01:00 `report.event` (version 004, 79
   channels, 38 states) digested into 276 readings over 119 channels
   within three minutes. Three machine rows do not follow the
   `<node>-state` naming from the declaration (`auto`, `la`, `lc` map
   to `top`, `ltn-buffer-only`, `local-control-top`); whether that is
   the journal's intended display naming is a JournalKeeper question
   (OPS-618).
   Found on the way, all roll-script matters: the pi unit-file check
   matched the ltn unit (fixed, pending commit); the install prompt
   needs a tty or a piped `yes`; and the roll does not touch the LTN's
   own layout pair under `~/ltn-<house>/.config/gridworks/ltn/`, which
   the branch's LTN loads through `load_layout` and rejects when it is
   not sema-authored (the spruce LTN crash-looped until the committed
   pair was copied in by hand). A roll to this branch owes the LTN the
   same pair it gives the pi.
3. The LTN harness mode (start for one hour at N watts, start for no
   energy, terminate), with a test: it sends a `SlowDispatchContract`
   with no FLO and no `Ha1Params`, and is what the branch runs against
   until the generalized FLO merges. The commands reach the LTN as a
   staging admin word sent over the broker, the shape of the scada's
   admin words. Then roll spruce, both halves, to the branch and leave
   it.
4. Couple the fleet-drift hook to the line a house runs: a scada-branch
   column in `gridworks-infra/fleet-inventory.md` that `roll.sh` writes
   and `wiki/tools/check-fleet-drift.sh` reads, in place of its
   per-house constants, which report a rolled house as drift until
   edited.
5. Distill into `executor/`, move what is still open into
   `ltns-ready.md`, delete this file.

## Open

- Seam findings sweep to OPS-622's comb-through and nowhere else; the
  stage 1 additions to `layout.lite` 013 that OPS-622 specifies ship
  here before 013 publishes.
