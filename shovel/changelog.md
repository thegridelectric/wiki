# Changelog

A reverse-chronological log of WHY we made each commit in the
`gridworks-shovel` code repo. The matching git commit holds the WHAT
(the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

Newest at the top.

## 2026-10-11 — Improved names; queue cap both on tap and on its own queue in prod (`d827169`)

The destination exchange is renamed from `earmic_tx` to `shovelmic_tx`:
gwbase has no `earmic_tx`, its grammar is one `<name>mic_tx` per
publisher fanning into `ear_tx`, and the shovel is the publisher here.

Queues are capped on both brokers. On the analytics broker the
definitions file's policy becomes `queue-cap` on `.*`: at most 10,000
messages, oldest dropped, and a queue idle (no consumer, no reads) for
an hour is deleted, so a queue bound by hand from the panel and
forgotten cannot fill the box. On prod the shovel declares its own
source queue with `x-max-length` (`source_queue_max_length`, 10,000) and
`x-overflow: drop-head`. Acking on receipt kept prod safe only while the
analytics broker was down; a shovel that falls behind or waits on a
blocked analytics broker would grow that queue on prod, whose only policy is
`debug-cap`. The override is the shovel's `setup_queue`; gwbase is
untouched.

The analytics publisher sets `blocked_connection_timeout`
(`blocked_timeout_seconds`, 10), so a publish the analytics broker holds
blocked during a memory or disk alarm fails, the message goes to the
in-memory buffer, and the consumer thread keeps answering prod's
heartbeats. The env template and the tests follow; new unit tests cover
the source queue's arguments and the connection parameter.

The shovel needs gwbase 0.5.17. gwbase 0.5.16 consumed with prefetch 1,
so the shovel waited one round trip to prod, about 110 ms, for every
message: a ceiling near 9 messages a second, and a lag of about 10 s
behind the once-a-minute burst of snapshots at 100 homes. 0.5.17 makes
prefetch a service setting with default 100, which the shovel takes
with no code of its own (`SHOVEL_PREFETCH_COUNT` overrides). gwbase acks
each message before dispatch, so prefetch changes only how many are in
flight; order holds with one consumer, and an unacked message is
redelivered by prod if the shovel dies.

## 2026-10-11 — gwbase 0.5.16: remove shutdown race (`7958496`, PR #1)

Branch `jm/gwbase-0-5-16`. The pin moves to 0.5.16, whose `stop()` ends
the reconnect loop itself, so the shovel no longer needs a `local_stop`
override for a clean stop. The destination connection is now closed in
`stop()` after the consumer thread has joined: that thread is the
connection's only user, and closing it from the main thread while a
publish could still be running was a shutdown race.

## 2026-10-10 — The shovel: a gwbase tap that mirrors `ear_tx` onto the analytics broker

First commit of the repo (OPS-426). A gwbase `ActorBase` tap on the
source broker, a confirm-mode publishing connection to the destination's
`earmic_tx`, a bounded in-memory buffer for the destination's outages
(oldest dropped), and the destination broker's definitions file. Built
as a service rather than the RabbitMQ shovel plugin so the prod-side
login is a principal with cert and claims through the FIS gate, which
the plugin's client cannot present; nothing shovel-shaped goes into
gwbase, which every actor inherits. Unit tests cover the forwarding
contract with a fake destination; the liveness test runs one message
through the dev broker playing both sides.
