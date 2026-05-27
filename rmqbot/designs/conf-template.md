# conf-template

Status: Draft · Pass 0 · Updated 2026-05-27

> Collapse the two RabbitMQ conf files (`for_docker/dev_rabbitmq.conf`
> for `d1__1` and `rabbit/rabbitconfig/rabbitmq.conf` for `hw1__1`)
> into **one minimal, parameterized template**.

## Why

Once `identities-in-definitions` lands, the two conf files differ in
exactly one line: `mqtt.vhost` (`d1__1` vs `hw1__1`). The
`management.load_definitions` path is the same on both sides. Keeping
two near-identical conf files invites drift.

## The shape

One template file with the vhost as the only env-substituted
variable:

```
mqtt.vhost = ${MQTT_VHOST}
management.load_definitions = /etc/rabbitmq/definitions.json
# ... rest identical across envs ...
```

`MQTT_VHOST=d1__1` in dev, `MQTT_VHOST=hw1__1` in prod. Single source
of truth.

## Dependencies

- **`identities-in-definitions`** must land first — otherwise the
  conf still differs on the identity lines.

## Cross-refs

- [`identities-in-definitions.md`](identities-in-definitions.md) —
  prerequisite.
