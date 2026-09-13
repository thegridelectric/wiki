# Launch Sema (hub)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-538

**EDD: no** build-out; verified by a stranger's walk-through of the front
door and by the consumer checks running green in gwbase and scada CI.

**▶ Active spoke: [`publish-schemas.md`](publish-schemas.md)**

> What this is: what "Sema is launched" means, and the work to get there
> before the 2026–27 heating season. The vision names the launch as one of
> two clear-and-present items: it opens the door for everyone else, people
> and agents alike, to join in their own language. The repo is already
> public and its README already teaches authoring. What is missing is the
> door itself: schema URLs that resolve, a conformance discipline that
> survives our own pace of change, and one page that tells a stranger why
> and how.

## Launched means

A stranger with no contact with us can, on one day:

1. open any `Sema:` schema URL and get the definition it names;
2. read one page that says why the vocabulary exists, how to author a
   word, and how a word gets promoted;
3. vendor a snapshot into their own repo and prove in their CI that it is
   what sema generates;
4. author a word on a topic branch and open a pull request that our
   governance can act on;
5. protect their snapshot with the same tools we use, installed in one
   line, so that the thing a third-party AI adopts by default is the
   thing we trust ourselves.

Everything else (the spec site, the web explorer, a validation API) is
welcome and later.

## Spokes

1. **[`publish-schemas.md`](publish-schemas.md)** serve the published
   vocabulary at `schemas.electricity.works`.
2. [`consumer-conformance.md`](consumer-conformance.md) the sema CLI is a
   published package from `main` that every consumer runs in its own CI;
   pins are package versions, so daily change on `dev` never reaches a
   consumer until it chooses a release.
3. [`snapshot-drift-check.md`](snapshot-drift-check.md) a vendored
   snapshot is provably what sema generates from its pinned commit.
4. [`front-door.md`](front-door.md) the one page for a stranger.
5. Spec site at `spec.electricity.works`: the plan is in
   `../../research/spec-publication.md`; becomes a spoke when it starts.
   May trail the launch.

## Notes

- Draft words are excluded from the public registry by
  `build_public_registry.py`; staging words are mutable and dev-broker
  only; published words are immutable and hash-pinned. The launch serves
  the published subset and nothing else.
- `schemas.electricity.works` does not resolve in DNS today (checked
  2026-09-13); the schema URLs in every generated runtime already point
  at it.
