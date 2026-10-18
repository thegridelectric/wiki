# NoData — a tracked house has sent nothing

Status: Draft · Pass 0 · Updated 2026-10-17

> What this is: the `NoData` house alert kind as the alerter raises,
> words and resolves it (`src/gwalerter/no_data.py`): the rule, the
> cause clause, and how it behaves across a broker outage. What is true of every kind (the store, the
> detector tick, the words, the witness bar) is in
> [`primary.md`](primary.md).

## The rule

Every tracked house whose last-heard is older
than `no_data_silence_s` (600) and has no NoData alert open is raised
once, empty evidence, the summary naming the house and its last-heard
time. Last-heard is the store's query floored at the alerter's boot
time, so a fresh alerter gives every house one threshold to speak
before paging. The first report or layout from the house's scada
resolves it with that arrival as evidence (the report's readings;
empty for a layout). Open-alert state is the store's, which is what
makes a restart neither re-raise nor forget. An LTN stop pages about
fourteen minutes after the stop, not ten: the scada's own link timeout
lets one more report out.

Last-heard is the latest report or layout from the house's scada. The
scada publishes a report only while its link to the LTN is active (an
event in its proactor, held on disk otherwise), so a stopped report
means the house's data is not reaching the cloud, whichever side
stopped it; when the LTN returns the held reports come up, which is
why nothing is lost and why the clear names "data again".
The summary names the cause from whether the house's two parties have
been heard at all: the scada (the `.scada` sibling) and the LTN (the
terminal asset's parent alias) are each "speaking" when anything
arrived from them inside `heard_period_s` (60, the expectation that
each is heard at least once a minute) times the Nyquist factor 2.1
(`NYQUIST`, as the scada sizes its own monitored-name timeouts). No
message type is looked at and no per-type cadence is assumed, since
the scada's and LTN's chatter is configurable and will change. Never
the silence threshold, under which a scada dead for nine minutes would
still read as speaking:

| Scada speaking | LTN speaking | Summary clause |
| --- | --- | --- |
| no | either | `scada silent for <d>` |
| yes | no | `ltn silent for <d>; scada does not send up reports with no ltn` |
| yes | yes | `no reports for <d>, scada and ltn both speaking` |

A silent scada reads the same whether or not the LTN is silent too:
the page is about the scada either way, the house side (the pi or its
network; the prober's BrokerUnreachable holds NoData for the MQTT
door). The second row is the LTN process or box, with reports safe on
the scada's disk. The third is a fault between two live parties, the
scada's link never going active or its own report path, on a house
that looks healthy from outside. The rule re-reads the clause on every
tick and, when it moves, rewrites the open alert's `Firing` record in
the store and broadcasts it again under the same `AlertId`. Resolve
names only the return of data.

While the broker is down the rule does nothing: no raise and no
clause update, since `evaluate` returns before the house loop on an
open `BrokerUnreachable`, and the actor skips the tick while it is
not consuming. An open NoData keeps the clause it had and the
`arrivals` rows stop moving. On the broker's return the floor moves,
so nothing new can raise for a full threshold.
