# scale-strategy starter (gjk lens)

Status: Draft · Pass 0 · Updated 2026-05-27

> Seed notes from the 2026-05-26 integration session. Not a strategy;
> a pin for insights worth keeping before they fade. The proper design
> work is largely a **gridworks-data** question (schema + retention)
> that journalkeeper sits downstream of.

## Three retention tiers, distinguishable by `message_type_name`

The dev `messages` table after the integration test had this row mix
(across multiple sessions accumulating):

| `message_type_name` | Count | Natural retention class |
|---|---|---|
| `snapshot.spaceheat` | 66 | **Minutes then discard** — current value is real-time state; the data is replicated in `report.event` |
| `weather` | 22 | **Years (don't lose)** — irreplaceable historical record once written; ground truth for analytics |
| `report.event` | 6 | **One year then archive** — large payloads, season-relevant; cold-storage after |
| `gridworks.event.problem` | 6 | Likely one-year-then-archive (operational forensics) |
| `power.watts` | 2 | Same as `report.event` — high volume, fades in value |

The "natural retention class" is a property of the type, not of the
message — that's the load-bearing insight. The same shape of table
can serve all three classes if we partition by `message_type_name`.

## Same-shape-different-name proposal (vs. native partitioning)

Two paths to evaluate (this belongs in a `gridworks-data` design
note):

**Option A — partition by name.** Same table shape, different
table names per retention class:

- `messages_hot` — minutes-then-discard (snapshots, fast-fading telemetry)
- `messages_warm` — year-then-archive (reports, problems)
- `messages_long_term` — keep-forever (weather, anything irreplaceable)

The persistor routes by a small `message_type_name → table` map.
Vacuum / drop / archive scripts run per-table on different cadences.
Schema migrations apply identically to all three (same shape).

**Option B — postgres native partitioning by `message_type_name`.**
One logical `messages` table partitioned by type. Retention enforced
by dropping or archiving partitions. Persistor doesn't need to know.

Tradeoffs to think through:
- Option A is simpler operationally but bakes the classification
  into the persistor code path.
- Option B keeps the table conceptually whole, but partition
  management adds DBA complexity and gridworks-data's current
  schema is unpartitioned today.
- Either way, the **classification table** (type → retention class)
  belongs somewhere durable — probably as a sema-side annotation on
  each type, so consumers can't drift.

## Prerequisite: test-isolation discipline must come first

The 66 + 6 + 6 + 2 pre-existing rows in the dev DB were ambient noise
from prior dev-test sessions. None had a "this is a test" marker.
Before any retention strategy is worth implementing, the dev/test
discipline needs:

- **`from_alias` namespacing for test runs.** Tests use
  `d1.test.<test-id>` (or similar). Production aliases never overlap.
- **Targeted teardown by `from_alias`.** Tests `DELETE FROM messages
  WHERE from_alias = 'd1.test.…'` in their teardown — never `TRUNCATE`
  (which would clobber other sessions' work).
- **A scheduled dev-DB cleaner** that drops rows older than N days for
  any `from_alias` matching a `d1.test.%` pattern (catches forgotten
  teardowns).

Without this, retention rules amplify the noise rather than reducing
it.

## Where this belongs eventually

- The retention-tier spec → `wiki/gridworks-data/designs/` (or
  `executor/`) — gridworks-data owns the schema, the routing question
  is theirs.
- The test-isolation discipline → cross-cutting; probably a
  `wiki/designs/` note on dev-DB hygiene.
- This file → distill into one of the above and delete when it's
  done its job.

## Cross-refs

- `wiki/gridworks-journalkeeper/research/findings.md` F-006 (test
  isolation observation) and the broader integration-test write-up.
- `wiki/gridworks-data/` — destination domain for the schema work.
