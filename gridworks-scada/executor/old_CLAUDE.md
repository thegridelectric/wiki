# CLAUDE.md

## Design & architecture live in the wiki — start there

This repo's architecture, design intent, invariants, and rebuild spec are **not**
in this file. They live in the GridWorks wiki:

> **`/Users/jessica/GridWorks/wiki/gridworks-scada/`**
> — start at [`executor/primary.md`](../wiki/gridworks-scada/executor/primary.md)
> (the rebuild spec). During the current cleanup/discovery phase, also read
> [`PROCESS.md`](../wiki/gridworks-scada/PROCESS.md) and
> [`research/map.md`](../wiki/gridworks-scada/research/map.md).

Do not re-document architecture here. New design facts go in the wiki (the
shared source of truth); this file holds only the repo's dev runbook below.
Terminology note: `atn`/`AtomicTNode` is legacy — read as **LTN**
(see `wiki/glossary.md`).

---

## Dev runbook (how to work in this repo)

### Environment setup

Not a `uv`/`pip` project at the top level — it uses a venv created by a script.

```bash
./tools/mkenv.sh         # creates gw_spaceheat/venv/, installs requirements/dev.txt,
                         # editable-installs packages/gridworks-scada-protocol,
                         # packages/gridworks-admin, and ../gridworks-innovations/gridworks-flo
./tools/install-gws.sh   # symlinks the `gws` CLI script into gw_spaceheat/venv/bin
cp .env-template .env    # required for `gws run`
```

Activating the env requires `PYTHONPATH` to include `gw_spaceheat/`:

```bash
alias gw="source $HOME/Coding/gridworks-scada/gw_spaceheat/venv/bin/activate \
  && cd $HOME/Coding/gridworks-scada \
  && export PYTHONPATH=$HOME/Coding/gridworks-scada/gw_spaceheat:$PYTHONPATH"
```

A hardware-layout JSON is required to run anything. Test layout:
`tests/config/nolan-layout.json` (set by `tests/conftest.py`). For dev runs,
point `SCADA_PATHS__HARDWARE_LAYOUT` / `LTN_PATHS__HARDWARE_LAYOUT` in `.env` at
a generated layout (see `gw_spaceheat/layout_gen/` or the sibling `tlayouts`
repo's `gen_orange.py`).

Dev needs two MQTT brokers: a RabbitMQ with the MQTT plugin (`gridworks_mqtt`
upstream) and a Mosquitto broker (`local_mqtt` to Scada2). See `README.md` for
broker recipes — non-obvious step is `docker exec ... rabbitmq-plugins enable
rabbitmq_mqtt` then `rabbitmqctl restart_app`.

### Common commands

```bash
gws run                  # run the SCADA
gws run --dry-run        # show what would run without starting actors
gws run-s2               # run Scada2 (secondary, LAN-side actor host)
gws ltn run              # run the local test LTN
gws config               # dump resolved ScadaSettings
gws layout show          # pretty-print the hardware layout
gws commands             # interactive TUI listing all CLI commands
gwa                      # run gridworks-admin (interactive monitoring UI)
pytest                   # full test suite (run from repo root)
pytest tests/actors/test_scada.py::test_name   # single test
ruff check               # lint — NOT run in CI; visual-only, code does not currently pass
./tools/pipc.sh          # recompile requirements/*.txt from *.in (then strip absolute paths manually)
```

To experiment in a REPL, instantiate `ScadaApp` or `LtnApp` via
`get_repl_app(...)` / `make_app_for_cli(...)` and call `app.run_in_thread()`;
`app.prime_actor` is the `Scada` instance. See README §F–G.

### Subpackages

`packages/gridworks-scada-protocol` (`gwsproto`) and `packages/gridworks-admin`
(`gwadmin`) are separate PyPI distributions managed with `uv` in their own
directories, editable-installed into the scada venv by `mkenv.sh`. Source edits
are picked up immediately, but **changes to a subpackage's `pyproject.toml`
require re-running `pip install -e packages/<name>` or `tools/mkenv.sh`**. Bump
versions with `uv version --bump patch` from inside the subpackage dir;
publishing happens in CI on merge to `main`.

### Branch flow

Default branch is `dev`. Bug fixes go directly to `dev`; features land via PR to
`dev`. Beta houses run `dev`; the production fleet runs `main`. Merging
`dev → main` triggers PyPI publication of `gridworks-scada-protocol` and
`gridworks-admin`.

### Tests

`tests/conftest.py` pulls fixtures from `gwproactor_test` (`restore_loggers`,
`clean_test_env`, `default_test_env`) and hardwires the test layout to
`tests/config/nolan-layout.json`. `--admin-verbosity N` controls live-test admin
logging; live-test options come from
`gwproactor_test.pytest_options.add_live_test_options`. Test certs are cached
under `tests/.certificate_cache/`.

### TLS

TLS is on by default for both MQTT links. Generating certs uses `gwcert key add`
against a local self-signed CA (see README §TLS). Production scada keys come
from the central `certbot` host via `gw_spaceheat/getkeys.py` (requires rclone
and the certbot ssh key).
