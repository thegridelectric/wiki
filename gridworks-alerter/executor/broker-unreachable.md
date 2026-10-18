# BrokerUnreachable — the prober

Status: Draft · Pass 0 · Updated 2026-10-17

> What this is: the `BrokerUnreachable` platform alert kind and the
> process that raises it, `gwalerter probe`: the one detector that
> reads no broker, because the fault it finds is the broker. What is
> true of every kind is in [`primary.md`](primary.md); how `NoData`
> holds while this kind is open is in [`no-data.md`](no-data.md).

## The prober

`gwalerter probe` (`src/gwalerter/prober.py`) is the alerter's third
process and the one detector that reads no broker. The alerter and the
houses share one broker, so a broker outage is silent on the broker
path: the alerter hears nothing and sees every house as silent at once.
The prober checks the broker's two doors from outside that path, as a
client of each, every `probe_interval_s` (60): an AMQPS round trip on
the `probe_amqp` broker client (connect, declare an exclusive auto-delete queue,
publish one message to it through the default exchange, receive it
back; a connect-only check passes through a memory or disk alarm that
blocks every publisher) and an MQTT connect on `probe_mqtt_host:port`,
the TLS listener the scadas use (handshake, CONNECT, an accepted
CONNACK; the prober has no username or password, its cert and
instance id are its login, and a refused CONNACK is the door shut: what
refuses the prober at the gate, FIS down or the gate broken, refuses
every scada). Both doors present the prober's cert and one instance id,
the AMQPS claims' and the MQTT client id, so the gate leases the prober
once; a client id that is not a uuid4 is refused as malformed, and a
second uuid4 would supersede the first. The
management API is not checked: a third listener that can be up while
both doors are shut. A door that fails `probe_failures_to_raise` (3)
probes running raises one `gw.alert` (`PlatformService`,
`BrokerUnreachable`, `Subject` the door as host:port, never the URL)
into the store with `Store.raise_alert`; the first success resolves it
with `Store.clear_alert`. The prober has no Opsgenie client: the tap
pages the record on its reconcile pass from the store, so the page
arrives within `tap_reconcile_s` with no broker involved. The probe is
made from the alerts box, so a network fault there looks the same as a
broker fault, and the summary says so.

The fleet being heard outranks the probe. Each tick the prober reads
the store's latest arrival from any alias (`Store.latest_arrival`, the
`arrivals` table the actor writes off every envelope); while anything
arrived inside the last `heard_period_s` (60), the broker is moving
the fleet's data whatever the probe found, so a failing door is logged
but not counted, nothing is raised, and an open `BrokerUnreachable`
resolves with a summary saying the fault is the prober's own (its
login, its cert, the box's network). The failures that raise are the
ones running while the fleet is unheard, so "three probes running"
means three minutes of a shut door and a silent fleet together.

While a `BrokerUnreachable` alert is open, the NoData rule raises
nothing, and when the last one resolves the rule moves its last-heard
floor to that moment, as at its own boot. The actor's own hearing is
the other hold, a different fact: the detector thread skips its tick
while the actor is not consuming, and each time consuming starts the
actor moves the same floor to that moment. The two diverge when the
MQTT door is down while AMQPS is up: the actor hears, the houses cannot
speak, and only the prober's alert holds the fleet off paging. A
`NoData` already open stays open and resolves on the house's first
message.
