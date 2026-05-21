# gridworks-base — TODO

Operational follow-ups not yet done. (Design/spec lives in `executor/`;
this is the lightweight backlog.)

## Validate the multi-arch dev-broker image on real hardware

The dev broker moved to one official multi-arch image
(`ghcr.io/thegridelectric/dev-rabbit`, `rabbitmq:4.1-management` base,
arm64 + amd64). Risk is low (our Dockerfile is `COPY`-only — no `RUN`, so no
QEMU-emulation correctness concern; the base is natively built per-arch
upstream), but we want field confirmation before relying on it:

- [ ] **Confirm the published manifest** lists both arches:
      `docker buildx imagetools inspect ghcr.io/thegridelectric/dev-rabbit:latest`
      → expect `linux/amd64` + `linux/arm64/v8`.
- [ ] **arm64 smoke test** (can run locally on Apple Silicon, on alternate
      ports so it doesn't disturb a running `gw-dev-rabbit`).
- [ ] **x86 / amd64 smoke test** — needs an x86 box. **(deferred)**
- Smoke checklist (each arch): boots; `rabbitmqctl status` clean;
  definitions loaded (`list_exchanges` shows `ltn_tx`/`super_tx`/…,
  `list_users` shows `smqPublic`); management UI `:15672`; MQTT `:1885`;
  a gwbase actor connects + consumes (run `uv run pytest` / `hello_rabbit.py`
  against it).

Context: this is the "tire-kick a first gwbase actor in dev" gate that, once
passed, unblocks the **deferred prod RabbitMQ 4.x upgrade** (see
`../../rmqbot/research/broker-todos.md`).

## One-time GHCR setup

- [ ] First push of `ghcr.io/thegridelectric/dev-rabbit` (CI workflow
      `broker-image.yml`, or manual via `rabbit/build-and-push.sh`).
- [ ] Set the GHCR package **visibility = Public** so other repos pull
      without auth.
