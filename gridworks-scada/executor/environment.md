Status: Draft · Pass 0 · Updated 2026-11-09

# SCADA Python environment — how it's built and maintained

What this is: how the scada's Python environment is declared, locked and
built, on the laptop, in CI, on the LTN box and on the Raspberry Pis, and
the non-obvious bits of each.

## The declaration and the lock

The repo root is a uv project with `package = false`: `pyproject.toml`
declares dependencies and nothing is built or installed from `gw_spaceheat/`,
which reaches the interpreter through `PYTHONPATH` (pytest's `pythonpath`,
the units' `Environment=PYTHONPATH=`). `uv.lock` at the root is the one
resolution for every environment.

| Set | Where declared | Who gets it |
|---|---|---|
| runtime | `[project] dependencies` | every environment |
| `drivers` | dependency group | the Pis only (adafruit, `board`) |
| `dev` | dependency group, uv's default | laptop, CI, LTN box; never a Pi |

`requires-python` is 3.12 only, the version `.python-version` names and the
Pis run. `[tool.uv] required-environments` holds the lock to aarch64 Linux,
so a lock that cannot install on a Pi fails on the laptop.

Three dependencies come from `[tool.uv.sources]`, not PyPI: the proactor
at a git tag of `gridworks-proactor`, and `gridworks-scada-protocol` and
`gridworks-admin` editable from `packages/` of the same checkout. Admin is
in `dev`, so a Pi has no `gwadmin`. The two packages stay standalone uv
projects with their own `uv.lock` for publishing; they are not workspace
members.

The root lock records each package's version, so a version bump in
`packages/` needs `uv lock` at the root, or CI's `uv sync --locked` fails.

## The venv

`.venv/` at the repo root, built by `uv sync --locked` through two wrappers
run from the repo top level:

- `tools/mkenv.sh [uv sync options]`: syncs (runtime + `dev`) and symlinks
  `gw_spaceheat/gws` into `.venv/bin/`. Laptop and the LTN box.
- `tools/mkenv-pi.sh`: `mkenv.sh --no-dev --group drivers`. The Pis.

uv uses an installed Python 3.12 or downloads one. Sync is exact: a package
not in the lock is removed, so `tools/lpro.sh` (local proactor and protocol
checkouts via `uv pip install -e`) lasts until the next sync or `uv run`;
`tools/rpro.sh` restores the locked pair.

## On a Pi

- uv lives in `~/.local/bin` (the standalone installer) and is needed only
  to build the venv. The units (`service/gwspaceheat.service`,
  `service2/gwspaceheat2.service`) run `.venv/bin/python gw_spaceheat/gws`
  directly, so boot never resolves or downloads.
- Every locked runtime and driver package has a cp312 aarch64 manylinux
  wheel except `pyModbusTCP`, which is pure Python; a Pi compiles nothing.
- A line still on pip keeps its venv at `gw_spaceheat/venv/` and its pins
  in `gw_spaceheat/requirements/`, so both venvs can sit in one checkout and
  a roll between the lines rebuilds neither by accident. `scripts/roll.sh`
  compares `uv.lock` and those requirement files between SHAs and stops
  the roll when either differs; the rebuild is `tools/mkenv-pi.sh` by hand
  on the box, whichever line it is on.

## The by-hand / fragile bits

- **The `gws` entrypoint is a symlink**, re-created by `mkenv.sh`; its
  shebang is the relative `.venv/bin/python`, so the bare `gws` works from
  the repo top level only.
- **The laptop keeps a `legacy` worktree with its own venv.**
  `GridWorks/scada-legacy` is a git worktree of the canonical checkout
  on `legacy` (`git -C gridworks-scada worktree list` shows both),
  built with its own `tools/mkenv.sh` run from inside it. A venv binds
  to one checkout, and the tlayouts gens for the houses on `legacy`
  and for `actual-spruce` import `layout_gen` and `gwsproto` at that
  line, so they run with `PYTHONPATH=scada-legacy/gw_spaceheat` under
  `scada-legacy/gw_spaceheat/venv/bin/python`, `legacy` being a pip
  line. A moved worktree needs its venv rebuilt (absolute paths inside).

## Running tests / experiments

`uv run pytest`, or `.venv/bin/python` (or `source .venv/bin/activate`),
**from the repo top level** so the editable packages + `gw_spaceheat/`
resolve. `./ci.sh` is the CI gate: `uv sync --locked`, `ruff check`, then
pytest under coverage; the workflow runs it after its broker and cert setup. The in-process live-test harness is documented in
[`testing.md`](testing.md); broker-based **experiments** (the World hook-up)
are in [`../../world/primary.md`](../../world/primary.md).

## Open

- `gridworks-scada-protocol` and `gridworks-admin` as `[tool.uv.workspace]`
  members with the one root lock, once nothing but the scada imports
  gwsproto (tlayouts and experiments still do). With it the scada becomes
  installable: `gws` a `[project.scripts]` entry, and the `PYTHONPATH`
  export (the units' `Environment=PYTHONPATH=` included), the `gws`
  symlink and its relative shebang retire.
- A first Pi built from `uv.lock` has not been run.
