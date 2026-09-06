# A day in the life of a connecting scada

Status: Draft · Pass 0 · Updated 2026-09-05

> What this is: what the Fleet Index Service is for, told as one house's
> scada going through a day. Read this before the contract spokes; it is
> written for a person, not a rebuild. Nothing here is normative; the
> hub ([`primary.md`](primary.md)) and the two contract spokes are.

## The problem FIS exists for

Every scada, every leaf transactive node, every market maker and every
platform service talks over one message broker. Each time something
connects, the broker has two questions. Who is this? And should this
particular copy of it be talking right now?

Certificates answer the first question. Each device or service holds a
private key and a certificate naming its durable identity, and the broker
checks the certificate before any message flows. That is ordinary mutual
TLS, and it never changes when the thing is restarted, redeployed, or
renamed.

The second question is the one FIS answers, and it exists because a
certificate names an identity, not a running process. The beech scada is
one identity. On a given afternoon there might be two processes holding
its key: the one on the pi in the basement, and the one someone started on
a laptop to debug, or the old process that a restart did not fully kill,
or the container from the last deploy that is still draining. If two of
them are both reporting temperatures and both answering dispatch, the
house is being run by two brains. Nobody can tell from the data which one
was real. FIS's job is to make sure that never happens: for each identity,
on each run of the system, exactly one process is allowed to speak, and
when a new one arrives the old one is closed and confirmed gone before the
new one is admitted.

There is a second, smaller job. A GNode's name, its alias, is decided by
the registry and can change, while its certificate does not. FIS checks
that what a process says about itself matches what the registry says
today, so a renamed node cannot keep publishing under its old name.

## Morning: beech boots

The beech scada boots on its pi. It has its certificate on disk, whose
common name is beech's GNodeId, and it knows which broker to reach. The
first thing it does is invent a fresh instance id, a random UUID that
names this particular boot and nothing else. Every boot gets a new one.

It opens a TLS connection to the broker and presents its certificate. The
broker validates the certificate against the GridWorks CA and takes the
username from the certificate's common name. No password is sent. The
scada speaks MQTT, and it puts its instance id in the one slot MQTT's
handshake offers, the client id. (An AMQP client such as the weather
service does the same job with a small claims payload carried in the SASL
step: its alias, instance id, run, and class.)

The broker now asks FIS, over localhost, whether to let this connection
in. FIS is told the username, the instance id, and the run the connection
is joining. FIS checks three things in order.

- Is this identity a known principal, and is it active? An identity that
  was never minted, or that an operator has suspended, is refused.
- Has FIS seen this instance id before? If it is the instance that
  already holds beech's lease on this run, this is a reconnect after a
  network blip, and it is let straight back in. If it is an instance that
  was superseded earlier, it is refused, permanently.
- Otherwise this is a new boot. FIS revokes whatever lease beech held on
  this run, tells the broker to close every connection beech still has,
  waits until the broker confirms none remain, records the new lease, and
  only then answers allow. On a normal restart there is nothing to close
  and the whole exchange takes well under a second.

The broker admits the connection. FIS writes down what it decided and why,
as an authorization event, so an operator can later see every admission
and every refusal.

Beech starts publishing. The broker checks each message's sender field
against the connection's identity itself. The first time beech publishes
on a given topic, the broker asks FIS once more: does the from-alias in
this topic match the registry's current alias for this identity? If it
does, the broker remembers the answer for that topic on that connection
and does not ask again. Subscribing is never gated; reading the fleet's
traffic is about visibility, and FIS is about authority.

## Afternoon: the things that go wrong

**A second copy appears.** Someone starts beech's scada on a laptop with a
copy of its certificate. It boots, invents its own instance id, connects.
FIS sees a new instance of an identity that already holds a lease, so it
supersedes: the pi's connection is closed and confirmed gone, and the
laptop is admitted. That is the wrong process winning, but it is the
right rule. The alternative, refusing the newcomer, would make a wedged
old process immortal, and the design chose that the newest boot is the
one that means it. What FIS guarantees is that they never run together,
and that the takeover is visible: the pi's next reconnect attempt presents
its old, revoked instance id and is refused, and both decisions are in the
event log. Two processes fighting over one identity shows up as churn in
that log rather than as silent double-reporting.

**The pi comes back.** The pi's service manager restarts the scada. New
boot, new instance id, supersession again: the laptop is closed and the pi
takes the lease back. Every restart is a supersession, which is why an
empty kill counts as success and a clean restart costs nothing.

**The registry renames beech.** An operator moves beech under a different
feeder, so its alias changes. Nothing about the certificate changes. FIS
learns of the rename from the registry, and because the broker has cached
topic verdicts for beech's live connection under the old alias, FIS has
the broker close the connection. The scada reconnects, looks up its own
current alias in the registry by its GNodeId, and publishes under the new
name. A copy that reconnects still using the old alias is admitted but its
first publish is refused, so a stale node cannot speak under a name that
is no longer its own.

**An emergency.** A house is being decommissioned, or a certificate is
believed stolen. The operator suspends the principal in FIS and has its
connections closed. From then on every connection attempt for that
identity is refused at the gate, whatever instance id it presents.

**FIS is down.** The broker cannot get an answer, so it admits no new
connection. Connections already open keep working. This is deliberate:
the alternative, admitting everyone while the authority is unreachable, is
exactly the double-brain failure the service exists to prevent. FIS lives
on the same box as the broker for this reason, and starts with it.

## What FIS is not

No message passes through FIS. It is not a router, not a data store for
readings, and not a health monitor: it knows who holds authority, not
whether that process is alive this minute. It reads the registry and
answers the broker, and that is the whole of it.
