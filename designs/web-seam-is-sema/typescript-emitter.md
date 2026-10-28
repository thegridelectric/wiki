# The TypeScript emitter

Status: Draft · Pass 0 · Updated 2026-10-28

> What this is: the sema emitter that writes a consumer's TypeScript
> snapshot, so the browser vendors its vocabulary the way the backend
> vendors its Python one. It starts from the hand-written zod schemas of
> `realtime-units.md`, which are its acceptance fixture.

## The bar

The emitter is done when, run against the seed request the browser
keeps, it reproduces the hand-written schemas in
`gridworks-web-frontend/src/sema/` and their tests pass unchanged, and
when a word that changes in sema reaches the browser by regenerating the
snapshot, the way `regen_sema_snapshot.sh` does for the Python consumers.

## Where it is built

On the `jm/ts` branch of sema, under the rule in
`wiki/conventions/sema-CLAUDE.md` "The TypeScript runtime is a work in
progress": the branch changes nothing under `definitions/`, and its
whole scope is accurate and stylistically correct TypeScript generation,
with Vitest and zod as sema's dependencies for it. The TypeScript
runtime is a sibling of the Python one: generated from the same seed
request and dependency closure, by a generator beside
`src/sema/tools/runtime_generation/`, with a TypeScript round-trip over
`samples/` in sema's own suite.

## Shape

- Output per word: a zod schema and the inferred type, PascalCase wire
  names, `Sema: <schema_url>` as the only docstring, axioms as named
  refinements (`checkAxiom<n>`). Output per enum: a zod enum. Formats
  become zod refinements from `definitions/formats/`.
- The browser's snapshot folder is `src/sema/`, generated whole; the
  hand `.d.ts` files go as their words are emitted.

## Open

- Versions: whether the browser's snapshot pins one version per word, as
  the Python consumers do, or reads a range (the real-time page reads
  `layout.lite` 011 through 013 today).
- Where the generated tests come from: emitted alongside the schemas
  from the sema samples, or kept by hand per consumer.
- The ordering of this spoke against the functional-name vocabulary.
