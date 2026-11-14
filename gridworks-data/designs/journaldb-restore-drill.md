# journaldb-restore-drill

Status: Draft · Pass 0 · Updated 2026-11-14 · Linear: OPS-680

**EDD: yes** verified when a restore of the latest backup to a scratch
instance has been run by hand, the backend's and the analysts' queries
return the same rows there as on the live database, and the date,
duration and findings are written in `gridworks-infra/databases/journaldb.md`.

> What this is: the habit that makes owning the journal database safe,
> wherever it is hosted. A backup nobody has restored is a hope; the
> drill turns it into a measured fact, on a schedule, with the same
> check each time.

## Why

The journal database is a projection: the record of truth is the S3
eventstore, and the journalkeeper can rebuild the journal from it. That
makes an outage survivable, but a rebuild from the archive is hours of
replay, and a restore from a backup is minutes. The difference only
exists if the restore works, and the only way to know is to have done
it. Today the backup and point-in-time-recovery settings of the Tiger
service are unknown (OPS-504 "Backups and access"), nobody has restored
one, and the database is about to be moved off AWS (OPS-676 names the
cluster as its eventual home). The drill is the acceptance test for
that move: a database that cannot be restored on the new host is not
moved.

## The drill

One person, one afternoon the first time, under an hour once practised.

1. **Restore** the latest backup to a scratch instance. On Tiger: a
   new service from the backup in the console, or a point-in-time
   fork. On a self-hosted Postgres: `pgbackrest restore` or `wal-g
   backup-fetch` into a fresh data directory on a scratch box. Note the
   wall-clock time from start to a connectable database.
2. **Check** the restored instance with the queries that matter, each
   with its result on the live database beside it:
   - the row count and the latest timestamp in `gridworks.messages`
     and in each readings table;
   - the hourly pull for one house over the last day
     (`experiments/spot-check-recipe.md`);
   - one report page's query set from the web backend, or its
     `gw_data` equivalent.
   Rows older than the backup's point in time match exactly; rows
   after it are absent on the restore and that gap is written down.
3. **Record** in `journaldb.md`: the date, the backup's point in time,
   the restore duration, the checks and their verdicts, anything that
   surprised. Then drop the scratch instance.
4. **Repeat** monthly, and once more on any day the database changes
   host or major version.

## Open

- Whether the check queries become a script in gridworks-data that
  runs against two URLs and prints one table (likely; the second drill
  decides).
- Who holds the Tiger console login for the first drill (OPS-504 says
  nobody does today).
- The schedule's home: a dated line in `journaldb.md` and a nudge in
  the session-start hooks when the last drill is older than five weeks.

## Plan

Open. Order of work once Accepted: the first drill on Tiger by hand;
the check script; the schedule and its nudge.
