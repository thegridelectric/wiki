# Deploying a gwbase service — the recommended box pattern

Status: Draft · Pass 0 · Updated 2026-07-23

> What this is: the recommended way to run a gwbase service on a production
> box. Heritage: the gwproactor/scada service setup (a systemd unit running
> the repo venv's binary, `.env` at the repo root, `Restart=always`),
> deliberately **flattened** — the wrapper scripts (`gwstart`/`gwstop`/…),
> install framework, and restart-catcher unit/timer are dropped; systemctl
> and journalctl are the interface. First applied to the grid-node-registry
> box. A recommendation, not a mandate: existing boxes migrate when touched.

## The pattern

1. **One login user per service** — the obvious name (`gnr`, `journal`, …).
   The service repo is cloned in its homedir; `.env` sits at the repo root
   (from `template.env`; creds live only there).
2. **One systemd unit per service process**, named for what it runs
   (`gnr-rabbit.service`, `gnr-api.service`). `ExecStart` invokes the repo
   venv's console script **directly** — no wrapper scripts, no `uv run`, no
   activation dance. `User=<login>`, `Restart=always`, `WantedBy=
   multi-user.target`. Unit files live in the repo (`service/`) and are
   **copied** to `/etc/systemd/system/` at setup — copied, not symlinked
   (symlinked units into a homedir carry enable/permission gotchas, and a
   copy means a mid-edit repo cannot change running config). A unit change
   is deliberately re-copy + `systemctl daemon-reload`; the README says so.
   The box runs only a **clean checkout of a pushed SHA** (never edit on
   the box); `uv sync --frozen` against the committed lockfile is the
   reproducibility story, and `git log -1` in the repo records what runs.
3. **A README in the homedir** — the obvious stuff for whoever lands on the
   box: what runs here, the unit names, where the logs are, the three
   commands that matter (`systemctl status/restart/stop <unit>`,
   `journalctl -u <unit>`). One screen, current, no wiki references.
   Convenience aliases MAY ship (`service/bash_aliases`, sourced from the
   login's `.bashrc` at setup): pure spelling over systemctl/tail —
   `<svc>start`/`<svc>stop`/`<svc>restart`/`<svc>log` — never logic; the
   heritage wrapper *scripts* stay dropped. Pair with a narrow sudoers
   drop-in granting the login exactly those systemctl invocations on its
   own units (NOPASSWD, exact-argument lines).
4. **Logs in the XDG state home** — `~/.local/state/gridworks/
   <service_name>/log/<service_alias>.log` (`actors.md` "Diagnostics", gwbase paths convention);
   stdout-only processes (e.g. a uvicorn façade) rely on journald.
5. **Vendored runtimes are containers; our services are native.** Postgres
   and the broker run as pinned containers (data on an encrypted volume)
   supervised by docker's own `restart: unless-stopped` — no systemd
   wrapper around a container. gwbase services run as the venv binary under
   systemd. This keeps the image build/push/pull machinery out of the
   change-to-box path entirely.

## Unit skeleton

```ini
[Unit]
Description=<service> — <one line>
After=network-online.target

[Service]
Type=simple
User=<login>
WorkingDirectory=/home/<login>/<repo>
ExecStart=/home/<login>/<repo>/.venv/bin/<console-script> <command>
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
```

**Multi-instance services use a systemd template unit.** When one codebase
runs as several deployed instances (the ears: one code, N slices), the
repo ships a single generic `\<name\>@.service` with `%i` in `User=` /
paths, and the instance name IS the login (`ear@ear`, `ear@gnr-ear`). The
repo stays exactly as generic as its code — one unit, one
`template.env` documenting the config surface — and the instance roster
(which instances exist, on which box) is an operational fact recorded in
gridworks-infra, not in the repo. A new instance costs a login + a `.env`
+ `systemctl enable --now \<name\>@\<login\>`; no repo change.

## The ci.sh gate

Every service repo ships a `ci.sh` at its root: one command that runs
locally everything the repo's CI workflow runs, so a push won't go red.
It is the gate the commit-suggestion rule invokes ("run the repo's CI
entrypoint before suggesting a code-repo commit"). Shape, from
`gridworks-base/ci.sh` and `gridworks-ear/ci.sh`:

1. `uv sync --locked` — resolve the env exactly as CI does.
2. **Directory-form lint first**: `ruff check --no-fix .` +
   `ruff format --check .`. Ordering is load-bearing:
   `pre-commit run --all-files` only sees git-TRACKED files, so a
   brand-new untracked file sails through pre-commit and then fails in
   CI; the directory form sees everything.
3. The repo's actual CI lint job (pre-commit, drift guards — whatever
   the workflow runs).
4. Tests, broker-aware: if the suite needs the dev broker, probe
   `localhost:5672` and either run the full suite or fall back to the
   suite's CI self-skip mode with a printed note — never hang, never
   silently skip.

A repo whose CI gains a job updates its `ci.sh` in the same change; the
two drifting apart recreates the push-and-pray loop this exists to end.

## Scope of the self-hosted-database stance

Running our own Postgres (as a container on the box) is recommended where
the database is a **rebuildable projection** — message-log-first services
whose DB can be replayed from the durable log (the registry pattern). For
authoritative data planes with real DB-durability stakes, a managed
database remains a legitimate choice and is in use on the analytics side
(managed RDS for TimescaleDB + Postgres). Keeping the ability to run our
own infrastructure is a goal of this pattern; it is not a prohibition on
managed services. Open: an estate-wide self-hosted-vs-managed position —
worth a dedicated grill when a durability-critical service moves.
