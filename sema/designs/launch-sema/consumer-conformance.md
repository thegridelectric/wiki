# Consumer conformance through the published tool (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-538

> What this is: every consumer repo runs the sema CLI as an installed,
> versioned package in its own tooling and CI, and never from a sema
> checkout. That is what keeps snapshot code unedited: the generator is a
> dependency, so regenerating is always cheaper than hand-editing, and the
> check that the snapshot matches the generator runs the same package.

## Branches and releases

`dev` is where vocabulary moves, daily. `main` receives a release: a tag
and a built package, cut when a promotion wave is done. A release carries
the registry as it stood at that commit, staging words included, so a
release is a self-consistent vocabulary that a consumer can pin.

Consumers depend on the package, not the repo. The pin is a package
version in the consumer's `pyproject.toml`; a pin bump is one dependency
edit, reviewed like any other. Between releases the consumer sees nothing
of `dev`, which is the whole answer to rapid development: churn is
invisible until someone chooses a newer release.

## What runs in a consumer

- `sema snapshot prepare|build` from the consumer's seed request, run by
  its `regen_sema_snapshot.sh`, producing the vendored snapshot.
- The drift check (`snapshot-drift-check.md`): CI rebuilds the snapshot
  with the pinned package and diffs against the vendored tree. A hand
  edit to generated code is red.
- `sema validate` as the oracle wherever a consumer hand-writes a twin.
  Today that is scada's gwsproto; its conformance sweep
  (`gridworks-scada/packages/gridworks-scada-protocol/gwsproto_sema_conformance.py`)
  already has a `--cli` path that revalidates each clean dump through the
  CLI, and reads a sibling sema checkout. It moves to the installed
  package and the checkout argument goes away.

## Severity

At the pinned release everything is a hard failure: example-reject,
dump-drift, value-drift, a format accepting a counterexample, a snapshot
diff. The release is self-consistent, so there is nothing to excuse.

Against the latest release, the same sweep is advisory: it reports that
newer versions of words exist (version drift) and whether the consumer's
twins still pass there. That report is the signal to bump the pin. It
never turns the build red.

Staging words need no special exception. A staging word mutates in place
on `dev`, but at a release it is one definite schema; a consumer on that
release checks against that schema. The registry status only matters
when the consumer runs on a non-dev broker, which the public registry
already governs.

## The one code change

Every sema tool locates the repo tree from its own file
(`Path(__file__).resolve().parents[3]`, in `interfaces/cli/snapshot.py:50`
and the `tools/build_*.py` modules) and the wheel packages only
`src/sema`, so an installed package cannot see `definitions/`. The
package has to ship the definitions and the indexes as package data and
the tools have to read them from there. Nothing else about the CLI
changes.

## Open

- Release cadence and version scheme: a release per promotion wave;
  whether the minor number tracks new published words and the patch
  number tooling, or the spec draft number leads.
- Where the package is published: PyPI, or a git tag installed by URL
  until the name is worth claiming. PyPI is the stranger-friendly answer
  and the launch is for strangers.
- gwbase and scada both vendor today; which pins first (gwbase, whose
  regen script exists).

## Do this next

Make the installed package self-sufficient (definitions and indexes as
package data), tag a first release from `main`, and switch gwbase's
`regen_sema_snapshot.sh` to the installed tool. Then the drift check runs
against that pin.
