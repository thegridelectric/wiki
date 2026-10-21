# dev-run — the design on the laptop's d1 stack

Status: Accepted · Pass 1 · Updated 2026-10-20 · Linear: OPS-473

> What this is: the fourth spoke of the disentangle-installations hub,
> the experiment that verifies the whole design before anything merges
> to `main`: a dev cedar. A new house enters the `d1` registry and a dev
> PII store through the onboarding sequence with scrambled person data,
> its simulated scada sends its layout over the dev broker, and the
> dashboard shows it from the `layouts` row. Every moving part is
> present: dev gnr, dev store and CLI, dev broker, local TimescaleDB,
> gjk, web-backend's API and gateway, the frontend, a sim scada.
> onboard-cedar stays the production run and waits for launch.

## Do this next

Runs once, with every moving part present, after the retire-installations
frontend branch exists: sema `jm/layout-bundle`, gjk `jm/layouts-projection`
(`d435ff0`), web-backend `jm/retire-installations` (`98df82a`) and the
frontend branch, all nine steps of "The sequence" in one run. The harness
and captures go in `experiments/2026-10-20-disentangle-dev-run/`.

## Why a dev run

The unit suites of the three repos share a wall clock and a backdoor
transport: web-backend's tests seed `layouts` rows by hand and gjk's
tests call the projection directly. Neither shows that a `layout.lite`
sent on a broker ends as a row the dashboard reads, nor that the gateway
has a house's layout before that house's scada speaks. This run does.

## The stack

All on the laptop, nothing on a deployed box:

- **Broker:** `gw-dev-rabbit`, AMQP `localhost:5672`, MQTT `localhost:1885`,
  vhost `d1__1`. Started from gridworks-base (`./arm.sh`).
- **Database:** the local TimescaleDB on `localhost:5433`, roles from
  `1_db_user_setup_dev.psql`, schema from gridworks-data `alembic upgrade
  head` on `main` (migration `b7d2e4f6a8c1` creates `layouts`).
- **gjk:** `jm/layouts-projection`, `.env` with the dev broker URL and
  the default dev `db_url`.
- **web-backend:** `jm/retire-installations`; the API and the gateway
  with `BACKEND_TSDB_URL` on the local database as `gw_visualizer` and
  the gateway's rabbit settings on the dev broker. The gateway binds
  `gw.#` on `ear_tx`; the dev broker's topology has that exchange or
  the run says what it lacks.
- **Scada:** the Nolan sim from gridworks-scada's test fixtures, placed
  by `experiments/put_layout.sh dev`, speaking MQTT to the dev broker as
  `d1.isone.me.versant.keene.beech.scada`.
- **Registry:** the `d1` gnr, reached by `gnregistrar`, broadcasting its
  forest on the dev broker so gjk fills `g_nodes` the production way.
- **Store:** a dev gridworks-pii database, separate from the production
  box's, with the operator CLI pointed at it. The scrambled customer is
  the only row the run adds.
- **Logins:** one admin role with a null `ta_g_node_id`, inserted by the
  harness, since the role tables have no seed on a fresh database.

## The sequence

Steps 1 and 2 are onboard-cedar's first two steps, run in `d1` with
scrambled data; the rest is the layout path and the dashboard.

1. **Registry.** The operator runs `gnregistrar create` against the dev
   gnr and enters the pending TerminalAsset
   `d1.isone.me.versant.keene.cedar.ta` and its LTN. The registry mints
   the GNodeId; the forest broadcast reaches gjk and the `g_nodes` rows
   appear. Capture: the rows, the GNodeId, no position.
2. **Store.** The operator runs `add-customer <that GNodeId>` against the
   dev store with a scrambled customer: an invented name, street, city,
   ZIP, email, phone and installer that match no real person. The CLI
   mints a label. Capture: `show <GNodeId>`, the change record's one row.
3. **Layout.** gjk is running. The sim scada starts as
   `d1.isone.me.versant.keene.cedar.scada` with a cedar layout (the Nolan
   sim fixtures with the alias changed). Its first `layout.lite` is
   journaled and projected. Capture: the `layouts` row keyed by the
   registry's GNodeId, `sent_at` against the message `timestamp`,
   `from_alias` = the scada alias.
4. **Summaries.** `GET /api/v2/installations/*/summaries` as an admin
   login: cedar listed, `TaGNodeId` the registry's id, `DisplayName` the
   registry's, `LayoutLite` present, `SystemMode` from the row, no person
   field. Capture: the response.
5. **Gateway seed.** Stop the scada. Start the gateway with the scada
   silent. Capture: the seed log line and `/gateway/health` with cedar
   `layout_loaded` true and `snapshot_loaded` false before any message.
6. **Layout change.** Change the sim's system mode, restart the scada.
   Capture: the row's new `SystemMode` and `sent_at`, the summaries'
   `SystemMode`, the gateway's status message over the websocket.
7. **Replay guard.** Publish the step-3 message body again on the broker
   with its original timestamp. Capture: the row unchanged, gjk's log
   line for the skipped write.
8. **Dashboard.** The frontend against the API: cedar in the house list
   by display name; Hardware shows the layout; the real-time page's
   sieg default comes from the layout; Parameters opens on defaults;
   Address and Contact are dark. Capture: screenshots.
9. **Not reporting.** With the scada stopped past the snapshot bound (or
   the bound shortened for the run and said so): the summary keeps
   `LayoutLite` and nulls `LatestSnapshotTime`; the dashboard shows
   cedar as not reporting.
10. **No person anywhere.** A grep of the journal's `messages`, every
    other gw_data table, the dev broker's queues and the API's responses
    finds neither the scrambled name nor the street. Only the store has
    them.

## What pass means

Every capture in the sequence matches its expectation. Steps 3 to 7 and
10 rerun unattended from the harness; steps 1, 2, 8 and 9 are run by a
person and read from the captures. A step that fails gets its local test first
(base-CLAUDE "A field bug gets its local test first"), then the fix,
then the rerun.

## Result

Not yet run.

## Open

- Where the dev gnr runs for this run (a `d1` instance on the laptop or
  a dev box) and whether `gnregistrar` can point at it; and where the
  dev PII store runs (a loopback Postgres on the laptop is the natural
  twin of the production box). Both are settled when the harness is
  written.

- Whether the dev broker's topology has the `ear_tx` fleet-stream
  exchange the gateway binds. If not, the harness declares it for the
  run, and the gap is a gridworks-base note.
- The sim scada's alias is in `d1`; the gateway's status keys on the
  short alias and web-backend's roles on the TA id, so no `hw1`
  assumption is expected in the path. The run confirms it.
