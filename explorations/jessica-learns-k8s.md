# Learning Kubernetes

Status: Draft · Pass 0 · Updated 2026-11-14

> What this is: a learning note, kept apart from the actionable plan
> (OPS-676, which says what gets built and in what order). This file is
> for what the cluster teaches and how the pieces fit, written for the
> person learning it. Not normative.

## Names

"Kubernetes" is spelled k8s (a k, eight letters, an s). k3s is one
distribution of it: a single binary, light enough for a Pi, with the
same API as the full thing. k3s is what a two-to-five node GridWorks
cluster would run; the concepts below are Kubernetes and do not depend
on the distribution.

## What the cluster teaches

Every item here is a concept the database, the ear, the broker and
everything after reuse. Learning them once on the first tenant is the
whole reason the database becomes small later.

- **Declared state and reconciliation.** You write what should exist
  (two copies of the ear, one Postgres primary with a replica); the
  cluster works to make it so and keeps working as nodes fail. This is
  the one idea everything else hangs off: nothing is "started", it is
  declared, and the system converges.
- **Pods and the two kinds of workload.** A pod that can be killed and
  rescheduled anywhere (the ear: stateless, idempotent writes to S3) and
  a pod that must keep its disk and its identity (a database). The first
  kind is a Deployment; the second is a StatefulSet, and most of what is
  hard in Kubernetes lives in the second kind.
- **Persistent volumes and storage classes.** Where a pod's disk comes
  from, what happens to it when the pod moves, and which disks are fast
  local ones that die with the node versus network ones that follow the
  pod. On Hetzner the storage class is their block volumes.
- **Secrets and config.** The `.env` files on the boxes become Secrets
  and ConfigMaps; the certificate a service presents is a Secret mounted
  into one pod, which is the one-cert-one-program rule made structural.
- **Services and ingress.** How a pod gets a stable name inside the
  cluster and how traffic from outside reaches it; the Caddy-on-each-box
  pattern becomes one ingress.
- **Operators.** A program that runs inside the cluster and knows how to
  run one kind of thing well: CloudNativePG for Postgres does failover,
  WAL shipping to object storage and restores from a declared manifest.
  Reading an operator's manifest is the test of whether the concepts
  above are understood.
- **Observing something you did not write.** `kubectl` describe, logs
  and events on a pod that is not healthy; where the cluster's own
  logs are. This replaces `journalctl -u` on a box and is the daily
  skill.
- **Images and rebuilds.** A service runs from an image at a digest, not
  from a checkout at a SHA; the rebuild and the digest check in OPS-676
  are this concept.

## What it does not teach

Postgres itself. Why a 900-row insert costs 1 to 3 s (OPS-616) is a
database question whoever hosts it, and the cluster does not answer
it. Backups that have been restored (OPS-680) are a habit, the same
on a plain box.

## Order to learn in

1. k3s on one box with the ear's second copy as the first tenant
   (OPS-676): Deployment, Secret, logs.
2. A second node and a node loss on purpose: reconciliation seen.
3. A volume-backed pod that survives a move: StatefulSet, storage.
4. The Postgres operator with a restore drill (OPS-680) as the test.
