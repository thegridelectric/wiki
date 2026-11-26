# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-proactor` code repo** (our fork of SmoothStoneComputing's
gridworks-proactor). The matching git commit holds the WHAT (the diff).
Each entry's date and one-line title mirror the corresponding code-repo
commit.

This changelog does NOT track wiki edits — those live in the wiki repo's
git history.

Newest at the top.

---

## 2026-11-25 — One jittered reconnect schedule and a 30 s keepalive (`e16a032`, jm/cap-mqtt-backoff, OPS-304)

The proactor owns every reconnect. Paho's own retry inside
`loop_forever` is off (`reconnect_on_failure=False`), so a dropped link
returns to the client thread and takes the same schedule as a link that
never connected: `ReconnectBackoff`, full jitter, each wait random in
[0, step], the step doubling from 1 s to the 30 s cap and staying
there, reset by an accepting CONNACK. The jitter is for the broker and
everything behind a login: the 2026-10-11 drill brought six LTNs back
within 42 ms of each other, each a TLS handshake, a FIS lease check and
a flush of held reports, because paho's schedule has no jitter and the
whole fleet lost the broker in the same second. The reset is new too:
the old loop never reset on success, so a link that struggled at boot
kept its long waits for a drop days later. The configured keepalive now
reaches `connect()` (it never did; paho ran its own 60 s default) and
the default is 30 s, so a half-open socket is noticed within a minute
instead of two, and the whole recovery fits the design's ~90 s. Tests:
the schedule's bounds, cap, reset and per-link difference; the
never-connected link's recorded waits; the configured keepalive handed
to `connect()`; a forced drop against the test broker reconnecting
through the client thread's schedule, once, from step 1.

## 2026-11-25 — Cap MQTT reconnect waits at 30 s on both retry paths (`f06de54`, jm/cap-mqtt-backoff, OPS-304)

A link whose broker is unreachable retried on two schedules, each able
to leave the link idle long after the broker was back: the client
thread's outer loop doubled its wait up to 1024 s for a link that never
connected (the 2026-02-12 Maple and Fir blackout, ~17 min comms-dead),
and paho's reconnect inside `loop_forever` doubled up to 120 s for a
link whose connection dropped (the 2026-10-11 prod-broker drill, every
LTN back 46–49 s after the broker). Both caps are now 30 s, from one
module constant; nothing else in the loop changes. Two tests fail on
the old code: the outer loop's recorded waits exceed 30 s, and paho's
configured cap reads 120 s. Jitter and the keepalive wiring stay with
OPS-304; this is the interim bound. Version `4.1.13+jm4` with the lock
refreshed, for scada to repin.

## 2026-10-08 — Bump version to 4.1.13+jm3

Scada pins the fork by git tag, so the client_id change needs a new tag
to reach a box; `v4.1.13+jm3` names `dev` with `jm/mqtt-client-id`
merged. `uv.lock` is left as is, as at `+jm2`.

## 2026-10-08 — The upstream MQTT client_id is a per-process instance id (OPS-422)

FIS reads the MQTT `client_id` as the GNodeInstanceId and denies any
value that is not a uuid4, so the segment-stripped random id the MQTT
link sent would have shut every house out once the gate goes on. The
proactor now mints one uuid4 at construction (`Proactor.instance_id`),
and the upstream link presents it at CONNECT, unchanged across
reconnects. Fresh per boot on purpose: two scadas started on one pi
each mint their own, FIS supersedes the earlier lease, and the loser's
reconnects stay denied rather than the pair flapping. Only the upstream
link carries it; each other link mints its own uuid4, because a broker
drops the existing session when a second CONNECT arrives with the same
`client_id`, and the scada's local and admin links share the pi's
mosquitto (the tree tests failed with one id on three links).
`tests/test_proactor/test_comm/test_mqtt_client_id.py` pins it.

## 2026-09-05 — Bump version to 4.1.13+jm2

Scada pins the fork by git tag, so the CONNACK fix needs a new tag to
reach a box; `v4.1.13+jm2` names the merge of `jm/connack-reason-code`
into `dev`. `uv.lock` is left as is: it already lags the `+jm1` bump,
and the local uv (0.7.14) writes an older lock revision than the file
carries, so refreshing it here would churn the lock for nothing.

## 2026-09-05 — A refused CONNACK is a connect failure, logged with its reason code

The honeysuckle DAC bench (2026-09-05) ran the scada's admin link with
the wrong password key in `.env`. The link logged `connecting --
mqtt_connected --> awaiting_setup_and_peer` and then dropped, every
paho reconnect cycle, with no line naming the cause. Root: paho calls
`on_connect` on every CONNACK, refusals included, and the wrapper in
`gwproactor/links/mqtt.py` queued an `MQTTConnectMessage` without
looking at the reason code; `LinkManager.process_mqtt_connected` then
moved the state machine, emitted a `mqtt.connect` comm event, and
subscribed on a socket the broker was about to close.

Now the wrapper branches on `reason_code.is_failure`: a refusal queues
an `MQTTConnectFailMessage` carrying the reason code (the payload's
`rc` is `None` only for failures below MQTT, no socket, no CONNACK),
and the socket close that follows a refusal is not reported as a
disconnect (paho never reached connected either; the `Connecting`
state rejects `mqtt_disconnected`). `process_mqtt_connect_fail` now
logs the transition with the reason (`CONNACK refused: Not authorized
(rc 135)`; the code is paho's MQTT v5 mapping of CONNACK 5) and emits
gwproto's `MQTTConnectFailedEvent`, which existed unused. No new state
or transition: the refusal rides the existing
`connecting -- mqtt_connect_failed --> connecting`.

Test: `tests/test_proactor/test_comm/test_connect_refused.py` spawns a
private mosquitto with a password file on an ephemeral port (the shared
1883 test broker allows anonymous clients, so a wrong password is
accepted there), connects the dummy child with a bad password, and
asserts no `mqtt.connect` event, state stays `connecting`, and the
child's `proactor.log` names the refusal. Skips when mosquitto is not
on the PATH. Also verified with the local scada's admin link against a
password-protected mosquitto, wrong then right password (the
spruce-unlimbo design records the run).

Local suite note: the comm tests default to TLS on 8883 as CI runs
them; locally that port is held by Docker and every client raised on
connect. The gitignored `tests/.env-gwproactor-test` turns TLS off,
but its variable names used prefixes no settings class reads
(`GWCHILD_`, `GWPARENT_`); the dummy apps read `PROACTOR_APP_` and the
tree admin `GWADMIN_`. With the seven correct names the full suite
passes locally against the anonymous broker on 1883.
