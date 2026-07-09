# gjk operational — how the service runs

Status: Draft · Pass 0 · Updated 2026-07-09

> One concern: start/stop, supervisor wiring, restart semantics. The live-path
> behavior itself (dispatch, persistence) is in
> [`primary.md`](primary.md); this is how the process is kept alive.

## Entrypoint

`run_journal_keeper.py` at the repo root is the service entrypoint:
`dotenv` load → `JournalKeeper(settings=Settings(), codec=SemaCodec())` →
`start()` → join the consuming thread. `ActorBase.start()` is non-blocking
(it spawns a daemon consumer thread plus JK's hourly main loop), so the join
is what holds the process open. `.env` is found from the working directory,
so the unit sets `WorkingDirectory` to the checkout root.

## systemd wiring (`service/` in the repo)

The pattern mirrors `gridworks-scada/service/`: unit files live in the repo
and are symlinked into `/lib/systemd/system` by `service/install`
(`service/uninstall` reverses everything).

- **`journalkeeper.service`** — `Type=simple`, `User=ubuntu`,
  `WorkingDirectory=/home/ubuntu/gridworks-journalkeeper`,
  `ExecStart` = the checkout's `.venv/bin/python run_journal_keeper.py`,
  `Restart=always` / `RestartSec=1`. Ordered `After=network-online.target`
  (it is a network consumer; there is no local broker to wait on).
- **`journalkeeper-restart.service` + `.timer`** — a oneshot every 15 min
  that starts the main service if it is not active. It catches the
  "manually stopped and forgot to restart" case, which `Restart=always`
  cannot (systemd treats a manual stop as intended).
- **Helpers** (symlinked into `~/.local/bin`): `jkstatus`, `jkstart`,
  `jkstop`, `jkpause`, `jkrestart`. `jkpause` stops only the main service —
  the timer brings it back within 15 min; `jkstop` stops the timer too, so
  the service stays down until `jkstart`.

No watchdog: gwbase actors do not sd_notify, so the unit carries no
`WatchdogSec`. Liveness beyond "process up" is the alerting layer's concern,
not the unit's.

## Configuration

All settings ride the `GJK_` env prefix (`gjk.config.Settings`, a gwbase
`ServiceSettings`), sourced from `.env` in the checkout root. The production
triple: `GJK_RABBIT__URL` (AMQP, production broker vhost `hw1__1`),
`GJK_DB_URL`, `GJK_SERVICE_ALIAS` (the tap's routable address in the
production world). `template.env` documents the keys; the repo README
"Production notes" has the install steps.

## Restart semantics

The consume queue is `auto_delete=True` with a per-boot suffix, so a killed
or restarted process leaves nothing behind on the broker; each boot declares
and binds a fresh queue. Messages crossing the bus while the service is down
are simply not captured live — the S3 backfill importer
(`s3_message_importer`) is the recovery path for gaps.

Shutdown is SIGTERM-terminate, not graceful: `JournalKeeper.stop()` joins the
main loop mid-`sleep(3600)`, so the unit does not call it — the process dies,
the broker connection drops, the queue auto-deletes. Nothing in the live path
holds state that needs flushing (each message persists synchronously in
dispatch).

## Open

- The production host for the new-line deployment is not yet provisioned;
  unit files assume `ubuntu` @ `/home/ubuntu/gridworks-journalkeeper`.
- Production `GJK_SERVICE_ALIAS` (e.g. `hw1.journal`) is not yet settled.
