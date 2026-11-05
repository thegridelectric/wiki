# scada-to-uv

Status: Draft · Pass 0 · Updated 2026-11-05 · Linear: OPS-661

**EDD: yes** verified when a bench Pi on the template image builds and
runs the scada under uv from a pushed SHA, and one deployed house is
rolled onto that build with `scripts/roll.sh` and reports through a
five-minute mark.

> What this is: gridworks-scada becomes a uv project, with one declared
> and locked dependency set in place of the hand-rolled `tools/mkenv.sh`
> and the pip-tools `requirements/` files. It is the shared dependency
> of proactor-makeover (OPS-428), whose rewrite is "flat-in-scada under
> uv", and of code-update (OPS-401), whose step 0 is uv on a real armv8
> Pi. Both start from a scada that is already a uv project.

## Why

The scada is the one GridWorks repo that is not a uv project. Its
`pyproject.toml` has no `[project]` table, so `uv run` and `uv sync` do
nothing at the root; the venv is built by `tools/mkenv.sh` from two
pip-tools locks, with two editable installs and a symlinked `gws`
entrypoint that does not survive a venv move. The environment spec
(`../executor/environment.md`) records this as temporary. The cost
shows up on every new machine: a laptop whose `python` is 3.14 built a
venv that could not import the test package (scada PR 607 pins the
version as a stop-gap), and an editable install has bound to the wrong
checkout before. The two later designs assume the migration is done.

## What stays fixed

These are deployment facts the migration works around; none of them
changes here.

- **The interpreter path in the units.** `service/gwspaceheat.service`
  and `service/gwltn@.service` exec `gw_spaceheat/venv/bin/python` on
  the Pi and the LTN box. The venv stays at that path
  (`UV_PROJECT_ENVIRONMENT=gw_spaceheat/venv` in the repo's uv config),
  so the units do not change and a box rolls as today.
- **The interpreter is 3.12 everywhere, and not the distro's.** Every
  box venv (the five LTNs on the LTN box, the five pis) runs Python
  3.12.12 from pyenv; the LTN box's system Python is 3.10 and the pis'
  is 3.11 on 64-bit bookworm. The SD card recipe in gridworks-infra
  moved the pis to 64-bit and pyenv when pendulum fell behind 3.12 on
  32-bit. uv installs and pins interpreters the way pyenv does, so a box
  needs no distro interpreter and no special case; `drivers.in` (the
  board and Adafruit libraries) resolves against the pinned 3.12 like
  everything else. A bump to 3.13 is its own one-line change after the
  port, when the lock is rebuilt anyway.
- **One lock, two installs.** The laptop and CI install the default
  set; a Pi installs the `drivers` extra; the LTN box installs the
  bruce sibling editable from `../optimal-flexibility` as `roll.sh`
  expects. All three resolve from the one `uv.lock`.
- **`roll.sh` is the only path onto a box.** It rebuilds the venv with
  `uv sync` in place of `mkenv.sh`, and its layout-pair check is
  untouched.

## Shape

- `pyproject.toml` gains a `[project]` table for the scada itself, with
  `gw_spaceheat` as the package root, and a `[tool.uv.workspace]` whose
  members are `packages/gridworks-scada-protocol` and
  `packages/gridworks-admin`. The two editables become workspace
  sources, so a venv can no longer bind to another checkout.
- `gws` becomes a `[project.scripts]` console script in place of the
  symlink.
- `.python-version` (PR 607) is the interpreter pin; the CI workflow
  already reads it and moves from `pip install -r` to `uv sync --locked`.
- `tools/mkenv.sh`, `tools/mkenv-pi.sh` and `gw_spaceheat/requirements/`
  are deleted in the same change, with their pins translated into the
  lock rather than loosened.
- The README's setup section and `docs/editor-setup.md` describe the uv
  flow; the wiki environment spec is rewritten to the new mechanism when
  the design ships.

## The experiment

1. **Bench Pi.** On the template image, install uv, clone the branch at
   a pushed SHA, `uv sync --extra drivers`, start the unit. Done when
   the scada boots against the dev broker and the unit's exec path is
   the uv-built venv.
2. **Laptop and CI.** `uv sync` and `uv run pytest` at the repo root;
   the workflow installs from the lock and the suite is green.
3. **One house.** `roll.sh <house> to <branch>` onto the uv build; the
   house reports through a five-minute mark and `roll.sh <house> check`
   is clean. Then the rest of the fleet moves with the branch's merge.

## Open

- Whether uv is installed on a Pi by the standalone installer or by the
  distro's pip, and whether pyenv stays beside it or goes; the
  provisioning design (OPS-576) decides, this design only needs uv to
  build the venv on the bench Pi.
- Whether the LTN box's bruce sibling stays an editable install or
  becomes a workspace source; it stays editable until the LTN leaves the
  scada repo (OPS-659).
