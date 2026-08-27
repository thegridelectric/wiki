# Design: S3 importer — target functionality + deferred improvements

> Status: Draft · Pass 0 · Updated 2026-08-26

What this is: where gjk's S3 → `gw_data` import is headed, beyond the robustness
fixes already shipped (empty-date guard, log-and-continue) and the idempotent
`uuid5` ids (`7308766`). Two parts: (1) the **target steady-state ingest
functionality**, and (2) a backlog of **deferred code improvements**.

## Target steady-state functionality

The importer SHALL load the S3 event store into `gw_data` subject to a
configurable **egress lag**: it MUST NOT ingest any data younger than
`today − lag`. The lag is the window in which Efficiency Maine can veto data
egress after a catastrophic event; **set it to 14 days**.

Required behaviors (these are functional requirements — *not* a prescription
that this be a separate CLI/wrapper):

- **Bounded backfill** — load an explicit inclusive UTC date range on demand,
  **clamped** so it can never cross `today − lag`.
- **Rolling steady-state load** — on a schedule, import the single date that has
  just aged past the lag (i.e. `today − lag`), exactly once.
- **Unattended-safe** — log-and-continue past bad objects with a run summary
  (shipped), and idempotent re-runs (`uuid5`, shipped) so a retried date is a
  no-op.
- **Configurable lag** — the 14-day value is a parameter, not a constant baked
  into call sites.

A working reference implementation of the two modes + the lag clamp already
exists on `jm/s3_hack` (currently `s3_analytics_import.py`); it demonstrates the
behavior, but the requirement here is the functionality, not that shape.

> Reconcile: earlier docs / the `jm/s3_hack` reference use a **5-day** lag. The
> intended value is now **14 days** — `gw-data-analytics-deployment.md` and the
> reference implementation should be updated to match.

## Periodic sweep — catch what the live keeper missed

The live keeper misses messages when it is down, when the broker drops it,
or when a type arrives at a version its snapshot cannot decode. All three
are bounded and recoverable from S3, so the importer also runs as a
**sweep**: on a daily timer on gjk, import the rolling window
`[today − lag − 3 days, today − lag]` (the window overlaps itself, so a
sweep that fails one night is covered by the next). Idempotency is the
persistor's property, not the sweep's: with the message-identity table in
place (OPS-502) a sweep over data that is mostly present is a no-op
except for the gaps. Until then the sweep is safe only for types whose
payload carries a created time.

Which types the sweep (and a from-scratch rebuild) load, and from what
floor date, is **a versioned file, not a CLI argument**: one YAML next to
`sema_seed_request.yaml` with a line per type — journaled or not, the
floor date, optionally a version floor — loaded through a `TypeAdapter`.
The `--types` / `~types` flag stays for one-off dev-machine runs. The same
file is what the rebuild recipe in `gridworks-infra/databases/journaldb.md`
points at, so the recipe and the sweep cannot drift; the population start
for a rebuild is 2024-10-13 (OPS-498).

## Deferred code improvements

### 1. Take everything (`msg_types=None`)
Stop filtering by the hardcoded known-type allowlist; let the SemaCodec/snapshot
be the authority on what's storable, and *notice* (log once) any type with no
special handling. **Deferred because** it's a coverage/design choice (the
allowlist works for today's types) entangled with the format→enum spec question
(`sema/spec/authoring/formats.md` — the format→enum closure rule)
and the "notice new types" goal. Decide alongside the snapshot/samples work.

### 2. boto3 region
`boto3.client("s3", region_name=settings.aws.region_name)` — needed only on a box
with no default region (EC2 instance role); a local `~/.aws` already sets one.
**Do when deploying the importer to the `gw-data-analytics` box.**

### 3. Robust filename parse
`name.rsplit("-", 3)` instead of `split("-")`, so an alias/type containing a dash
doesn't silently drop the object. Low likelihood (names are dotted), failure is a
logged skip — purely defensive.

### 4. Bulk-import speed (batch commits)
`SemaMessagePersistor` commits **per message** (`get_db()` per call). A multi-week
backfill = millions of tiny transactions → slow. Improve: batch / commit-per-N
(or COPY-style bulk load), preserving per-message idempotency — the deterministic
`uuid5` ids make a batch safely re-runnable. **Single biggest backfill speedup.**
*Further (unspecced):* parallelize S3 downloads (objects are fetched sequentially).

### 5. Per-day memory / streaming
`find_messages_on_date` materializes the *entire* day's `S3MessageInfo` list
before yielding (needed only for `sort`). On the 2 GB box a high-volume day
pressures memory. Improve: stream for the unsorted / rolling path; materialize
only when a sort is requested. *Further (unspecced):* resumable checkpoint
(persist last-imported key/date; the importer already has a `skip_past` param).

## Sequencing
- Items **2 / 1 / 3** when their triggers arrive: deploy-to-box → 2;
  snapshot/samples + format→enum decision → 1; opportunistic → 3.
- **4** is the priority once the backfill is real and slow; **5** +
  parallelism/checkpoint follow if scale demands.
- The target steady-state functionality is the end goal these support.

## Cross-refs
- **layered-test-harness** (sibling JK design) — the idempotency
  assertion (re-run → no dup) is what lets item 4 batch safely.
- **gw-data-analytics-deployment** (gridworks-data design) — backfill/deployment
  context (and the 5→14 day lag reconcile).
- `sema/spec/authoring/formats.md` (the format→enum closure rule)
  — gates item 1's "store everything" decision.
