# dev-stack-contract — running the services on a laptop

Status: Draft · Pass 0 · Updated 2026-11-11 · Linear: [OPS-614](https://linear.app/gridworks/issue/OPS-614)
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
   README, an installed console script where the repo is a package, and
   one that runs from any directory. Journalkeeper and web-backend have
   none; the run used `python -m` paths. The scada's `gws` runs only from
   its repo root (a relative interpreter line), and its LTN was started
   by a python one-liner for a week while `gws ltn run` existed.
2. **Every listen port and peer address is a setting** under the repo's
   own prefix, with a dev default off 8000, which the laptop keeps for
   scada live tests (experiments README "Conventions"). web-backend
   gained `BACKEND_API_PORT` in the run; the registry's read API still
   defaults to 8000.
3. **A dev posture reachable by settings alone**: plain AMQP to
   `gw-dev-rabbit`, a local database, no client cert, from one env file
   whose name and place the README states, with a committed
   `template.env` that is the dev posture. web-backend gained
   `BACKEND_RABBIT_TLS` in the run. The scada had two `.env` files and
   its tool read the one the runbook did not name; the experiments
   capture reads a `.env` that has no template, so a second laptop
   stopped on it.
4. **A readiness signal**: an HTTP health route for anything that
   listens, a documented log line for anything that does not. The
   gateway has `/gateway/health`; nothing else answers.
5. **An idempotent dev-state command**: stand up the service's own state
   from an empty database AND its config home under `~/.config/gridworks/`
   (its identity file, its layout pair, its caches), so a second run is a
   no-op and a second laptop is one command. The registry's dev universe
   seed is reachable only from the test suite; the laptop's `d1` was
   seeded in August by a path that no longer exists. The FLO's identity
   file takes four runbook steps (registry database, seed, read façade,
   curl) for one JSON file that nothing reads again; `put_layout.sh`
   places the scada and LTN homes; bruce's matrix cache has no command
   at all, and a laptop without the file loses a slot to a build.
6. **Any production gate has a documented dev posture.** The registry's
   write proof is simply absent on an ungated target, which is fine; the
   runbook should say so instead of inventing a token.
7. **The repo README states its own dev posture for a human** and says
   nothing about the stack or the other services (base-CLAUDE "No
   cross-service declarations in a repo").

The scada and the frontend are not gwbase services and meet the same
items in their own idiom: the scada's start is its sim entrypoint with a
layout file and a config home, the frontend's is vite with its `.env`.

Item 4 has one answer that covers every broker-connected service with
no HTTP route: the dev broker's management API (`/api/queues/<vhost>`,
`/api/bindings/<vhost>`). A service is ready when its queue has a
consumer and the bindings its README names; the tool can probe that for
every gwbase actor and for the MQTT scada alike.

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

## Standing, 2026-11-05

The flo-dev-harness stand-up (`experiments/2026-11-05-flo-dev-harness/`),
six processes on one laptop and a second laptop following the README,
two hours for two people before the first request. Each stop was a
contract gap, none a defect in what was under test.

| service | 1 start | 2 ports | 3 dev posture | 4 ready | 5 dev state | 7 README |
|---|---|---|---|---|---|---|
| grid-node-registry | `gnr api` | 8010 by `.env` | yes | none; curl of a record | `gnr seed-dev` (done); identity file is four steps | partial |
| gridworks-flo | `gwflo rabbit` | n/a | `template.env` is the dev posture | log line; mgmt API shows queue + 2 bindings | none for the config home | yes |
| bruce (optimal-flexibility) | library | n/a | `.env.example` builds matrices | file present in cache | none; copy by hand or a 15 min test | no |
| gridworks-scada LTN | `gws ltn run`, repo root only | 1885 by `.env` | two `.env`s; wrong one read | log line | `put_layout.sh dev <change> [house]` | wrong file named |
| gridworks-scada sim | `gws run`, repo root only | 1885 by `.env` | yes | log line | same script | partial |
| experiments capture | `capture_broker.py` | n/a | `.env` with no template | log line | n/a | partial |

What the harness README had to say for itself, and the tool should
own: which house's layout pair, which universe's broker, which services
are once-per-laptop (the registry façade stops after the identity file
is written) and which are the experiment.

## Standing, 2026-11-09

The flo-plot-from-words round trip (OPS-665), the same harness with the
rabbit LTN and the journalkeeper added. The first journalkeeper start on
this laptop since 2026-10-25 failed every persist: the local `tsdb` was
one migration behind the code (`reading_channels.channel_id`, cut
2026-10-23). Getting it to head took four steps, none of them the
experiment:

| part | 1 start | 3 dev posture | 4 ready | 5 dev state |
|---|---|---|---|---|
| journal DB `gw-data-pg` (gridworks-data) | `docker start` | `.env` named a database the server does not have; `template.env` was right | `alembic current` is head, but only a human reads it | `alembic upgrade head`, which the migration refused |
| gridworks-journalkeeper | `python run_journal_keeper.py`, no console script | `.env` is the dev posture | none; it logs one persist error per message | none; its state is another repo's schema |

What the stops teach, each a line for the contract:

- **A store is a service for item 5.** The journal DB's dev state is
  its schema at the head the writers expect, and the command is
  gridworks-data's `alembic upgrade head`. Neither standing table had a
  row for it, so nothing asserted it.
- **A migration's inputs are reproducible from the database it runs
  on.** The channel_id migration applies a map keyed by production row
  ids and refuses any other dataset; its map script reads files at
  tlayouts paths that no longer exist and needs a local `jm/spruce`
  ref. A migration that needs a dataset-specific input generates it
  from the live table, or ships a dev posture that works on an empty
  database; a path into another repo's working tree is neither.
- **A writer checks the schema at startup (item 4 for a store
  client).** A service that writes to a database reads the schema
  version and refuses to start when it is not the version its code
  expects, naming both and the command. One boot failure instead of
  an error per message, on a box as on a laptop.
- **In compose, the migration is a one-shot service** built from the
  gridworks-data image, and the writers `depends_on` its completion.
  That is the programmatic form of the first two lines: the stack
  cannot start a journalkeeper against a schema it has not brought to
  head.

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

## Dockerizing each service

The contract above is what a service owes so a tool can start it on a
laptop. A container is the same posture with the host taken out of it:
the service's process, filesystem and `/dev/shm` are its own, and a
login on the box can touch none of them. Containers are the likely
direction for every box. The `hw1` services run native under systemd
today, and the `hw2` simulation host (`gridworks-infra/hw2-1/`) is the
first box built to run GridWorks services from compose. What a service
owes in addition, each item one more line in its README:

1. **A `Dockerfile` in the repo** that builds the service from its
   pushed commit with `uv`, runs it as a non-root user inside the
   image, and starts it with the item 1 foreground command. The image
   is tagged with the commit it was built from, so the box-runs-a-pushed-
   SHA guarantee holds for a container as for a checkout.
2. **Configuration enters only as settings and mounted files.** The
   env file of item 3 and the identity file of item 5 are mounted read-
   only; nothing is baked into the image that differs between dev and a
   box. A client certificate is mounted read-only into the one container
   that is its program (base-CLAUDE "A TLS cert belongs to one program").
3. **State is a named volume**, one per directory the service writes
   under its config or state home, and the item 5 dev-state command
   fills an empty volume the same way it fills an empty home.
4. **Readiness is the item 4 probe**, unchanged: the health route, or
   the management API showing the service's queue with a consumer.
5. **Logs go to stdout**, so `docker logs` and the stack tool's `logs
   <service>` read the same stream; a file log inside the container is
   lost with it.
6. **Memory is a limit on the container**, sized as the unit's
   `MemoryMax` is today, and the README states the number and what it
   is sized for.

The compose files are not the service's to hold: the dev stack's lives
in the experiments repo beside the stack spec, a box's in
`gridworks-infra`, and each names only what that stack runs. The order
is the Open item's: the uv packages first, with the FLO as the worked
example, then the registry it takes its identity from, then
journalkeeper and web-backend; the scada joins after OPS-661.

**FLO notes.** The service is stateless but for one directory, bruce's
matrix cache, which becomes the one named volume; a matrix placed by
hand today is a file copied into that volume until the manifest
command exists. The image needs bruce built in from the private
`optimal-flexibility` repo at a pinned commit, which is a build-time
credential and nothing the running container holds. The build pool's
worker processes are plain subprocesses, so the container's default
`/dev/shm` of 64 MB is more than it uses and `--shm-size` stays unset.
The memory limit is `GWFLO_WORKERS` builds at the largest plant shape
plus the actor, the number the unit's `MemoryMax` states today. The
production container mounts the `hw1.flo` identity file and its client
certificate read-only; the dev container mounts the `d1.flo` file and
no certificate, the item 3 posture.

## Open

- Whether the stack spec becomes a sema word once two tools read it
  (the devstack tool and, later, a box's service inventory), or stays a
  typed record in the experiments repo.
- Whether `gw-dev-rabbit`'s topology (the `ear_tx` binding the gateway
  needs) is part of the broker's dev state or a stack-level step.
- Where the dev-run login for web-backend lives once roles are seeded
  by a command rather than by hand.
- **Docker compose.** The experimentation-tools spoke (OPS-40) set the
  rule: pre-docker while an experiment is a handful of actors, compose
  when hand-launching is the bottleneck. The 2026-11-05 stand-up was
  that bottleneck. A compose stack needs each service to build as a
  container, and the scada cannot before OPS-661 (scada-to-uv), so the
  order is: the contract items per service, `devstack.py` as the
  pre-docker orchestration, compose for the services that are already
  uv packages (registry, FLO, journalkeeper), the scada joining after
  OPS-661. Whether compose then replaces `devstack.py` or sits under it
  is open.
- **The production twin.** `gridworks-infra/new-platform-service.md` is
  the box version of the laptop stand-up (alias, identity file,
  broker definitions, checkout, unit, first-start check). The two
  recipes should mirror each other step for step, so a service's dev
  posture and its deployed posture differ only in settings. Infra stays
  the record of deployed boxes; the laptop tool stays in experiments.

## Do this next

Take the contract to Pass 1 against both standing tables, with item 5
widened to the config home and the management-API probe under item 4.
Then the first per-service fix is the one that cost the most on
2026-11-05: a `home` command on the FLO and the registry that writes the
service's config files idempotently, and a `template.env` in the
experiments repo.
