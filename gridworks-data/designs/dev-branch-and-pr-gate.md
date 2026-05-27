# dev-branch-and-pr-gate

Status: Draft · Pass 0 · Updated 2026-05-27

> Establish a `dev` branch as the integration target and protect `main`
> against direct pushes — merges to `main` require a PR from `dev` (or
> a feature branch). Small, focused: just the branch model + the
> GitHub gate.

## Why

`gridworks-data` is the **canonical SQLAlchemy schema** consumed by
app services (journalkeeper today; future analytics consumers). A
single accidental push that breaks a model or alters a column type
cascades to every consumer's regen / migration. The
"Karan-style autonomy" pattern documented in
`wiki/working-with-llms.md` ("Karan's commit rules") explicitly
assumes a PR gate as the merge-safety guardrail — gridworks-data is
currently missing that gate, so the guardrail isn't actually engaged.

The fix is small and well-trodden: `dev` for in-flight integration,
`main` for shipped, GitHub branch protection forces the PR.

## The change

**Branch model:**
- `main` — shipped, stable. Tagged releases live here.
- `dev` — integration. PRs from feature branches land here. Continuous
  CI runs against `dev`.
- Feature branches (`<handle>/<topic>`, e.g. `jm/add-weather-table`)
  branch from `dev`, merge to `dev` via PR.
- `dev` → `main` happens via PR at release boundaries (tagged, with
  changelog entry).

**GitHub branch protection on `main`:**
- Require pull request before merging.
- Require at least 1 approving review (or 0 for solo dev with
  required status checks as the substitute — see Open Q).
- Require status checks to pass before merging (tests workflow).
- Restrict who can push to `main` to the repo owner (or just
  "Administrators only" — solo-friendly).
- Optionally: require linear history (no merge commits to `main`).

## Invariants

1. **No direct pushes to `main`.** Even by the owner. PR or nothing.
2. **CI status check is required.** A green check from
   `.github/workflows/tests.yml` (or equivalent) before merge is
   allowed.
3. **Default branch in the GitHub UI is `dev`**, so PRs and
   contributor flow target `dev` by default. `main` is just the
   release pointer.
4. **Releases are tagged on `main`** (semver), and the
   `dev → main` PR carries the changelog summary for the release
   window.

## Execution

1. **Create `dev` from current `main`** on GitHub (or
   `git push origin main:dev`).
2. **Set `dev` as the default branch** in repo Settings → Branches.
3. **Add a branch protection rule on `main`** with the invariants
   above.
4. **Update README** to document the branching model (one paragraph,
   matches the gridworks-base / sema pattern if they have one).
5. **Mirror this to other gridworks code repos** when each is ready —
   but **this design ships for gridworks-data first**, gated on the
   schema-criticality argument above. Other repos can adopt opportunistically.

## Open questions

- **Solo-dev reviewer requirement.** For a one-maintainer repo,
  GitHub will let you set "0 approving reviews required" + "require
  status checks" as the substitute. Worth verifying that satisfies
  the safety goal (CI green = OK to self-merge) vs. mandating a
  second pair of eyes. Recommend: **0 reviews + required CI** for now
  (solo-friendly), revisit when a second maintainer is consistent.
- **What about the bulk-edit-from-Claude pattern?** Claude sessions
  on feature branches → PR to `dev` is the natural model. Coordinate
  via `wiki/active-claims.md` (which already exists) for in-flight
  branches.
- **Sema/gridworks-base parity.** Do those repos already have this
  pattern? If yes, mirror exactly. If no, this design is the
  prototype.

## Cross-refs

- `wiki/working-with-llms.md` "Karan's commit rules" — the autonomy
  pattern this gate enables.
- `wiki/gridworks-data/changelog.md` — entry lands here when
  executed.
- `wiki/active-claims.md` — multi-session coordination (orthogonal
  but related).
