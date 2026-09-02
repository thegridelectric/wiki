# platform-drift-corrector

Status: Draft · Pass 0 · Updated 2026-08-31 · Linear: OPS-515

**EDD: yes** verified by seeded drift on a real platform box: a clean
behind-main box auto-corrects and the Telegram alert arrives; a deliberately
dirtied tree is quarantined intact and its owner notified; a pinned box is
left alone.

> What this is: go one step beyond the session-start drift *check*
> (`wiki/tools/check-drift.sh`): automatically correct platform-box
> deviations from boxes-run-pushed-`main`, with Telegram notifications
> through the alert-manager. Platform boxes only — the fleet (scadas,
> LTNs) stays report-only. Target: Tier 1 live within a month.

## Policy (the org's branch invariant)

Three rules, independent of any repo's branching model:

1. Deployed boxes run the deployed branch (`main` unless pinned) at a
   pushed SHA, tree clean.
2. Nothing lands on `main` without a PR; `main` is protected in GitHub.
3. Nobody commits or edits on a deployed checkout. Test in dev; land in
   git; pull on the box.

A repo may keep a `dev` integration branch or not — that is the owner's
choice; the invariant is the three rules. The corrector enforces rule 1
mechanically, which makes rules 2–3 the path of least resistance: work
left on a box is quarantined, never lost, and never stays.

## Why now

- Reports alone don't change behavior: the drift check reported gjk's
  divergence for three days (2026-08-28→31) before a human dug in.
- Both developers currently develop on production branches, sometimes
  with dirty deployed trees. The 2026-08-29 alerts-box hand edit was a
  live test rig — evidence that correction must preserve work, and that
  a box that never stays dirty removes the incentive to test there.
- The habit fix should be an impartial machine with notifications, not
  recurring conversations.

## Tiers

- **Tier 1 — fully automatic.** Clean tree, on the declared branch,
  behind origin: `git pull --ff-only`, `uv sync --frozen`, restart the
  box's units, notify. Most real drift; completely safe.
- **Tier 2 — preserve, then correct.** Dirty tree or undeclared branch:
  move the WIP aside first (dated `git stash` or copy to
  `~/drift-quarantine/<date>/`), reset to the declared branch at origin,
  restart, notify loudly and personally with recovery instructions.
  Work is never destroyed; the box never stays dirty. Launches only
  after Tier 1 has run quietly for two weeks.
- **Never automatic.** Non-repo state (`.env`, sudoers, sshd), the
  systemd unit copies in `/etc` (root re-copies deliberately), and the
  fleet: scadas (auto-restarting heat control on a git trigger is an
  outage path) and LTNs until OPS-511 makes them units.

## Pin ledger

Deliberate deviations are declared, not fought: a per-box pin (file on
the box, or a column in `platform-inventory.md` the corrector reads)
naming the intended branch. A pinned box gets report-only treatment
against its declared branch. Live examples: `web-api2` on
`jds/tsdb_api` (tsdb migration), gjk's temporary rollback (2026-08-31).

## Notifications

Through the alert-manager (`POST /new-alert`, site_alias = box,
alert_alias = `drift-corrected` / `drift-quarantined`): Telegram with
acknowledgement, exercising the OPS-506 stack. Quarantine alerts name
the owner's WIP location and recovery command.

## Open

- Where the corrector runs: per-box systemd timer (no central
  credentials; each box corrects itself) vs. one central runner over
  ssh (single code path, sees everything). Leaning per-box timer with
  the laptop check as the independent witness.
- Trigger: schedule (hourly?) vs. push webhook; schedule is simpler and
  drift is not urgent on the minutes scale.
- Whether Tier 1's unit restart consults the running-process-vs-commit
  check the drift script already does, or restarts unconditionally.
- GitHub `main` protection for gridworks-alerts, gridworks-alert-manager,
  gridworks-web-backend, gridworks-data (rule 2 is not uniformly on).
- Relation to `check-drift.sh`: the check stays as the read-only
  laptop-side witness; the corrector reports what it did into the same
  channel.
