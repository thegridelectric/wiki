# FLO merge rollout

Status: Draft · Pass 0 · Updated 2026-11-14 (steps 1, 2, 3 and the backend half of 4 done and deployed; #28 closed) · Linear: OPS-665 (cap-8; no issue of its own until a slot opens)

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
   - keep the fix the logs found (`57cec45d`, in `actors/scada.py`): a
     capturer the primary scada runs posts its readings to the derived
     generator itself, but one on scada2 cannot, so the primary posts the
     synced readings scada2 forwards it on to the generator when they
     feed a derived channel; `dist-swt` and `dist-rwt` are read on scada2
     at the installed houses, so without it the rolling distribution
     energy stayed at zero;
   - add the test that fix lacks: dist temps read on scada2, flow from
     the power meter, a nonzero rolling energy, and no double post for a
     capturer the primary runs (`tests/actors/test_dist_energy_from_scada2.py`);
   - the three `TODO`s in `flo_request.py` become notes: solar is zero
     until the weather forecast word has a solar field; the radiator
     exponent and minimum RSWT are module constants and candidate
     `heating.curve` fields if houses prove to differ;
   - regenerate the scada snapshot from sema `dev` after step 2.1 so the
     snapshot is generated, not hand-edited to match; the regen also
     brings `gw.market.product.name` 001 (`rt60gate1`) and the
     `latest.price` and `layout.lite` examples sema `dev` added, and the
     gwsproto enum twin follows to 001;
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

### 4. The re-run as a local developer tool, drawn by the visualizer

Status: Accepted · Pass 1 · Updated 2026-11-14

What #28 built that the words do not replace is the re-run: solve an
hour again from its `flo.params` with the penalty tuning changed and
heat pump steps forced on or off, and look at the plot. It is the
optimizer author's inspection tool. It becomes a feature of the dev
stack on a laptop: the visualizer's FLO view gains a re-run panel, a
local backend solves the re-run with bruce installed beside it, and the
browser draws the answer with the same `FloPlot` it draws the journaled
word with. Thomas and George run the backend and the frontend locally
against `tsdb_tap` for the house's journaled hours, and nothing changes
on the web box, which has no optimizer.

The seam is sema both ways:

- **Request.** `POST /api/v2/installations/{id}/flo.rerun` takes a
  `flo.params` word as its body: the hour's journaled word with its
  `Tuning` edited by the person. The browser builds it from the word the
  `flo.params` endpoint served, through the vendored `.d.ts`.
- **Answer.** The response is a `flo.recommendation` 001 word, so the
  store state and the penalties come back and `FloPlot` draws them with
  no new browser code.
- **Solving.** The backend decodes the body through its codec and calls
  `bruce.service.recommend`, in a thread, with the bruce package an
  optional dependency group (`rerun`) of the backend that only a laptop
  installs (`uv sync --group rerun`; a git source at optimal-flexibility
  `main`, since a path source breaks a box's sync when the sibling
  checkout is absent). The route is mounted only when a
  settings value turns it on (`BACKEND_FLO_RERUN=in-process`) and bruce
  imports; otherwise it answers 404 like any absent route, and the
  browser hides the panel when a probe of the route says so. Production
  never sets the value and never installs the extra.
- **The panel.** Beside the plot: the thirteen penalty fields of
  `flo.tuning.bruce` (the RSWT, short-cycle and stability penalties)
  prefilled from the hour's `Tuning`, a Re-run button, and the resulting
  plot in place of the journaled one with a "re-run" label; the journaled
  plot comes back with the hour arrows or a Reset.
- **Forced steps are phase 2, behind a sema word.** No word carries
  "heat pump forced on at steps 3 and 4" today; bruce's optimizer params
  already accept them. The ask to Thomas is concrete: make a sema word
  for this, a `flo.rerun.request` that wraps a `flo.params` with the
  forced-on and forced-off step lists (or, if he prefers, the two lists
  as fields of `flo.params` itself). Phase 1 ships the tuning re-run with
  the body a plain `flo.params`; phase 2 switches the body to the new
  word and adds the forced steps to the panel.

bruce caches one transition matrix per tank shape under
`~/.config/bruce/graph_optimizer` and builds a missing one only when
`CAN_COMPUTE_TRANSITION_MATRICES=true`; penalty tuning is not part of the
shape, so a re-run after the first is well under a second.

Checks: the suite in each repo; on the laptop, a journaled hour re-run
with unchanged tuning draws the journaled plot, and one with the
stability penalty off draws a different path; the web box answers 404 on
the route.

### 5. Later: the re-run over the broker

The production shape, after step 4: the backend's re-run endpoint sends
the `flo.params` over the broker to a FLO service and answers with its
`flo.recommendation`, so a hosted visualizer can re-run with no
optimizer on the web box. The endpoint's in-process solver and its
broker solver are two settings values of the same route. It is a
feature, and it waits for a Linear slot under the cap.

## Done so far

- Step 1: web-backend PR #30 merged 2026-11-14 and deployed to web-api2;
  the api journal has no SQL text.
- Step 2: sema PR #37 (`3f98f67`), scada PR #609 (`03ff59bb`) and
  tlayouts PR #5 (`6c315f5`) merged 2026-11-14; every layout regenerated
  (`3516263`). Beech, oak, fir and elm rolled to main, maple to
  `jm/sieg-init-homing` with main merged. OPS-668 (the two-word split) is
  postponed to after step 3.
- Step 3, repos 1 to 5: optimal-flexibility #4 (`f6c6530`), gridworks-flo
  #6 (`3cf9810`), journalkeeper #208, scada #620 (`ab3442ac`) and
  web-backend #31 (`1eb7fb6`) merged 2026-11-14, each with main merged in
  first. The flo box runs both merged mains since 15:03 EST and answers
  at 001. web-api2 runs backend `main` (`1eb7fb6`) since 15:23 EST, venv
  synced from the new lock (the optimizer dependency gone), both
  services active and the FLO routes mounted. Frontend PR #21 merged
  (`ef09c54`, 15:32 EST) and Pages deployed `main`.
- Step 3, the LTN check: for the 16:00 EST slot of 2026-11-14 both beech
  and oak sent `flo.params` 001, the FLO answered `flo.recommendation` 001
  (2 PQ pairs each), both bid, and at 16:00 each kept its cleared path,
  wrote a new-shape `previous_run.json` and published `flo.previous.run`
  000; the journal on `tsdb_tap` has every one of those words. Each LTN
  also receives the other house's recommendation and drops it ("Dropping
  a flo.recommendation for ... the request held is for ..."), one dropped
  message per house per hour: a fault, parked as a comment on OPS-665
  (the FLO should answer the LTN that asked).
- Step 3's verification: the visualizer on Pages draws beech's 17:00 EST
  hour of 2026-11-14 from the journaled 001 word, all three panels (the
  heat pump path against load and prices, the store state as a heat map
  with the state of charge from the store's empty and full references,
  and the penalties with the terminal cost), seen 17:04 EST.
- Step 4, the backend half: web-backend PR #32 (`9bac6f7`) merged
  2026-11-14 with the `rerun` dependency group, the `BACKEND_FLO_RERUN`
  setting, the `flo.rerun` route, six tests and the README recipe. The
  scada's stale-file fix is on main too (PR #621, `df2962b9`). web-backend
  #28 closed without merging, its comment pointing at this step.
- The deploy: web-api2 runs backend `main` at `7e8fc3a` (which includes
  `9bac6f7`), venv on numpy 2.5.4 and pandas 3.1.1, both services active,
  no api warnings since. Beech and oak run scada `main` at `7e8e52f4`
  (which includes `df2962b9`). Checked 2026-11-15.

## Do this next

1. **Step 4, the frontend panel** (the frontend claim is free): the
   thirteen penalty fields, Re-run, Reset, the probe that hides the panel
   when the route answers 404. Then the laptop check against `tsdb_tap`
   with `BACKEND_FLO_RERUN=in-process`.
2. **The dev-stack recipe** gets the re-run lines (the `rerun` group,
   `BACKEND_FLO_RERUN`, `CAN_COMPUTE_TRANSITION_MATRICES`); that file's
   claim is free too.
3. **Forced steps** wait on the `flo.rerun.request` word (step 4, phase 2).

## Open

- **The visualizer's hour arrow takes about 4 s per press** (seen 17:04
  EST 2026-11-14 on Pages against web-api2). Measured from the box: the
  access check and the slot lookup run under 10 ms each, the codec
  under 1 ms, the login check is a JWT parse, the box is idle. The api
  logs each FLO GET about 4 s after its CORS preflight, and a press's
  two FLO requests finish within 5 ms of each other, which points at a
  shared wait, not two slow queries. Neither the api log nor nginx
  records request duration. Next: split browser from server with the
  DevTools Network timing of one `flo.recommendation` request, or time
  the endpoint from the box with a short-lived token minted by the app's
  own code (asked; wait for the yes). After the rollout.

- **web-api2's root disk.** 6.8 GB on a t3.medium, 82% used after the
  reclaim; apt's daily run failed for space on 2026-11-13. Two paths,
  undecided: grow the EBS volume to 20 GB (online: modify the volume,
  `growpart`, `resize2fs`), or move the box to Hetzner with the rest of
  the platform and size it there. The box has no `instance-README.md`
  in gridworks-infra, which is where either decision is recorded. The
  production-security design notes the same box needs the larger disk
  before its security pocket is applied.
