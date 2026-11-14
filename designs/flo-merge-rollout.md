# FLO merge rollout

Status: Draft · Pass 0 · Updated 2026-11-14 (step 1 and step 2.1 done) · Linear: OPS-665 (cap-8; no issue of its own until a slot opens)

**EDD: no** build-out and rollout; each step is verified by the repo's CI
gate and the live check named in the step.

> What this is: the order in which Thomas's open work and the FLO-plot
> words merge in November 2026, agreed with Thomas at the 2026-11-13 team
> meeting. One small fix ships first, the scada house-parameter PR merges
> second to clear the path, the FLO-plot words merge third across six repos,
> and the FLO re-run Thomas built on the web backend becomes a developer
> tool in his own repo now and a request to the FLO service later.

## Why this order

The three pieces of open work touch the same files on the web backend
and cannot all merge as they stand:

- web-backend PR #28 `td/bruce-flo` (opened 2026-11-06) re-solves a FLO
  hour on the web box with the bruce optimizer installed from a sibling
  checkout, caches plots on disk, and adds a re-run with forced heat pump
  steps and penalty overrides.
- The `jm/flo-plot-words` branches (OPS-665) make the backend read the
  FLO service's published recommendation from the journal through the
  codec, with no optimizer on the web box.
- scada PR #609 `td/new-house-params` and sema PR #37
  `td/houseparamslatest` change the LTN's load model and the staging
  words `heating.curve` and `gw.operational.params`; beech and oak have
  run that scada branch since 2026-11-12.

The web box has a 6.8 GB root disk, 82% used after the 2026-11-14 reclaim
(the poetry cache and the disabled snap revisions removed, snap retain set
to 2). Its api service logs every SQL statement to the journal, about
6,600 lines an hour, so the one-line fix that stops it goes first.

## Steps

### 1. The SQL echo fix

