# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Format:

```
## YYYY-MM-DD — <commit subject line>

**Why:** <the motivation — what problem, constraint, or decision drove
this change; what alternatives were considered; what this unblocks>
```

Newest at the top.

---

## 2026-05-23 — README: clarify postgres setup walkthrough

**Why:** First end-to-end walkthrough of the setup (during the
gridworks-journalkeeper → base 0.4.2 refactor) exposed several friction
points that stopped a fresh reader cold: typo'd IP and script
filename; no concrete `docker run` example; the two interactive
prompts (`\password` in `0_server_init.psql`, `getpass` in
`1_db_seed.py`) were undocumented and broke `psql -f` / piped
execution; only `gw_admin` was mentioned even though the script also
creates `gw_writer` and `gw_reader`; no verify step and no enumeration
of what `alembic upgrade head` produces. The edits replace abstract
instructions with the concrete commands that actually worked, and
hoist Docker/psql/Python prereqs into a single block so the reader
isn't reverse-engineering them from §1/§2.
