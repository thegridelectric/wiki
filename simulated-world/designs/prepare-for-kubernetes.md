# Prepare for Kubernetes

Status: Draft · Pass 0 · Updated 2026-11-19 · Linear: OPS-676

**EDD: no** a deployment-shape change; verified by the first service
running as two copies with two identities, each seen connecting through
the FIS gate and writing the archive, one of them stopped and restarted
while the record stays whole.

> What this is: how the platform services move into containers and, in
> time, an orchestrator, and which service goes first.

## Why

The platform is fourteen VMs, most of them one small gwbase actor each,
patched and rebooted one at a time with a person present. Containers
make a service's image the artifact and let several services share a
host; an orchestrator makes "two copies, one restarting" routine. Both
need answers the fleet does not have yet: how many identities a service
with N running copies has, who mints them, how the FIS lease (one cert,
one running instance) meets a replica set, and how much of the GNode
tree a service must know to be placed and spawned.

## The first candidate: the ear

The ear is a non-GNode service. It has no position in the grid and
talks to nobody; it listens to everything and writes the audit archive.
Its one piece of work is an idempotent put: the S3 key is a function of
the message, so two witnesses writing the same object agree. That makes
it the service where several running copies need no coordination, and
where the replica questions can be worked without touching the tree:

- **Identities.** Two copies are two principals (`hw1.ear` and a second
  name) with two certs and two queues, both writing the archive. The
  FIS lease stays one cert, one running instance. Whether a logical
  service gets per-copy names beneath it, or the FIS grows a lease with
  slots, is decided here.
- **Not a GNode.** A GNode is a position in the grid and a party to the
  binding table. Deployment counts are not topology; the tree does not
  learn how many copies something has. The ear becomes tree-shaped only
  when witnesses are scoped per subtree, a witness for this site, and
  that is a later design.
- **Restart without loss.** Today every gwbase actor consumes from an
  auto-delete queue it declares itself, so a reboot loses the gap for
  that consumer. Two copies cover each other's gaps. The queue stays
  ephemeral; see "Queues stay ephemeral".

## Decisions

Three answers to the "Why" questions, settled 2026-11-19 while designing
the Supervisor (OPS-695).

1. **Replicas are principals.** A service with N running copies is N
   identities, each with its own cert and lease, each serving or watching
   a shard. The fabric has no replica set of one identity; the ear's two
   copies above are the first instance of the rule.
2. **Recreate, never RollingUpdate.** Kubernetes' default strategy starts
   the new pod before it stops the old. Under supersession the new pod
   takes the lease and the old one is refused for life, so every workload
   that presents a cert uses the `Recreate` strategy, and a rolling
   deploy is a controlled restart of one identity at a time.
3. **Three owners at the seam.** Kubernetes owns processes: probes,
   restarts, replica counts. FIS owns identity: it admits a pod as one
   GNode or Service. A World service, the Supervisor, owns liveness on
   the fabric, because a probe sees a running pod and not a half-open
   broker link. The Supervisor reads the cluster's roster and reports
   onto the fabric; it never acts on the cluster. Its roster comes from
   the process owner (systemd's infra roster today, a label selector
   under Kubernetes) and never from the registry, which does not know
   where things run.

## Queues stay ephemeral

The data-architecture principle (`gridworks-infra/data-architecture.md`
"Delivery to the record"): a message that must reach the record travels
an acked path and the sender holds it until acked; consumers keep their
auto-delete queues and a gap is covered by a second running copy, never
by a durable queue in the broker. A RabbitMQ queue's properties are fixed
at declaration in any case, so a queue cannot become durable later. For
the ear this means the second copy is the whole answer to "restart
without loss", and it is also the Kubernetes rehearsal.

## The database, last

The journal database comes to the cluster after it has survived a node
loss with the ear on it, not before. It is the one tenant that must
keep its disk, so it exercises persistent volumes, a StatefulSet and an
operator (CloudNativePG with a TimescaleDB image: failover, WAL shipping
to object storage and restores from the manifest) all at once. Two
things gate it:

- **OPS-616 first.** The per-report cost against Tiger (1 to 3 s a
  report, five times the laptop) has not been phase-timed. Its verdict
  says whether the cost is connection setup, the hypertable's index
  check or round trips, and that decides whether closeness to the
  database matters and so where the database and its writers go. The
  move is made for a measured reason or not yet.
- **OPS-680 as the acceptance test.** The database is moved when a
  restore of its backup on the new host has been run and checked. A
  database that cannot be restored there is not moved.

Hosting it ourselves is the plan: Tiger runs only on AWS and Azure, and
the Community edition of TimescaleDB is free to self-host. The S3
eventstore stays the record of truth; the journal stays a projection.

## Plan

Open. Order of work once Accepted: a second ear identity and the second
copy on hw2-1 as the first container and the observer agent (OPS-681)
as the second; the image rebuild and digest check; the shared-host
consolidation; the database last, after OPS-616
and with OPS-680 as its gate.