Cherry-pick web-backend commit `4dcd5d4a` ("Stop printing every SQL
command", one line in `api/v2/dependencies.py`) onto a `jm/` branch from
`main`, run `ci.sh`, open the PR, merge. Deploy to web-api2 the committed
way: pull `main` in the `ubuntu/gridworks-web-backend` checkout, then
`sudo systemctl restart gridworks-api gridworks-gateway` (the README's
recipe). Check: `journalctl -u gridworks-api` shows no SQL text.

### 2. Merge the house parameters

sema first, then scada, then the layouts, then the fleet.

1. **sema #37 → `dev`.** `heating.curve` 000 and `gw.operational.params`
   000 are `staging`, edited in place, which is right, and the branch
   moves each word's `created` forward to the revision's time, as the
   spec requires for a staging word (`registry/structure.md`). Before
   merge: `dev` has since revised `gw.operational.params` 000 again
   (2026-11-13), so the merge of `dev` into the branch moves both stamps
   forward to the merge's own time, and the indexes are regenerated and
   the suite run inside the branch's checkout. Jessica reviews; Thomas
   merges.
2. **scada #609 → `main`.** Jessica opens the final PR from the branch
   with Thomas's agreement (asked 2026-11-13). Before merge:
   - the temporary per-tick logs (`013e868f`) are already removed by
     `60a91049` on the branch, so no history rewrite is needed; commits go
     straight onto `td/new-house-params` with Thomas's agreement, never a
     force-push, so beech and oak fast-forward at the next pull;
   - keep commit `7b6b6a75`, the fix the logs found: the multipurpose
     sensor forwards its channels that feed a derived channel to the
     derived generator as a second `SyncedReadings` message, so
     `dist-swt` and `dist-rwt` reach the rolling distribution energy;
   - add the test that fix lacks: SWT and RWT through a multipurpose
     sensor, flow through the power meter, a nonzero rolling energy;
   - resolve the three `TODO`s in `flo_request.py` into Linear or into
     the code (solar fixed at 0, the radiator exponent and minimum RSWT
     as module constants);
   - regenerate the scada snapshot from sema `dev` after step 2.1 so the
     snapshot is generated, not hand-edited to match;
   - `ci.sh` green.
3. **tlayouts `td/new-house-params` → `main`**, 14 commits, the gens and
   outputs the scada branch pairs with. Merge after the scada PR so the
   pair is whole on `main`.
4. **Roll the fleet to `main`** with `scripts/roll.sh <house> to main`:
   beech and oak off the branch; fir, elm and spruce are one commit
   behind `main` and move to the tip; maple stays on
   `jm/sieg-init-homing` until that work is done. The compare at each
   roll is read, every field.

### 3. Merge the FLO-plot words

The design under OPS-665 names the branches and the order; its gate was
Thomas's yes on 2026-11-13. The order is dependency order:

1. optimal-flexibility #4 `jm/flo-plot-words`, rebased onto thdfw `main`
   (two-head edges, the RSWT penalty and params changes merged
   2026-11-10 to 2026-11-13); `path_words` rewritten over
   `graph.rollout`; `test_recommend.py`; the matrix rebuilt in its new
   form for the laptop and the flo box.
2. gridworks-flo `jm/flo-plot-words`; the flo box then pulls both.
3. gridworks-journalkeeper `jm/flo-plot-words`.
4. gridworks-scada `jm/flo-plot-words` (snapshot, twins, the LTN's
   `flo.previous.run`), after step 2 so it rebases cleanly.
5. gridworks-web-backend `jm/flo-plot-words`; web-api2 pulls and
   restarts.
6. gridworks-web-frontend `jm/flo-plot-words`; Pages deploys `main`.
7. web-backend #28 closes without merging, with a comment naming step 4
   as where its re-run lives on. The frontend branch `td/dev` is Thomas's
   to delete.

Check: the OPS-665 design's verification, a fleet LTN running at 001 and
the visualizer drawing the hour from the word on `tsdb_tap`.

### 4. The re-run as a developer tool in optimal-flexibility

What #28 built that the words do not replace is the re-run: solve an
hour again from its `flo.params` with the penalty tuning changed and
heat pump steps forced on or off, and look at the plot. It is the
optimizer author's inspection tool, and it moves into Thomas's repo so
Thomas and George both have it on a laptop with nothing installed on the
web box:

- `scripts/run_flo_plot.py` and the re-run functions
  (`with_penalty_tuning`, the forced-step handling) move from the
  web-backend branch into `optimal-flexibility`, beside `flo_params.py`.
- Its input is a `flo.params` word as JSON. The backend endpoint
  `/api/v2/installations/{id}/flo.params?time=` from step 3 serves
  exactly that for any house and hour, so the tool needs no database
  login: fetch the word, run the tool, read the plot.
- The tool parses the word through `bruce.sema`, not a hand twin
  (main's `flo_params.py` hand-twins three words today; raised with
  Thomas, his to fix).

Thomas owns this step; the move is offered with the #28 close.

### 5. Later: the re-run as a request to the FLO service

The dashboard version of step 4 is its own design, after step 3 ships.
Sketch, so the thinking is not lost:

- The backend's re-run endpoint builds a modified `flo.params` (tuning
  overrides, forced steps) and sends it over the broker to a FLO
  service, which answers `flo.recommendation` 001 with the store and
  penalty words. The browser draws the answer with the same `FloPlot`.
- Forced steps need a field on `flo.params` or its tuning word: a sema
  question for Thomas before any code.
- On the laptop the target is the dev broker and a local FLO with bruce.
  In production the endpoint is off unless a settings value names a
  re-run broker, so the web box still has no optimizer.
- It is a feature, not a refactor, and it waits for a Linear slot under
  the cap.

## Done so far

- Step 1: web-backend PR #30 merged 2026-11-14 and deployed to web-api2;
  the api journal has no SQL text.
- Step 2.1: sema PR #37 merged to `dev` 2026-11-14 with the review fixes
  (`3f98f67`): both words restamped at the merge, the regression model
  named in the description, `RhoTimes100` positive, axioms 1 and 2 on the
  anchors with mutation tests. OPS-668 (the two-word split) is postponed
  to after step 3; its design records the two kept axioms and the absent
  `MaxEwtF` one.

## Do this next

Step 2.2: scada #609, committing on `td/new-house-params`. Regenerate the
scada snapshot from sema `dev` at `3f98f67`, update the hand-written
`heating_curve.py` twin with `check_axiom_1` and `check_axiom_2`, add the
multipurpose-sensor-to-derived-generator test, resolve the three
`flo_request.py` `TODO`s, run `ci.sh`.

## Open

- **web-api2's root disk.** 6.8 GB on a t3.medium, 82% used after the
  reclaim; apt's daily run failed for space on 2026-11-13. Two paths,
  undecided: grow the EBS volume to 20 GB (online: modify the volume,
  `growpart`, `resize2fs`), or move the box to Hetzner with the rest of
  the platform and size it there. The box has no `instance-README.md`
  in gridworks-infra, which is where either decision is recorded. The
  production-security design notes the same box needs the larger disk
  before its security pocket is applied.
