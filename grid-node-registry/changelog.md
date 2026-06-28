# Changelog

A reverse-chronological log of WHY we made each commit **in the
`grid-node-registry` code repo**. The matching git commit holds the WHAT
(the diff). Each entry's date and one-line title mirror the corresponding
code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki repo's
git history.

Newest at the top.

---

## 2026-06-28 — Reconcile to ids-only connectivity edges + regenerate snapshot (`ae3be8f`)

**What:** Regenerated the vendored Sema snapshot against the edited
`connectivity.edge.gt` (alias fields dropped) and `position.point.gt`, and dropped
the `from_g_node_alias` / `to_g_node_alias` columns and their `to_gt`/`from_gt`
references from `ConnectivityEdgeSql` (`src/gnr/db/models.py`). Imports clean;
snapshot round-trip green.

**Why:** the standup grill ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
settled that edges store **immutable ids only** — alias is derived on read, so a
rename touches zero edges. Mirrors the matching sema edit (see `wiki/sema/changelog.md`).

## 2026-06-27 — Regenerate gnr Sema snapshot off sim-vocab (g.node.gt v004); add seed request + build script (`8402df2`)

**What:** Regenerated the vendored `src/gnr/sema/` snapshot from the sema
repo's `jm/sim-vocab` branch, and added the reproducible regen path:
`gnr_seed_request.yaml` (targets `g.node.gt` · `connectivity.edge.gt` ·
`position.point.gt`; enums by closure) + `build_gnr_snapshot.sh` (drives
`sema snapshot prepare|build --package-name gnr`, rsyncs `output/sema/`
into `src/gnr/sema/`). `g.node.gt` is now **v004**: `GNodeClass` changed
from a closed enum to an axiom-governed open `str`, so the `g.node.class`
enum word dropped out of the closure. The snapshot is now self-describing —
it gained vendored `definitions/`, `indexes/`, `samples/`, `roundtrip.py`.

**Why:** The vendored snapshot dated to Feb and sema's vocabulary had moved
substantially since. Regenerating gives a clean baseline to build the
registry against, and checking in the seed request + build script settles
the "how does the vendored snapshot stay in sync" question (the gwta
pattern, homed in the consumer so the only sema-side write is its gitignored
scratch). Verified: the snapshot round-trip gate passed (3 samples), the
`gnr.sema` package imports cleanly, and no repo code referenced the dropped
enum. To redo once sema settles on `dev`.
