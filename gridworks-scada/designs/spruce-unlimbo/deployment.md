# Fleet deployment (spoke)

Status: Draft · Pass 0 · Updated 2026-10-23 · Linear: OPS-392

> What this is: what happens when `jm/spruce-unlimbo` merges to `main`:
> the ordered box sequence, per-house verification, and the post-launch
> loop for updating a deployed layout or ops params through tlayouts.
> Running the branch under the box service before the merge, and the
> roll-forward and roll-back mechanics, are `finalize-layout-lite-13.md`
> "The branch under the service". The launch is not done when the branch
> is good; it is done when every box runs it.

## Preconditions (the gates before the swap)

The branch does not become `main` until:

- Every launch spoke is green: the layout gens (OPS-539, done), the
  layout-word axioms (`layout-word-axioms.md`), the ops-word cleanup
  (`operational-params-cleanup.md`), the sieg loop proven on new code
  (`basic-sieg.md`), the Nolan control loop (done),
  strategy selection (`control-strategy-selection.md`), and the small items
  (`odds-and-ends.md`).
- `layout.lite/013` is published with its closure (`finalize-layout-lite-13.md`)
  — spruce cannot connect on the production broker until the word it sends on
  link-up is published.
- The commits `main` took after the branch point are each carried or
  dismissed (`main-changes.md`).

## The first data catch

Before any box moves to `main`, three boxes run the branch on the
production broker for a day and the journal is checked to carry what they
send. The gates, the JournalKeeper release and the catch itself are
`first-data-catch.md`.

## The swap

`jm/spruce-unlimbo` replaces `main`. Every deployed box holds a full clone
(never shallow/single-branch) normally on `main`, so the swap is a fast-forward
of `main` to the branch tip, then each box pulls.

## Rollout order and mechanics

Prod boxes run committed code only: the only path onto a box is
land-in-git → push → pull on the box. No scp, no hand-edits; a hand-deploy
dirties the tree and blocks the next pull. Non-repo box state (a sudoers
drop-in, a `.bashrc` line) is recorded in the box's instance-README, not
pushed.

Two layout families: spruce on `gw.nolan.layout`, and every other house
on `gw.house0.layout`. Every House0 layout declares a sieg loop. The
houses without one installed (oak, fir) declare it on a pico that does
not exist, with its node and channels disabled and its relays wired to
nothing; sieg loops may yet be installed in every home, so the
declaration may end up true. A `gw.house0.no.sieg` word is not a launch
item.

The cutover runs house by house with `scripts/roll.sh <house> forward`
(2026-10-23): spruce first, already proven under the branch through the
experiment window, then oak, maple and fir, each watched for a clean boot
before the next. Beech is sick and waits. Elm is offline and is not in
this rollout: it leaves the House0 family with its Arctic heat pump and
stays on its current code until its own word exists.

The roll moves a house's pi and its LTN together, to one pushed SHA, with
the committed layout pair verified on both and the LTN restarted before
the scada. A house's second pi (scada2) is outside the roll: it stays on
its line and its file is not compared.

Per house: roll, then watch (`gwa watch <house>`) for a clean boot,
layout+ops decode without crash, and the expected relay/pump posture
before moving on. A box off `main` after the swap is a deviation the
platform-drift check surfaces.

## Rollback

A box rolls back the way it rolled forward: the roll script checks out
the matching scada and tlayouts branches at pushed SHAs, verifies the
box's layout against the committed JSON, and restarts the service
(`finalize-layout-lite-13.md` "The branch under the service"; the
executor once built). The winter hack on `actual-spruce` and `main`
elsewhere stay as the roll-back targets until the fleet has run `main`
through a heating-season stretch and the web backend and frontend show
the new data well. A single misbehaving family rolls back alone; the rest
of the fleet stays where it is.

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
5. Commit the gen and its JSON together, push, and roll the house
   (`scripts/roll.sh <house> to <branch>`), which installs the committed
   pair under `~/.config/gridworks/scada/` and restarts.

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
- One post-launch layout/ops update has gone through the tlayouts loop end to
  end on a real box.
- The house scadas and LTNs are off their internal password users and on
  cert plus FIS, one box at a time, each password user deleted as its box
  moves (on MQTT an explicit username and password outranks the cert name,
  so a live password user is a bypass of the gate). Until then the boxes
  stay on passwords: the broker chains `internal` before FIS, so the
  platform services authorize through FIS while the houses do not, and a
  password-side box is outside FIS's lease logic (no supersession of a
  second scada on one pi, no eviction by suspending its principal). The
  first move is a beta window: the window scada connects on proactor
  `v4.1.13+jm3`, whose upstream `client_id` is the per-process instance
  id, and FIS `auth_events` shows that uuid4 and the lease created on it.
  Then `ssl_cert_login` and the per-box flip (OPS-420 notch 4), and
  plaintext 5672 and 1883 close after the last password user goes.

## Open

- Whether the swap is one fleet-wide window or staged over several days.
- Who runs each box's pull — the box-runs-a-pushed-SHA guarantee holds either
  way, but the sequencing owner is unset.
- Whether the layout artifact joins OPS-408's scope as written, or the LTN
  update surface becomes its own cross-cutting design that OPS-408's
  param-update rides on.
