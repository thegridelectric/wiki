# Pull ledger: one row per fetch from an outside source

Status: Draft · Pass 0 · Updated 2026-11-16 · Linear: OPS-687

**EDD: no** build-out in the weather service's store, verified by the
suite and one live hour on hw1 whose two fetches and the emissions they
produced trace to pull rows.

## What this is

The weather service's store gains one table, `pulls`: one row per fetch
from an outside source, whether the live loop's hourly fetch or an
archive command's long pull. A row names the Method and SourceLocator,
the kind of pull, the window or the source's own run stamp, when the
fetch started and finished, the code revision (the deployed SHA) of the
service that ran it, what came of it (observations or forecast
emissions published, or the refusal), and for an archive pull the hash
of the command it answered. Today the only trace of a live fetch is the
upserted latest product, overwritten by the next fetch; with the ledger
every emitted forecast and observation traces to a pull row, and the
pull row names the code. Two live pulls an hour is about 17,000 rows a
year.

Method stays a table in the service's code, mapped to one adapter
function and the quantities its product serves; a Method with no
adapter is refused.

## Open

- Whether Method becomes a minted record the pull row references.
- Whether a pull row is also a word broadcast once, so the journal
  holds the provenance beside the readings.
- The columns, as a migration in the service's store.
