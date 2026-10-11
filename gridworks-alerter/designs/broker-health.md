# broker-health

Status: Draft · Pass 0 · Updated 2026-10-11 · Linear: OPS-585

**EDD: yes** each alert is verified by causing its condition on a real
broker (the shovel stopped, a queue filled past its threshold, a memory
alarm forced with a low watermark on the dev broker) and seeing the
alert reach its receiver, then resolve.

> What this is: monitoring for the two hw1 brokers and the shovel
> between them: Prometheus on the alerts box scrapes RabbitMQ's own
> metrics from prod (`hw1-1`) and the analytics tap (`hw1-tap`) and the
> shovel's counters, and its rules raise to Alertmanager.

## Why

Nothing watches either broker today. A memory or disk alarm on prod
blocks every publisher in the fleet; on the tap it stops the mirror the
web realtime gateway and dashboards read. The shovel's capacity limits
(gridworks-infra `rmqtap/instance-README.md` "Capacity and faults") show
up first as lag, long before anything breaks, and nobody would see it.
A gauge with a threshold gives that warning while there is still time to
act, instead of an outage.

## The shape

```
prod broker  ──:15692──┐
tap broker   ──:15692──┼──► Prometheus (alerts box) ──► Alertmanager ──► receivers
shovel       ──/metrics┘         rules
```

- **RabbitMQ's `rabbitmq_prometheus` plugin** on both brokers, on its
  own port (15692), reachable only from the alerts box (AWS security
  group on prod, the Hetzner firewall on the tap). Per-object metrics
  (queue depth per queue) are on, since the shovel's queue on prod is
  the one we most need.
- **The shovel exposes `/metrics`**: messages heard, forwarded and
  dropped, buffer length, seconds since the last forward. These are the
  counters it already logs hourly.
- **Prometheus on the alerts box** scrapes all three over HTTP. Checks
  of a broker do not go through that broker.
- **Alertmanager** routes, as already proposed in OPS-547. This design
  adds rules, not a second router.

## Alerts

Severities follow the glitch scale: Warning is looked at during the
day, Critical pages on-call.

| alert | condition (first guess) | severity |
|---|---|---|
| prod broker alarm | memory or disk alarm raised on `hw1-1` | Critical |
| prod headroom | memory over 70 % of the watermark, or disk free under 2× the limit, for 15 min | Warning |
| prod connections or file handles | over 80 % of the limit | Warning |
| shovel lag | shovel queue on prod over 1,000 messages for 5 min | Warning |
| shovel gone | no consumer on a `hw1.shovel-*` queue on prod, or the shovel's scrape down, for 5 min | Warning |
| mirror silent | prod `ear_tx` publishing and nothing forwarded for 10 min | Warning |
| shovel dropping | dropped count rising | Warning |
| tap broker alarm | memory or disk alarm raised on `hw1-tap` | Warning |
| tap headroom | as prod headroom | Warning |
| certificate expiry | the tap's Let's Encrypt certificate within 14 days of expiry | Warning |

The tap's alarms are Warning, not Critical: losing the tap loses the
live view, never data or control.

## Scope of work

1. Enable `rabbitmq_prometheus` on the tap broker (its compose and
   `enabled_plugins` in gridworks-infra) and open 15692 to the alerts
   box only.
2. The shovel's `/metrics` endpoint (gridworks-shovel), also open to the
   alerts box only.
3. Prometheus on the alerts box with the scrape config and the rules
   above, deployed like the other services there.
4. Enable the plugin on prod, with the port open to the alerts box only.
   A change to the live broker: the plugin load and the security group
   rule are steps Jessica runs.
5. Each alert witnessed once against reality, then the thresholds
   recorded with the box READMEs.

## Do this next

Step 1 on the tap: enable the plugin and read its output from the
alerts box. The tap is the safe place to learn the metric names the
rules need before prod is touched.

## Open questions

- Who watches Prometheus? A dead Prometheus raises nothing. An
  always-firing watchdog alert sent to an outside check-in service is
  the usual answer.
- Retention: Prometheus defaults to 15 days on local disk. Enough for
  alerting; longer only if we want capacity trends.
- Grafana: not needed for alerting. Worth adding only if someone will
  look at the trends.
- The shovel lag threshold: set from the shovel's measured ceiling on
  the box, with room to act before it is reached.
