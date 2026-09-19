# Fleet deployment (spoke)

Status: Draft · Pass 0 · Updated 2026-09-18 · Linear: OPS-392

> What this is: the actual rollout of `jm/spruce-unlimbo` onto the six
> production boxes as `main` before the heating season — the ordered box
> sequence, per-house verification, the rollback path if a box misbehaves,
> and the post-launch loop for updating a deployed layout or ops params
> through tlayouts. The launch is not done when the branch is good; it is
> done when every box runs it.

## Preconditions (the gates before the swap)

The branch does not become `main` until:

- Every launch spoke is green: the layout gens (OPS-539, done;
  `house0-no-sieg-layout.md`), the layout-word axioms
  (`layout-word-axioms.md`), the ops-word cleanup
  (`operational-params-cleanup.md`), the sieg loop proven on new code
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

## tlayouts on GitHub is the interim record

Until the terminal-asset registry exists
(Stand up TAR, [OPS-471](https://linear.app/gridworks/issue/OPS-471);
this section is step 1 of that design's path to the registry), the record of
every house's layout and operational params is the tlayouts repo on GitHub:
the generators and the JSON they emit, committed together. A generator and
its JSON cannot be two authorities if a check holds them equal. Today
neither half holds: `output/` is gitignored, so no deployed layout is in
git at all, and `jm/spruce` has run many commits ahead of its remote, so
the generators behind the deployed files have lived on one laptop.

The cleanup, before the fleet swap:

1. **The JSON is committed.** `output/<house>/` for the six houses and the
   sim pairs comes out of `.gitignore`. The strays in `output/`
   (`*.generated.json`, `*.uploaded.json`, one-off experiments) are deleted
   or stay ignored; only the per-house directories are the record.
2. **A drift test holds JSON to generator.** tlayouts gets a `ci.sh` and a
   GitHub Action that re-run every gen and fail unless the output is
   byte-identical to the committed JSON and decodes through the vendored
   snapshot. The gens import `gwsproto.names`, so the job installs the scada
   protocol package at a pinned SHA; that dependency goes away when names
   live in sema.
3. **A box takes its files only from GitHub.** Each box holds a full tlayouts
   clone. One script on the box pulls, checks that the checkout is clean
   and on a pushed SHA, validates the pair, leaves the dated
   `*.pre-<change>.json` copies, installs the two files, and prints the
   SHA. Nothing is copied to a box from a laptop, which is the enforcement:
   a change that was never pushed cannot reach a house. This is the
   prod-boxes-run-committed-code rule applied to layouts.
4. **The scada reports what it runs.** The tlayouts SHA (or a checksum of
   each file) rides the scada's link-up report, so what a house runs is
   read from the house and compared with the repo, not inferred.

**Until step 3, `experiments/put_layout.sh` is the path onto a box**, and
only for the experiment-window files
(`~/.config/gridworks/scada-experiment/hardware-layout.json` and
`operational-params.json`): it copies the laptop's `output/<house>/` pair
over them, keeps the dated previous copy, verifies sha256 and refuses
while a window runs. spruce, beech and maple hold the 2026-09-18 output
this way. spruce and beech have the rest of a window setup
(`~/gridworks-scada-unlimbo`, `~/envs/dev.env`); maple has neither, so
its pair waits for a checkout and an env. It is a laptop copy of ungitted JSON, which steps 1 and 3
retire; the box's pull script takes over its checks.

**Committing the JSON also gives minted ids their home.** The spruce,
beech and maple gens take ids from the pi's deployed layout, then from
their own previous output, then mint
(`wiki/tlayouts/executor/primary.md` "Invariants"). With `output/`
ignored, an id minted for a name the pi lacks lives on one laptop and on
the box it was put to; a gen run from a fresh clone would mint it again.
Step 1 closes that. elm, fir and oak take the same reference before
their layouts go to a box.

**The LTN parameter API is the first step past this.** Operational params
change far more often than layouts, and the LTN API for adjusting house
parameters is needed anyway
([OPS-531](https://linear.app/gridworks/issue/OPS-531): one acceptance
path, an in-force set with its id, reconciliation on scada boot). Ops move
onto that path first, reading their starting instance from this repo;
layouts follow on the same exchange ("The next design" below); the
registry then replaces the repo as the store behind the LTN.

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
5. Commit the gen and its JSON together, push, run the box's pull script,
   restart. The box's layout and ops files under
   `~/.config/gridworks/scada-experiment/` stay byte-identical to the
   committed tlayouts output.

The staging → published promotion of the full layout closure and the
operational-params pair, once the fleet runs them, is the spruce-settled
publish work (OPS-532); this spoke covers the deploy and update *mechanics*,
that spoke covers the word promotion.

## The next design: layouts and params through the LTN

The tlayouts loop above is a stepping stone. The destination is an LTN
surface that accepts an updated layout or operational-params artifact from
an appropriately credentialed web page and delivers it to the scada, with no
engineer on the box. Its home is the LTN-brokered app-comms design
([OPS-408](https://linear.app/gridworks/issue/OPS-408)), which already owns
mode and control-parameter changes from a web frontend through the LTN and
gains the layout artifact as a third kind of update when that design
resumes; it is drafted here so the interim loop is built pointing at it.

**Target shape.** The web page posts a whole artifact to the LTN's HTTPS
surface (the named foreign-contract exception to writes-ride-rabbit, since a
browser has no broker; `api-pattern.md`). The LTN validates it through the
sema word, checks the pair (`APPROVED_PAIRS`, the same check the scada
runs), keeps the prior version, and sends the scada a layout-update or
ops-update command over the broker. The scada validates again, writes the
local JSON, applies live what can apply live and reports restart-required
for the rest (`control-strategy-selection.md` "Open", live ops updates),
and acks with the version it now runs. Who may post is OPS-408's identity
question (customer or fleet-owner credential, per-home authorization),
distinct from operator certs.

**Harmonize with OPS-531 first.** Two designs already describe an LTN
API for house parameters:
[OPS-408](https://linear.app/gridworks/issue/OPS-408) (mode, control
params and homeowner setpoints from a web frontend, brokered by the LTN)
and [OPS-531](https://linear.app/gridworks/issue/OPS-531)
(ltn-automated-house-params: the fitted thermal parameter set beside the
layout, an in-force set the LTN pushes to the scada with reconciliation
on boot, operator changes through the LTN's HTTPS API, with the rule that
the LTN is the only writer to the scada). The layout artifact is a third
thing that wants the same path. Before drafting the update surface, read
both and settle one path: one HTTPS surface, one identity model, one
LTN-to-scada "in-force artifact" exchange that carries a whole set with
its id, for params and layouts alike. Whether the layout rides OPS-531's
in-force word pattern or OPS-408's param-update command is the decision;
two mechanisms for what is one shape is the outcome to avoid.

**Direction checks the tlayouts loop must already satisfy.** Each is a
property the LTN path needs, so building the interim loop without it means
rebuilding it:

1. The box only ever runs a sema-validated pair; the validator the loop
   runs by hand is the one the LTN will run.
2. An update is a whole artifact (layout, or ops), never a field edit on
   the box. The scada decodes it by `TypeName`, never by filename.
3. The prior artifact is kept beside the new one (`*.pre-<change>.json`
   today; the LTN's version history later) and the rollback is "run the
   prior one", the same on both paths.
4. Authoring runs off the box: the generators are the authoring tool and
   the box is a consumer. Nothing in the loop assumes a venv or a generator
   on the box.
5. Apply semantics are declared per field: which ops fields apply without
   a restart, which need one, which are refused live (the strategy
   selectors). The interim loop restarts for everything; the declaration is
   what lets the LTN path stop doing so.
6. The change is recorded where the LTN will record it: the version the
   box runs is reportable (the ack carries it), not inferred from a file
   mtime.

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
- The tlayouts cleanup's details: whether the box script installs copies or
  symlinks into the clone; whether tlayouts `main` or `jm/spruce` is what
  boxes track; whether the drift test also runs as a pre-push hook on dev
  machines.
- Whether the layout artifact joins OPS-408's scope as written, or the LTN
  update surface becomes its own cross-cutting design that OPS-408's
  param-update rides on.
