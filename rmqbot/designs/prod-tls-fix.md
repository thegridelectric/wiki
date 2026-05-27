# prod-tls-fix

Status: Draft · Pass 0 · Updated 2026-05-27

> Fix the broken TLS configuration on the prod broker `hw1__1`. Today
> the broker is **not using TLS correctly** (per `authority/certbot`
> notes). Encryption-only is the immediate goal; mutual TLS auth is a
> later track (see [`../research/concerns/mtls-fis-auth.md`](../research/concerns/mtls-fis-auth.md)).

## Why

- Plaintext credentials over the public internet between SCADAs and
  the broker is a current exposure.
- It blocks the FIS auth model (mTLS, cert CN = `GNodeId`) — see
  [`../../gridworks-fleet-index-service/research/lifecycle.md`](../../gridworks-fleet-index-service/research/lifecycle.md).
- It blocks the `analytics-broker-shovel` design (the shovel link
  itself needs TLS).

## The fix

Follow the
[gridworks-proactor TLS](https://github.com/SmoothStoneComputing/gridworks-proactor/tree/dev#tls)
setup. There is a sample rabbit config there that needs to be
copied; the current one is misconfigured. **Encryption only** —
broker access stays password-based for now.

## Verification

Test plan (from `rmq-docker/README.md`):
- `mosquitto_pub` / `mosquitto_sub` on port 8883 (MQTT-over-TLS)
- Management UI on `https://hw1-1.electricity.works:15671/`

## Dependencies

None on the analysis side. On the execution side, this is a
prerequisite for:
- `analytics-broker-shovel`
- `mtls-fis-auth` (Phase 0 of the planned security architecture)
- `prod-4x-upgrade` (TLS work should land on 4.x, not on the EOL 3.9)

## Cross-refs

- `gridworks-infra/authority/certbot/README.md` — the source-of-truth
  for the current broken state.
- `authority/tls/tls-certs.md` — the planned phase architecture (Phase
  0 is this design).
