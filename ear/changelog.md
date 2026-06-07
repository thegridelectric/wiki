# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-ear` code repo**. The matching git commit (in
`gridworks-ear`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2024-11-01 — update to better mqtt version (`1a3ce0d`)

**What:** Bumps `gridworks-base` from `^0.2.3` to `^0.2.4` in
`pyproject.toml` (regenerating `poetry.lock` to match) and adds an
operations section to `README.md` — how to SSH into the prod ear instance
(`hw1-1-s3-ear.electricity.works` via `gridworks-main.pem`), the `ear
service` commands, and where the live `state.txt` log tails
(`~/.local/state/gridworks/ear/log`).

**Why:** gridworks-base 0.2.4 carries the improved MQTT support ("better
mqtt version"); pinning it lets ear consume the newer broker behaviour. The
README ops notes capture the prod runbook inline so an operator doesn't
have to rediscover the instance + log locations. Pre-dates the current wiki
convention by a year — logged now as part of the changelog cleanup so the
repo's dormant HEAD resolves to an entry.
