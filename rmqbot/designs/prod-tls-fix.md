# prod-tls-fix

Status: Draft · Pass 0 · Updated 2026-06-25 · Linear: OPS-423

> Fix the broken TLS configuration on the prod broker `hw1__1`. Today
> the broker is **not using TLS correctly** (per `authority/certbot`
> notes). Encryption-only is the immediate goal; mutual TLS auth is a
> later track.

## Why

- Plaintext credentials over the public internet between SCADAs and
  the broker is a current exposure.
- It blocks the FIS auth model (mTLS, cert CN = `GNodeId`) — see
  [`../../gridworks-fleet-index-service/research/lifecycle.md`](../../gridworks-fleet-index-service/research/lifecycle.md).

## The fix

Follow the
[gridworks-proactor TLS](https://github.com/SmoothStoneComputing/gridworks-proactor/tree/dev#tls)
setup. There is a sample rabbit config there that needs to be
copied; the current one is misconfigured. **Encryption only** —
broker access stays password-based for now.

**Fold in the conf cleanup:** while you're editing the broker conf for TLS,
collapse the two near-identical conf files into one parameterized template — the
conf needs real changes here anyway.

## Verification

Test plan (from `rmq-docker/README.md`):
- `mosquitto_pub` / `mosquitto_sub` on port 8883 (MQTT-over-TLS)
- Management UI on `https://hw1-1.electricity.works:15671/`

## Cross-refs

- `gridworks-infra/authority/certbot/README.md` — the source-of-truth
  for the current broken state.
- `authority/tls/tls-certs.md` — the planned phase architecture (Phase
  0 is this design).
