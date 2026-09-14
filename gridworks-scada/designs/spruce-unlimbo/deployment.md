# Fleet deployment (spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-392

> What this is: the actual rollout of `jm/spruce-unlimbo` onto the six
> production boxes as `main` before the heating season — the ordered box
> sequence, per-house verification, the rollback path if a box misbehaves,
> and the post-launch loop for updating a deployed layout or ops params
> through tlayouts. The launch is not done when the branch is good; it is
> done when every box runs it.

## Preconditions (the gates before the swap)

The branch does not become `main` until:

- Every launch spoke is green: the layout gens (`correct-house0.md`,
  `house0-no-sieg-layout.md`), the layout-word axioms
  (`layout-word-axioms.md`), the ops-word cleanup
  (`operational-params-cleanup.md`), pico requirements
  (`extra-pico-channels.md`), the sieg loop proven on new code
  (`refactor-sieg.md`), the Nolan control loop (`nolan-local-control.md`),
  strategy selection (`control-strategy-selection.md`), and the small items
  (`odds-and-ends.md`).
- `layout.lite/013` is published with its closure (`finalize-layout-lite-13.md`)
  — spruce cannot connect on the production broker until the word it sends on
  link-up is published.
- The commits `main` took after the branch point are each carried or
  dismissed (`main-changes.md`).

## The swap

`jm/spruce-unlimbo` replaces `main`. Every deployed box holds a full clone
(never shallow/single-branch) normally on `main`, so the swap is a fast-forward
of `main` to the branch tip, then each box pulls.

## Rollout order and mechanics

Prod boxes run committed code only: the only path onto a box is
land-in-git → push → pull on the box. No scp, no hand-edits — a hand-deploy
dirties the tree and blocks the next pull. Non-repo box state (a sudoers
drop-in, a `.bashrc` line) is recorded in the box's instance-README, not
pushed.

Roll out one family at a time, the already-proven box first, so a fault is
caught on the box already running the branch before it reaches the boxes that
are not:

1. **spruce** (`gw.nolan.layout`) — already runs the branch through the
   experiment window; it becomes the standing deployed line. Verify the Nolan
   control loop carries a real heating-season cycle, not the summer hack.
2. **maple, beech** (`gw.house0.layout`, sieg) — the sieg loop must have run
   on the new code first (`refactor-sieg.md`). Verify per box: heat call →
   dist flow + pump power, the sieg leg reaching ready.
3. **oak, fir, elm** (`gw.house0.no.sieg`) — the last family authored; verify
   each with no assumption of a buffer tank, iso valve, or water store tanks.

Per box: pull to the pushed SHA, restart the scada service, then watch
(`gwa watch <house>`) for a clean boot, layout+ops decode without crash, and
the expected relay/pump posture before moving on. A box off `main` after the
swap is a deviation the platform-drift check surfaces.

## Rollback

Each box carries a full clone, so a box can be checked out onto the prior
`main` SHA or a `jm/<hotfix>` branch and restarted — the same
pull-restart mechanics in reverse. Capture, before the swap:

- The prior `main` SHA per box (the known-good to return to).
- The prior deployed layout + ops artifacts (kept as dated
  `*.pre-<change>.json` copies beside the live files, byte-identical to their
  tlayouts gen output).

If a box misbehaves after its pull: check out the prior SHA on that box,
restart, confirm it returns to the known-good posture, and leave the fleet
partially rolled rather than forcing a bad line onto the rest. A single
misbehaving family does not block rolling back just that family.

## Post-launch: updating a deployed layout or ops params

After launch, a layout or ops change is not a hand-edit on the box. It goes
through tlayouts, regenerating from the currently-deployed shape:

1. Edit the box's generator (`<house>_gen.py`) or the ops inputs; the gen
   reads the existing deployed layout + operational-params as its starting
   point so the update is a diff on the real deployed shape, not a rebuild
   from scratch.
2. Run the gen from the scada venv; leave a dated `*.pre-<change>.json` copy
   beside each edited artifact.
3. `sema validate` the emitted instance; refresh any vendored closure copy
   and run the conformance test if the layout closure moved.
4. For a word that changed status, promote bottom-up with `sema promote` and
   record it in the sema changelog.
5. Land in git, push, pull on the box, restart. The box's layout and ops
   files under `~/.config/gridworks/scada-experiment/` stay byte-identical to
   the tlayouts gen output.

The staging → published promotion of the full layout closure and the
operational-params pair, once the fleet runs them, is the spruce-settled
publish work (OPS-532); this spoke covers the deploy and update *mechanics*,
that spoke covers the word promotion.

## Done when

- All six boxes run the branch as `main`, each verified for its family.
- A rollback has been rehearsed at least once (a box returned to its prior
  SHA and posture) so the path is proven, not theoretical.
- One post-launch layout/ops update has gone through the tlayouts loop end to
  end on a real box.

## Open

- Whether the swap is one fleet-wide window or staged over several days.
- Who runs each box's pull — the box-runs-a-pushed-SHA guarantee holds either
  way, but the sequencing owner is unset.
