# EC2 security-group cleanup

Status: Draft · Pass 0 · Updated 2026-07-08 · Linear: OPS-447

**EDD: no** infra remediation; verified per tier by re-surveying the live
account (`aws ec2 describe-security-groups` + connectivity checks against each
affected service), not a standalone experiment.

> What this is: remediation of the AWS account's security groups and launch
> templates, surveyed 2026-07-06. Deliberately its own design — every change
> here MAY impact a running service, so each tier is staged and verified
> against the services it touches. New builds (the gnr deployment) do NOT wait
> on this: they get purpose-built minimal groups (see the
> stand-up-grid-node-registry populate-and-deploy spoke).

## Findings (2026-07-06 survey)

- **Five internet-open Postgres instances.** The `postgres` SG
  (sg-08f19d34eccc52fc5) allows 5432 from `0.0.0.0/0` on JournalDb, PriceDb,
  observatory, and gw-data-analytics; BackofficeDb sits on `launch-wizard-3`
  (sg-000cacb02983d216f) with 5432 + 22 world-open. Password auth is the only
  barrier.
- **`ssh inbound` (sg-0e95a59c5283950f2) is a kitchen-sink on 16 interfaces.**
  Despite the name it opens 22, 80, 443, 8000, and 8080–8090 to the world and
  is attached to nearly every instance — including the atn/ltn boxes and the
  Timescale machines that serve no web. Anything listening on 8000 on any of
  those boxes is public.
- **The fleet broker (hw1-1.electricity.works, `RabbitMQ` SG) over-exposes.**
  TLS ports (5671/8883/15671) world-open is required — homes connect from
  residential dynamic IPs. But epmd 4369, inter-node 25672, plaintext AMQP
  5672, plaintext MQTT 1883, and the management UI on plain-HTTP 15672 are
  also world-open.
- **Seven orphan SGs** (attached to nothing): launch-wizard-1, launch-wizard-2,
  gni-apps, platform-apps, shadow-ear, "All outbound", and the default SG
  (which carries a stray RDP rule).
- **12 launch templates, 2021–2024**, several named for the legacy world
  (WorldCoordinator, Supervisor, WorldRabbit, CloudAtn). Clutter, not risk.

## Plan (tiers, each staged + verified independently)

1. **Lock down Postgres.** Replace the world-open 5432 rules with: admin IP(s)
   + SG-references from the specific consumer services. Per-instance check
   before/after: which services actually connect to each DB (JournalDb,
   PriceDb, BackofficeDb, observatory, gw-data-analytics) and from where —
   this is the tier most likely to break something quietly, so one instance
   at a time.
2. **Split `ssh inbound` into role groups** (e.g. `admin-ssh` 22-from-admin,
   `web-public` 80/443, `internal-api` 8000-range from inside the VPC), then
   re-attach per instance by actual role and delete the kitchen-sink. The
   web-serving boxes (web-backend, visualizer, certbot) keep public 80/443;
   nothing else does.
3. **Close the broker's non-TLS surface**: restrict 4369/25672 to the VPC,
   15672 + 1883 + 5672 to admin/VPC. Verify fleet connectivity (TLS ports)
   after each rule change — the six homes are live on this broker.
4. **Delete the orphan SGs** and the default SG's RDP rule.
5. **Prune stale launch templates** (owner confirms which names are dead).

## Constraints

- One tier at a time; re-survey + service-connectivity verification after
  each; every change reversible (note the prior rule before removing it).
- The fleet broker tier (3) touches live homes — schedule with awareness of
  heating-season criticality (summer is the window).
- Admin access assumptions (whose IPs may SSH) need the owner's call before
  tier 2.
