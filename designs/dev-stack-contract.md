# dev-stack-contract — running the services on a laptop

Status: Draft · Pass 0 · Updated 2026-10-22 · Linear: [OPS-614](https://linear.app/gridworks/issue/OPS-614)
**EDD: yes** — verified when the OPS-473 dev run (`experiments/2026-10-21-disentangle-dev-run/`) reruns from one `stack up` and its runbook shrinks to the steps that are the experiment.

> What this is: the contract every GridWorks service meets so a dev run
> can start it on a laptop, and the experiments-repo tool that brings a
> named stack of such services up and down. One flat design.

## Why

The OPS-473 dev run of 2026-10-21 stood up eight repos on the laptop:
the dev broker, the local journal database, the `d1` registry, a dev
PII store, journalkeeper, web-backend's API and gateway, the frontend
and a simulated scada. Its runbook is 137 lines of hand commands. Between
runs the API had died and nothing said so. Three processes wanted port
8000. Two settings had to be added to web-backend mid-run because it
could not talk to a plain-AMQP broker or pick a port. The frontend
needed an env line nobody had written down. Only the gateway has a health
endpoint, and two of the six Python services have no console
entrypoint.

None of that was a defect in the design under test. It is the cost of
having no agreed answer to "run me on a laptop". Every design that
reaches `Verified` through an experiment against a real broker pays it
again. The contract is the durable part; the tool is a day's work once
the contract holds.

## The contract

What each service repo owes so a stack tool can start it, wait for it,
and tear it down. Each item traces to a gap in the dev run.

1. **One foreground start command per process**, documented in the repo
   README, an installed console script where the repo is a package.
   Journalkeeper and web-backend have none; the run used `python -m`
   paths.
2. **Every listen port and peer address is a setting** under the repo's
   own prefix, with a dev default off 8000, which the laptop keeps for
   scada live tests (experiments README "Conventions"). web-backend
   gained `BACKEND_API_PORT` in the run; the registry's read API still
   defaults to 8000.
3. **A dev posture reachable by settings alone**: plain AMQP to
   `gw-dev-rabbit`, a local database, no client cert. web-backend gained
   `BACKEND_RABBIT_TLS` in the run.
4. **A readiness signal**: an HTTP health route for anything that
   listens, a documented log line for anything that does not. The
   gateway has `/gateway/health`; nothing else answers.
5. **An idempotent dev-state command**: stand up the service's own state
   from an empty database. The registry's dev universe seed is reachable
   only from the test suite; the laptop's `d1` was seeded in August by a
   path that no longer exists.
6. **Any production gate has a documented dev posture.** The registry's
   write proof is simply absent on an ungated target, which is fine; the
   runbook should say so instead of inventing a token.
7. **The repo README states its own dev posture for a human** and says
   nothing about the stack or the other services (base-CLAUDE "No
   cross-service declarations in a repo").

The scada and the frontend are not gwbase services and meet the same
items in their own idiom: the scada's start is its sim entrypoint with a
layout file and a config home, the frontend's is vite with its `.env`.

## Standing, 2026-10-21

| service | 1 start | 2 ports | 3 dev posture | 4 ready | 5 dev state | 6 gate | 7 README |
|---|---|---|---|---|---|---|---|
| gw-dev-rabbit (gridworks-base) | `./arm.sh` | fixed in compose | is the dev posture | docker health | compose | none | yes |
| grid-node-registry | `gnr rabbit`, `gnr api` | API defaults 8000 | yes | none | test-only seed | ungated dev | partial |
| gridworks-pii | `gwpii` | n/a | yes | n/a | alembic | none | yes |
| gridworks-journalkeeper | `python run_journal_keeper.py` | n/a | yes | log line only | forest bootstrap | none | partial |
| gridworks-web-backend API | `python -m api` | yes (added) | yes (added) | none | roles by hand | none | partial |
| gridworks-web-backend gateway | `python -m gateway` | 8100 fixed? | yes | `/gateway/health` | seeds from `layouts` | none | partial |
| gridworks-web-frontend | vite | 5173 | `.env` ws base | HTTP 200 | none needed | none | no |
| gridworks-scada sim | fixture layout + config home | 8000 by layout | MQTT to dev broker | log line | layout file | none | partial |

Cells to verify before Accepted: the gateway's port setting, the
journalkeeper's readiness line, the scada sim's start command as a
documented thing rather than a runbook recipe.

## The tool

`experiments/devstack.py`, beside `capture_broker.py` and
`tap_listen.py`. It reads a stack spec and gives `up`, `down`, `status`
and `logs <service>` for a named stack. A stack spec is a typed record
per service (sema gravity below the word layer): repo path, branch to
assert, start command, env file, readiness probe, log path, and the
dev-state command to run once on an empty store. Specs live beside the
tool, one per purpose (`d1-dashboard`, `d1-market`), and an experiment
runbook names its stack instead of listing its services.

The tool owns nothing a service owns. It never edits a repo's `.env`,
never passes secrets on a command line, and refuses to start a service
whose checkout is not on the branch the spec names. Logs go under the
experiment folder when run from one, else under the session scratchpad.

Home: the experiments repo, because dev runs are experiments under the
EDD bar, the laptop tooling already lives there, and the stack spec
declares what every service does and needs, which no service repo may
say about another.

## Plan

1. Registry first, as the smallest full example of items 1 to 7: a
   `seed-dev` command on the existing seed, the read API off 8000 in the
   dev template, one display-name rule shared by the seed and `gnr
   create` (its own fix, surfaced by the same run). Merged to the
   registry's `main` 2026-10-22 (`7eff734`).
2. Fill the standing table's unverified cells; agree the contract at
   Pass 1.
3. Console entrypoints and health routes for journalkeeper and
   web-backend; the frontend `.env` line in its README; the scada sim
   start as a documented command.
4. `devstack.py` and the `d1-dashboard` spec; rerun the OPS-473 dev run
   from it; shrink that runbook. That rerun is the verifying experiment.

Effort: step 1 about 2 h; step 3 about 3 h across three repos; step 4
about a day. Point 12 h, 90 % range 8 to 20.

## Open

- Whether the stack spec becomes a sema word once two tools read it
  (the devstack tool and, later, a box's service inventory), or stays a
  typed record in the experiments repo.
- Whether `gw-dev-rabbit`'s topology (the `ear_tx` binding the gateway
  needs) is part of the broker's dev state or a stack-level step.
- Where the dev-run login for web-backend lives once roles are seeded
  by a command rather than by hand.

## Do this next

Step 2 of the Plan: verify the standing table's open cells (the gateway's
port setting, journalkeeper's readiness line, the scada sim's start
command) and take the contract to Pass 1.
