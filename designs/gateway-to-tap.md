# gateway-to-tap

Status: Accepted · Pass 1 · Updated 2026-10-11 · Linear: OPS-586

**EDD: yes** the gateway consuming `ear_tx` on the tap over AMQPS and
pushing live house updates is the verification; a claim reaches Verified
only when it runs against the real tap broker and the live fleet stream.

> What this is: moving the web-backend realtime gateway
> (`gridworks-web-backend/gateway/`) off the prod broker and onto the
> analytics tap, with its first sema snapshot. It is the last password
> client on prod; once it is off, OPS-578 can close plaintext 5672.

## Today

`gateway/config.py` connects as `smqPublic` to
`amqp://hw1-1.electricity.works:5672/hw1__1` (plaintext), with the
password defaulting to `"PASSWORD"`. `gateway/consumer.py` binds `gw.#`
on `amq.topic` with a server-named exclusive queue, keeps `layout.lite`
and `snapshot.spaceheat` from `*.scada` sources, and reads them as raw
`json.loads` dicts.

## Security

- Connects to `amqps://web.gateway:<pw>@hw1-tap.electricity.works:5671/hw1__1`.
  TLS against the system CA bundle; no client cert.
- `web.gateway` already exists on the tap: configure and write
  `^web\..*$`, read `ear_tx` and its own queues, publish nowhere
  (gridworks-infra `rmqtap/instance-README.md` "Broker logins").
- The queue is named `web.gateway.<uuid>` and declared exclusive; a
  server-named `amq.gen-*` queue falls outside the login's configure
  permission.
- Binds `gw.#` on `ear_tx`. Prod copies `amq.topic` into `ear_tx` with
  `#`, and routing key and body cross the shovel verbatim, so a scada's
  messages keep `gw.<scada-alias-with-dashes>.to.ltn.<type-name>`, the
  grammar `decode_routing_key` reads (gridworks-infra
  `rmqtap/instance-README.md` "A walk through the panel":
  `gw.*.to.ltn.snapshot-spaceheat`). `app_id`, `user_id` and
  `correlation_id` do not cross.
- The password is required with no default; user, host, port and vhost
  come from the gateway's `.env`.

## Sema

- The gateway vendors its own snapshot and keeps using every sema word
  it already reads, at the versions the fleet sends, plus `report.event`:

  | Boxes on | `layout.lite` | `report.event` | `snapshot.spaceheat` |
  |---|---|---|---|
  | `main` (every house but spruce) | 011 | 002 | 003 |
  | `actual-spruce` (spruce) | 012 | 003 | 003 |
  | `jm/spruce-unlimbo` (window) | 013 | 004 | 003 |

  013 stays staging; this pass does not publish it.
- `gw.house.operating.status` (staging) stays out of this pass. 013 drops
  `SystemMode` from the layout, so the gateway shows no system mode for
  boxes sending 013; it picks the posture facts up under OPS-542.
- Every message the gateway keeps is decoded through the snapshot codec
  and narrowed to its class; no raw dicts.
- Reading channels by the layout word instead of by name (the thermostat
  pattern match in `gateway/state.py`) comes later under OPS-542.

## When it is off prod

OPS-578 closes plaintext 5672 and rotates the default password, and
`analytics.ear.reader` is removed from prod if no consumer remains on it.

## The experiment (the EDD bar)

1. The gateway connects to the tap with `web.gateway`, declares its
   `web.*` queue and receives fleet traffic on `ear_tx`.
2. Every `report.event` from a scada decodes through the snapshot, for
   each of 002–004 present on the wire.
3. A browser connected to the gateway sees spruce update live.

## Deploy and verify (do this next)

The code is merged on `jds/tsdb_api` (`817933c`). web-api2 (`ubuntu`,
`gridworks-hybrid` key; gridworks-infra `platform-inventory.md`) has the
checkout at `~/gridworks-web-backend` on that branch, clean and behind
origin by the merge; its `.venv` already has pydantic, pydantic-settings
and aio-pika at versions the new code runs on, so no sync is needed. Its
`.env` has only `BACKEND_RABBIT_PASSWORD`.

1. `git pull` on the box.
2. `.env`: set `BACKEND_RABBIT_PASSWORD` to the tap's
   `WEB_GATEWAY_PASSWORD` (a human does this; the value is on the tap box
   and in 1Password), and add `BACKEND_RABBIT_USER=web.gateway`,
   `BACKEND_RABBIT_HOST=hw1-tap.electricity.works`,
   `BACKEND_RABBIT_PORT=5671`, `BACKEND_RABBIT_VHOST=hw1__1`.
3. `sudo systemctl restart gridworks-gateway`;
   `journalctl -u gridworks-gateway -n 30` shows
   `Consuming 'gw.#' on 'ear_tx' through queue 'web.gateway.<uuid>'`.
4. The experiment: `curl localhost:8100/gateway/health` on the box fills
   with every house (`layout_loaded`, `snapshot_time_unix_ms`,
   `report_time_unix_ms` advancing); a browser on a house page updates
   live; the tap's management UI lists the `web.gateway.<uuid>` queue;
   the journal shows no decode errors for `layout.lite` 011 and 012,
   `snapshot.spaceheat` 003 or `report.event` 002–004. A 013 decode is
   seen only while a `jm/spruce-unlimbo` window runs.
5. After it holds: `platform-inventory.md` row for web-api2 names
   `web.gateway` on the tap as the gateway's login; stamp this design
   Verified with `Reviewed`; distill into
   `gridworks-web-backend/executor/primary.md` (the tap-consumer
   invariant is already there), delete this file, finalize OPS-586 with
   hours; OPS-578 can then close 5672 on prod.

## Open

- None.
