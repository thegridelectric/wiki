# prod-4x-upgrade

Status: Draft · Pass 0 · Updated 2026-05-27

> Upgrade the prod broker `hw1__1` from RabbitMQ 3.9.13 (EOL) to 4.x,
> after the new 4.x dev broker has been kicked-the-tires by a first
> gridworks-base actor.

## Why

3.9.13 is at/near community EOL. Don't anchor new security-critical
auth work (mTLS, FIS) on an unsupported line. The dev-broker
upgrade-and-validate path de-risks the prod jump.

This is `gridworks-base open #6` (resolved as deferred).

## The sequence

1. **Dev first.** Stand up the new dev broker on RabbitMQ 4.x,
   GHCR-published image, new generated definitions. Validate a first
   gwbase actor end-to-end. *(Note: the integration test on
   2026-05-26 — gwwf→gjk on `gw-dev-rabbit` — was an instance of
   this. 22 weather messages flowed cleanly. Validated.)*
2. **Then prod.** Upgrade `hw1__1` to 4.x. The prod target matches
   dev, so the dev validation transfers.

## Intentional dev/prod parity suspension

Until step 2 lands, **dev and prod intentionally run different
RabbitMQ majors** (dev 4.x, prod 3.9.13). The generated definitions
are kept **version-agnostic** — plain exchanges / bindings / queues /
identities, no 4.x-only features — so the *same* topology loads on
both.

## Dependencies

- **`prod-tls-fix`** SHOULD land first (TLS work belongs on 4.x, not
  on the EOL 3.9 line).
- After this lands, unblocks: `mtls-fis-auth`,
  `analytics-broker-shovel` (analytics-broker SHOULD run the same
  major as prod for shovel compatibility).

## Cross-refs

- [`prod-tls-fix.md`](prod-tls-fix.md).
- [`analytics-broker-shovel.md`](analytics-broker-shovel.md).
- [`../research/concerns/mtls-fis-auth.md`](../research/concerns/mtls-fis-auth.md).
