Status: Draft · Pass 0 · Updated 2026-06-09

# SCADA dev/test environment — how it's built and maintained (pre-uv)

What this is: the **as-is** mechanism for building and maintaining the scada's
Python environment, including the non-obvious, partially-by-hand bits. This is
operational scaffolding that exists **until the scada is migrated to `uv`** —
record it so experiments/tests are reproducible in the meantime, and so the uv
migration knows what it is replacing.

> **TEMPORARY.** The scada repo is **not** a flat `uv` project — its
> `pyproject.toml` carries only `[tool.pytest.ini_options]` / `[tool.ruff]`,
> **no `[project]` table**, so `uv run` / `uv sync` do **not** work at the repo
> root. Dependency management is the hand-rolled `tools/mkenv.sh` + pinned
> `requirements/` files below. Going through the scada with uv replaces all of
> this with a declared, locked dependency set.

## The venv

The scada virtual env lives at **`gw_spaceheat/venv/`** — NOT a top-level
`.venv/`. Python **3.12**. `gw_spaceheat/venv/bin/python` is the interpreter for
running tests, scripts, and experiments.

## The build tool: `tools/mkenv.sh`

Run from the **repo top level**. It **recreates** the venv from scratch:

1. `rm -rf gw_spaceheat/venv` then `python -m venv gw_spaceheat/venv`
   (override the interpreter with `PYTHON=python3.12 ./tools/mkenv.sh`).
2. `pip install -r gw_spaceheat/requirements/dev.txt` (the pinned dep set).
3. `pip install -e packages/gridworks-scada-protocol` — `gwsproto`, editable
   from **this** checkout.
4. `pip install -e packages/gridworks-admin` — `gwadmin` (skippable: 2nd arg
   ≠ `install_admin`).
5. Symlink the **`gws`** CLI (`gw_spaceheat/gws`) into the venv `bin/`.
6. `pip install -e ../gridworks-innovations/gridworks-flo/` — `gridflo`, the FLO
   engine, editable from a **sibling repo** (skippable: 3rd arg ≠ `install_flo`).

Args: `mkenv.sh [requirements-file] [install_admin] [install_flo]`.

## The by-hand / fragile bits (why this needs writing down)

- **Two editable installs point at local source trees** — `gwsproto` and
  `gwadmin` from `packages/`, and `gridflo` from the **sibling**
  `../gridworks-innovations/gridworks-flo/` (not on PyPI; the FLO engine is a
  separate house). A checkout missing that sibling can't build the full env.
- **Editable installs can silently bind to a *different* checkout.** Observed: a
  `gw_spaceheat/venv` whose `gridworks-scada-protocol` editable resolved to
  `~/Coding/gridworks-scada/packages/...` instead of the working checkout, so
  `import gwsproto` failed here. Fix: re-run `tools/mkenv.sh` from the intended
  checkout so the editables rebind to it. (Stop-gap without a rebuild: prepend
  `gw_spaceheat` + `packages/*/src` to `PYTHONPATH`.)
- **The `gws` entrypoint is a symlink**, re-created by `mkenv.sh` — it is not a
  packaged console-script, so it doesn't survive a venv copy/move.
- **No root uv project** (above) — IDE/tooling that assumes `uv` at the root
  will mis-resolve; point them at `gw_spaceheat/venv`.

## Running tests / experiments

Use `gw_spaceheat/venv/bin/python` (or `source gw_spaceheat/venv/bin/activate`),
**from the repo top level** so the editable packages + `gw_spaceheat/` resolve.
`pytest` + `pytest-asyncio` are in the venv. The in-process live-test harness is
documented in [`testing.md`](testing.md); broker-based **experiments** (the
World hook-up) are in [`../../world/primary.md`](../../world/primary.md).

## Open

- The uv migration: declare the three editable local deps + the FLO sibling as
  proper sources, lock them, and retire `mkenv.sh` + the `gws` symlink.
- Decide how `gridflo` (separate house) is versioned/pinned across checkouts.
