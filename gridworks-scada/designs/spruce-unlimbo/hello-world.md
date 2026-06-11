# Hello-world: LTN ↔ SCADA over dev rabbit, seen by a dev JK

Status: Draft · Pass 0 · Updated 2026-06-10

> What this is: spruce-unlimbo spoke — the plan's first executable step.
> Get a real LTN and a real SCADA, both on `jm/spruce-unlimbo` with the
> nolan layout, exchanging messages over `gw-dev-rabbit`, with a dev
> JournalKeeper consuming the exchange off the broker. The comms
> substrate proven before any control work builds on it.

## Why this is first

- It exercises the whole pipe — layout load, actor bring-up, broker
  links, topic grammar, JK parse/persist — on the branch we intend to
  stabilize, with zero control-logic risk.
- Its byproduct is verifying the cold-start recipe, which lives in
  `executor/running.md` (created 2026-06-10 — the dry-run path verified,
  the live-broker path `told` until this step confirms it). Durable
  facts found along the way go there, not here.
- It extends the verified 2026-06-09 experimentation-rig run (patched
  LTN → JK over `gw-dev-rabbit`, see `executor/experimentation-rig.md`)
  from one-sided emission to a real two-process exchange.

## Building blocks (verified 2026-06-10 unless noted)

- `gws run --dry-run` and `gws ltn run --dry-run` both pass on
  `jm/spruce-unlimbo` after two fixes: `.env` layout paths now point at
  `tests/config/nolan-layout.json` (the rename left them dangling), and
  nolan-layout.json's config versions bumped to match the gleaned
  RelayActorConfig 003 / I2cThermistorChannelConfig 001.
- Broker: `gw-dev-rabbit` (docker) — AMQP 5672, MQTT 1885 (non-TLS),
  management 15672, vhost `d1__1`, anonymous → `smqPublic`. MQTT
  publishes bridge onto `amq.topic`. (From experimentation-rig.md.)
- JK observer: runs against the dev broker with the unpublished
  gridworks-base branch (`uv run --with-editable …`); catch-all
  `routing_key="#"` bind; recorder in place of the DB persistor.
  (Verified 2026-06-09.)
- LTN: `gws ltn run` exists; needs `LTN_SCADA_MQTT__{HOST,PORT,
  TLS__USE_TLS}` pointed at the broker and its own config-dir layout
  copy (`~/.config/gridworks/ltn/…` — the known rig friction).

## Definition of done

1. From a clean checkout of `jm/spruce-unlimbo`, following ONLY a
   written recipe: SCADA up via `gws run`, LTN up via `gws ltn run`,
   both against `gw-dev-rabbit`, nolan layout.
2. Bidirectional traffic observed: LTN→scada (`gw.<ltn>.to.s.<type>` —
   e.g. gridworks-ping / send-layout) and scada→LTN, all PARSED by the
   dev JK (no drops, no legacy_hack needed for this branch's types).
3. `executor/running.md`'s live-broker path is upgraded from `told` to
   verified, and a fresh Claude session reproduces it cold — that
   session's transcript is the verification.
4. Snags found on the way (TLS-off flags, cert expectations, config-dir
   setup) are fixed or documented, not worked around silently.

## Open

- Does the scada side connect to dev rabbit cleanly with
  `SCADA_GRIDWORKS_MQTT__*` env overrides alone (TLS off), or does the
  cert plumbing get in the way? (.env has the commented block ready.)
- What does the scada→LTN direction emit unprompted on the nolan layout
  (status/snapshot cadence), and is that enough for "bidirectional" or
  do we drive one message by hand?
- Dev JK setup: still needs the unpublished gwbase branch — coordinate
  with the JK live-test work before calling the JK leg reproducible.
- Whether `running.md` should fold in the local-mosquitto variant (no
  rabbit, no JK) as the lighter recipe for scada-only claudes.
