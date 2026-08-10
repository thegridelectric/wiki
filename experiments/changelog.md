# experiments — changelog

One entry per commit in the `experiments` code repo
(github.com/thegridelectric/experiments); git holds the *what*, this file
the *why*.

Newest at the top.

---

## 2026-08-10 — Semafy experiments (`76eba97`)

**What:** the first two experiment folders become fully sema-typed. All
experiment data rides instances of the new staging vocabulary
(`gw.experiment.run`, `gw.channel.jump.stats`, `gw.channel.noise.stats`,
`gw.readings`) decoded/encoded through the vendored `gwexp` snapshot;
channel words come from the scada's own emitted `layout.lite` in the S3
eventstore; the reader component rides the reinstated
`i2c.thermistor.reader.component.gt/000`. Shared tooling at the root:
`pull_readings.py` (archive → `gw.readings` instance → display CSV),
`naming.py` (spaceheat.name ↔ left.right.dot bijection, dash-grammar
filenames), `unit_encodings.py` (word-driven display conversion),
`stats_display.py`, `ci.sh` (pyright zero-error + emitters reproduce
committed instances byte-for-byte + `sema validate` every instance).
Snapshot regenerated at sema `03e068b`, bringing codec
`expect=` narrowing into `gwexp`; decode call sites use
`from_dict(..., expect=Word)` in place of decode + assert.

**Why:** the database is storage, not truth — meaning lives in the words,
so units, channel identity, and hardware facts are read from sema
instances, never from DB columns or hand-kept copies. Committed data is
sema instances + external evidence only; display CSVs are generated on
demand and gitignored.
