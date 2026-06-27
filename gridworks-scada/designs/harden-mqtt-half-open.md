# harden-mqtt-half-open

Status: Draft · Pass 0 · Updated 2026-06-26 · Linear: OPS-304

**EDD: yes** the bar is a fault-injection experiment — a mid-connection half-open /
blackholed socket — asserting the scada detects + reconnects in **< ~90 s** rather
than the ~15-minute blackhole; not code reading.

> What this is: a **bite-size** hardening of the existing gwproactor MQTT reconnect
> so a half-open / blackholed socket recovers in under ~90 s instead of ~15
> minutes. **Interim** — on the proactor that proactor-makeover
> ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) retires — but the
> blackhole is a live operational risk now. Analysis in
> [`../executor/scada-ltn-link-state.md`](../executor/scada-ltn-link-state.md)
> ("Broker-access liveness — a second, worse gap").

## The incident (2026-02-12)

~19:11 UTC: Maple and Fir stopped delivering MQTT to `hw1-1` while the SCADA loop
ran, ssh worked, the proactor logged normally, and the TCP socket stayed
**ESTABLISHED**. A route/IP change blackholed packets with no TCP RST — the socket
sat **half-open**, paho's loop saw no error. Total blackout ~17 minutes; the broker
closed the connection on missed keepalive at ~19:12, clients reconnected ~19:28.

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
   paho's default applies and the knob does nothing. Half-open *detection* rides
   the keepalive, so it can't be tightened today.
3. Paho's **internal** reconnect (under `loop_forever`) has its own backoff
   (`reconnect_delay_set`, default max 120 s), which governs the
   half-open-while-connected path — also too slow at the 15-minute scale.

## The fix (small, surgical)

- **Cap the outer backoff** at ~30–60 s (not 1024).
- **Wire the keepalive config into** `connect(..., keepalive=self._client_config.keepalive)`
  and lower the default to ~30 s, so a dead socket is detected in tens of seconds.
- **Bound paho's internal reconnect** with `reconnect_delay_set(min_delay=1, max_delay=30)`.
- **Confirm reconnect re-resolves DNS/route** — the trigger was an IP change; paho's
  `connect()` on reconnect re-resolves the host, but verify it under the experiment.

These land in the scada's pinned proactor fork (`v4.1.13+jm1`).

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

## Scope / relates

- **Interim** on the existing proactor; the fundamental decoupled liveness (an
  active broker-reachability probe + the scada↔LTN heartbeat) lands with
  proactor-makeover ([OPS-428](https://linear.app/gridworks/issue/OPS-428)).
- Pairs with the other change-now transport-honesty fixes: `ally.inactive`
  emission ([OPS-317](https://linear.app/gridworks/issue/OPS-317)), poison-messages
  ([OPS-432](https://linear.app/gridworks/issue/OPS-432)).
