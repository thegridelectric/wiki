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
