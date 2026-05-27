# identities-in-definitions

Status: Draft · Pass 0 · Updated 2026-05-27

> Move broker users/vhosts/permissions out of the `rabbitmq.conf`
> (`default_vhost` / `default_user` / `default_pass` /
> `default_permissions.*`) and into the **generated definitions JSON**.
> The definitions file becomes the single source of truth for both
> identity and topology.

## Why

The current split — conf-level `default_*` lines for identity,
load_definitions for topology — has an unfortunate import-order
ambiguity (when RabbitMQ first boots, which wins?). Resolved by
collapsing both into the generated definitions, where the order is
defined by the file itself.

RabbitMQ definitions natively support `password_hash`, so no
plaintext secrets need to live in the JSON.

This is resolved as `gridworks-base open #5`.

## The two variants

**Dev (`d1__1`, GHCR public image):**
- The `smqPublic` user + its hash is committed in the dev definitions.
- Non-secret (password = `smqPublic`). Fine to bake into the public
  image.

**Prod (`hw1__1`):**
- Do **NOT** bake the prod user/hash into any published artifact.
- Inject at deploy via one of:
  - [docker compose secrets](https://docs.docker.com/compose/use-secrets/)
  - [conf env-variable interpolation](https://www.rabbitmq.com/configure.html#env-variable-interpolation)
  - Keep the prod definitions file private (and inject via that)
- Decide which during execution.

## Subsumed TODOs

This design subsumes two historical TODOs from `broker-todos.md`:
- "remove hardcoded user/pass from `rabbitmq.conf`" (the
  `THE_PASSWORD` placeholder)
- "replace username references in `rabbit_definitions.json` with
  something indirect"

## Dependencies

None. Composable with everything else.

## Cross-refs

- [`conf-template.md`](conf-template.md) — once identities leave the
  conf, this design becomes possible.
- [`../../gridworks-base/`](../../gridworks-base/) — generates the
  definitions.
