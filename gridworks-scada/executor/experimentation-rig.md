Status: Draft · Pass 0 · Updated 2026-06-09

# Experimentation rig — standing the scada/LTN up on a real broker

What this is: the **as-is** mechanics for running the scada side as a participant
in a broker-based **experiment** (not a test) — messages cross a real RabbitMQ,
never an in-process backdoor. Written from a live run: a patched LTN's messages
reaching a JournalKeeper over `gw-dev-rabbit`. The reusable-tooling wishlist this
exposed is the `experimentation-tools` spoke of the
`simulated-test-environment` design (this domain's `designs/`); the
methodology (experiment vs test) is in [`../../world/primary.md`](../../world/primary.md).

> **Experiment, not test.** The in-process `ScadaLiveTest` harness
> ([`testing.md`](testing.md)) links proactors with a same-process transport —
> great for tests, but it is exactly the backdoor an experiment must avoid. An
> experiment points each actor at a **real broker**.

## The broker

`gw-dev-rabbit` (docker, `ghcr.io/thegridelectric/dev-rabbit`) exposes:
- **AMQP** `5672`, **MQTT** `1885`, **management** `15672`.
- vhost **`d1__1`**; anonymous connections map to **`smqPublic`** (so no creds
  needed). MQTT publishes are bridged onto the **`amq.topic`** exchange.
- It already carries the gwbase topology (a consumer can assert `ear_tx`).

## Consumer side — JournalKeeper observer (verified)

Run JK against the dev broker **with the unpublished gwbase branch** (the
tolerant parser + `on_routing_key_parse_error` hook), via
`uv run --with-editable /…/gridworks-base python <script>` from the gjk repo.

- Env: `GJK_RABBIT__URL=amqp://smqPublic:smqPublic@localhost:5672/d1__1` and
  **`GJK_SERVICE_ALIAS=d1.journalkeeper`** (the 3-tier base requires
  `service_alias`; JK's `.env` predates it — OPS-386).
- Bind catch-all: `queue_bind(jk.queue_name, "amq.topic", routing_key="#")` in a
  `local_rabbit_startup` override (sees everything bridged from MQTT).
- To observe parsing **without a DB**, swap `jk.persistor` / `jk._persist_body`
  for a recorder and wrap `dispatch_message` + `on_routing_key_parse_error` to
  log. Then `PARSED` vs `PARSE-ERR → legacy_hack` is visible per delivery.

## Producer side — the LTN

The patched LTN emits `gw/<src>/to/<dst>/<type>` (proactor topic grammar),
bridged to AMQP `gw.<src>.to.<dst>.<type>`: `to/s` (scada), `to/mm`
(MarketMaker). Two ways to produce on the broker:

- **Full `LtnApp` (the real thing, still being wired):** `LtnApp.get_repl_app(
  start=True, …)` boots the LTN in a thread. Point its `SCADA_MQTT` link at the
  dev broker with `LTN_SCADA_MQTT__HOST=localhost`, `LTN_SCADA_MQTT__PORT=1885`,
  `LTN_SCADA_MQTT__TLS__USE_TLS=false` (non-TLS 1885; `MQTTClient.effective_port`
  uses `tls.port` only when `use_tls`). Needs a hardware layout + config dir
  (the framework expects `~/.config/gridworks/ltn/…`; `gwproactor_test` does this
  via an isolated XDG dir — outside pytest it must be set up by hand). Then drive
  a single emit by routing a typed `Message` (e.g. `FloNextHourPlans`) to the
  prime actor. **Open:** the clean one-call "emit type X once" entry point.
- **Wire-faithful publisher (stopgop, used to verify the consumer):** publish the
  exact bytes to `amq.topic`/`d1__1` with pika. Still through the real broker, so
  not a backdoor — but it bypasses the LTN's own code. Use only until the
  `LtnApp` path is wired.

## Verified run (2026-06-09)

**Real `LtnApp` against `gw-dev-rabbit`.** Booted via
`LtnApp.get_repl_app(app_settings=LtnSettings(_env_file=dotenv.find_dotenv()))`
with `LTN_SCADA_MQTT__{HOST=localhost,PORT=1885,TLS__USE_TLS=false}`; layout
linked by copying `tests/config/hardware-layout.json` into
`~/.config/gridworks/ltn/hardware-layout.json` (the friction the "experimental
actor" tool should remove); one `Glitch` driven through `process_ltn_message`.
The JK observer saw, from the **real LTN**:
`gw.…orange1.to.s.gridworks-ping` (LTN liveness — the original dropped class!),
`…to.s.send-layout`, and `…to.s.glitch` — **all PARSED, no drops**.

A prior round used a wire-faithful pika publisher and additionally exercised
`…to.mm.bid` → **PARSED** and `broadcast.glitch` → **PARSE-ERR → legacy_hack**
(source recovered from `Header.Src`). Together: the gridworks-base tolerant
parser + the gjk `legacy_hack`, confirmed end to end on a real broker by a real
actor.

## Gotchas (rig friction → see the harness design)

- Two scada checkouts + a per-checkout venv ([`environment.md`](environment.md)).
- JK needs the gwbase **branch** (unpublished) — `--with-editable`.
- `service_alias` required; dev creds anonymous; non-TLS port is `1885` not 1883.
- Each side hand-rolls broker-pointing env + an observer/recorder + an emit
  trigger. That repetition is what the harness tooling should remove.
