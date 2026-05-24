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

## 2026-05-23 — drop obsolete tests; add JournalKeeper smoke tests

**Why:** Most of the existing test suite (`tests/types/`,
`tests/old_types/`, `tests/enums/`, `tests/test_utils.py`) mirrored
modules that the next stage of this refactor deletes. Keeping them
green would have meant either rewriting them against gridworks-base
0.4.0 (wasted effort, since the source files go shortly) or excluding
them with sentinel markers (noise that has to be cleaned up later).
`src/gjk/sema/tests/test_property_format.py` came out for a different
reason: it's a vendored copy of canonical sema's own format-validation
tests; tests for type definitions belong with the type definitions in
`sema/`, not duplicated in every consumer. `src/gjk/__main__.py` +
`tests/test_main.py` were an empty click stub plus a test that
confirmed the stub exited 0 — neither carries any real contract; a
real actor entry point will land with Stage 5's dev-stack smoke. The
new `tests/test_journal_keeper.py` covers the actually-load-bearing
contract — that `dispatch_message` decodes JSON, routes well-formed
SemaTypes to the persistor, swallows malformed JSON without raising
(the live actor must keep running), and skips degraded SemaTypes.

## 2026-05-23 — port journal_keeper.py to SemaCodec + SemaMessagePersistor

**Why:** The live AMQP path and the S3 backfill path were diverged.
The live path used a hand-maintained 18-handler `if/elif` over
`gjk.named_types`; the backfill path (Joe's `s3_message_importer.py`)
already used `SemaCodec.from_dict` + `SemaMessagePersistor`.
Converging both onto the single parse + persist path eliminates the
divergence, lets new types flow through with zero code edits here
(the persistor's `all_known_message_types()` becomes the only source
of truth for what gets bound and persisted), and matches the
construction shape Joe already established. `ActorBase` rather than
`GridworksActor` is the correct base by definition: journalkeeper is
not a GNode actor on the grid — it doesn't participate in
heartbeat/time-coordinator semantics, just persists what crosses the
broker. The in-file S3 utilities went away because
`s3_message_importer.py` does that job; keeping two copies is the
divergence problem in miniature.

## 2026-05-23 — align pyproject with gridworks-base 0.4.0

**Why:** Foundation for the journal_keeper port. The new pika-native
`ActorBase` / `RoutingEnvelope` shape this refactor consumes ships in
gridworks-base 0.4.0; pinning that here was the prerequisite to
landing the port. 0.4.1 / 0.4.2 are failed CI publish attempts with
no functional change — 0.4.0 is what's actually on PyPI. The
hatchling + py3.12-3.14 + classifier choices mirror what
gridworks-base itself uses, so the two repos compose without
toolchain surprises. Lint / style config changes were intentionally
kept out of this commit so the diff is the minimal functional change
needed to consume the new base.
