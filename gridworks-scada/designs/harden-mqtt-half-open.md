# harden-mqtt-half-open

Status: Accepted · Pass 1 · Updated 2026-10-11 · Linear: OPS-304

**EDD: yes** the bar is two experiments: a fault-injection run (a mid-connection
half-open / blackholed socket) asserting the scada detects + reconnects in
**< ~90 s** rather than the ~15-minute blackhole, and a broker outage asserting the
MQTT fleet returns within the cap and spread out
(`experiments/2026-10-11-prod-broker-outage-drill/`); not code reading.

> What this is: a **bite-size** hardening of the existing gwproactor MQTT reconnect
> so a half-open / blackholed socket recovers in under ~90 s instead of ~15
> minutes. **Interim** — on the proactor that proactor-makeover
> ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) retires — but the
> blackhole is a live operational risk now. Analysis in
> [`../executor/scada-ltn-link-state.md`](../executor/scada-ltn-link-state.md)
> ("Broker-access liveness — a second, worse gap").

## Do this now: cap both backoffs at 30 s

The interim, ahead of jitter and keepalive: bound how long a link sits idle
after the broker is back. In `gridworks-proactor`, on a `jm/` branch off `dev`
(which has `v4.1.13+jm3`), in `gwproactor/links/mqtt.py`:

1. **Local tests first; both fail on today's code.**
   - *Never-connected link.* A link pointed at a port with nothing listening
     goes through the outer loop on every attempt; assert no wait between
     attempts exceeds 30 s (today 2, 4, 8 … 1024 s).
   - *Dropped link.* A connected link whose connection the test severs and then
     refuses (a local forwarding socket between the client and the test
     broker); assert paho's retries are never more than 30 s apart (today
     1 → 120 s).
2. **The fix.** `self._client.reconnect_delay_set(min_delay=1, max_delay=30)`
   after the client is built, and `max_back_off = 30` in `_client_thread`.
   Nothing else in the loop changes.
3. **Proactor CI green, then tag `v4.1.13+jm4`** and push.

Then scada repins to `jm4` and the fleet picks it up through a normal
deploy; that step follows scada's own care rules and is not part of this one.

## The incident (2026-02-12)

~19:11 UTC: Maple and Fir stopped delivering MQTT to `hw1-1` while the SCADA loop
ran, ssh worked, the proactor logged normally, and the TCP socket stayed
**ESTABLISHED**. A route/IP change blackholed packets with no TCP RST — the socket
sat **half-open**, paho's loop saw no error. Total blackout ~17 minutes; the broker
closed the connection on missed keepalive at ~19:12, clients reconnected ~19:28.

## The prod-broker outage drill (2026-10-11)

A planned stop of the prod broker, listeners down 9 min 20 s, timed every
client's return from the broker log
(`experiments/2026-10-11-prod-broker-outage-drill/`, README "Found" 3–4). The
gwbase (AMQP) services were back within 30 s of startup. The MQTT clients waited
46–49 s after a broker that was already accepting, then arrived in lockstep:

> all six LTNs connected at 18:28:12 within
> 42 ms of each other

and four scadas within 2.2 s after them, from five networks. That is paho's
default internal backoff (smoking gun 3 below) with every client in phase, since
all lost the broker at the same instant: 1+2+4+8+16+32+64 = 127 s, then 120 s
steps; 18:18:05 + 607 s = 18:28:12. The outer 1024 s loop was not exercised;
every client was connected when the broker stopped.

## What the code does today

`gwproactor/links/mqtt.py` `_client_thread`:

```python
self._client.connect(self._client_config.host, port=...)   # keepalive NOT passed
self._client.loop_forever(retry_first_connection=True)
...
max_back_off = 1024
backoff = min(backoff * 2, max_back_off)                   # 1→2→4→…→1024 s  (~17 min)
```

Smoking guns:

1. **The outer reconnect backoff caps at `1024 s` (~17 min).** After repeated
   failed reconnects (route still blackholed), the next attempt is delayed up to
   ~17 min — matching the observed blackout.
2. **The `keepalive: int = 60` config is dead** — `connect()` never passes it, so
   paho's default applies and the knob does nothing. Half-open *detection* depends
   on the keepalive, so it can't be tightened today.
3. Paho's **internal** reconnect (under `loop_forever`) has its own backoff
   (`reconnect_delay_set`, default max 120 s), which governs the
   half-open-while-connected path and every reconnect after a broker outage.
   It has no jitter, so clients that dropped together retry together.

## The fix (small, surgical)

- **Cap the outer backoff** at ~30–60 s (not 1024).
- **Wire the keepalive config into** `connect(..., keepalive=self._client_config.keepalive)`
  and lower the default to ~30 s, so a dead socket is detected in tens of seconds.
- **Bound paho's internal reconnect** with `reconnect_delay_set(min_delay=1, max_delay=30)`.
- **Add full jitter** to the reconnect wait: each wait is random between 0 and the
  current step, the step doubling from 1 s to the 30 s cap. Paho has no jitter
  option, so the proactor drives its own reconnects (one backoff for a dropped link
  and a link that never connected) instead of `loop_forever`'s internal retry; the
  `reconnect_delay_set` line above is the one-line interim until it does. Jitter is
  for the broker and everything behind a login: each MQTT reconnect is a TLS
  handshake, a FIS gate lease check, a session with its subscriptions restored and
  the scada's held reports flushed, and a fleet in phase delivers all of that in
  the same second, every step, to a broker that may be struggling after a restart.
  The cap shortens the return; the jitter spreads it (200 clients across 30 s is
  about 7 logins a second).
- **Confirm reconnect re-resolves DNS/route** — the trigger was an IP change; paho's
  `connect()` on reconnect re-resolves the host, but verify it under the experiment.

These go in the scada's pinned proactor fork (`v4.1.13+jm3` today).

## The EDD experiment (the verification bar)

Inject a paho/socket stub that **succeeds, establishes, then silently blackholes
mid-connection** — writes succeed into the void, no reads, no RST (the half-open
case). Assert:

- the scada **detects** the dead link (keepalive timeout) within ~one keepalive
  interval, and
- **reconnects** (to a restored route) in **< ~90 s**, not minutes.

Run on the **old** settings (reproduce the ~15-min blackhole) and the **new** ones
(bounded recovery) — the experiment is what tells us whether the outer 1024 s loop
or paho's internal retry produced the 15 minutes. Keep the harness as the
re-runnable reproducer behind the eventual `Verified` stamp.

**The outage case.** Local test first: against the test broker, stop the broker
under a few connected links and assert every one returns within the cap of the
restart and not all in the same second; start a link with the broker down and
assert it connects within the cap of the broker coming up (today's outer loop can
wait up to 1024 s). Both fail on today's code. Then a dev-broker run with a set of
proactor clients, read off the broker log as the drill's `views.py reconnects`
does, and a re-run of the prod drill (`runbook.sh` in the drill folder).

## Scope / relates

- **Interim** on the existing proactor; the fundamental decoupled liveness (an
  active broker-reachability probe + the scada↔LTN heartbeat) comes with
  proactor-makeover ([OPS-428](https://linear.app/gridworks/issue/OPS-428)).
- Pairs with the other change-now transport-honesty fixes: `ally.inactive`
  emission ([OPS-317](https://linear.app/gridworks/issue/OPS-317)), poison-messages
  ([OPS-432](https://linear.app/gridworks/issue/OPS-432)).
